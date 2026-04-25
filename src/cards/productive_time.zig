const std = @import("std");
const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const Stats, utc_offset: i8) !void {
    _ = allocator;
    _ = utc_offset; // GraphQL contributions have date-level granularity; we plot by weekday.

    const w: u32 = 480;
    const h: u32 = 220;
    try svg.header(writer, w, h, theme, "Activity by Weekday");

    var max: u32 = 1;
    for (s.weekday_commits) |c| if (c > max) max = c;
    const max_f: f64 = @floatFromInt(max);

    const labels = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
    const bar_h: f64 = 14;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        const y: f64 = 70 + @as(f64, @floatFromInt(i)) * 20;
        try svg.text(writer, 20, y + 11, "text", labels[i]);
        const value = s.weekday_commits[i];
        const ratio = if (max == 0) 0.0 else @as(f64, @floatFromInt(value)) / max_f;
        const max_bar: f64 = 320;
        const bar_w: f64 = max_bar * ratio;
        try svg.rect(writer, 70, y, max_bar, bar_h, 4, theme.border);
        try svg.rect(writer, 70, y, bar_w, bar_h, 4, theme.palette[i % 8]);
        var buf: [32]u8 = undefined;
        const num = try std.fmt.bufPrint(&buf, "{d}", .{value});
        try svg.text(writer, 70 + max_bar + 8, y + 11, "muted", num);
    }

    try svg.footer(writer);
}
