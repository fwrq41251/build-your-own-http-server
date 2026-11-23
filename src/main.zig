const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", 4221);
    var server = try address.listen(io, .{
        .reuse_address = true,
    });
    defer server.deinit(io);

    const stream = try server.accept(io);
    defer stream.close(io);
    try println(io, "client connected!");

    const request = try parseHttpRequest(io, stream);

    const url = request.path;
    if (std.mem.eql(u8, url, "/")) {
        const response = HttpResponse{
            .status_code = 200,
            .reason_phrase = "OK",
            .headers = std.StringHashMap([]const u8).init(std.heap.page_allocator),
            .response_body = "Hello, World!\n",
        };
        try sendHttpResponse(io, stream, response);
    } else {
        const response = HttpResponse{
            .status_code = 404,
            .reason_phrase = "Not Found",
            .headers = std.StringHashMap([]const u8).init(std.heap.page_allocator),
            .response_body = "404 Not Found\n",
        };
        try sendHttpResponse(io, stream, response);
    }
}

fn sendHttpResponse(io: std.Io, stream: std.Io.net.Stream, response: HttpResponse) !void {
    var write_buffer: [4096]u8 = undefined;
    var writer = stream.writer(io, &write_buffer);

    // Write status line
    try writer.interface.writeAll("HTTP/1.1 ");
    try writer.interface.print("{d}", .{response.status_code});
    try writer.interface.writeAll(" ");
    try writer.interface.writeAll(response.reason_phrase);
    try writer.interface.writeAll("\r\n");

    // Write headers
    var header_it = response.headers.iterator();
    while (header_it.next()) |header| {
        try writer.interface.writeAll(header.key_ptr.*);
        try writer.interface.writeAll(": ");
        try writer.interface.writeAll(header.value_ptr.*);
        try writer.interface.writeAll("\r\n");
    }
    try writer.interface.writeAll("\r\n"); // End of headers

    // Write body
    if (response.response_body.len > 0) {
        try writer.interface.writeAll(response.response_body);
    }

    try writer.interface.flush();
}

fn println(io: std.Io, message: []const u8) !void {
    try std.Io.File.writeStreamingAll(std.Io.File.stdout(), io, message);
    try std.Io.File.writeStreamingAll(std.Io.File.stdout(), io, "\n");
}

const HttpResponse = struct {
    status_code: u16,
    reason_phrase: []const u8,
    headers: std.StringHashMap([]const u8),
    response_body: []const u8,
};

const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    HEAD,
    OPTIONS,
    PATCH,
};

const HttpRequest = struct {
    method: HttpMethod,
    path: []const u8,
    version: []const u8,
    headers: std.StringHashMap([]const u8),
    request_body: []const u8,
};

fn parseHttpRequest(io: std.Io, stream: std.Io.net.Stream) !HttpRequest {
    var read_buffer: [4096]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);

    //parse request line
    const request_line = try reader.interface.takeDelimiterExclusive('\n');

    if (request_line.len == 0) {
        return error.InvalidRequest;
    }
    var parts = std.mem.splitScalar(u8, request_line, ' ');
    const method_str = parts.next() orelse return error.InvalidRequest;
    const path = parts.next() orelse return error.InvalidRequest;
    const version = parts.next() orelse return error.InvalidRequest;
    if (parts.next() != null) {
        return error.InvalidRequest;
    }

    const method = std.meta.stringToEnum(HttpMethod, method_str) orelse
        return error.InvalidMethod;

    //parse headers
    var headers = std.StringHashMap([]const u8).init(std.heap.page_allocator);
    while (true) {
        const header_line = try reader.interface.takeDelimiterExclusive('\n');
        if (header_line.len == 0) {
            break; // 空行表示请求头结束
        }
        const colon_index = std.mem.indexOf(u8, header_line, ":") orelse return error.InvalidHeader;
        const key = header_line[0..colon_index];
        const value = std.mem.trim(u8, header_line[colon_index + 1 ..], " ");
        try headers.put(key, value);
    }

    //parse body
    var request_body: []const u8 = "";
    if (headers.get("Content-Length")) |content_length_str| {
        const content_length = try std.fmt.parseInt(u64, content_length_str, 10);
        request_body = try reader.interface.take(content_length);
    }

    return HttpRequest{
        .method = method,
        .path = path,
        .version = version,
        .headers = headers,
        .request_body = request_body,
    };
}
