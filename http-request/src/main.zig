const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const request_str = "GET /HTTP/ChunkedScript HTTP/1.1\r\nHost: jigsaw.w3.org\r\nConnection: close\r\n\r\n";

    const ips = try std.net.getAddressList(allocator, "jigsaw.w3.org", 80);
    defer ips.deinit();

    const ip = ips.addrs[0];

    const stream = try std.net.tcpConnectToAddress(ip);
    defer stream.close();

    var writer = stream.writer();
    const size = try writer.write(request_str);

    print("Sending '{s}', total written: {d} bytes\n", .{ request_str, size });

    var buf: [1024]u8 = undefined;

    while (true) {
        var reader = stream.reader();
        const sz = try reader.read(&buf);
        if (sz != 0) {
            const read_slc = buf[0..sz];
            const received_string = std.mem.sliceAsBytes(read_slc);

            try std.io.getStdOut().writer().print("Received: {s}\n", .{received_string});
            break;
        }
    }
}
