const std = @import("std");
const Value = std.json.Value;

pub const LangCount = struct { name: []const u8, color: []const u8, value: f64 };

pub const ContribDay = struct { date: []const u8, count: u32, weekday: u8 };

pub const RepoSummary = struct {
    name: []const u8,
    description: []const u8,
    stars: u32,
    forks: u32,
    primary_lang: []const u8,
    primary_color: []const u8,
};

pub const DisplayOpts = struct {
    top_langs: usize = 6,
    bio_max: usize = 56,
    humanize: bool = false,
};

pub const Stats = struct {
    name: []const u8,
    login: []const u8,
    bio: []const u8,
    avatar_url: []const u8,
    avatar_data_url: ?[]const u8 = null,
    created_at: []const u8,

    followers: u32,
    following: u32,
    total_prs: u32,
    total_issues: u32,
    total_repos: u32,
    total_stars: u64,
    total_forks: u64,
    total_commits: u32,
    total_contributions: u32,
    contributed_repos: u32,

    repos_per_language: []LangCount,
    commit_per_language: []LangCount,
    contributions: []ContribDay,
    top_repos: []RepoSummary,

    /// True when contributions span the user's full account history rather
    /// than just the most recent year.
    all_time: bool,

    display: DisplayOpts = .{},
};

fn getString(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj.get(key)) |v| return switch (v) {
        .string => |s| s,
        else => "",
    };
    return "";
}

fn getU32(obj: std.json.ObjectMap, key: []const u8) u32 {
    if (obj.get(key)) |v| return switch (v) {
        .integer => |i| blk: {
            if (i < 0) break :blk 0;
            if (i > std.math.maxInt(u32)) break :blk std.math.maxInt(u32);
            break :blk @intCast(i);
        },
        .float => |f| if (f < 0) 0 else @intFromFloat(@min(f, @as(f64, std.math.maxInt(u32)))),
        else => 0,
    };
    return 0;
}

fn isExcluded(name: []const u8, exclude: []const []const u8) bool {
    for (exclude) |e| if (std.ascii.eqlIgnoreCase(name, e)) return true;
    return false;
}

const TallyEntry = struct { color: []const u8, value: f64 };

fn addToTally(tally: *std.StringHashMap(TallyEntry), name: []const u8, color: []const u8, value: f64) !void {
    if (tally.getPtr(name)) |entry| {
        entry.value += value;
    } else {
        try tally.put(name, .{ .color = color, .value = value });
    }
}

fn tallyToSorted(arena: std.mem.Allocator, tally: *std.StringHashMap(TallyEntry)) ![]LangCount {
    var items = try arena.alloc(LangCount, tally.count());
    var idx: usize = 0;
    var it = tally.iterator();
    while (it.next()) |kv| : (idx += 1) {
        items[idx] = .{
            .name = try arena.dupe(u8, kv.key_ptr.*),
            .color = try arena.dupe(u8, kv.value_ptr.color),
            .value = kv.value_ptr.value,
        };
    }
    std.sort.pdq(LangCount, items, {}, langDesc);
    return items;
}

fn langDesc(_: void, a: LangCount, b: LangCount) bool {
    return a.value > b.value;
}

const ContribAcc = struct {
    arena: std.mem.Allocator,
    exclude: []const []const u8,
    seen_dates: std.StringHashMap(void),
    contribs: std.ArrayList(ContribDay),
    contributed_repos: std.StringHashMap(void),
    commit_lang_tally: std.StringHashMap(TallyEntry),
    total_commits: u32 = 0,
    total_contributions: u32 = 0,

    fn init(arena: std.mem.Allocator, exclude: []const []const u8) ContribAcc {
        return .{
            .arena = arena,
            .exclude = exclude,
            .seen_dates = std.StringHashMap(void).init(arena),
            .contribs = .empty,
            .contributed_repos = std.StringHashMap(void).init(arena),
            .commit_lang_tally = std.StringHashMap(TallyEntry).init(arena),
        };
    }

    fn ingest(acc: *ContribAcc, cc: std.json.ObjectMap) !void {
        if (cc.get("contributionCalendar")) |cal_v| if (cal_v == .object) {
            if (cal_v.object.get("weeks")) |weeks_v| if (weeks_v == .array) {
                for (weeks_v.array.items) |w| {
                    if (w != .object) continue;
                    if (w.object.get("contributionDays")) |days_v| if (days_v == .array) {
                        for (days_v.array.items) |d| {
                            if (d != .object) continue;
                            const date_raw = getString(d.object, "date");
                            if (date_raw.len == 0) continue;
                            if (acc.seen_dates.contains(date_raw)) continue;

                            const date_owned = try acc.arena.dupe(u8, date_raw);
                            try acc.seen_dates.put(date_owned, {});

                            const count = getU32(d.object, "contributionCount");
                            const weekday = getU32(d.object, "weekday");
                            const wd: u8 = @intCast(weekday & 0x7);

                            acc.total_contributions +|= count;
                            try acc.contribs.append(acc.arena, .{
                                .date = date_owned,
                                .count = count,
                                .weekday = wd,
                            });
                        }
                    };
                }
            };
        };

        if (cc.get("commitContributionsByRepository")) |arr_v| if (arr_v == .array) {
            for (arr_v.array.items) |entry| {
                if (entry != .object) continue;
                const eo = entry.object;

                var name_with_owner: []const u8 = "";
                var has_lang = false;
                var lname: []const u8 = "Unknown";
                var lcolor: []const u8 = "#888888";
                if (eo.get("repository")) |rv| if (rv == .object) {
                    name_with_owner = getString(rv.object, "nameWithOwner");
                    if (rv.object.get("primaryLanguage")) |pl| if (pl == .object) {
                        const ln = getString(pl.object, "name");
                        if (ln.len > 0) {
                            lname = ln;
                            has_lang = true;
                        }
                        const lc = getString(pl.object, "color");
                        if (lc.len > 0) lcolor = lc;
                    };
                };

                var commits: u32 = 0;
                if (eo.get("contributions")) |cv| if (cv == .object) {
                    if (cv.object.get("nodes")) |nodes_v| if (nodes_v == .array) {
                        for (nodes_v.array.items) |n| {
                            if (n != .object) continue;
                            commits +|= getU32(n.object, "commitCount");
                        }
                    };
                };

                if (commits == 0) continue;

                acc.total_commits +|= commits;
                if (name_with_owner.len > 0 and !acc.contributed_repos.contains(name_with_owner)) {
                    const owned = try acc.arena.dupe(u8, name_with_owner);
                    try acc.contributed_repos.put(owned, {});
                }

                if (!has_lang) continue;
                if (isExcluded(lname, acc.exclude)) continue;
                try addToTally(&acc.commit_lang_tally, lname, lcolor, @as(f64, @floatFromInt(commits)));
            }
        };
    }
};

fn dateLessThan(_: void, a: ContribDay, b: ContribDay) bool {
    return std.mem.order(u8, a.date, b.date) == .lt;
}

pub fn fromGraphQL(
    arena: std.mem.Allocator,
    profile_root: Value,
    extra_collections: []const Value,
    exclude: []const []const u8,
    all_time: bool,
    top_repos_limit: usize,
) !Stats {
    if (profile_root != .object) return error.BadResponse;
    const data_v = profile_root.object.get("data") orelse return error.BadResponse;
    if (data_v != .object) return error.BadResponse;
    const user_v = data_v.object.get("user") orelse return error.BadResponse;
    if (user_v != .object) return error.BadResponse;
    const u = user_v.object;

    const name = try arena.dupe(u8, getString(u, "name"));
    const login = try arena.dupe(u8, getString(u, "login"));
    const bio = try arena.dupe(u8, getString(u, "bio"));
    const avatar_url = try arena.dupe(u8, getString(u, "avatarUrl"));
    const created_at = try arena.dupe(u8, getString(u, "createdAt"));

    const followers = if (u.get("followers")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;
    const following = if (u.get("following")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;
    const total_prs = if (u.get("pullRequests")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;
    const total_issues = if (u.get("issues")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;

    var total_stars: u64 = 0;
    var total_forks: u64 = 0;
    var total_repos: u32 = 0;

    var repo_lang_tally = std.StringHashMap(TallyEntry).init(arena);
    var top: std.ArrayList(RepoSummary) = .empty;

    if (u.get("repositories")) |repos_v| if (repos_v == .object) {
        total_repos = getU32(repos_v.object, "totalCount");
        if (repos_v.object.get("nodes")) |nodes_v| if (nodes_v == .array) {
            for (nodes_v.array.items) |r| {
                if (r != .object) continue;
                const ro = r.object;
                total_stars += getU32(ro, "stargazerCount");
                total_forks += getU32(ro, "forkCount");

                var has_lang = false;
                var lang_name: []const u8 = "Unknown";
                var lang_color: []const u8 = "#888888";
                if (ro.get("primaryLanguage")) |pl| if (pl == .object) {
                    const ln = getString(pl.object, "name");
                    if (ln.len > 0) {
                        lang_name = ln;
                        has_lang = true;
                    }
                    const lc = getString(pl.object, "color");
                    if (lc.len > 0) lang_color = lc;
                };
                if (has_lang and !isExcluded(lang_name, exclude)) {
                    try addToTally(&repo_lang_tally, lang_name, lang_color, 1.0);
                }

                if (top.items.len < top_repos_limit) {
                    try top.append(arena, .{
                        .name = try arena.dupe(u8, getString(ro, "name")),
                        .description = try arena.dupe(u8, getString(ro, "description")),
                        .stars = getU32(ro, "stargazerCount"),
                        .forks = getU32(ro, "forkCount"),
                        .primary_lang = try arena.dupe(u8, lang_name),
                        .primary_color = try arena.dupe(u8, lang_color),
                    });
                }
            }
        };
    };

    var acc = ContribAcc.init(arena, exclude);

    if (u.get("contributionsCollection")) |cc_v| if (cc_v == .object) {
        try acc.ingest(cc_v.object);
    };

    for (extra_collections) |cc_v| {
        if (cc_v != .object) continue;
        try acc.ingest(cc_v.object);
    }

    const sorted_contribs = try acc.contribs.toOwnedSlice(arena);
    std.sort.pdq(ContribDay, sorted_contribs, {}, dateLessThan);

    return .{
        .name = name,
        .login = login,
        .bio = bio,
        .avatar_url = avatar_url,
        .created_at = created_at,
        .followers = followers,
        .following = following,
        .total_prs = total_prs,
        .total_issues = total_issues,
        .total_repos = total_repos,
        .total_stars = total_stars,
        .total_forks = total_forks,
        .total_commits = acc.total_commits,
        .total_contributions = acc.total_contributions,
        .contributed_repos = @intCast(acc.contributed_repos.count()),
        .repos_per_language = try tallyToSorted(arena, &repo_lang_tally),
        .commit_per_language = try tallyToSorted(arena, &acc.commit_lang_tally),
        .contributions = sorted_contribs,
        .top_repos = try top.toOwnedSlice(arena),
        .all_time = all_time,
    };
}

/// Helper for callers that want to extract `data.user.contributionsCollection`
/// from a response root, e.g. when iterating year-by-year via the
/// contributions-only query.
pub fn extractContributionsCollection(root: Value) ?Value {
    if (root != .object) return null;
    const data_v = root.object.get("data") orelse return null;
    if (data_v != .object) return null;
    const user_v = data_v.object.get("user") orelse return null;
    if (user_v != .object) return null;
    return user_v.object.get("contributionsCollection");
}

pub fn extractCreatedAt(root: Value) ?[]const u8 {
    if (root != .object) return null;
    const data_v = root.object.get("data") orelse return null;
    if (data_v != .object) return null;
    const user_v = data_v.object.get("user") orelse return null;
    if (user_v != .object) return null;
    const cv = user_v.object.get("createdAt") orelse return null;
    return switch (cv) {
        .string => |s| s,
        else => null,
    };
}

pub fn streakStats(contributions: []const ContribDay) struct { current: u32, longest: u32, total_active: u32 } {
    var current: u32 = 0;
    var longest: u32 = 0;
    var total_active: u32 = 0;

    var run: u32 = 0;
    for (contributions) |d| {
        if (d.count > 0) {
            total_active += 1;
            run += 1;
            if (run > longest) longest = run;
        } else {
            run = 0;
        }
    }
    if (contributions.len > 0) {
        var i: isize = @as(isize, @intCast(contributions.len)) - 1;
        if (i >= 0 and contributions[@intCast(i)].count == 0) i -= 1;
        while (i >= 0) : (i -= 1) {
            if (contributions[@intCast(i)].count > 0) {
                current += 1;
            } else break;
        }
    }
    return .{ .current = current, .longest = longest, .total_active = total_active };
}
