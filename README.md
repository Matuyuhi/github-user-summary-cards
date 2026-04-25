# github-user-summary-cards

GitHub ユーザーの統計から SVG のサマリーカードを生成する Zig 製 CLI / GitHub Action。
[`vn7n24fzkq/github-profile-summary-cards`](https://github.com/vn7n24fzkq/github-profile-summary-cards) のコンセプトを Zig で再実装したものです。

`GITHUB_TOKEN` を環境変数で渡すと、その所有者ユーザーに対してはプライベートリポジトリ／プライベートコントリビューションも集計対象になります（GraphQL の `viewer` スコープ）。トークン無しでも公開データだけで動きます（時間あたり 60 リクエスト制限）。

## 出力されるカード（8 枚）

| ファイル名 | 内容 |
|---|---|
| `profile-details.svg`        | 名前 / Bio / フォロワー / スター総数 / コミット数 ほか |
| `repos-per-language.svg`     | 所有リポジトリの primaryLanguage 内訳（ドーナツ） |
| `most-commit-language.svg`   | 直近 1 年のコミット数で重み付けした言語内訳（ドーナツ） |
| `stats.svg`                  | スター・フォーク・コミット・PR・Issue などの集計 |
| `productive-time.svg`        | 曜日別アクティビティ |
| `contribution-heatmap.svg`   | 直近 1 年の日別コントリビューションヒートマップ |
| `streak.svg`                 | 現在のストリーク / 最長ストリーク / アクティブ日数 |
| `top-repos.svg`              | スター数 Top 6 のリポジトリ |

## CLI 使い方

ビルド:

```sh
zig build -Doptimize=ReleaseSafe
```

実行:

```sh
# 公開データのみ
./zig-out/bin/github-user-summary-cards octocat

# プライベートも含める（自分のトークンで自分のユーザーを指定したとき）
GITHUB_TOKEN=ghp_xxx ./zig-out/bin/github-user-summary-cards your-login

# テーマ・除外言語・出力先などを指定
./zig-out/bin/github-user-summary-cards your-login \
  --theme dracula \
  --exclude HTML,CSS \
  --utc-offset 9 \
  --output cards/
```

### オプション / 環境変数

| CLI フラグ | 環境変数 | 既定値 |
|---|---|---|
| `<username>` (positional) | `GITHUB_USERNAME` | (必須) |
| —                         | `GITHUB_TOKEN`    | unset（公開データのみ） |
| `--theme`                 | `THEME`           | `default` |
| `--exclude`               | `EXCLUDE`         | `""` |
| `--utc-offset`            | `UTC_OFFSET`      | `0` |
| `--output`                | `OUTPUT_DIR`      | `profile-summary-card-output` |

### テーマ

`default` / `dracula` / `nord_dark` / `tokyonight` / `gruvbox` / `solarized_light`

## GitHub Action として使う

リポジトリ内のワークフローで利用:

```yaml
# .github/workflows/profile-cards.yml
name: Profile Summary Cards
on:
  schedule:
    - cron: '0 18 * * *'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: matuyuhi/github-user-summary-cards@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          THEME: dracula
      - uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: 'chore: regenerate profile summary cards'
          file_pattern: profile-summary-card-output/*.svg
```

`GITHUB_TOKEN` には自動で発行される `secrets.GITHUB_TOKEN` を渡せば公開データの取得は十分です。プライベートコントリビューションも含めたい場合は、`read:user` / `repo` スコープ付きの PAT を `secrets.PRIVATE_PAT` などに登録して渡してください。

生成された SVG は README に直接埋め込めます:

```markdown
![](./profile-summary-card-output/profile-details.svg)
![](./profile-summary-card-output/stats.svg)
![](./profile-summary-card-output/repos-per-language.svg)
![](./profile-summary-card-output/most-commit-language.svg)
![](./profile-summary-card-output/contribution-heatmap.svg)
![](./profile-summary-card-output/streak.svg)
![](./profile-summary-card-output/productive-time.svg)
![](./profile-summary-card-output/top-repos.svg)
```

## 開発

- Zig 0.14.0 が必要（`mlugg/setup-zig@v1` で CI セットアップ可能）。
- 外部依存ゼロ（標準ライブラリのみ）。
- すべての GitHub データは GraphQL 1 リクエストで取得。
- 実装: `src/main.zig` がエントリ、`src/github.zig` が GraphQL POST、`src/stats.zig` が集計、`src/cards/*.zig` が各カード描画、`src/svg.zig` が共通ヘルパ。

## Notes

- 「コミット時刻別」の生産性カードは GraphQL のコントリビューション粒度が日単位のため、本実装では曜日別アクティビティとして描画しています。
- ストリークは「直近 1 年」分のカレンダーから算出します（GitHub のプロフィールヒートマップと同じ範囲）。
- レート制限に当たった場合は数分〜1 時間待つか、`GITHUB_TOKEN` を設定してください。

## License

MIT
