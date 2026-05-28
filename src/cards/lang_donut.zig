const std = @import("std");
const svg = @import("../svg.zig");
const stats = @import("../stats.zig");

pub fn render(
    w: *svg.Writer,
    theme: svg.Theme,
    title: []const u8,
    items: []const stats.LangCount,
    opts: stats.DisplayOpts,
) !void {
    const width: u32 = 540;

    if (items.len == 0) {
        try svg.header(w, width, 280, theme, title);
        try svg.text(w, 32, 130, "muted", "(no data)");
        try svg.footer(w);
        return;
    }

    const top_n: usize = if (items.len > opts.top_langs) opts.top_langs else items.len;
    var total: f64 = 0;
    for (items) |it| total += it.value;
    var other: f64 = 0;
    if (items.len > top_n) {
        for (items[top_n..]) |it| other += it.value;
    }
    if (total <= 0) total = 1;

    // legend: top_n entries + optional "Other"; each row is 24px starting at y=78
    // bottom margin of 34px matches the default layout (6 langs + Other → height=280)
    const n_legend: usize = top_n + if (other > 0) @as(usize, 1) else 0;
    const height: u32 = @max(280, @as(u32, @intCast(n_legend * 24 + 78 + 34)));

    try svg.header(w, width, height, theme, title);

    const cx: f64 = 130;
    const cy: f64 = 160;
    const r: f64 = 78;
    const inner: f64 = 50;

    try svg.circle(w, cx, cy, r + 1, theme.border);

    var start: f64 = 0;
    var i: usize = 0;
    while (i < top_n) : (i += 1) {
        const it = items[i];
        const sweep = it.value / total * 360.0;
        if (sweep > 0.01) try svg.donutSlice(w, cx, cy, r, inner, start, start + sweep, it.color);
        start += sweep;
    }
    if (other > 0) {
        const sweep = other / total * 360.0;
        if (sweep > 0.01) try svg.donutSlice(w, cx, cy, r, inner, start, start + sweep, "#9aa1a8");
    }

    try svg.circle(w, cx, cy, inner - 0.5, theme.bg);

    const top_lang = items[0];
    const top_pct = items[0].value / total * 100.0;
    var top_buf: [16]u8 = undefined;
    const top_pct_str = try std.fmt.bufPrint(&top_buf, "{d:.0}%", .{top_pct});
    try w.print(
        \\<text x="{d:.2}" y="{d:.2}" text-anchor="middle" class="huge" fill="{s}">{s}</text>
        \\
    , .{ cx, cy + 4, top_lang.color, top_pct_str });
    try svg.textAnchor(w, cx, cy + 22, "muted", "middle", top_lang.name);

    const legend_x: f64 = 240;
    var ly: f64 = 78;
    i = 0;
    while (i < top_n) : (i += 1) {
        const it = items[i];
        try svg.circle(w, legend_x + 6, ly - 4, 5, it.color);
        try svg.text(w, legend_x + 18, ly, "text", it.name);
        var buf: [32]u8 = undefined;
        const pct = it.value / total * 100.0;
        const pct_str = try std.fmt.bufPrint(&buf, "{d:.1}%", .{pct});
        try svg.textAnchor(w, @as(f64, @floatFromInt(width)) - 24, ly, "bold", "end", pct_str);
        ly += 24;
    }
    if (other > 0) {
        try svg.circle(w, legend_x + 6, ly - 4, 5, "#9aa1a8");
        try svg.text(w, legend_x + 18, ly, "text", "Other");
        var buf: [32]u8 = undefined;
        const pct = other / total * 100.0;
        const pct_str = try std.fmt.bufPrint(&buf, "{d:.1}%", .{pct});
        try svg.textAnchor(w, @as(f64, @floatFromInt(width)) - 24, ly, "bold", "end", pct_str);
    }

    try svg.footer(w);
}
