const std = @import("std");
const themes = @import("themes.zig");

pub const Theme = themes.Theme;
pub const Writer = std.Io.Writer;

pub fn escape(w: *Writer, s: []const u8) !void {
    for (s) |c| switch (c) {
        '&' => try w.writeAll("&amp;"),
        '<' => try w.writeAll("&lt;"),
        '>' => try w.writeAll("&gt;"),
        '"' => try w.writeAll("&quot;"),
        '\'' => try w.writeAll("&#39;"),
        else => try w.writeByte(c),
    };
}

pub const HeaderOpts = struct {
    extra_defs: []const u8 = "",
};

pub fn header(w: *Writer, width: u32, height: u32, theme: Theme, title: []const u8) !void {
    try headerExt(w, width, height, theme, title, .{});
}

pub fn headerExt(w: *Writer, width: u32, height: u32, theme: Theme, title: []const u8, opts: HeaderOpts) !void {
    try w.print(
        \\<svg xmlns="http://www.w3.org/2000/svg" width="{d}" height="{d}" viewBox="0 0 {d} {d}" fill="none">
        \\<defs>
        \\<linearGradient id="card-bg" x1="0" y1="0" x2="0" y2="1">
        \\<stop offset="0%" stop-color="{s}" stop-opacity="1"/>
        \\<stop offset="100%" stop-color="{s}" stop-opacity="0.92"/>
        \\</linearGradient>
        \\{s}
        \\</defs>
        \\<style>
        \\.title    {{ font: 700 18px 'Segoe UI', system-ui, Sans-Serif; fill: {s}; }}
        \\.text     {{ font: 400 13px 'Segoe UI', system-ui, Sans-Serif; fill: {s}; }}
        \\.muted    {{ font: 400 11px 'Segoe UI', system-ui, Sans-Serif; fill: {s}; opacity: 0.7; }}
        \\.bold     {{ font: 700 14px 'Segoe UI', system-ui, Sans-Serif; fill: {s}; }}
        \\.num      {{ font: 700 15px 'Segoe UI', system-ui, Sans-Serif; fill: {s}; }}
        \\.huge     {{ font: 800 30px 'Segoe UI', system-ui, Sans-Serif; }}
        \\.label    {{ font: 600 10px 'Segoe UI', system-ui, Sans-Serif; fill: {s}; opacity: 0.7; letter-spacing: 0.6px; }}
        \\.fadein   {{ animation: fadein 0.6s ease-in both; }}
        \\@keyframes fadein {{ from {{ opacity: 0; transform: translateY(4px); }} to {{ opacity: 1; transform: translateY(0); }} }}
        \\</style>
        \\<rect x="0.5" y="0.5" rx="8" ry="8" width="{d}" height="{d}" fill="url(#card-bg)" stroke="{s}"/>
        \\<rect x="20" y="14" width="3" height="22" rx="1.5" fill="{s}"/>
        \\<text class="title" x="32" y="30">
    , .{
        width,           height,          width,           height,
        theme.bg,        theme.bg,
        opts.extra_defs,
        theme.title,     theme.text,      theme.text,      theme.text,
        theme.text,      theme.text,
        width - 1,       height - 1,      theme.border,
        theme.title,
    });
    try escape(w, title);
    try w.writeAll("</text>\n");
}

pub fn footer(w: *Writer) !void {
    try w.writeAll("</svg>\n");
}

pub fn donutSlice(w: *Writer, cx: f64, cy: f64, r: f64, inner: f64, start_deg: f64, end_deg: f64, color: []const u8) !void {
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
    try w.print(
        \\<path d="M{d:.2},{d:.2} A{d:.2},{d:.2} 0 {d} 1 {d:.2},{d:.2} L{d:.2},{d:.2} A{d:.2},{d:.2} 0 {d} 0 {d:.2},{d:.2} Z" fill="{s}"/>
        \\
    , .{ x0, y0, r, r, large, x1, y1, xi1, yi1, inner, inner, large, xi0, yi0, color });
}

pub fn rect(w: *Writer, x: f64, y: f64, width: f64, height: f64, rx: f64, color: []const u8) !void {
    try w.print(
        \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" rx="{d:.2}" fill="{s}"/>
        \\
    , .{ x, y, width, height, rx, color });
}

pub fn rectOpacity(w: *Writer, x: f64, y: f64, width: f64, height: f64, rx: f64, color: []const u8, opacity: f64) !void {
    try w.print(
        \\<rect x="{d:.2}" y="{d:.2}" width="{d:.2}" height="{d:.2}" rx="{d:.2}" fill="{s}" opacity="{d:.2}"/>
        \\
    , .{ x, y, width, height, rx, color, opacity });
}

pub fn circle(w: *Writer, cx: f64, cy: f64, r: f64, color: []const u8) !void {
    try w.print(
        \\<circle cx="{d:.2}" cy="{d:.2}" r="{d:.2}" fill="{s}"/>
        \\
    , .{ cx, cy, r, color });
}

pub fn text(w: *Writer, x: f64, y: f64, class: []const u8, body: []const u8) !void {
    try w.print(
        \\<text class="{s}" x="{d:.2}" y="{d:.2}">
    , .{ class, x, y });
    try escape(w, body);
    try w.writeAll("</text>\n");
}

pub fn textAnchor(w: *Writer, x: f64, y: f64, class: []const u8, anchor: []const u8, body: []const u8) !void {
    try w.print(
        \\<text class="{s}" x="{d:.2}" y="{d:.2}" text-anchor="{s}">
    , .{ class, x, y, anchor });
    try escape(w, body);
    try w.writeAll("</text>\n");
}

/// Abbreviate `n` with SI suffixes (`k`/`m`/`b`/`t`). Returns:
///   <1000     -> "999"
///   1k..9.9k  -> "1.2k" (one decimal, trailing .0 dropped)
///   10k..999k -> "12k"  (no decimal, rounded)
///   ...same scheme for m / b / t.
pub fn humanizeInt(buf: []u8, n: u64) ![]const u8 {
    if (n < 1000) return std.fmt.bufPrint(buf, "{d}", .{n});

    const suffixes = [_]u8{ 'k', 'm', 'b', 't' };
    var v = @as(f64, @floatFromInt(n)) / 1000.0;
    var idx: usize = 0;
    while (idx + 1 < suffixes.len and v >= 999.5) : (idx += 1) {
        v /= 1000.0;
    }
    const ch = suffixes[idx];

    if (v >= 10.0) {
        const rounded = @as(u64, @intFromFloat(@round(v)));
        return std.fmt.bufPrint(buf, "{d}{c}", .{ rounded, ch });
    }
    const tenths = @as(u32, @intFromFloat(@round(v * 10.0)));
    const whole = tenths / 10;
    const frac = tenths % 10;
    if (frac == 0) return std.fmt.bufPrint(buf, "{d}{c}", .{ whole, ch });
    return std.fmt.bufPrint(buf, "{d}.{d}{c}", .{ whole, frac, ch });
}

pub fn fmtInt(buf: []u8, n: u64, humanize: bool) ![]const u8 {
    if (humanize) return humanizeInt(buf, n);
    return std.fmt.bufPrint(buf, "{d}", .{n});
}

pub fn divider(w: *Writer, x: f64, y: f64, len: f64, color: []const u8) !void {
    try w.print(
        \\<line x1="{d:.2}" y1="{d:.2}" x2="{d:.2}" y2="{d:.2}" stroke="{s}" stroke-width="1" opacity="0.6"/>
        \\
    , .{ x, y, x + len, y, color });
}
