const std = @import("std");
const Io = std.Io;
const Writer = std.Io.Writer;

const config = @import("config.zig");
const themes = @import("themes.zig");
const github = @import("github.zig");
const queries = @import("queries.zig");
const stats_mod = @import("stats.zig");
const svg = @import("svg.zig");

const profile_card = @import("cards/profile_details.zig");
const repos_lang_card = @import("cards/repos_per_language.zig");
const commit_lang_card = @import("cards/most_commit_language.zig");
const stats_card = @import("cards/stats_card.zig");
const heatmap_card = @import("cards/contribution_heatmap.zig");
const streak_card = @import("cards/streak.zig");
const top_repos_card = @import("cards/top_repos.zig");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const gpa = init.gpa;
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    const cfg = config.parse(arena, args, init.environ_map) catch |err| switch (err) {
        error.HelpRequested => {
            var buf: [4096]u8 = undefined;
            const ls = std.debug.lockStderr(&buf);
            defer std.debug.unlockStderr();
            try config.printHelp(&ls.file_writer.interface);
            return;
        },
        error.MissingUsername => {
            std.log.err("usage: github-user-summary-cards <username> (or set GITHUB_USERNAME)", .{});
            std.process.exit(1);
        },
        error.UnknownCardName => {
            std.log.err("--cards: unknown card name (valid: profile, repos-per-language, most-commit-language, stats, contribution-heatmap, streak, top-repos)", .{});
            std.process.exit(1);
        },
        error.InvalidNumber => {
            std.log.err("invalid number passed to --top-langs / --top-repos / --bio-max", .{});
            std.process.exit(1);
        },
        else => return err,
    };

    if (cfg.token == null) {
        std.log.warn("no GITHUB_TOKEN set — using unauthenticated GraphQL (60/hour limit, public data only)", .{});
    }

    const theme = themes.byName(cfg.theme);
    const today = github.todaysDate(io);

    const profile_query = try buildProfileQuery(arena, cfg.include_forks);

    var first_from_buf: [32]u8 = undefined;
    var first_to_buf: [32]u8 = undefined;
    const first_window: struct { from: []const u8, to: []const u8 } = if (cfg.all_time) .{
        .from = try github.formatDayStart(&first_from_buf, today.year, 1, 1),
        .to = try github.formatDayEnd(&first_to_buf, today.year, today.month, today.day),
    } else blk: {
        const w = try github.yearWindow(io, &first_from_buf, &first_to_buf);
        break :blk .{ .from = w.from, .to = w.to };
    };

    std.log.info("fetching GitHub stats for @{s}{s}...", .{
        cfg.username,
        if (cfg.all_time) " (all-time)" else "",
    });

    var resp = github.postGraphQL(
        gpa,
        io,
        profile_query,
        try buildVars(arena, cfg.username, first_window.from, first_window.to),
        cfg.token,
    ) catch |err| switch (err) {
        error.UserNotFound => {
            std.log.err("user not found: {s}", .{cfg.username});
            std.process.exit(2);
        },
        error.HttpError, error.GraphQLError => {
            std.log.err("github API error: {s}", .{@errorName(err)});
            std.process.exit(2);
        },
        else => return err,
    };
    defer resp.deinit();

    var extra_collections: std.ArrayList(std.json.Value) = .empty;
    var extra_responses: std.ArrayList(github.Response) = .empty;
    defer for (extra_responses.items) |*r| r.deinit();

    if (cfg.all_time) {
        const created_at = stats_mod.extractCreatedAt(resp.root()) orelse "";
        if (parseYear(created_at)) |join_year| {
            var year: i32 = @as(i32, today.year) - 1;
            while (year >= @as(i32, join_year)) : (year -= 1) {
                const y: u16 = @intCast(year);
                var fb: [32]u8 = undefined;
                var tb: [32]u8 = undefined;

                const from_str = if (y == join_year) blk: {
                    if (created_at.len >= 10) {
                        break :blk try std.fmt.bufPrint(&fb, "{s}T00:00:00Z", .{created_at[0..10]});
                    }
                    break :blk try github.formatDayStart(&fb, y, 1, 1);
                } else try github.formatDayStart(&fb, y, 1, 1);

                const to_str = try github.formatDayEnd(&tb, y, 12, 31);

                const sub_resp = github.postGraphQL(
                    gpa,
                    io,
                    queries.contributions_query,
                    try buildVars(arena, cfg.username, from_str, to_str),
                    cfg.token,
                ) catch |err| {
                    std.log.warn("contributions query failed for {d}: {s} — skipping", .{ y, @errorName(err) });
                    continue;
                };
                try extra_responses.append(arena, sub_resp);

                if (stats_mod.extractContributionsCollection(sub_resp.root())) |cc| {
                    try extra_collections.append(arena, cc);
                }
            }
        } else {
            std.log.warn("could not parse createdAt — falling back to current-year contributions only", .{});
        }
    }

    var stats = try stats_mod.fromGraphQL(
        arena,
        resp.root(),
        extra_collections.items,
        cfg.exclude,
        cfg.all_time,
        cfg.top_repos,
    );
    stats.display = .{
        .top_langs = cfg.top_langs,
        .bio_max = cfg.bio_max,
        .humanize = cfg.humanize,
    };

    if (cfg.embed_avatar and stats.avatar_url.len > 0 and shouldRender(cfg.cards, .profile)) {
        stats.avatar_data_url = github.fetchImageDataUrl(arena, io, stats.avatar_url) catch |err| blk: {
            std.log.warn("avatar fetch failed: {s} — falling back to remote URL", .{@errorName(err)});
            break :blk null;
        };
    }

    Io.Dir.cwd().createDirPath(io, cfg.output_dir) catch |err| {
        std.log.err("cannot create output dir {s}: {s}", .{ cfg.output_dir, @errorName(err) });
        std.process.exit(3);
    };

    var rendered: usize = 0;
    for (cfg.cards) |kind| {
        try renderCard(io, arena, cfg.output_dir, kind, theme, &stats);
        rendered += 1;
    }

    std.log.info("wrote {d} SVG card(s) to {s}/", .{ rendered, cfg.output_dir });
}

fn shouldRender(cards: []const config.CardKind, target: config.CardKind) bool {
    for (cards) |c| if (c == target) return true;
    return false;
}

fn renderCard(
    io: Io,
    arena: std.mem.Allocator,
    out_dir: []const u8,
    kind: config.CardKind,
    theme: svg.Theme,
    s: *const stats_mod.Stats,
) !void {
    const path = try std.fs.path.join(arena, &.{ out_dir, kind.filename() });
    var file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);

    var buf: [16 * 1024]u8 = undefined;
    var fw = file.writer(io, &buf);
    const w = &fw.interface;

    switch (kind) {
        .profile => try profile_card.render(w, theme, s),
        .repos_lang => try repos_lang_card.render(w, theme, s),
        .commit_lang => try commit_lang_card.render(w, theme, s),
        .stats => try stats_card.render(w, theme, s),
        .heatmap => try heatmap_card.render(w, theme, s),
        .streak => try streak_card.render(w, theme, s),
        .top_repos => try top_repos_card.render(w, theme, s),
    }

    try fw.end();
}

fn buildProfileQuery(arena: std.mem.Allocator, include_forks: bool) ![]u8 {
    const fork_filter: []const u8 = if (include_forks) "" else ", isFork: false";
    return try std.mem.replaceOwned(u8, arena, queries.profile_query_template, "%FORK_FILTER%", fork_filter);
}

fn buildVars(arena: std.mem.Allocator, login: []const u8, from: []const u8, to: []const u8) ![]u8 {
    var body: Writer.Allocating = .init(arena);
    const w = &body.writer;
    try w.writeAll("{\"login\":");
    try std.json.Stringify.value(login, .{}, w);
    try w.writeAll(",\"from\":");
    try std.json.Stringify.value(from, .{}, w);
    try w.writeAll(",\"to\":");
    try std.json.Stringify.value(to, .{}, w);
    try w.writeAll("}");
    return try body.toOwnedSlice();
}

fn parseYear(iso: []const u8) ?u16 {
    if (iso.len < 4) return null;
    return std.fmt.parseInt(u16, iso[0..4], 10) catch null;
}
