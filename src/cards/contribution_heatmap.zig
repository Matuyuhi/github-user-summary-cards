const std = @import("std");
const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;

fn levelColor(theme: svg.Theme, count: u32, max: u32) []const u8 {
    if (count == 0) return theme.border;
    const ratio = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(@max(max, 1)));
    if (ratio < 0.25) return theme.palette[2];
    if (ratio < 0.5) return theme.palette[1];
    if (ratio < 0.75) return theme.palette[0];
    return theme.palette[3];
}

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const Stats) !void {
    _ = allocator;
    const w: u32 = 760;
    const h: u32 = 170;
    try svg.header(writer, w, h, theme, "Contribution Heatmap (last year)");

    if (s.contributions.len == 0) {
        try svg.text(writer, 20, 80, "muted", "(no data)");
        try svg.footer(writer);
        return;
    }

    var max: u32 = 0;
    for (s.contributions) |d| if (d.count > max) max = d.count;

    const cell: f64 = 11;
    const gap: f64 = 2;
    const ox: f64 = 20;
    const oy: f64 = 50;

    // First day's weekday determines starting offset.
    const first_wd: u8 = s.contributions[0].weekday;
    var col: usize = 0;
    var row: usize = first_wd;

    for (s.contributions) |d| {
        const x = ox + @as(f64, @floatFromInt(col)) * (cell + gap);
        const y = oy + @as(f64, @floatFromInt(row)) * (cell + gap);
        try svg.rect(writer, x, y, cell, cell, 2, levelColor(theme, d.count, max));
        row += 1;
        if (row > 6) {
            row = 0;
            col += 1;
        }
    }

    var buf: [64]u8 = undefined;
    const summary = try std.fmt.bufPrint(&buf, "{d} contributions in the last year", .{s.total_contributions_year});
    try svg.text(writer, 20, 160, "muted", summary);

    try svg.footer(writer);
}
