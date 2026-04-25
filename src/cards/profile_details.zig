const std = @import("std");
const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const Stats) !void {
    _ = allocator;
    const w: u32 = 480;
    const h: u32 = 220;
    try svg.header(writer, w, h, theme, "Profile Details");

    const display = if (s.name.len > 0) s.name else s.login;
    try svg.text(writer, 20, 60, "bold", display);

    var bio_buf: [200]u8 = undefined;
    const bio_trim = if (s.bio.len > 80) s.bio[0..80] else s.bio;
    const bio_str = std.fmt.bufPrint(&bio_buf, "{s}", .{bio_trim}) catch s.bio;
    try svg.text(writer, 20, 82, "muted", bio_str);

    const Row = struct { label: []const u8, value: u64 };
    const rows = [_]Row{
        .{ .label = "Followers", .value = s.followers },
        .{ .label = "Following", .value = s.following },
        .{ .label = "Stars Earned", .value = s.total_stars },
        .{ .label = "Forks", .value = s.total_forks },
        .{ .label = "Total PRs", .value = s.total_prs },
        .{ .label = "Total Issues", .value = s.total_issues },
        .{ .label = "Repos Owned", .value = s.total_repos },
        .{ .label = "Commits (1y)", .value = s.total_commits_year },
    };

    var i: usize = 0;
    while (i < rows.len) : (i += 1) {
        const col = i % 2;
        const row = i / 2;
        const x: f64 = 20 + @as(f64, @floatFromInt(col)) * 230;
        const y: f64 = 110 + @as(f64, @floatFromInt(row)) * 25;
        try svg.text(writer, x, y, "text", rows[i].label);
        var num_buf: [32]u8 = undefined;
        const num = try std.fmt.bufPrint(&num_buf, "{d}", .{rows[i].value});
        try svg.text(writer, x + 150, y, "bold", num);
    }

    try svg.footer(writer);
}
