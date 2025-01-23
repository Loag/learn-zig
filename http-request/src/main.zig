const std = @import("std");
const print = std.debug.print;

const HttpClient = struct {
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator) HttpClient {
        return HttpClient{ .allocator = allocator };
    }

    pub fn get(self: HttpClient, request: []const u8) ![]const u8 {
        const host_and_request = try self.split(request);

        const host = host_and_request.host;
        const request_str = host_and_request.request;

        const req: []const u8 = try std.fmt.allocPrint(self.allocator, "GET {s} HTTP/1.1\r\nHost:{s}\r\nConnection: close\r\n\r\n", .{ request_str, host });

        const ip = try self.get_ip(host);

        const stream = try std.net.tcpConnectToAddress(ip);
        defer stream.close();

        var writer = stream.writer();
        const size = try writer.write(req);

        print("Sending:\n '{s}'\ntotal written: {d} bytes\n\n", .{ req, size });

        const buf = try self.allocator.alloc(u8, 1024);

        while (true) {
            var reader = stream.reader();
            const sz = try reader.read(buf);
            if (sz != 0) {
                break;
            }
        }

        return buf;
    }

    fn split(self: HttpClient, request: []const u8) !struct { host: []const u8, request: []const u8 } {
        var result = std.ArrayList([]const u8).init(self.allocator);

        for (request, 0..) |c, i| {
            if (c == '/') {
                try result.append(request[0..i]);
                try result.append(request[i..request.len]);
                break;
            }
        }

        if (result.items.len == 2) {
            return .{ .request = result.pop(), .host = result.pop() };
        }

        return .{ .host = "", .request = "" };
    }

    fn get_ip(self: HttpClient, host: []const u8) !std.net.Address {
        const ips = try std.net.getAddressList(self.allocator, host, 80);
        defer ips.deinit();

        return ips.addrs[0];
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const client = HttpClient.new(allocator);

    const req = "jigsaw.w3.org/HTTP/ChunkedScript";

    const res = try client.get(req);

    print("Received:\n {s}\n", .{res});

    allocator.free(res);
}
