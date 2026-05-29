# github-user-summary-cards

A Zig-based CLI / GitHub Action that generates SVG summary cards from GitHub user statistics.

When `GITHUB_TOKEN` is provided as an environment variable, private repositories and private contributions for the token owner are included in the aggregation. Without a token, only public data is used — but since GitHub GraphQL generally requires authentication, a token is practically required.

## Generated Cards (7 total)

| Filename | Description |
|---|---|
| `profile-details.svg`        | Name / @login / Bio / Joined date / Avatar + 8 key metrics |
| `repos-per-language.svg`     | Breakdown of owned repositories by primaryLanguage (donut chart + top language % in center) |
| `most-commit-language.svg`   | Language breakdown weighted by commit count (donut chart) |
| `stats.svg`                  | Aggregated stars, forks, commits, PRs, issues, and contributed repos |
| `contribution-heatmap.svg`   | Daily contribution heatmap for the past year (month labels + 5-level legend) |
| `streak.svg`                 | Current streak / longest streak / total active days |
| `top-repos.svg`              | Top N repositories by star count (with language color + star/fork counts) |

Avatars are base64-encoded at fetch time and embedded in the SVG, so they display correctly when referenced via `<img src="...svg">` in a README.

## CLI Usage

Build:

```sh
zig build -Doptimize=ReleaseSafe   # Requires Zig 0.16.0+
```

Run:

```sh
# Basic (past year)
GITHUB_TOKEN=ghp_xxx ./zig-out/bin/github-user-summary-cards your-login

# All-time (aggregates from account creation to now by calendar year; commits/contributions/streak are full-history)
GITHUB_TOKEN=ghp_xxx ./zig-out/bin/github-user-summary-cards your-login --all-time

# Theme, card filtering, count limits, and humanized numbers
./zig-out/bin/github-user-summary-cards your-login \
  --theme tokyonight \
  --cards profile,stats,streak,top-repos \
  --top-langs 8 \
  --top-repos 8 \
  --humanize
```

### Options / Environment Variables

| CLI Flag | Env Var | Default | Description |
|---|---|---|---|
| `<username>` (positional) | `GITHUB_USERNAME` | (required) | Target user |
| —                  | `GITHUB_TOKEN`     | unset | GraphQL authentication. Includes private data for the token owner |
| `--theme`          | `THEME`            | `default` | Color theme (see below) |
| `--exclude`        | `EXCLUDE`          | `""` | Languages to exclude from tally (CSV, e.g. `HTML,CSS`) |
| `--all-time`       | `ALL_TIME`         | `false` | Aggregate from account creation instead of the past year (runs N queries) |
| `--cards`          | `CARDS`            | `""` (=all) | CSV of card names to output (short names accepted: `heatmap`, `repos`, etc.) |
| `--top-langs`      | `TOP_LANGS`        | `6` | Number of languages to show in donut chart (1..20) |
| `--top-repos`      | `TOP_REPOS`        | `6` | Number of repos in top-repos card (1..20) |
| `--include-forks`  | `INCLUDE_FORKS`    | `false` | Include forked repos in the tally |
| `--bio-max`        | `BIO_MAX`          | `56` | Max characters for bio truncation in profile card (8..400) |
| `--no-avatar-embed`| `NO_AVATAR_EMBED`  | `false` | Skip base64 avatar embedding (lighter output, but won't display via `<img>`) |
| `--humanize`       | `HUMANIZE`         | `false` | Abbreviate numbers in `1.2k` / `3.4m` format |
| `--output`         | `OUTPUT_DIR`       | `profile-summary-card-output` | Output directory |

Boolean environment variables accept `1` / `true` / `yes` / `on` as truthy values.

### Themes

`default` / `dracula` / `nord_dark` / `tokyonight` / `gruvbox` / `solarized_light`

### `--all-time` Behavior and API Cost

- GitHub limits `contributionsCollection` to a 1-year window, so the tool queries year-by-year from account creation to the current year (N+1 requests total).
- Authenticated GraphQL rate limit: 5,000 points/hour. Each query costs ≈ 1 point, so even 10–15 years of history fits comfortably.
- The heatmap always renders only the most recent year, even in all-time mode (to avoid excessive width).

## Using as a GitHub Action

Minimal example:

```yaml
# .github/workflows/profile-cards.yml
name: Profile Summary Cards

on:
  workflow_dispatch:

permissions:
  contents: write

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: matuyuhi/github-user-summary-cards@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          THEME: tokyonight
          ALL_TIME: 'true'
          HUMANIZE: 'true'
          AUTO_PUSH: 'true'
          # PUSH_BRANCH: profile-summary-card-output  (default)
```

With `AUTO_PUSH: 'true'`, the generated SVGs are force-pushed to a **dedicated orphan branch** (no history — always a single latest commit). This keeps your main branch clean while allowing README references via:

```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/profile-details.svg)
```
![](/profile-summary-card/profile-details.svg)
```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/stats.svg)
```
![](/profile-summary-card/stats.svg)
```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/contribution-heatmap.svg)
```
![](/profile-summary-card/contribution-heatmap.svg)
```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/streak.svg)
```
![](/profile-summary-card/streak.svg)
```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/top-repos.svg)
```
![](/profile-summary-card/top-repos.svg)
```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/repos-per-language.svg)
```
![](/profile-summary-card/repos-per-language.svg)
```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/most-commit-language.svg)
```
![](/profile-summary-card/most-commit-language.svg)

You can also skip `AUTO_PUSH` to only generate the files and handle them in a subsequent step (in which case `permissions: contents: write` is not needed).

### Action Inputs (excerpt)

Input names match CLI flags (uppercase). Only `AUTO_PUSH`-related inputs are Action-specific:

| Input | Default | Description |
|---|---|---|
| `AUTO_PUSH`         | `''`                            | Force-push SVGs to `PUSH_BRANCH` when truthy |
| `PUSH_BRANCH`       | `profile-summary-card-output`   | Target orphan branch for force-push |
| `COMMIT_MESSAGE`    | (auto)                          | Commit message |
| `COMMIT_USER_NAME`  | `github-actions[bot]`           | Committer name |
| `COMMIT_USER_EMAIL` | `41898282+github-actions[bot]@users.noreply.github.com` | Committer email |

### Including Private Data

The auto-issued `secrets.GITHUB_TOKEN` cannot read private contribution data for the target user. Register a PAT with `read:user` / `repo` scopes as a secret and pass it as the `GITHUB_TOKEN` input:

```yaml
        with:
          GITHUB_TOKEN: ${{ secrets.PROFILE_PAT }}
```

## Development

- Required: **Zig 0.16.0+**
- Zero external dependencies (Zig standard library only)
- Source files:
  - `src/main.zig` — Entry point. Receives `std.process.Init`; sets up Args / Environ / Io / Allocator
  - `src/config.zig` — CLI/env parsing
  - `src/github.zig` — GraphQL POST, avatar fetch + base64 encoding, date helpers
  - `src/queries.zig` — GraphQL queries (profile + auxiliary contributions-only)
  - `src/stats.zig` — JSON parsing and aggregation (merging multiple contribution ranges, deduplicating dates)
  - `src/svg.zig` — Shared SVG helpers (header/footer/text/rect/donut/humanizeInt, etc.)
  - `src/icons.zig` — Lucide-style stroke-based icons
  - `src/themes.zig` — Color palettes
  - `src/cards/*.zig` — Individual card renderers

## Notes

- Streak is calculated from all fetched contributions (full history when `--all-time` is set).
- The heatmap is always clipped to the most recent year (up to 53 weeks) for display reasons.
- Repos with a null `primaryLanguage` (README-only repos, config repos, etc.) are excluded from repos-per-language and most-commit-language tallies (but still appear in top-repos).
- GitHub GraphQL requires authentication even for public data, so `GITHUB_TOKEN` is effectively required.

## License

MIT
