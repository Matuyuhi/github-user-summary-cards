const std = @import("std");
const themes = @import("themes.zig");

pub const Theme = themes.Theme;

pub fn escape(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '&' => try writer.writeAll("&amp;"),
            '<' => try writer.writeAll("&lt;"),
            '>' => try writer.writeAll("&gt;"),
            '"' => try writer.writeAll("&quot;"),
            '\'' => try writer.writeAll("&#39;"),
            else => try writer.writeByte(c),
        }
    }
}

pub fn header(writer: anytype, width: u32, height: u32, theme: Theme, title: []const u8) !void {
    try writer.print(
        \\<svg xmlns="http://www.w3.org/2000/svg" width="{d}" height="{d}" viewBox="0 0 {d} {d}" fill="none">
        \\<style>
        \\.title {{ font: 600 18px 'Segoe UI', Ubuntu, Sans-Serif; fill: {s}; }}
        \\.text  {{ font: 400 13px 'Segoe UI', Ubuntu, Sans-Serif; fill: {s}; }}
        \\.muted {{ font: 400 11px 'Segoe UI', Ubuntu, Sans-Serif; fill: {s}; opacity: 0.7; }}
        \\.bold  {{ font: 700 14px 'Segoe UI', Ubuntu, Sans-Serif; fill: {s}; }}
        \\</style>
        \\<rect x="0.5" y="0.5" rx="6" ry="6" width="{d}" height="{d}" fill="{s}" stroke="{s}"/>
        \\<text class="title" x="20" y="30">
    , .{
        width, height, width, height,
        theme.title, theme.text, theme.text, theme.text,
        width - 1, height - 1, theme.bg, theme.border,
    });
    try escape(writer, title);
    try writer.writeAll("</text>\n");
}

pub fn footer(writer: anytype) !void {
    try writer.writeAll("</svg>\n");
}

pub fn donutSlice(writer: anytype, cx: f64, cy: f64, r: f64, inner: f64, start_deg: f64, end_deg: f64, color: []const u8) !void {
    const tau = std.math.tau;
    const a0 = (start_deg - 90.0) * tau / 360.0;
    const a1 = (end_deg - 90.0) * tau / 360.0;
    const x0 = cx + r * @cos(a0);
    const y0 = cy + r * @sin(a0);
    const x1 = cx + r * @cos(a1);
    const y1 = cy + r * @sin(a1);
    const xi1 = cx + inner * @cos(a1);
    const yi1 = cy + inner * @sin(a1);
    const xi0 = cx + inner * @cos(a0);
    const yi0 = cy + inner * @sin(a0);
    const large: u8 = if ((end_deg - start_deg) > 180.0) 1 else 0;
    try writer.print(
        \\<path d="M{d:.2},{d:.2} A{d:.2},{d:.2} 0 {d} 1 {d:.2},{d:.2} L{d:.2},{d:.2} A{d:.2},{d:.2} 0 {d} 0 {d:.2},{d:.2} Z" fill="{s}"/>
        \\
    , .{ x0, y0, r, r, large, x1, y1, xi1, yi1, inner, inner, large, xi0, yi0, color });
}

pub fn rect(writer: anytype, x: f64, y: f64, w: f64, h: f64, rx: f64, color: []const u8) !void {
    try writer.print(
        \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" rx="{d:.2}" fill="{s}"/>
        \\
    , .{ x, y, w, h, rx, color });
}

pub fn text(writer: anytype, x: f64, y: f64, class: []const u8, body: []const u8) !void {
    try writer.print(
        \\<text class="{s}" x="{d:.2}" y="{d:.2}">
    , .{ class, x, y });
    try escape(writer, body);
    try writer.writeAll("</text>\n");
}
