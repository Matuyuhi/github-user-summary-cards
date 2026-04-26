const std = @import("std");
const svg = @import("../svg.zig");
const icons = @import("../icons.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(w: *svg.Writer, theme: svg.Theme, s: *const Stats) !void {
    const count: u32 = @intCast(s.top_repos.len);
    const row_h: u32 = 66;
    const width: u32 = 600;
    const header_h: u32 = 56;
    const height: u32 = header_h + row_h * @max(count, 1) + 16;
    try svg.header(w, width, height, theme, "Top Repositories");

    try icons.stroke(w, .trophy, @as(f64, @floatFromInt(width)) - 38, 14, 18, theme.icon);

    if (s.top_repos.len == 0) {
        try svg.text(w, 32, 90, "muted", "(no public repos)");
        try svg.footer(w);
        return;
    }

    var i: usize = 0;
    while (i < s.top_repos.len) : (i += 1) {
        const r = s.top_repos[i];
        const y: f64 = @as(f64, @floatFromInt(header_h)) + @as(f64, @floatFromInt(i)) * @as(f64, @floatFromInt(row_h));
        const card_x: f64 = 16;
        const card_w: f64 = @as(f64, @floatFromInt(width)) - 32;
        const card_h: f64 = @as(f64, @floatFromInt(row_h)) - 10;

        try svg.rectOpacity(w, card_x, y, card_w, card_h, 8, theme.border, 0.4);

        try w.print(
            \\<rect x="{d:.2}" y="{d:.2}" width="3.5" height="{d:.2}" rx="2" fill="{s}"/>
            \\
        , .{ card_x + 8, y + 8, card_h - 16, r.primary_color });

        const text_x: f64 = card_x + 22;
        try svg.text(w, text_x, y + 24, "bold", r.name);

        if (r.description.len > 0) {
            const desc = if (r.description.len > 64) r.description[0..64] else r.description;
            try svg.text(w, text_x, y + 41, "muted", desc);
        }

        try svg.circle(w, text_x + 4, y + 53, 4, r.primary_color);
        try svg.text(w, text_x + 14, y + 56, "muted", r.primary_lang);

        const stars_col_x: f64 = @as(f64, @floatFromInt(width)) - 130;
        const forks_col_x: f64 = @as(f64, @floatFromInt(width)) - 60;

        try icons.filled(w, .star, stars_col_x, y + 14, 14, theme.palette[3]);
        var star_buf: [32]u8 = undefined;
        const stars_str = try svg.fmtInt(&star_buf, r.stars, s.display.humanize);
        try svg.text(w, stars_col_x + 18, y + 25, "bold", stars_str);

        try icons.stroke(w, .fork, forks_col_x, y + 14, 14, theme.icon);
        var fork_buf: [32]u8 = undefined;
        const forks_str = try svg.fmtInt(&fork_buf, r.forks, s.display.humanize);
        try svg.text(w, forks_col_x + 18, y + 25, "bold", forks_str);
    }

    try svg.footer(w);
}
