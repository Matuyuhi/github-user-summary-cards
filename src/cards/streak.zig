const std = @import("std");
const svg = @import("../svg.zig");
const icons = @import("../icons.zig");
const stats = @import("../stats.zig");

pub fn render(w: *svg.Writer, theme: svg.Theme, s: *const stats.Stats) !void {
    const width: u32 = 540;
    const height: u32 = 220;
    try svg.header(w, width, height, theme, "Contribution Streak");

    try icons.stroke(w, .flame, @as(f64, @floatFromInt(width)) - 38, 14, 18, theme.icon);

    const r = stats.streakStats(s.contributions);

    const Box = struct { icon: icons.Icon, label: []const u8, value: u32, color: []const u8 };
    const boxes = [_]Box{
        .{ .icon = .flame,    .label = "Current Streak", .value = r.current,      .color = theme.palette[0] },
        .{ .icon = .trophy,   .label = "Longest Streak", .value = r.longest,      .color = theme.palette[2] },
        .{ .icon = .activity, .label = "Active Days",    .value = r.total_active, .color = theme.palette[3] },
    };

    const box_w: f64 = 156;
    const gap: f64 = 12;
    const total_w: f64 = box_w * 3 + gap * 2;
    const start_x: f64 = (@as(f64, @floatFromInt(width)) - total_w) / 2.0;
    const box_y: f64 = 64;
    const box_h: f64 = 130;

    var i: usize = 0;
    while (i < boxes.len) : (i += 1) {
        const x: f64 = start_x + @as(f64, @floatFromInt(i)) * (box_w + gap);

        try svg.rectOpacity(w, x, box_y, box_w, box_h, 8, boxes[i].color, 0.10);
        try w.print(
            \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" rx="8" fill="none" stroke="{s}" stroke-width="1" opacity="0.4"/>
            \\
        , .{ x, box_y, box_w, box_h, boxes[i].color });

        try icons.stroke(w, boxes[i].icon, x + box_w / 2 - 12, box_y + 14, 24, boxes[i].color);

        var buf: [32]u8 = undefined;
        const num = try svg.fmtInt(&buf, boxes[i].value, s.display.humanize);
        try w.print(
            \\<text x="{d:.2}" y="{d:.2}" class="huge" fill="{s}" text-anchor="middle">{s}</text>
            \\
        , .{ x + box_w / 2, box_y + 80, boxes[i].color, num });

        try svg.textAnchor(w, x + box_w / 2, box_y + box_h - 14, "label", "middle", boxes[i].label);
    }

    try svg.footer(w);
}
