const std = @import("std");
const svg = @import("../svg.zig");
const stats = @import("../stats.zig");

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const stats.Stats) !void {
    _ = allocator;
    const w: u32 = 480;
    const h: u32 = 180;
    try svg.header(writer, w, h, theme, "Contribution Streak");

    const r = stats.streakStats(s.contributions);

    const Box = struct { label: []const u8, value: u32, color: []const u8 };
    const boxes = [_]Box{
        .{ .label = "Current",      .value = r.current,      .color = theme.palette[0] },
        .{ .label = "Longest",      .value = r.longest,      .color = theme.palette[2] },
        .{ .label = "Active Days",  .value = r.total_active, .color = theme.palette[3] },
    };

    var i: usize = 0;
    while (i < boxes.len) : (i += 1) {
        const x: f64 = 20 + @as(f64, @floatFromInt(i)) * 150;
        try svg.rect(writer, x, 60, 130, 90, 6, theme.border);
        var buf: [32]u8 = undefined;
        const num = try std.fmt.bufPrint(&buf, "{d}", .{boxes[i].value});
        try writer.print(
            \\<text x="{d:.2}" y="105" font-family="Segoe UI, Ubuntu, Sans-Serif" font-size="28" font-weight="700" fill="{s}" text-anchor="middle">
        , .{ x + 65, boxes[i].color });
        try writer.writeAll(num);
        try writer.writeAll("</text>\n");
        try writer.print(
            \\<text x="{d:.2}" y="135" font-family="Segoe UI, Ubuntu, Sans-Serif" font-size="13" fill="{s}" text-anchor="middle">{s}</text>
            \\
        , .{ x + 65, theme.text, boxes[i].label });
    }

    try svg.footer(writer);
}
