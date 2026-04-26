const std = @import("std");
const svg = @import("../svg.zig");
const icons = @import("../icons.zig");
const Stats = @import("../stats.zig").Stats;

pub fn render(w: *svg.Writer, theme: svg.Theme, s: *const Stats) !void {
    const width: u32 = 560;
    const height: u32 = 280;

    const avatar_href: ?[]const u8 = s.avatar_data_url orelse if (s.avatar_url.len > 0) s.avatar_url else null;
    const has_avatar = avatar_href != null;
    const defs_extra = if (has_avatar)
        \\<clipPath id="avatar-clip"><circle cx="62" cy="100" r="38"/></clipPath>
    else
        "";

    try svg.headerExt(w, width, height, theme, "Profile Details", .{ .extra_defs = defs_extra });

    if (avatar_href) |href| {
        try svg.circle(w, 62, 100, 40, theme.border);
        try w.writeAll("<image href=\"");
        try svg.escape(w, href);
        try w.writeAll(
            \\" x="24" y="62" width="76" height="76" clip-path="url(#avatar-clip)" preserveAspectRatio="xMidYMid slice"/>
            \\
        );
        try w.print(
            \\<circle cx="62" cy="100" r="38" fill="none" stroke="{s}" stroke-width="1" opacity="0.5"/>
            \\
        , .{theme.border});
    }

    const display = if (s.name.len > 0) s.name else s.login;
    const text_x: f64 = if (has_avatar) 120 else 20;
    try svg.text(w, text_x, 80, "bold", display);

    if (s.name.len > 0 and s.login.len > 0) {
        var login_buf: [80]u8 = undefined;
        const login_str = std.fmt.bufPrint(&login_buf, "@{s}", .{s.login}) catch s.login;
        try svg.text(w, text_x, 100, "muted", login_str);
    }

    if (s.bio.len > 0) {
        const bio_trim = if (s.bio.len > s.display.bio_max) s.bio[0..s.display.bio_max] else s.bio;
        try svg.text(w, text_x, 122, "text", bio_trim);
    }

    if (s.created_at.len >= 10) {
        var join_buf: [64]u8 = undefined;
        const join = std.fmt.bufPrint(&join_buf, "Joined {s}", .{s.created_at[0..10]}) catch "";
        try svg.text(w, text_x, 142, "muted", join);
    }

    try svg.divider(w, 20, 158, @floatFromInt(width - 40), theme.border);

    const Row = struct { icon: icons.Icon, label: []const u8, value: u64 };
    const rows = [_]Row{
        .{ .icon = .users,         .label = "Followers",     .value = s.followers },
        .{ .icon = .user_plus,     .label = "Following",     .value = s.following },
        .{ .icon = .star,          .label = "Stars Earned",  .value = s.total_stars },
        .{ .icon = .fork,          .label = "Forks",         .value = s.total_forks },
        .{ .icon = .pull_request,  .label = "Total PRs",     .value = s.total_prs },
        .{ .icon = .issue,         .label = "Total Issues",  .value = s.total_issues },
        .{ .icon = .repo,          .label = "Repos Owned",   .value = s.total_repos },
        .{ .icon = .commit,        .label = "Commits",       .value = s.total_commits },
    };

    const col_w: f64 = (@as(f64, @floatFromInt(width)) - 40) / 2.0;
    const row_h: f64 = 26;
    const start_y: f64 = 184;

    var i: usize = 0;
    while (i < rows.len) : (i += 1) {
        const col = i % 2;
        const row = i / 2;
        const cx: f64 = 20 + @as(f64, @floatFromInt(col)) * col_w;
        const cy: f64 = start_y + @as(f64, @floatFromInt(row)) * row_h;

        try icons.stroke(w, rows[i].icon, cx, cy - 12, 14, theme.icon);
        try svg.text(w, cx + 22, cy, "text", rows[i].label);

        var num_buf: [32]u8 = undefined;
        const num = try svg.fmtInt(&num_buf, rows[i].value, s.display.humanize);
        try svg.textAnchor(w, cx + col_w - 14, cy, "num", "end", num);
    }

    try svg.footer(w);
}
