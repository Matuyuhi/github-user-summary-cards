const std = @import("std");
const process = std.process;

pub const CardKind = enum {
    profile,
    repos_lang,
    commit_lang,
    stats,
    heatmap,
    streak,
    top_repos,

    pub fn filename(self: CardKind) []const u8 {
        return switch (self) {
            .profile => "profile-details.svg",
            .repos_lang => "repos-per-language.svg",
            .commit_lang => "most-commit-language.svg",
            .stats => "stats.svg",
            .heatmap => "contribution-heatmap.svg",
            .streak => "streak.svg",
            .top_repos => "top-repos.svg",
        };
    }
};

pub const all_cards = [_]CardKind{ .profile, .repos_lang, .commit_lang, .stats, .heatmap, .streak, .top_repos };

fn parseCardName(name: []const u8) ?CardKind {
    const Pair = struct { name: []const u8, kind: CardKind };
    const aliases = [_]Pair{
        .{ .name = "profile",              .kind = .profile },
        .{ .name = "profile-details",      .kind = .profile },
        .{ .name = "repos-per-language",   .kind = .repos_lang },
        .{ .name = "repos-lang",           .kind = .repos_lang },
        .{ .name = "lang-repos",           .kind = .repos_lang },
        .{ .name = "most-commit-language", .kind = .commit_lang },
        .{ .name = "commit-lang",          .kind = .commit_lang },
        .{ .name = "stats",                .kind = .stats },
        .{ .name = "contribution-heatmap", .kind = .heatmap },
        .{ .name = "heatmap",              .kind = .heatmap },
        .{ .name = "streak",               .kind = .streak },
        .{ .name = "top-repos",            .kind = .top_repos },
        .{ .name = "repos",                .kind = .top_repos },
    };
    for (aliases) |a| {
        if (std.ascii.eqlIgnoreCase(name, a.name)) return a.kind;
    }
    return null;
}

pub const Config = struct {
    username: []const u8,
    token: ?[]const u8,
    theme: []const u8,
    exclude: []const []const u8,
    all_time: bool,
    output_dir: []const u8,

    cards: []const CardKind,
    top_langs: usize,
    top_repos: usize,
    include_forks: bool,
    bio_max: usize,
    embed_avatar: bool,
    humanize: bool,
};

fn envOr(env: *const process.Environ.Map, name: []const u8, fallback: []const u8) []const u8 {
    return env.get(name) orelse fallback;
}

fn isTruthy(s: []const u8) bool {
    if (s.len == 0) return false;
    return std.ascii.eqlIgnoreCase(s, "1") or
        std.ascii.eqlIgnoreCase(s, "true") or
        std.ascii.eqlIgnoreCase(s, "yes") or
        std.ascii.eqlIgnoreCase(s, "on");
}

fn splitCsv(arena: std.mem.Allocator, csv: []const u8) ![]const []const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, csv, ',');
    while (it.next()) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0) continue;
        try list.append(arena, try arena.dupe(u8, trimmed));
    }
    return try list.toOwnedSlice(arena);
}

fn parseCardsCsv(arena: std.mem.Allocator, csv: []const u8) ![]const CardKind {
    var list: std.ArrayList(CardKind) = .empty;
    var it = std.mem.splitScalar(u8, csv, ',');
    while (it.next()) |raw| {
        const trimmed = std.mem.trim(u8, raw, " \t\r\n");
        if (trimmed.len == 0) continue;
        const kind = parseCardName(trimmed) orelse return error.UnknownCardName;
        var seen = false;
        for (list.items) |existing| if (existing == kind) {
            seen = true;
            break;
        };
        if (!seen) try list.append(arena, kind);
    }
    return try list.toOwnedSlice(arena);
}

fn clamp(value: usize, lo: usize, hi: usize) usize {
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
}

fn parseSize(s: []const u8, lo: usize, hi: usize) !usize {
    const n = std.fmt.parseInt(usize, s, 10) catch return error.InvalidNumber;
    return clamp(n, lo, hi);
}

pub fn parse(
    arena: std.mem.Allocator,
    args: []const [:0]const u8,
    env: *const process.Environ.Map,
) !Config {
    var positional: ?[]const u8 = null;
    var theme_arg: ?[]const u8 = null;
    var exclude_arg: ?[]const u8 = null;
    var out_arg: ?[]const u8 = null;
    var cards_arg: ?[]const u8 = null;
    var top_langs_arg: ?[]const u8 = null;
    var top_repos_arg: ?[]const u8 = null;
    var bio_max_arg: ?[]const u8 = null;
    var all_time_flag: ?bool = null;
    var include_forks_flag: ?bool = null;
    var embed_avatar_flag: ?bool = null;
    var humanize_flag: ?bool = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--theme") and i + 1 < args.len) {
            i += 1;
            theme_arg = args[i];
        } else if (std.mem.eql(u8, a, "--exclude") and i + 1 < args.len) {
            i += 1;
            exclude_arg = args[i];
        } else if (std.mem.eql(u8, a, "--output") and i + 1 < args.len) {
            i += 1;
            out_arg = args[i];
        } else if (std.mem.eql(u8, a, "--cards") and i + 1 < args.len) {
            i += 1;
            cards_arg = args[i];
        } else if (std.mem.eql(u8, a, "--top-langs") and i + 1 < args.len) {
            i += 1;
            top_langs_arg = args[i];
        } else if (std.mem.eql(u8, a, "--top-repos") and i + 1 < args.len) {
            i += 1;
            top_repos_arg = args[i];
        } else if (std.mem.eql(u8, a, "--bio-max") and i + 1 < args.len) {
            i += 1;
            bio_max_arg = args[i];
        } else if (std.mem.eql(u8, a, "--all-time")) {
            all_time_flag = true;
        } else if (std.mem.eql(u8, a, "--include-forks")) {
            include_forks_flag = true;
        } else if (std.mem.eql(u8, a, "--no-avatar-embed")) {
            embed_avatar_flag = false;
        } else if (std.mem.eql(u8, a, "--humanize")) {
            humanize_flag = true;
        } else if (std.mem.eql(u8, a, "-h") or std.mem.eql(u8, a, "--help")) {
            return error.HelpRequested;
        } else if (a.len > 0 and a[0] != '-' and positional == null) {
            positional = a;
        }
    }

    const username_src = positional orelse env.get("GITHUB_USERNAME") orelse return error.MissingUsername;
    const username = try arena.dupe(u8, username_src);

    const token: ?[]const u8 = if (env.get("GITHUB_TOKEN")) |t|
        if (t.len == 0) null else try arena.dupe(u8, t)
    else
        null;

    const theme_src = theme_arg orelse envOr(env, "THEME", "default");
    const theme = try arena.dupe(u8, theme_src);

    const exclude_csv = exclude_arg orelse envOr(env, "EXCLUDE", "");
    const exclude = try splitCsv(arena, exclude_csv);

    const all_time = all_time_flag orelse if (env.get("ALL_TIME")) |v| isTruthy(v) else false;
    const include_forks = include_forks_flag orelse if (env.get("INCLUDE_FORKS")) |v| isTruthy(v) else false;
    const embed_avatar = embed_avatar_flag orelse if (env.get("NO_AVATAR_EMBED")) |v| !isTruthy(v) else true;
    const humanize = humanize_flag orelse if (env.get("HUMANIZE")) |v| isTruthy(v) else false;

    const cards_csv = cards_arg orelse envOr(env, "CARDS", "");
    const cards = if (cards_csv.len == 0)
        try arena.dupe(CardKind, &all_cards)
    else
        try parseCardsCsv(arena, cards_csv);

    const top_langs_str = top_langs_arg orelse envOr(env, "TOP_LANGS", "6");
    const top_langs = parseSize(top_langs_str, 1, 20) catch return error.InvalidNumber;

    const top_repos_str = top_repos_arg orelse envOr(env, "TOP_REPOS", "6");
    const top_repos = parseSize(top_repos_str, 1, 20) catch return error.InvalidNumber;

    const bio_max_str = bio_max_arg orelse envOr(env, "BIO_MAX", "56");
    const bio_max = parseSize(bio_max_str, 8, 400) catch return error.InvalidNumber;

    const out_src = out_arg orelse envOr(env, "OUTPUT_DIR", "profile-summary-card-output");
    const output_dir = try arena.dupe(u8, out_src);

    return .{
        .username = username,
        .token = token,
        .theme = theme,
        .exclude = exclude,
        .all_time = all_time,
        .output_dir = output_dir,
        .cards = cards,
        .top_langs = top_langs,
        .top_repos = top_repos,
        .include_forks = include_forks,
        .bio_max = bio_max,
        .embed_avatar = embed_avatar,
        .humanize = humanize,
    };
}

pub fn printHelp(w: *std.Io.Writer) !void {
    try w.writeAll(
        \\github-user-summary-cards <username> [options]
        \\
        \\Options:
        \\  --theme <name>      Theme: default, dracula, nord_dark, tokyonight, gruvbox, solarized_light
        \\  --exclude <csv>     Comma-separated languages to exclude
        \\  --all-time          Aggregate across the user's full history (issues N+1 GraphQL queries)
        \\  --cards <csv>       Subset of cards to render. Names: profile, repos-per-language,
        \\                      most-commit-language, stats, contribution-heatmap, streak, top-repos
        \\                      (default: all)
        \\  --top-langs <n>     Top N languages shown in donut cards (1..20, default 6)
        \\  --top-repos <n>     Number of repos shown in top-repos card (1..20, default 6)
        \\  --include-forks     Include forked repositories in repo / language tallies
        \\  --bio-max <n>       Max bio characters shown on profile card (8..400, default 56)
        \\  --no-avatar-embed   Skip avatar fetch / base64 embedding (smaller SVG, but the avatar
        \\                      will not render when the SVG is loaded as <img src="...">)
        \\  --humanize          Abbreviate large numbers (e.g. 1234 -> 1.2k, 3450000 -> 3.5m)
        \\  --output <dir>      Output directory (default: profile-summary-card-output)
        \\  -h, --help          Show this help
        \\
        \\Environment:
        \\  GITHUB_USERNAME   Fallback if no positional argument is given
        \\  GITHUB_TOKEN      Optional. When set, private repos / private contributions are included.
        \\  ALL_TIME, INCLUDE_FORKS, NO_AVATAR_EMBED, HUMANIZE   Truthy values (1/true/yes/on)
        \\  CARDS, TOP_LANGS, TOP_REPOS, BIO_MAX, THEME, EXCLUDE, OUTPUT_DIR
        \\                    Same as the matching CLI flags
        \\
    );
}
