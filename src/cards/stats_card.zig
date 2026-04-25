const std = @import("std");
const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const Stats) !void {
    _ = allocator;
    const w: u32 = 480;
    const h: u32 = 220;
    try svg.header(writer, w, h, theme, "Stats");

    const Row = struct { label: []const u8, value: u64, color: []const u8 };
    const rows = [_]Row{
        .{ .label = "Total Stars Earned",      .value = s.total_stars,                .color = theme.palette[0] },
        .{ .label = "Total Forks",             .value = s.total_forks,                .color = theme.palette[1] },
        .{ .label = "Total Commits (1y)",      .value = s.total_commits_year,         .color = theme.palette[2] },
        .{ .label = "Total Contributions (1y)",.value = s.total_contributions_year,   .color = theme.palette[3] },
        .{ .label = "Total PRs",               .value = s.total_prs,                  .color = theme.palette[4] },
        .{ .label = "Total Issues",            .value = s.total_issues,               .color = theme.palette[5] },
        .{ .label = "Repos Owned",             .value = s.total_repos,                .color = theme.palette[6] },
        .{ .label = "Contributed Repos (1y)",  .value = s.contributed_repos_year,     .color = theme.palette[7] },
    };

    var i: usize = 0;
    while (i < rows.len) : (i += 1) {
        const x: f64 = 20;
        const y: f64 = 60 + @as(f64, @floatFromInt(i)) * 19;
        try svg.rect(writer, x, y - 9, 8, 8, 2, rows[i].color);
        try svg.text(writer, x + 16, y, "text", rows[i].label);
        var buf: [32]u8 = undefined;
        const num = try std.fmt.bufPrint(&buf, "{d}", .{rows[i].value});
        try svg.text(writer, 360, y, "bold", num);
    }

    try svg.footer(writer);
}
