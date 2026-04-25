const std = @import("std");

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
    allocator: std.mem.Allocator,
    query: []const u8,
    variables_json: []const u8,
    token: ?[]const u8,
) !Response {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // Build the JSON body: {"query": "...", "variables": {...}}
    var body = std.ArrayList(u8).init(allocator);
    defer body.deinit();
    try body.appendSlice("{\"query\":");
    try std.json.stringify(query, .{}, body.writer());
    try body.appendSlice(",\"variables\":");
    try body.appendSlice(variables_json);
    try body.appendSlice("}");

    var auth_buf: [256]u8 = undefined;
    const auth_header: ?[]const u8 = if (token) |t|
        std.fmt.bufPrint(&auth_buf, "bearer {s}", .{t}) catch null
    else
        null;

    var response_body = std.ArrayList(u8).init(allocator);
    defer response_body.deinit();

    const headers = std.http.Client.Request.Headers{
        .content_type = .{ .override = "application/json" },
        .authorization = if (auth_header) |a| .{ .override = a } else .default,
        .user_agent = .{ .override = "github-user-summary-cards/0.1" },
    };

    const result = try client.fetch(.{
        .location = .{ .url = "https://api.github.com/graphql" },
        .method = .POST,
        .headers = headers,
        .extra_headers = &.{
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "X-Github-Next-Global-ID", .value = "1" },
        },
        .payload = body.items,
        .response_storage = .{ .dynamic = &response_body },
        .max_append_size = 16 * 1024 * 1024,
    });

    if (result.status != .ok) {
        std.log.err("github: HTTP {d}: {s}", .{ @intFromEnum(result.status), response_body.items });
        return error.HttpError;
    }

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, response_body.items, .{
        .allocate = .alloc_always,
    });
    errdefer parsed.deinit();

    // Surface GraphQL-level errors clearly.
    if (parsed.value == .object) {
        if (parsed.value.object.get("errors")) |_| {
            std.log.err("graphql errors in response body: {s}", .{response_body.items});
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

    return Response{ .parsed = parsed };
}

/// Format an ISO-8601 UTC timestamp for "now - 1 year" and "now" as required by GraphQL DateTime.
pub fn yearWindow(buf_from: []u8, buf_to: []u8) !struct { from: []const u8, to: []const u8 } {
    const now = std.time.timestamp();
    const year_seconds: i64 = 365 * 24 * 60 * 60;
    const from = now - year_seconds;
    const from_s = try formatIso(buf_from, from);
    const to_s = try formatIso(buf_to, now);
    return .{ .from = from_s, .to = to_s };
}

fn formatIso(buf: []u8, ts: i64) ![]const u8 {
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(ts) };
    const day = epoch.getEpochDay();
    const ydm = day.calculateYearDay();
    const md = ydm.calculateMonthDay();
    const ds = epoch.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        @as(u32, ydm.year),
        @as(u32, md.month.numeric()),
        @as(u32, md.day_index) + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    });
}
