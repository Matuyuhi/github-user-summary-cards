const std = @import("std");
const svg = @import("../svg.zig");
const stats = @import("../stats.zig");

pub fn render(
    allocator: std.mem.Allocator,
    writer: anytype,
    theme: svg.Theme,
    title: []const u8,
    items: []const stats.LangCount,
) !void {
    _ = allocator;
    const w: u32 = 480;
    const h: u32 = 220;
    try svg.header(writer, w, h, theme, title);

    if (items.len == 0) {
        try svg.text(writer, 20, 100, "muted", "(no data)");
        try svg.footer(writer);
        return;
    }

    // Top 6 + Other
    const top_n: usize = if (items.len > 6) 6 else items.len;
    var total: f64 = 0;
    for (items) |it| total += it.value;
    var other: f64 = 0;
    if (items.len > top_n) {
        for (items[top_n..]) |it| other += it.value;
    }
    if (total <= 0) total = 1;

    const cx: f64 = 100;
    const cy: f64 = 130;
    const r: f64 = 60;
    const inner: f64 = 36;

    var start: f64 = 0;
    var i: usize = 0;
    while (i < top_n) : (i += 1) {
        const it = items[i];
        const sweep = it.value / total * 360.0;
        if (sweep > 0.01) try svg.donutSlice(writer, cx, cy, r, inner, start, start + sweep, it.color);
        start += sweep;
    }
    if (other > 0) {
        const sweep = other / total * 360.0;
        if (sweep > 0.01) try svg.donutSlice(writer, cx, cy, r, inner, start, start + sweep, "#888888");
    }

    // Legend
    const legend_x: f64 = 200;
    var ly: f64 = 70;
    i = 0;
    while (i < top_n) : (i += 1) {
        const it = items[i];
        try svg.rect(writer, legend_x, ly - 10, 12, 12, 2, it.color);
        var buf: [128]u8 = undefined;
        const pct = it.value / total * 100.0;
        const line = try std.fmt.bufPrint(&buf, "{s}  {d:.1}%", .{ it.name, pct });
        try svg.text(writer, legend_x + 18, ly, "text", line);
        ly += 22;
    }
    if (other > 0) {
        try svg.rect(writer, legend_x, ly - 10, 12, 12, 2, "#888888");
        var buf: [64]u8 = undefined;
        const pct = other / total * 100.0;
        const line = try std.fmt.bufPrint(&buf, "Other  {d:.1}%", .{pct});
        try svg.text(writer, legend_x + 18, ly, "text", line);
    }

    try svg.footer(writer);
}
