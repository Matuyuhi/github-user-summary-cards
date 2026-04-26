const std = @import("std");
const svg = @import("../svg.zig");
const icons = @import("../icons.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(w: *svg.Writer, theme: svg.Theme, s: *const Stats) !void {
    const width: u32 = 480;
    const height: u32 = 260;
    try svg.header(w, width, height, theme, "Stats");

    const Row = struct { icon: icons.Icon, label: []const u8, value: u64, color: []const u8 };
    const rows = [_]Row{
        .{ .icon = .star,         .label = "Total Stars Earned",       .value = s.total_stars,              .color = theme.palette[0] },
        .{ .icon = .fork,         .label = "Total Forks",              .value = s.total_forks,              .color = theme.palette[1] },
        .{ .icon = .commit,       .label = "Total Commits",            .value = s.total_commits,            .color = theme.palette[2] },
        .{ .icon = .activity,     .label = "Total Contributions",      .value = s.total_contributions,      .color = theme.palette[3] },
        .{ .icon = .pull_request, .label = "Total PRs",                .value = s.total_prs,                .color = theme.palette[4] },
        .{ .icon = .issue,        .label = "Total Issues",             .value = s.total_issues,             .color = theme.palette[5] },
        .{ .icon = .repo,         .label = "Repos Owned",              .value = s.total_repos,              .color = theme.palette[6] },
        .{ .icon = .layers,       .label = "Contributed Repos",        .value = s.contributed_repos,        .color = theme.palette[7] },
    };

    const row_h: f64 = 22;
    const start_y: f64 = 64;

    var i: usize = 0;
    while (i < rows.len) : (i += 1) {
        const y: f64 = start_y + @as(f64, @floatFromInt(i)) * row_h;
        try svg.rectOpacity(w, 20, y - 12, 18, 18, 4, rows[i].color, 0.18);
        try icons.stroke(w, rows[i].icon, 22, y - 10, 14, rows[i].color);
        try svg.text(w, 48, y, "text", rows[i].label);
        var buf: [32]u8 = undefined;
        const num = try svg.fmtInt(&buf, rows[i].value, s.display.humanize);
        try svg.textAnchor(w, @as(f64, @floatFromInt(width)) - 24, y, "num", "end", num);
    }

    try svg.footer(w);
}
