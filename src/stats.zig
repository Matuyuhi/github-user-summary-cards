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

pub const Stats = struct {
    allocator: std.mem.Allocator,

    name: []const u8,
    login: []const u8,
    bio: []const u8,
    avatar_url: []const u8,
    created_at: []const u8,

    followers: u32,
    following: u32,
    total_prs: u32,
    total_issues: u32,
    total_repos: u32,
    total_stars: u64,
    total_forks: u64,
    total_commits_year: u32,
    total_contributions_year: u32,
    contributed_repos_year: u32,

    repos_per_language: []LangCount,
    commit_per_language: []LangCount,
    contributions: []ContribDay, // chronological
    weekday_commits: [7]u32, // Sunday..Saturday
    top_repos: []RepoSummary,

    pub fn deinit(self: *Stats) void {
        const a = self.allocator;
        a.free(self.name);
        a.free(self.login);
        a.free(self.bio);
        a.free(self.avatar_url);
        a.free(self.created_at);
        for (self.repos_per_language) |l| {
            a.free(l.name);
            a.free(l.color);
        }
        a.free(self.repos_per_language);
        for (self.commit_per_language) |l| {
            a.free(l.name);
            a.free(l.color);
        }
        a.free(self.commit_per_language);
        for (self.contributions) |c| a.free(c.date);
        a.free(self.contributions);
        for (self.top_repos) |r| {
            a.free(r.name);
            a.free(r.description);
            a.free(r.primary_lang);
            a.free(r.primary_color);
        }
        a.free(self.top_repos);
    }
};

fn dupOpt(allocator: std.mem.Allocator, v: ?Value) ![]u8 {
    if (v == null) return try allocator.dupe(u8, "");
    return switch (v.?) {
        .string => |s| try allocator.dupe(u8, s),
        else => try allocator.dupe(u8, ""),
    };
}

fn getString(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    if (obj.get(key)) |v| {
        return switch (v) {
            .string => |s| s,
            else => "",
        };
    }
    return "";
}

fn getU32(obj: std.json.ObjectMap, key: []const u8) u32 {
    if (obj.get(key)) |v| {
        return switch (v) {
            .integer => |i| blk: {
                if (i < 0) break :blk 0;
                if (i > std.math.maxInt(u32)) break :blk std.math.maxInt(u32);
                break :blk @intCast(i);
            },
            .float => |f| if (f < 0) 0 else @intFromFloat(@min(f, @as(f64, std.math.maxInt(u32)))),
            else => 0,
        };
    }
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

fn tallyToSorted(allocator: std.mem.Allocator, tally: *std.StringHashMap(TallyEntry)) ![]LangCount {
    var items = try allocator.alloc(LangCount, tally.count());
    var idx: usize = 0;
    var it = tally.iterator();
    while (it.next()) |kv| : (idx += 1) {
        items[idx] = .{
            .name = try allocator.dupe(u8, kv.key_ptr.*),
            .color = try allocator.dupe(u8, kv.value_ptr.color),
            .value = kv.value_ptr.value,
        };
    }
    std.sort.pdq(LangCount, items, {}, langDesc);
    return items;
}

fn langDesc(_: void, a: LangCount, b: LangCount) bool {
    return a.value > b.value;
}

pub fn fromGraphQL(
    allocator: std.mem.Allocator,
    root: Value,
    exclude: []const []const u8,
) !Stats {
    if (root != .object) return error.BadResponse;
    const data_v = root.object.get("data") orelse return error.BadResponse;
    if (data_v != .object) return error.BadResponse;
    const user_v = data_v.object.get("user") orelse return error.BadResponse;
    if (user_v != .object) return error.BadResponse;
    const u = user_v.object;

    const name = try allocator.dupe(u8, getString(u, "name"));
    const login = try allocator.dupe(u8, getString(u, "login"));
    const bio = try allocator.dupe(u8, getString(u, "bio"));
    const avatar_url = try allocator.dupe(u8, getString(u, "avatarUrl"));
    const created_at = try allocator.dupe(u8, getString(u, "createdAt"));

    const followers = if (u.get("followers")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;
    const following = if (u.get("following")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;
    const total_prs = if (u.get("pullRequests")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;
    const total_issues = if (u.get("issues")) |v| (if (v == .object) getU32(v.object, "totalCount") else 0) else 0;

    // Repositories
    var total_stars: u64 = 0;
    var total_forks: u64 = 0;
    var total_repos: u32 = 0;

    var repo_lang_tally = std.StringHashMap(TallyEntry).init(allocator);
    defer repo_lang_tally.deinit();

    var top = std.ArrayList(RepoSummary).init(allocator);
    defer {
        for (top.items) |r| {
            allocator.free(r.name);
            allocator.free(r.description);
            allocator.free(r.primary_lang);
            allocator.free(r.primary_color);
        }
        top.deinit();
    }

    if (u.get("repositories")) |repos_v| if (repos_v == .object) {
        total_repos = getU32(repos_v.object, "totalCount");
        if (repos_v.object.get("nodes")) |nodes_v| if (nodes_v == .array) {
            for (nodes_v.array.items) |r| {
                if (r != .object) continue;
                const ro = r.object;
                total_stars += getU32(ro, "stargazerCount");
                total_forks += getU32(ro, "forkCount");

                var lang_name: []const u8 = "Unknown";
                var lang_color: []const u8 = "#888888";
                if (ro.get("primaryLanguage")) |pl| if (pl == .object) {
                    const ln = getString(pl.object, "name");
                    if (ln.len > 0) lang_name = ln;
                    const lc = getString(pl.object, "color");
                    if (lc.len > 0) lang_color = lc;
                };
                if (!isExcluded(lang_name, exclude)) {
                    try addToTally(&repo_lang_tally, lang_name, lang_color, 1.0);
                }

                if (top.items.len < 6) {
                    try top.append(.{
                        .name = try allocator.dupe(u8, getString(ro, "name")),
                        .description = try allocator.dupe(u8, getString(ro, "description")),
                        .stars = getU32(ro, "stargazerCount"),
                        .forks = getU32(ro, "forkCount"),
                        .primary_lang = try allocator.dupe(u8, lang_name),
                        .primary_color = try allocator.dupe(u8, lang_color),
                    });
                }
            }
        };
    };

    // Contributions
    var total_commits_year: u32 = 0;
    var total_contributions_year: u32 = 0;
    var contributed_repos_year: u32 = 0;
    var contribs = std.ArrayList(ContribDay).init(allocator);
    defer {
        for (contribs.items) |c| allocator.free(c.date);
        contribs.deinit();
    }
    var weekday_commits = [_]u32{0} ** 7;

    var commit_lang_tally = std.StringHashMap(TallyEntry).init(allocator);
    defer commit_lang_tally.deinit();

    if (u.get("contributionsCollection")) |cc_v| if (cc_v == .object) {
        const cc = cc_v.object;
        total_commits_year = getU32(cc, "totalCommitContributions");
        contributed_repos_year = getU32(cc, "totalRepositoriesWithContributedCommits");

        if (cc.get("contributionCalendar")) |cal_v| if (cal_v == .object) {
            total_contributions_year = getU32(cal_v.object, "totalContributions");
            if (cal_v.object.get("weeks")) |weeks_v| if (weeks_v == .array) {
                for (weeks_v.array.items) |w| {
                    if (w != .object) continue;
                    if (w.object.get("contributionDays")) |days_v| if (days_v == .array) {
                        for (days_v.array.items) |d| {
                            if (d != .object) continue;
                            const date = getString(d.object, "date");
                            const count = getU32(d.object, "contributionCount");
                            const weekday = getU32(d.object, "weekday");
                            const wd: u8 = @intCast(weekday & 0x7);
                            weekday_commits[wd] +|= count;
                            try contribs.append(.{
                                .date = try allocator.dupe(u8, date),
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
                var lname: []const u8 = "Unknown";
                var lcolor: []const u8 = "#888888";
                if (eo.get("repository")) |rv| if (rv == .object) {
                    if (rv.object.get("primaryLanguage")) |pl| if (pl == .object) {
                        const ln = getString(pl.object, "name");
                        if (ln.len > 0) lname = ln;
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
                if (isExcluded(lname, exclude)) continue;
                try addToTally(&commit_lang_tally, lname, lcolor, @as(f64, @floatFromInt(commits)));
            }
        };
    };

    return Stats{
        .allocator = allocator,
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
        .total_commits_year = total_commits_year,
        .total_contributions_year = total_contributions_year,
        .contributed_repos_year = contributed_repos_year,
        .repos_per_language = try tallyToSorted(allocator, &repo_lang_tally),
        .commit_per_language = try tallyToSorted(allocator, &commit_lang_tally),
        .contributions = try contribs.toOwnedSlice(),
        .weekday_commits = weekday_commits,
        .top_repos = try top.toOwnedSlice(),
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
    // Walk back from end for current streak (allow today=0, count from yesterday).
    if (contributions.len > 0) {
        var i: isize = @as(isize, @intCast(contributions.len)) - 1;
        // Skip today if zero (so missing today doesn't break streak).
        if (i >= 0 and contributions[@intCast(i)].count == 0) i -= 1;
        while (i >= 0) : (i -= 1) {
            if (contributions[@intCast(i)].count > 0) {
                current += 1;
            } else break;
        }
    }
    return .{ .current = current, .longest = longest, .total_active = total_active };
}
