const svg = @import("../svg.zig");
const Stats = @import("../stats.zig").Stats;
const donut = @import("lang_donut.zig");

pub fn render(w: *svg.Writer, theme: svg.Theme, s: *const Stats) !void {
    try donut.render(w, theme, "Most Commit Language", s.commit_per_language, s.display);
}
