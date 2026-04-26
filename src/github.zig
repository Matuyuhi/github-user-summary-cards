const std = @import("std");
const Io = std.Io;
const Writer = std.Io.Writer;

pub const Response = struct {
    parsed: std.json.Parsed(std.json.Value),

    pub fn root(self: *const Response) std.json.Value {
        return self.parsed.value;
    }

    pub fn deinit(self: *Response) void {
        self.parsed.deinit();
    }
};

pub fn postGraphQL(
    gpa: std.mem.Allocator,
    io: Io,
    query: []const u8,
    variables_json: []const u8,
    token: ?[]const u8,
) !Response {
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();

    var body: Writer.Allocating = .init(gpa);
    defer body.deinit();
    const body_w = &body.writer;

    try body_w.writeAll("{\"query\":");
    try std.json.Stringify.value(query, .{}, body_w);
    try body_w.writeAll(",\"variables\":");
    try body_w.writeAll(variables_json);
    try body_w.writeAll("}");

    var auth_buf: [256]u8 = undefined;
    const auth_header: ?[]const u8 = if (token) |t|
        std.fmt.bufPrint(&auth_buf, "bearer {s}", .{t}) catch null
    else
        null;

    const headers: std.http.Client.Request.Headers = .{
        .content_type = .{ .override = "application/json" },
        .authorization = if (auth_header) |a| .{ .override = a } else .default,
        .user_agent = .{ .override = "github-user-summary-cards/0.1" },
    };

    var response_body: Writer.Allocating = .init(gpa);
    defer response_body.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = "https://api.github.com/graphql" },
        .method = .POST,
        .headers = headers,
        .extra_headers = &.{
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-Github-Next-Global-ID", .value = "1" },
        },
        .payload = body.written(),
        .response_writer = &response_body.writer,
    });

    const body_bytes = response_body.written();
    if (result.status != .ok) {
        std.log.err("github: HTTP {d}: {s}", .{ @intFromEnum(result.status), body_bytes });
        return error.HttpError;
    }

    var parsed = try std.json.parseFromSlice(std.json.Value, gpa, body_bytes, .{
        .allocate = .alloc_always,
    });
    errdefer parsed.deinit();

    if (parsed.value == .object) {
        if (parsed.value.object.get("errors")) |_| {
            std.log.err("graphql errors in response body: {s}", .{body_bytes});
            return error.GraphQLError;
        }
        if (parsed.value.object.get("data")) |data| {
            if (data == .object) {
                if (data.object.get("user")) |u| {
                    if (u == .null) return error.UserNotFound;
                }
            }
        }
    }

    return .{ .parsed = parsed };
}

/// Fetch raw bytes from a URL. Caller owns returned slice (allocated via gpa).
/// Returns null if the response is not 2xx or the URL is empty.
pub fn fetchBytes(gpa: std.mem.Allocator, io: Io, url: []const u8) !?[]u8 {
    if (url.len == 0) return null;
    var client: std.http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();

    var body: Writer.Allocating = .init(gpa);
    errdefer body.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .headers = .{
            .user_agent = .{ .override = "github-user-summary-cards/0.1" },
        },
        .response_writer = &body.writer,
    });

    if (@intFromEnum(result.status) < 200 or @intFromEnum(result.status) >= 300) {
        body.deinit();
        return null;
    }
    return try body.toOwnedSlice();
}

/// Detects the image MIME type by looking at the first bytes.
/// Returns null for unrecognized formats.
pub fn detectImageMime(bytes: []const u8) ?[]const u8 {
    if (bytes.len >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF) return "image/jpeg";
    if (bytes.len >= 8 and std.mem.eql(u8, bytes[0..8], "\x89PNG\r\n\x1a\n")) return "image/png";
    if (bytes.len >= 6 and (std.mem.eql(u8, bytes[0..6], "GIF87a") or std.mem.eql(u8, bytes[0..6], "GIF89a"))) return "image/gif";
    if (bytes.len >= 12 and std.mem.eql(u8, bytes[0..4], "RIFF") and std.mem.eql(u8, bytes[8..12], "WEBP")) return "image/webp";
    return null;
}

/// Fetch an image and return a `data:<mime>;base64,...` URL. Returns null on
/// any failure (network error, non-image, unknown format).
pub fn fetchImageDataUrl(gpa: std.mem.Allocator, io: Io, url: []const u8) !?[]u8 {
    const bytes = (try fetchBytes(gpa, io, url)) orelse return null;
    defer gpa.free(bytes);

    const mime = detectImageMime(bytes) orelse return null;

    const enc = std.base64.standard.Encoder;
    const encoded_len = enc.calcSize(bytes.len);
    const prefix_len = "data:".len + mime.len + ";base64,".len;
    const out = try gpa.alloc(u8, prefix_len + encoded_len);
    errdefer gpa.free(out);

    const written = try std.fmt.bufPrint(out[0..prefix_len], "data:{s};base64,", .{mime});
    std.debug.assert(written.len == prefix_len);
    _ = enc.encode(out[prefix_len..], bytes);
    return out;
}

pub const Date = struct { year: u16, month: u8, day: u8 };

pub fn todaysDate(io: Io) Date {
    const ts = Io.Timestamp.now(io, .real);
    const now: i64 = @intCast(@divTrunc(ts.nanoseconds, std.time.ns_per_s));
    return dateFromUnix(now);
}

fn dateFromUnix(ts: i64) Date {
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const day = epoch.getEpochDay();
    const ydm = day.calculateYearDay();
    const md = ydm.calculateMonthDay();
    return .{
        .year = ydm.year,
        .month = md.month.numeric(),
        .day = @as(u8, md.day_index) + 1,
    };
}

pub fn yearWindow(io: Io, buf_from: []u8, buf_to: []u8) !struct { from: []const u8, to: []const u8 } {
    const ts = Io.Timestamp.now(io, .real);
    const now: i64 = @intCast(@divTrunc(ts.nanoseconds, std.time.ns_per_s));
    const year_seconds: i64 = 365 * 24 * 60 * 60;
    const from = now - year_seconds;
    return .{
        .from = try formatIso(buf_from, from),
        .to = try formatIso(buf_to, now),
    };
}

pub fn formatDayStart(buf: []u8, year: u16, month: u8, day: u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T00:00:00Z", .{ year, month, day });
}

pub fn formatDayEnd(buf: []u8, year: u16, month: u8, day: u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T23:59:59Z", .{ year, month, day });
}

fn formatIso(buf: []u8, ts: i64) ![]const u8 {
    const d = dateFromUnix(ts);
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const ds = epoch.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        d.year,                       d.month,                        d.day,
        ds.getHoursIntoDay(),         ds.getMinutesIntoHour(),        ds.getSecondsIntoMinute(),
    });
}
