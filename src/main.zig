const std = @import("std");
const config = @import("config.zig");
const themes = @import("themes.zig");
const github = @import("github.zig");
const queries = @import("queries.zig");
const stats_mod = @import("stats.zig");

const profile_card = @import("cards/profile_details.zig");
const repos_lang_card = @import("cards/repos_per_language.zig");
const commit_lang_card = @import("cards/most_commit_language.zig");
const stats_card = @import("cards/stats_card.zig");
const productive_card = @import("cards/productive_time.zig");
const heatmap_card = @import("cards/contribution_heatmap.zig");
const streak_card = @import("cards/streak.zig");
const top_repos_card = @import("cards/top_repos.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cfg = config.parse(allocator) catch |err| {
        switch (err) {
            error.MissingUsername => {
                std.log.err("usage: github-user-summary-cards <username> (or set GITHUB_USERNAME)", .{});
                std.process.exit(1);
            },
            error.InvalidUtcOffset => {
                std.log.err("invalid --utc-offset: must be integer in [-12, 14]", .{});
                std.process.exit(1);
            },
            else => return err,
        }
    };
    defer cfg.deinit();

    if (cfg.token == null) {
        std.log.warn("no GITHUB_TOKEN set — using unauthenticated GraphQL (60/hour limit, public data only)", .{});
    }

    const theme = themes.byName(cfg.theme);

    var from_buf: [32]u8 = undefined;
    var to_buf: [32]u8 = undefined;
    const window = try github.yearWindow(&from_buf, &to_buf);

    var vars_buf = std.ArrayList(u8).init(allocator);
    defer vars_buf.deinit();
    try vars_buf.appendSlice("{\"login\":");
    try std.json.stringify(cfg.username, .{}, vars_buf.writer());
    try vars_buf.appendSlice(",\"from\":");
    try std.json.stringify(window.from, .{}, vars_buf.writer());
    try vars_buf.appendSlice(",\"to\":");
    try std.json.stringify(window.to, .{}, vars_buf.writer());
    try vars_buf.appendSlice("}");

    std.log.info("fetching GitHub stats for @{s}...", .{cfg.username});

    var resp = github.postGraphQL(allocator, queries.profile_query, vars_buf.items, cfg.token) catch |err| {
        switch (err) {
            error.UserNotFound => {
                std.log.err("user not found: {s}", .{cfg.username});
                std.process.exit(2);
            },
            error.HttpError, error.GraphQLError => {
                std.log.err("github API error: {s}", .{@errorName(err)});
                std.process.exit(2);
            },
            else => return err,
        }
    };
    defer resp.deinit();

    var stats = try stats_mod.fromGraphQL(allocator, resp.root(), cfg.exclude);
    defer stats.deinit();

    std.fs.cwd().makePath(cfg.output_dir) catch |err| {
        std.log.err("cannot create output dir {s}: {s}", .{ cfg.output_dir, @errorName(err) });
        std.process.exit(3);
    };

    try renderToFile(allocator, cfg.output_dir, "profile-details.svg", theme, &stats, profile_card.render);
    try renderToFile(allocator, cfg.output_dir, "repos-per-language.svg", theme, &stats, repos_lang_card.render);
    try renderToFile(allocator, cfg.output_dir, "most-commit-language.svg", theme, &stats, commit_lang_card.render);
    try renderToFile(allocator, cfg.output_dir, "stats.svg", theme, &stats, stats_card.render);
    try renderProductive(allocator, cfg.output_dir, "productive-time.svg", theme, &stats, cfg.utc_offset);
    try renderToFile(allocator, cfg.output_dir, "contribution-heatmap.svg", theme, &stats, heatmap_card.render);
    try renderToFile(allocator, cfg.output_dir, "streak.svg", theme, &stats, streak_card.render);
    try renderToFile(allocator, cfg.output_dir, "top-repos.svg", theme, &stats, top_repos_card.render);

    std.log.info("wrote 8 SVG cards to {s}/", .{cfg.output_dir});
}

fn renderToFile(
    allocator: std.mem.Allocator,
    out_dir: []const u8,
    filename: []const u8,
    theme: themes.Theme,
    stats: *const stats_mod.Stats,
    comptime render: anytype,
) !void {
    const path = try std.fs.path.join(allocator, &.{ out_dir, filename });
    defer allocator.free(path);
    var f = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer f.close();
    var buf = std.io.bufferedWriter(f.writer());
    try render(allocator, buf.writer(), theme, stats);
    try buf.flush();
}

fn renderProductive(
    allocator: std.mem.Allocator,
    out_dir: []const u8,
    filename: []const u8,
    theme: themes.Theme,
    stats: *const stats_mod.Stats,
    utc_offset: i8,
) !void {
    const path = try std.fs.path.join(allocator, &.{ out_dir, filename });
    defer allocator.free(path);
    var f = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer f.close();
    var buf = std.io.bufferedWriter(f.writer());
    try productive_card.render(allocator, buf.writer(), theme, stats, utc_offset);
    try buf.flush();
}
