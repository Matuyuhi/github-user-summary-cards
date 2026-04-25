const std = @import("std");

pub const Config = struct {
    allocator: std.mem.Allocator,
    username: []const u8,
    token: ?[]const u8,
    theme: []const u8,
    exclude: []const []const u8,
    utc_offset: i8,
    output_dir: []const u8,

    pub fn deinit(self: *Config) void {
        self.allocator.free(self.username);
        if (self.token) |t| self.allocator.free(t);
        self.allocator.free(self.theme);
        for (self.exclude) |e| self.allocator.free(e);
        self.allocator.free(self.exclude);
        self.allocator.free(self.output_dir);
    }
};

fn envOr(allocator: std.mem.Allocator, name: []const u8, fallback: []const u8) ![]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try allocator.dupe(u8, fallback),
        else => return err,
    };
}

fn envOptional(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

fn splitCsv(allocator: std.mem.Allocator, csv: []const u8) ![]const []const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (list.items) |item| allocator.free(item);
        list.deinit();
    }
    var it = std.mem.splitScalar(u8, csv, ',');
    while (it.next()) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0) continue;
        try list.append(try allocator.dupe(u8, trimmed));
    }
    return try list.toOwnedSlice();
}

pub fn parse(allocator: std.mem.Allocator) !Config {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var positional: ?[]const u8 = null;
    var theme_arg: ?[]const u8 = null;
    var exclude_arg: ?[]const u8 = null;
    var utc_arg: ?[]const u8 = null;
    var out_arg: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--theme") and i + 1 < args.len) {
            i += 1;
            theme_arg = args[i];
        } else if (std.mem.eql(u8, a, "--exclude") and i + 1 < args.len) {
            i += 1;
            exclude_arg = args[i];
        } else if (std.mem.eql(u8, a, "--utc-offset") and i + 1 < args.len) {
            i += 1;
            utc_arg = args[i];
        } else if (std.mem.eql(u8, a, "--output") and i + 1 < args.len) {
            i += 1;
            out_arg = args[i];
        } else if (std.mem.eql(u8, a, "-h") or std.mem.eql(u8, a, "--help")) {
            printHelp();
            std.process.exit(0);
        } else if (a.len > 0 and a[0] != '-' and positional == null) {
            positional = a;
        }
    }

    var username: []u8 = undefined;
    if (positional) |p| {
        username = try allocator.dupe(u8, p);
    } else {
        username = std.process.getEnvVarOwned(allocator, "GITHUB_USERNAME") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => return error.MissingUsername,
            else => return err,
        };
    }

    const token = try envOptional(allocator, "GITHUB_TOKEN");

    const theme = if (theme_arg) |t|
        try allocator.dupe(u8, t)
    else
        try envOr(allocator, "THEME", "default");

    const exclude_csv = if (exclude_arg) |e|
        try allocator.dupe(u8, e)
    else
        try envOr(allocator, "EXCLUDE", "");
    defer allocator.free(exclude_csv);
    const exclude = try splitCsv(allocator, exclude_csv);

    const utc_str = if (utc_arg) |u|
        try allocator.dupe(u8, u)
    else
        try envOr(allocator, "UTC_OFFSET", "0");
    defer allocator.free(utc_str);
    const utc_offset = std.fmt.parseInt(i8, utc_str, 10) catch return error.InvalidUtcOffset;
    if (utc_offset < -12 or utc_offset > 14) return error.InvalidUtcOffset;

    const output_dir = if (out_arg) |o|
        try allocator.dupe(u8, o)
    else
        try envOr(allocator, "OUTPUT_DIR", "profile-summary-card-output");

    return Config{
        .allocator = allocator,
        .username = username,
        .token = token,
        .theme = theme,
        .exclude = exclude,
        .utc_offset = utc_offset,
        .output_dir = output_dir,
    };
}

fn printHelp() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(
        \\github-user-summary-cards <username> [options]
        \\
        \\Options:
        \\  --theme <name>          Theme: default, dracula, nord_dark, tokyonight, gruvbox, solarized_light
        \\  --exclude <csv>         Comma-separated languages to exclude
        \\  --utc-offset <hours>    Integer hours offset for productive-time card (-12..14)
        \\  --output <dir>          Output directory (default: profile-summary-card-output)
        \\  -h, --help              Show this help
        \\
        \\Environment:
        \\  GITHUB_USERNAME   Fallback if no positional argument is given
        \\  GITHUB_TOKEN      Optional. When set, private repos / private contributions are included.
        \\  THEME, EXCLUDE, UTC_OFFSET, OUTPUT_DIR  Same as the matching CLI flags
        \\
    , .{}) catch {};
}
