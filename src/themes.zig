const std = @import("std");

pub const Theme = struct {
    name: []const u8,
    bg: []const u8,
    title: []const u8,
    text: []const u8,
    icon: []const u8,
    border: []const u8,
    palette: [8][]const u8,
};

pub const themes = [_]Theme{
    .{
        .name = "default",
        .bg = "#fffefe",
        .title = "#2f80ed",
        .text = "#434d58",
        .icon = "#4c71f2",
        .border = "#e4e2e2",
        .palette = .{ "#2f80ed", "#79c0ff", "#56d364", "#f78166", "#bc8cff", "#ffd33d", "#fa7970", "#a371f7" },
    },
    .{
        .name = "dracula",
        .bg = "#282a36",
        .title = "#ff79c6",
        .text = "#f8f8f2",
        .icon = "#bd93f9",
        .border = "#44475a",
        .palette = .{ "#bd93f9", "#ff79c6", "#50fa7b", "#ffb86c", "#8be9fd", "#f1fa8c", "#ff5555", "#6272a4" },
    },
    .{
        .name = "nord_dark",
        .bg = "#2e3440",
        .title = "#88c0d0",
        .text = "#e5e9f0",
        .icon = "#81a1c1",
        .border = "#3b4252",
        .palette = .{ "#88c0d0", "#81a1c1", "#a3be8c", "#ebcb8b", "#d08770", "#bf616a", "#b48ead", "#8fbcbb" },
    },
    .{
        .name = "tokyonight",
        .bg = "#1a1b27",
        .title = "#70a5fd",
        .text = "#a9b1d6",
        .icon = "#bb9af7",
        .border = "#414868",
        .palette = .{ "#7aa2f7", "#bb9af7", "#9ece6a", "#e0af68", "#f7768e", "#7dcfff", "#ff9e64", "#73daca" },
    },
    .{
        .name = "gruvbox",
        .bg = "#282828",
        .title = "#fabd2f",
        .text = "#ebdbb2",
        .icon = "#fe8019",
        .border = "#504945",
        .palette = .{ "#fabd2f", "#fe8019", "#b8bb26", "#83a598", "#d3869b", "#fb4934", "#8ec07c", "#d65d0e" },
    },
    .{
        .name = "solarized_light",
        .bg = "#fdf6e3",
        .title = "#268bd2",
        .text = "#586e75",
        .icon = "#2aa198",
        .border = "#eee8d5",
        .palette = .{ "#268bd2", "#2aa198", "#859900", "#b58900", "#cb4b16", "#dc322f", "#d33682", "#6c71c4" },
    },
};

pub fn byName(name: []const u8) Theme {
    for (themes) |t| {
        if (std.ascii.eqlIgnoreCase(name, t.name)) return t;
    }
    return themes[0];
}
