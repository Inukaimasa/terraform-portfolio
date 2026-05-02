# GitHub CLI セットアップ手順

## 目的

GitHub CLI（`gh`）を WSL / Ubuntu 環境にインストールし、GitHub へログインできる状態にする。

GitHub CLI を使うと、ターミナルから以下の操作ができる。

- GitHub へのログイン状態確認
- GitHub Actions の実行結果確認
- Pull Request 作成
- リポジトリ情報確認
- 認証まわりのトラブル切り分け

---

## GitHub CLI とは

GitHub CLI は、GitHub をターミナルから操作するためのコマンドツール。

コマンド名は以下。

```bash
gh
```

通常の Git 操作とは役割が違う。

| ツール | 役割 |
|---|---|
| `git` | commit、push、branch などローカル Git 操作 |
| `gh` | GitHub 上の操作、PR、Actions、認証確認 |

---

## インストール確認

まず、GitHub CLI がインストールされているか確認する。

```bash
gh --version
```

今回の実行結果。

```text
gh version 2.92.0 (2026-04-28)
https://github.com/cli/cli/releases/tag/v2.92.0
```

このようにバージョンが表示されれば、インストール成功。

---

## 今回実行したインストール手順

Ubuntu / WSL 環境で、GitHub CLI 公式リポジトリを apt に追加してインストールした。

### 1. wget を用意する

```bash
type -p wget >/dev/null || sudo apt update && sudo apt install wget -y
```

### 2. keyrings ディレクトリを作成する

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
```

### 3. GitHub CLI の認証鍵を取得する

```bash
out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg
```

### 4. 認証鍵を apt 用の場所に保存する

```bash
cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
```

### 5. 認証鍵の読み取り権限を設定する

```bash
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
```

### 6. apt のリポジトリ設定ディレクトリを作成する

```bash
sudo mkdir -p -m 755 /etc/apt/sources.list.d
```

### 7. GitHub CLI 公式リポジトリを apt に追加する

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
```

### 8. apt のパッケージ一覧を更新する

```bash
sudo apt update
```

### 9. GitHub CLI をインストールする

```bash
sudo apt install gh -y
```

### 10. インストール確認

```bash
gh --version
```

---

## 途中で発生したエラーと原因

最初に長いコマンドを貼り付けた際、以下のようなエラーが出た。

```text
0+0 records in
0+0 records out
0 bytes copied
Command 'keyring.' not found
```

原因は、コマンドの途中に不要な改行や空白が入っていたため。

間違い例。

```text
https://cli.github.com/package
s/githubcli-archive-keyring. gpg
```

本来は以下が正しい。

```text
https://cli.github.com/packages/githubcli-archive-keyring.gpg
```

特に注意する箇所。

| 間違い | 正しい形 |
|---|---|
| `package s` | `packages` |
| `keyring. gpg` | `keyring.gpg` |
| `github. com` | `github.com` |
| `sources. list.d` | `sources.list.d` |

長いコマンドは、1行ずつ実行した方が安全。

---

## GitHub CLI にログインする

インストール後、以下を実行する。

```bash
gh auth login
```

表示された画面で以下のように選択する。

---

### 1. GitHub の種類を選択

```text
? Where do you use GitHub?
> GitHub.com
  Other
```

通常は `GitHub.com` を選んで Enter。

---

### 2. Git 操作のプロトコルを選択

以下のように聞かれたら、

```text
What is your preferred protocol for Git operations?
```

基本は以下を選ぶ。

```text
HTTPS
```

SSH 設定をまだしていない場合は、HTTPS が扱いやすい。

---

### 3. GitHub 認証情報を Git でも使うか

以下のように聞かれたら、

```text
Authenticate Git with your GitHub credentials?
```

以下を選ぶ。

```text
Yes
```

---

### 4. 認証方法を選択

以下のように聞かれたら、

```text
How would you like to authenticate GitHub CLI?
```

以下を選ぶ。

```text
Login with a web browser
```

---

## ブラウザ認証の流れ

ブラウザ認証を選ぶと、以下のような表示が出る。

```text
! First copy your one-time code: XXXX-XXXX
Press Enter to open github.com in your browser...
```

作業手順。

1. 表示されたワンタイムコードをコピーする
2. Enter を押す
3. GitHub の認証ページをブラウザで開く
4. コードを入力する
5. GitHub CLI を認可する

WSL 環境でブラウザが自動で開かない場合は、表示された URL を Chrome などに貼り付けて開く。

---

## ログイン状態確認

ログイン後、以下を実行する。

```bash
gh auth status
```

成功していれば、GitHub アカウント名やログイン状態が表示される。

---

## よく使う GitHub CLI コマンド

### GitHub CLI のバージョン確認

```bash
gh --version
```

### GitHub ログイン状態確認

```bash
gh auth status
```

### GitHub Actions の実行履歴確認

```bash
gh run list
```

### GitHub Actions の詳細確認

```bash
gh run view
```

### Pull Request 作成

```bash
gh pr create
```

### 現在のリポジトリ確認

```bash
gh repo view
```

---

## Terraform ポートフォリオでの使い方

Terraform コードや README を修正した後、以下のような流れで使う。

### 1. 作業ブランチを作成

```bash
git checkout -b docs/add-github-cli-readme
```

### 2. ファイルを修正・追加

例。

```text
README_GITHUB_CLI.md
```

### 3. 変更確認

```bash
git status
```

### 4. add

```bash
git add README_GITHUB_CLI.md
```

### 5. commit

```bash
git commit -m "docs: add GitHub CLI setup guide"
```

### 6. push

```bash
git push -u origin docs/add-github-cli-readme
```

### 7. GitHub Actions 確認

```bash
gh run list
```

### 8. Pull Request 作成

```bash
gh pr create --title "Add GitHub CLI setup guide" --body "Add GitHub CLI installation and authentication steps"
```

---

## 今回やったことのまとめ

今回実施した内容は以下。

1. GitHub CLI をインストールした
2. `gh --version` でインストール確認した
3. GitHub CLI v2.92.0 が入っていることを確認した
4. `gh auth login` を実行した
5. GitHub.com を選択する画面まで進んだ
6. 今後、GitHub Actions 確認や Pull Request 作成をターミナルから実行できる準備をした

---

## 実務的なメリット

GitHub CLI を使えると、以下の作業がターミナルで完結しやすくなる。

- GitHub 認証状態の確認
- GitHub Actions の CI 結果確認
- Pull Request 作成
- GitHub リポジトリ情報の確認
- Terraform の CI/CD 確認
- push 後の失敗原因調査

Terraform や GitHub Actions を使うポートフォリオでは、実務に近い操作になる。

---

## 補足

`git` と `gh` は別物。

- `git` はローカルの変更管理に使う
- `gh` は GitHub 上の操作に使う

例。

```bash
git add .
git commit -m "message"
git push
```

これは `git` の作業。

```bash
gh auth status
gh run list
gh pr create
```

これは `gh` の作業。