const std = @import("std");
const svg = @import("../svg.zig");
const icons = @import("../icons.zig");
const Stats = @import("../stats.zig").Stats;

fn levelColor(theme: svg.Theme, count: u32, max: u32) []const u8 {
    if (count == 0) return theme.border;
    const ratio = @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(@max(max, 1)));
    if (ratio < 0.25) return theme.palette[5];
    if (ratio < 0.5) return theme.palette[3];
    if (ratio < 0.75) return theme.palette[2];
    return theme.palette[0];
}

const month_short = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

fn parseMonth(date: []const u8) ?u8 {
    if (date.len < 7) return null;
    const m1 = date[5];
    const m2 = date[6];
    if (m1 < '0' or m1 > '9' or m2 < '0' or m2 > '9') return null;
    const m = (m1 - '0') * 10 + (m2 - '0');
    if (m < 1 or m > 12) return null;
    return m;
}

fn isFirstOfMonth(date: []const u8) bool {
    if (date.len < 10) return false;
    return date[8] == '0' and date[9] == '1';
}

pub fn render(w: *svg.Writer, theme: svg.Theme, s: *const Stats) !void {
    const width: u32 = 800;
    const height: u32 = 220;
    try svg.header(w, width, height, theme, "Contribution Heatmap");

    try icons.stroke(w, .calendar, @as(f64, @floatFromInt(width)) - 38, 14, 18, theme.icon);

    if (s.contributions.len == 0) {
        try svg.text(w, 32, 110, "muted", "(no data)");
        try svg.footer(w);
        return;
    }

    const window_max_days: usize = 53 * 7;
    const start_idx: usize = if (s.contributions.len > window_max_days)
        s.contributions.len - window_max_days
    else
        0;
    const window = s.contributions[start_idx..];

    var max: u32 = 0;
    var window_total: u64 = 0;
    for (window) |d| {
        if (d.count > max) max = d.count;
        window_total += d.count;
    }

    const cell: f64 = 11;
    const gap: f64 = 2;
    const ox: f64 = 36;
    const oy: f64 = 76;

    const first_wd: u8 = window[0].weekday;

    const day_labels = [_][]const u8{ "", "Mon", "", "Wed", "", "Fri", "" };
    var d: usize = 0;
    while (d < 7) : (d += 1) {
        if (day_labels[d].len > 0) {
            const y = oy + @as(f64, @floatFromInt(d)) * (cell + gap) + cell - 2;
            try svg.text(w, 18, y, "label", day_labels[d]);
        }
    }

    var col: usize = 0;
    var row: usize = first_wd;

    for (window, 0..) |day, idx| {
        const x = ox + @as(f64, @floatFromInt(col)) * (cell + gap);
        const y = oy + @as(f64, @floatFromInt(row)) * (cell + gap);
        try svg.rect(w, x, y, cell, cell, 2, levelColor(theme, day.count, max));

        if (isFirstOfMonth(day.date)) {
            if (parseMonth(day.date)) |m| {
                if (idx > 0 or row == 0) {
                    try svg.text(w, x, oy - 8, "label", month_short[m - 1]);
                }
            }
        }

        row += 1;
        if (row > 6) {
            row = 0;
            col += 1;
        }
    }

    const legend_y: f64 = @as(f64, @floatFromInt(height)) - 22;
    try svg.text(w, 36, legend_y, "muted", "Less");
    var lx: f64 = 70;
    var lvl: u32 = 0;
    while (lvl < 5) : (lvl += 1) {
        const fake_count: u32 = if (lvl == 0) 0 else lvl;
        const fake_max: u32 = 4;
        const c = levelColor(theme, fake_count, fake_max);
        try svg.rect(w, lx, legend_y - 10, cell, cell, 2, c);
        lx += cell + gap + 1;
    }
    try svg.text(w, lx + 4, legend_y, "muted", "More");

    var n_buf: [32]u8 = undefined;
    const total_str = try svg.fmtInt(&n_buf, window_total, s.display.humanize);
    var buf: [96]u8 = undefined;
    const summary = try std.fmt.bufPrint(&buf, "{s} contributions in the last year", .{total_str});
    try svg.textAnchor(w, @as(f64, @floatFromInt(width)) - 24, legend_y, "bold", "end", summary);

    try svg.footer(w);
}
