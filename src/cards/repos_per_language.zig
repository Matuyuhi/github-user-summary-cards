const std = @import("std");
const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;
const donut = @import("lang_donut.zig");

pub fn render(allocator: std.mem.Allocator, writer: anytype, theme: svg.Theme, s: *const Stats) !void {
    try donut.render(allocator, writer, theme, "Repos per Language", s.repos_per_language);
}
