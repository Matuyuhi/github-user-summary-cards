const std = @import("std");
const Writer = std.Io.Writer;

pub const Icon = enum {
    star,
    fork,
    repo,
    users,
    user_plus,
    pull_request,
    issue,
    commit,
    flame,
    calendar,
    code,
    clock,
    trophy,
    bar_chart,
    sparkles,
    eye,
    activity,
    layers,
};

fn body(name: Icon) []const u8 {
    return switch (name) {
        .star =>
        \\<path d="M12 2l2.939 5.955 6.572.955-4.755 4.635 1.123 6.545L12 17l-5.878 3.09 1.123-6.545L2.49 8.91l6.572-.955z"/>
        ,
        .fork =>
        \\<circle cx="12" cy="6" r="2.5"/>
        \\<circle cx="6" cy="18" r="2.5"/>
        \\<circle cx="18" cy="18" r="2.5"/>
        \\<path d="M12 8.5v2A3.5 3.5 0 0 1 8.5 14H8a4 4 0 0 0-4 4v-2.5"/>
        \\<path d="M12 8.5v2A3.5 3.5 0 0 0 15.5 14H16a4 4 0 0 1 4 4v-2.5"/>
        ,
        .repo =>
        \\<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
        ,
        .users =>
        \\<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
        \\<circle cx="9" cy="7" r="4"/>
        \\<path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
        \\<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
        ,
        .user_plus =>
        \\<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
        \\<circle cx="8.5" cy="7" r="4"/>
        \\<line x1="20" y1="8" x2="20" y2="14"/>
        \\<line x1="23" y1="11" x2="17" y2="11"/>
        ,
        .pull_request =>
        \\<circle cx="6" cy="6" r="3"/>
        \\<circle cx="6" cy="18" r="3"/>
        \\<circle cx="18" cy="18" r="3"/>
        \\<path d="M6 9v6"/>
        \\<path d="M13 6h3a2 2 0 0 1 2 2v7"/>
        ,
        .issue =>
        \\<circle cx="12" cy="12" r="10"/>
        \\<line x1="12" y1="8" x2="12" y2="12"/>
        \\<line x1="12" y1="16" x2="12" y2="16"/>
        ,
        .commit =>
        \\<circle cx="12" cy="12" r="3"/>
        \\<path d="M3 12h6"/>
        \\<path d="M15 12h6"/>
        ,
        .flame =>
        \\<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 0 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>
        ,
        .calendar =>
        \\<rect x="3" y="4" width="18" height="18" rx="2"/>
        \\<line x1="16" y1="2" x2="16" y2="6"/>
        \\<line x1="8" y1="2" x2="8" y2="6"/>
        \\<line x1="3" y1="10" x2="21" y2="10"/>
        ,
        .code =>
        \\<polyline points="16 18 22 12 16 6"/>
        \\<polyline points="8 6 2 12 8 18"/>
        ,
        .clock =>
        \\<circle cx="12" cy="12" r="10"/>
        \\<polyline points="12 6 12 12 16 14"/>
        ,
        .trophy =>
        \\<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/>
        \\<path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/>
        \\<path d="M4 22h16"/>
        \\<path d="M10 14.66V17c0 .55.47.98.97 1.21C12.04 18.75 13 20.24 13 22"/>
        \\<path d="M14 14.66V17c0 .55-.47.98-.97 1.21C11.96 18.75 11 20.24 11 22"/>
        \\<path d="M18 2H6v7a6 6 0 0 0 12 0V2z"/>
        ,
        .bar_chart =>
        \\<line x1="12" y1="20" x2="12" y2="10"/>
        \\<line x1="18" y1="20" x2="18" y2="4"/>
        \\<line x1="6" y1="20" x2="6" y2="16"/>
        ,
        .sparkles =>
        \\<path d="M12 3l1.9 5.6L19.5 10l-5.6 1.4L12 17l-1.9-5.6L4.5 10l5.6-1.4z"/>
        \\<path d="M19 17l.7 2.1 2.1.9-2.1.7L19 23l-.7-2.3L16.2 20l2.1-.9z"/>
        ,
        .eye =>
        \\<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7z"/>
        \\<circle cx="12" cy="12" r="3"/>
        ,
        .activity =>
        \\<polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>
        ,
        .layers =>
        \\<polygon points="12 2 2 7 12 12 22 7 12 2"/>
        \\<polyline points="2 17 12 22 22 17"/>
        \\<polyline points="2 12 12 17 22 12"/>
        ,
    };
}

pub fn stroke(w: *Writer, name: Icon, x: f64, y: f64, size: f64, color: []const u8) !void {
    const s = size / 24.0;
    try w.print(
        \\<g transform="translate({d:.2},{d:.2}) scale({d:.4})" fill="none" stroke="{s}" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
    , .{ x, y, s, color });
    try w.writeAll(body(name));
    try w.writeAll("</g>\n");
}

pub fn filled(w: *Writer, name: Icon, x: f64, y: f64, size: f64, color: []const u8) !void {
    const s = size / 24.0;
    try w.print(
        \\<g transform="translate({d:.2},{d:.2}) scale({d:.4})" fill="{s}" stroke="none">
    , .{ x, y, s, color });
    try w.writeAll(body(name));
    try w.writeAll("</g>\n");
}
