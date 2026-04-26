# github-user-summary-cards

GitHub ユーザーの統計から SVG のサマリーカードを生成する Zig 製 CLI / GitHub Action。
[`vn7n24fzkq/github-profile-summary-cards`](https://github.com/vn7n24fzkq/github-profile-summary-cards) のコンセプトを Zig で再実装したものです。

`GITHUB_TOKEN` を環境変数で渡すと、その所有者ユーザーに対してはプライベートリポジトリ／プライベートコントリビューションも集計対象になります。トークン無しでも公開データだけで動きますが、GitHub GraphQL は基本的に認証必須なので実用上はトークン必須です。

## 出力されるカード（7 枚）

| ファイル名 | 内容 |
|---|---|
| `profile-details.svg`        | 名前 / @login / Bio / Joined date / アバター + 主要 8 指標 |
| `repos-per-language.svg`     | 所有リポジトリの primaryLanguage 内訳（ドーナツ + 中央に Top 言語 %） |
| `most-commit-language.svg`   | コミット数で重み付けした言語内訳（ドーナツ） |
| `stats.svg`                  | スター・フォーク・コミット・PR・Issue・コントリビュート Repo の集計 |
| `contribution-heatmap.svg`   | 直近 1 年の日別コントリビューションヒートマップ（月ラベル + 5 段階凡例） |
| `streak.svg`                 | 現在のストリーク / 最長ストリーク / アクティブ日数 |
| `top-repos.svg`              | スター数 Top N のリポジトリ（言語色 + star/fork 数） |

アバターは取得時に base64 エンコードして SVG に埋め込まれるので、README で `<img src="...svg">` 経由で参照しても表示されます。

## CLI 使い方

ビルド:

```sh
zig build -Doptimize=ReleaseSafe   # Zig 0.16.0+ が必要
```

実行:

```sh
# 基本（直近 1 年）
GITHUB_TOKEN=ghp_xxx ./zig-out/bin/github-user-summary-cards your-login

# all-time（入会から現在までを年単位で集計、commit/contribution/streak が全期間ベース）
GITHUB_TOKEN=ghp_xxx ./zig-out/bin/github-user-summary-cards your-login --all-time

# テーマ・カード絞り込み・件数指定・大きい数の省略表記
./zig-out/bin/github-user-summary-cards your-login \
  --theme tokyonight \
  --cards profile,stats,streak,top-repos \
  --top-langs 8 \
  --top-repos 8 \
  --humanize
```

### オプション / 環境変数

| CLI フラグ | 環境変数 | 既定値 | 内容 |
|---|---|---|---|
| `<username>` (positional) | `GITHUB_USERNAME` | (必須) | 対象ユーザー |
| —                  | `GITHUB_TOKEN`     | unset | GraphQL 認証用。所有者なら private も含む |
| `--theme`          | `THEME`            | `default` | カラーテーマ（下記参照） |
| `--exclude`        | `EXCLUDE`          | `""` | 言語タリーから除外（CSV、例: `HTML,CSS`） |
| `--all-time`       | `ALL_TIME`         | `false` | 直近 1 年でなく入会から全期間を集計（年数ぶんクエリ実行） |
| `--cards`          | `CARDS`            | `""` (=all) | 出力するカード名 CSV（短縮名も可: `heatmap`, `repos` 等） |
| `--top-langs`      | `TOP_LANGS`        | `6` | ドーナツに表示する言語数（1..20） |
| `--top-repos`      | `TOP_REPOS`        | `6` | top-repos カードの件数（1..20） |
| `--include-forks`  | `INCLUDE_FORKS`    | `false` | fork した repo もタリー対象に |
| `--bio-max`        | `BIO_MAX`          | `56` | profile カードの bio 切り詰め文字数（8..400） |
| `--no-avatar-embed`| `NO_AVATAR_EMBED`  | `false` | アバターを base64 埋め込みしない（軽量化、ただし `<img>` 経由非表示） |
| `--humanize`       | `HUMANIZE`         | `false` | 数値を `1.2k` `3.4m` 形式で省略表記 |
| `--output`         | `OUTPUT_DIR`       | `profile-summary-card-output` | 出力ディレクトリ |

`bool` 系の環境変数は `1` / `true` / `yes` / `on` のいずれかが truthy。

### テーマ

`default` / `dracula` / `nord_dark` / `tokyonight` / `gruvbox` / `solarized_light`

### `--all-time` の挙動と API コスト

- `contributionsCollection` は GitHub の制約で 1 年が上限のため、入会年から今年まで calendar year 単位で N 回クエリして集計します（合計 N+1 リクエスト）。
- 認証済み GraphQL レート: 5000 ポイント/時間。各クエリ ≈ 1 ポイントなので 10〜15 年経過していても余裕で収まります。
- ヒートマップは all-time でも常に直近 1 年のみ描画（横長になりすぎるため）。

## GitHub Action として使う

最小例:

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

`AUTO_PUSH: 'true'` を付けると、生成された SVG が **専用 orphan ブランチ** に force-push されます（履歴は持たず常に最新 1 commit）。これによりリポ本体の `master` を汚さず、README から下記の URL で参照できます:

```markdown
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/profile-details.svg)
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/stats.svg)
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/contribution-heatmap.svg)
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/streak.svg)
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/top-repos.svg)
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/repos-per-language.svg)
![](https://raw.githubusercontent.com/<user>/<repo>/profile-summary-card-output/most-commit-language.svg)
```

`AUTO_PUSH` を使わず生成だけ行い、別ステップで好きなように扱うことも可能です（その場合 `permissions: contents: write` 不要）。

### Action inputs（抜粋）

CLI と同名（大文字）です。`AUTO_PUSH` 関連だけ Action 専用:

| input | default | 内容 |
|---|---|---|
| `AUTO_PUSH`         | `''`                            | truthy で SVG を `PUSH_BRANCH` に force-push |
| `PUSH_BRANCH`       | `profile-summary-card-output`   | force-push 先の orphan ブランチ |
| `COMMIT_MESSAGE`    | (auto)                          | コミットメッセージ |
| `COMMIT_USER_NAME`  | `github-actions[bot]`           | committer name |
| `COMMIT_USER_EMAIL` | `41898282+github-actions[bot]@users.noreply.github.com` | committer email |

### プライベートデータも集計したい場合

自動発行される `secrets.GITHUB_TOKEN` は対象 user の private コントリビューション情報を読めません。`read:user` / `repo` スコープ付きの PAT を secret に登録して `GITHUB_TOKEN` input に渡してください:

```yaml
        with:
          GITHUB_TOKEN: ${{ secrets.PROFILE_PAT }}
```

## 開発

- 必要環境: **Zig 0.16.0+**
- 外部依存ゼロ（Zig 標準ライブラリのみ）
- 実装ファイル:
  - `src/main.zig` — エントリ。`std.process.Init` を受け、Args / Environ / Io / Allocator を取得
  - `src/config.zig` — CLI/env パース
  - `src/github.zig` — GraphQL POST、avatar fetch + base64 化、日付ヘルパー
  - `src/queries.zig` — GraphQL クエリ（profile + 補助 contributions-only）
  - `src/stats.zig` — JSON 解析・集計（複数 contribution range のマージ・date 重複排除）
  - `src/svg.zig` — SVG 共通ヘルパー（header/footer/text/rect/donut/humanizeInt 等）
  - `src/icons.zig` — Lucide ライク stroke ベースアイコン
  - `src/themes.zig` — カラーパレット
  - `src/cards/*.zig` — 各カード描画

## Notes

- ストリークは取得した contributions 全体から計算します（`--all-time` 指定時は入会以降全期間）。
- ヒートマップは表示の都合で常に直近 1 年（最大 53 週）に切り出して描画します。
- `primaryLanguage` が null の repo（README only / 設定リポ等）は repos-per-language / most-commit-language の集計から除外します（top-repos には残ります）。
- 公開データのみであっても GitHub GraphQL は認証必須のため `GITHUB_TOKEN` は実質必須です。

## License

MIT
