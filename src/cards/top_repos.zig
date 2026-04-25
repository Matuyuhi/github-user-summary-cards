const std = @import("std");
const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const Stats) !void {
    _ = allocator;
    const count: u32 = @intCast(s.top_repos.len);
    const row_h: u32 = 48;
    const w: u32 = 540;
    const h: u32 = 60 + row_h * @max(count, 1);
    try svg.header(writer, w, h, theme, "Top Repositories");

    if (s.top_repos.len == 0) {
        try svg.text(writer, 20, 80, "muted", "(no public repos)");
        try svg.footer(writer);
        return;
    }

    var i: usize = 0;
    while (i < s.top_repos.len) : (i += 1) {
        const r = s.top_repos[i];
        const y: f64 = 60 + @as(f64, @floatFromInt(i)) * @as(f64, @floatFromInt(row_h));
        try svg.rect(writer, 12, y, @as(f64, @floatFromInt(w)) - 24, @as(f64, @floatFromInt(row_h)) - 8, 6, theme.border);
        try svg.text(writer, 20, y + 18, "bold", r.name);

        // Language dot + name
        try writer.print(
            \\<circle cx="22" cy="{d:.2}" r="5" fill="{s}"/>
            \\
        , .{ y + 32, r.primary_color });
        try svg.text(writer, 32, y + 36, "muted", r.primary_lang);

        var buf: [64]u8 = undefined;
        const stars = try std.fmt.bufPrint(&buf, "* {d}", .{r.stars});
        try svg.text(writer, @as(f64, @floatFromInt(w)) - 140, y + 36, "text", stars);

        var buf2: [64]u8 = undefined;
        const forks = try std.fmt.bufPrint(&buf2, "Y {d}", .{r.forks});
        try svg.text(writer, @as(f64, @floatFromInt(w)) - 80, y + 36, "text", forks);

        if (r.description.len > 0) {
            const desc = if (r.description.len > 60) r.description[0..60] else r.description;
            try svg.text(writer, 150, y + 18, "muted", desc);
        }
    }

    try svg.footer(writer);
}
