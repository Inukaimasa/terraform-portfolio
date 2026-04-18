# Setup and Workflow Guide

このドキュメントは、**Windows + WSL2 + Ubuntu** を前提に、
**上から順番にコマンドを実行すると、今の開発環境に近い状態を再現できる**ように整理したものです。

対象:
- Windows 10 / 11
- WSL2
- Ubuntu
- Python / venv
- Git / GitHub
- Terraform
- AWS CLI
- VS Code
- GitHub Actions の最小 CI

---

## 0. 先に確認すること

### Windows 側で確認する項目
WSL2 は Windows のバージョン条件に依存します。Microsoft の公式ドキュメントでは、
**Windows 10 version 2004 以降（Build 19041 以降）または Windows 11** が、以下の簡易インストールコマンドの前提です。  
参考:  
- Microsoft WSL install: https://learn.microsoft.com/ja-jp/windows/wsl/install

### Windows バージョン確認コマンド
PowerShell か Windows Terminal で実行します。

```powershell
winver
```

#### 意味
- Windows のバージョンとビルド番号を GUI で確認する
- WSL2 の簡易導入が使えるか確認する

### OS 情報の詳細確認コマンド

```powershell
systeminfo
```

#### 意味
- OS 名
- OS バージョン
- システムの種類（x64 など）
- BIOS / メモリなど
を確認する

### 仮想化が有効か確認したいとき

```powershell
systeminfo | findstr /i "Hyper-V"
```

#### 意味
- WSL2 に必要な仮想化系の状態確認に役立つ

---

## 1. WSL2 のインストール

PowerShell を**管理者権限**で開いて実行します。

```powershell
wsl --install
wsl --list --online
wsl --install -d Ubuntu
```

#### 各コマンドの意味
- `wsl --install`  
  WSL を有効化し、必要な Windows 機能をまとめて導入する
- `wsl --list --online`  
  インストール可能な Linux ディストリビューション一覧を表示する
- `wsl --install -d Ubuntu`  
  Ubuntu を指定してインストールする

### 補足
再起動が求められたら再起動します。  
初回起動時に Ubuntu 側で Linux ユーザー名とパスワードを設定します。

参考:
- Microsoft WSL install: https://learn.microsoft.com/ja-jp/windows/wsl/install
- 古い Windows 向け手動手順: https://learn.microsoft.com/ja-jp/windows/wsl/install-manual

---

## 2. Ubuntu 側の基本ツール

Ubuntu ターミナルで実行します。

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git unzip curl gnupg software-properties-common python3 python3-pip python3-venv
```

#### 各コマンドの意味
- `apt update`  
  パッケージ一覧を最新化する
- `apt upgrade -y`  
  既存パッケージを更新する
- `apt install ...`  
  開発に必要な基本ツールを入れる

### 入る主なもの
- `git`  
  ソースコード管理
- `unzip`  
  zip 解凍
- `curl`  
  URL からファイル取得
- `gnupg`, `software-properties-common`  
  Terraform リポジトリ登録時に使う
- `python3`, `python3-pip`, `python3-venv`  
  Python 実行・パッケージ管理・仮想環境

---

## 3. 作業用ディレクトリを作る

```bash
cd ~
mkdir -p terraform-portfolio/terraform
mkdir -p terraform-portfolio/.github/workflows
cd terraform-portfolio
pwd
```

#### 各コマンドの意味
- `cd ~`  
  ホームディレクトリへ移動
- `mkdir -p ...`  
  必要なフォルダをまとめて作る
- `pwd`  
  今いる場所を確認する

### ここで確認したいこと
最終的に、だいたい次の場所にいること。

```text
/home/<your-linux-user>/terraform-portfolio
```

---

## 4. Python 仮想環境（.venv）を作る

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python --version
pip --version
```

#### 各コマンドの意味
- `python3 -m venv .venv`  
  プロジェクト専用の Python 実行環境を作る
- `source .venv/bin/activate`  
  仮想環境を有効化する
- `python -m pip install --upgrade pip`  
  pip を最新化する

### 仮想環境を使う理由
- プロジェクトごとに Python 環境を分けられる
- boto3 などを安全に入れられる
- VS Code の補完やエラー表示が安定しやすい

### 作業終了時

```bash
deactivate
```

#### 意味
- 仮想環境から抜ける

---

## 5. Terraform のインストール

HashiCorp の公式リポジトリを使う方法です。

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo $VERSION_CODENAME) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt install -y terraform
terraform -version
```

#### 各コマンドの意味
- GPG キー登録  
  パッケージの信頼性確認に使う
- `hashicorp.list` 作成  
  apt に Terraform の配布元を教える
- `apt install terraform`  
  Terraform CLI を導入する
- `terraform -version`  
  正常に入ったか確認する

参考:
- Terraform install: https://developer.hashicorp.com/terraform/install
- Terraform CLI docs: https://developer.hashicorp.com/terraform/cli/commands

---

## 6. AWS CLI のインストール（必要な場合）

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install --update
aws --version
```

#### 各コマンドの意味
- `curl ... -o awscliv2.zip`  
  AWS CLI の zip をダウンロード
- `unzip -o awscliv2.zip`  
  展開する
- `sudo ./aws/install --update`  
  インストールまたは更新する
- `aws --version`  
  導入確認

### AWS 認証確認

```bash
aws configure
aws sts get-caller-identity
```

#### 意味
- `aws configure`  
  AWS アクセスキー、シークレットキー、リージョンなどを設定
- `aws sts get-caller-identity`  
  今どの AWS アカウント / IAM で認証されているか確認

参考:
- AWS CLI docs: https://docs.aws.amazon.com/cli/

---

## 7. VS Code の準備

Windows 側に VS Code をインストールします。

参考:
- VS Code download: https://code.visualstudio.com/download
- VS Code Windows setup: https://code.visualstudio.com/docs/setup/windows

### 推奨拡張
- WSL
- Python
- Terraform

### WSL で開く
Ubuntu ターミナルでプロジェクトディレクトリに移動してから:

```bash
code .
```

#### 意味
- 今いるフォルダを VS Code で開く
- WSL 拡張が入っていれば Ubuntu 環境のまま編集できる

### Python 仮想環境を使うとき
VS Code で:
- `Ctrl + Shift + P`
- `Python: Select Interpreter`
- `~/terraform-portfolio/.venv/bin/python` を選ぶ

---

## 8. Git / GitHub 初期設定

### Git 設定

```bash
git config --global user.name "あなたの名前"
git config --global user.email "あなたのメールアドレス"
git config --global init.defaultBranch main
git config --global --list
```

#### 各コマンドの意味
- `user.name`  
  commit の作者名
- `user.email`  
  commit の作者メール
- `init.defaultBranch main`  
  新規リポジトリの初期ブランチを main にする
- `--list`  
  設定確認

### GitHub 側でやること
- GitHub で `terraform-portfolio` リポジトリを作る

参考:
- Git install for Windows: https://git-scm.com/install/windows
- Git install docs: https://git-scm.com/book/ja/v2/%E4%BD%BF%E3%81%84%E5%A7%8B%E3%82%81%E3%82%8B-Git%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB

---

## 9. リポジトリ初期構成を作る

```bash
cd ~/terraform-portfolio

touch README.md
touch .gitignore

touch terraform/provider.tf
touch terraform/versions.tf
touch terraform/main.tf
touch terraform/variables.tf
touch terraform/outputs.tf
touch terraform/terraform.tfvars.example

touch .github/workflows/terraform-ci.yml
```

#### 意味
- README を作る
- Terraform の最低限ファイルを作る
- CI 用 workflow ファイルを作る
- `.gitignore` を先に用意して事故を防ぐ

---

## 10. .gitignore を最初に書く

```gitignore
# Terraform
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.*
terraform/crash.log
terraform/.terraform.tfstate.lock.info
terraform/override.tf
terraform/override.tf.json
terraform/*_override.tf
terraform/*_override.tf.json

# tfvars
terraform/*.tfvars
terraform/*.tfvars.json

# Python
.venv/
__pycache__/
*.pyc
```

### 意味
Git に上げてはいけないものを除外する。
特に:
- `.terraform/`
- `tfstate`
- `tfvars`
- `.venv/`

は上げない方が安全です。

---

## 11. Git 初回 commit

```bash
cd ~/terraform-portfolio
git init
git add .
git commit -m "Initial commit"
```

#### 各コマンドの意味
- `git init`  
  Git 管理を開始
- `git add .`  
  変更ファイルをステージする
- `git commit -m ...`  
  履歴として保存する

---

## 12. GitHub へ接続して push

```bash
git remote add origin https://github.com/<your-github-name>/terraform-portfolio.git
git branch -M main
git push -u origin main
```

#### 各コマンドの意味
- `git remote add origin ...`  
  GitHub リポジトリを接続する
- `git branch -M main`  
  ブランチ名を main に統一
- `git push -u origin main`  
  GitHub に初回 push する

---

## 13. PAT を使う場合の注意

GitHub Actions の workflow ファイルを push する場合、
トークンには最低限次の権限が必要です。

- `Contents: Read and write`
- `Workflows: Read and write`

### 認証が壊れたとき

```bash
printf "protocol=https\nhost=github.com\n" | git credential reject
```

#### 意味
- 古い GitHub 認証情報を捨てる
- その後、再度 push 時に認証し直す

### 注意
- README やソースコードにトークン文字列を貼らない
- トークンは GitHub Secrets かローカル環境で管理する

参考:
- GitHub Actions secrets: https://docs.github.com/actions/security-guides/using-secrets-in-github-actions
- Workflow syntax: https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions

---

## 14. Terraform の最小構成

### ファイルの役割
- `provider.tf`  
  AWS Provider 設定
- `versions.tf`  
  Terraform 本体と Provider バージョン条件
- `main.tf`  
  resource の本体
- `variables.tf`  
  外から変えたい値
- `outputs.tf`  
  実行後に表示したい値
- `terraform.tfvars.example`  
  値のサンプル

### `provider.tf` の考え方
- `region = var.aws_region`
- `default_tags` で共通タグを付与

例:
- `Project = var.project_name`
- `Environment = var.environment`
- `ManagedBy = "terraform"`

### `variable / locals / output` の使い分け
- `variable`  
  外から変えたい値
- `locals`  
  既存値を組み合わせた中間値
- `output`  
  実行後に見たい値

例:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
```

---

## 15. Terraform でよく使うコマンド

```bash
terraform version
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform destroy
terraform state list
```

### 意味
- `terraform version`  
  バージョン確認
- `terraform init`  
  provider ダウンロード、初期化
- `terraform fmt`  
  見た目を Terraform 標準に整える
- `terraform validate`  
  書き方と構成の整合性チェック
- `terraform plan`  
  何が変わるかの予行演習
- `terraform apply`  
  実際に反映
- `terraform destroy`  
  作ったものを削除
- `terraform state list`  
  Terraform が管理中のリソース一覧を表示

### 作業前の基本

```bash
cd ~/terraform-portfolio/terraform
terraform fmt -recursive
terraform validate
```

### 補足
`initialized in an empty directory!` と出たら、
その場所に `.tf` ファイルがない可能性があります。  
`~/terraform-portfolio/terraform` で実行しているか確認します。

---

## 16. GitHub Actions の最小 CI

最初の CI は以下で十分です。
- `terraform fmt -check -recursive`
- `terraform init -backend=false`
- `terraform validate`

### `.github/workflows/terraform-ci.yml` 例

```yaml
name: Terraform CI

on:
  push:
    branches:
      - main
    paths:
      - "frontend/**"
      - "backend/**"
      - "terraform/**"
      - ".github/workflows/terraform-ci.yml"
  pull_request:
    branches:
      - main
    paths:
      - "frontend/**"
      - "backend/**"
      - "terraform/**"
      - ".github/workflows/terraform-ci.yml"

jobs:
  terraform:
    runs-on: ubuntu-latest

    defaults:
      run:
        working-directory: terraform

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate
```

### この CI で防げること
- インデント崩れ
- HCL の書き方ミス
- Provider 初期化失敗
- 壊れた Terraform コードの main 混入

### まだ防げないこと
- AWS 側で本当に作れるか
- リソース名重複
- 認証権限不足
- 実行時の設計ミス

そこは後で `plan` や `apply` を考えます。

---

## 17. フロント / バックエンドの初期フォルダ構成

```bash
cd ~/terraform-portfolio

mkdir -p frontend/css frontend/js
mkdir -p backend/redirect backend/analytics backend/common
mkdir -p terraform
mkdir -p .github/workflows

touch frontend/index.html
touch frontend/profile.html
touch frontend/admin.html
touch frontend/admin-profile.html
touch frontend/admin-links.html
touch frontend/admin-analytics.html
touch frontend/login.html

touch backend/redirect/app.py
touch backend/analytics/app.py
touch backend/common/dynamodb.py

touch terraform/s3.tf
touch terraform/cloudfront.tf
touch terraform/dynamodb.tf
touch terraform/lambda.tf
touch terraform/apigateway.tf
touch terraform/iam.tf
```

#### 意味
- 公開画面
- 管理画面
- Lambda
- DynamoDB 補助コード
- Terraform 分割ファイル

を最初から箱だけ用意する

---

## 18. フロントのローカル確認

```bash
cd ~/terraform-portfolio/frontend
python3 -m http.server 8000
```

#### 意味
- `frontend/` をローカルの簡易 HTTP サーバーとして配信する
- HTML の見た目確認に使う

### 確認 URL
- `http://localhost:8000/index.html`
- `http://localhost:8000/profile.html`

---

## 19. このプロジェクトで最初に固定する方針

### Phase1 の最小構成
- S3
- CloudFront
- API Gateway
- Lambda
- DynamoDB
- Terraform
- GitHub Actions

### アクセス確認の考え方
プロフィール画面のリンクは直接外部 URL に飛ばさず、

1. API Gateway + Lambda を通す
2. DynamoDB にクリック数を加算する
3. 302 で外部 URL へ転送する

という形にする

### 理由
CloudFront 標準ログは運用・調査用には使えるが、
管理画面で見せる「正確なクリック数」は**自前記録**の方が向いているため

---

## 20. 毎日の作業の基本

### 作業開始

```bash
cd ~/terraform-portfolio
source .venv/bin/activate
```

### Terraform 変更後

```bash
cd ~/terraform-portfolio/terraform
terraform fmt -recursive
terraform validate
```

### Git へ上げる前

```bash
git status
git add .
git commit -m "Describe your change"
git push origin main
```

### 作業終了

```bash
deactivate
```

---

## 21. 今はやらないこと

最初から重くしすぎないため、以下は後回しにする。

- 本格認証の深掘り
- JWT / Cognito の作り込み
- CSRF 対策の実装
- 決済
- サブスク
- 高度な CRM
- 大規模な複数クリエイター運用設計
- ALB / Zabbix（Phase2）

---

## 22. 補足 URL 集

### 公式ドキュメント
- WSL install: https://learn.microsoft.com/ja-jp/windows/wsl/install
- WSL manual install: https://learn.microsoft.com/ja-jp/windows/wsl/install-manual
- VS Code download: https://code.visualstudio.com/download
- VS Code Windows setup: https://code.visualstudio.com/docs/setup/windows
- Git install for Windows: https://git-scm.com/install/windows
- Git install docs: https://git-scm.com/book/ja/v2/%E4%BD%BF%E3%81%84%E5%A7%8B%E3%82%81%E3%82%8B-Git%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB
- Terraform install: https://developer.hashicorp.com/terraform/install
- Terraform CLI commands: https://developer.hashicorp.com/terraform/cli/commands
- AWS CLI docs: https://docs.aws.amazon.com/cli/
- GitHub Actions workflow syntax: https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions
- GitHub secrets: https://docs.github.com/actions/security-guides/using-secrets-in-github-actions

---

## 23. 完了条件

このドキュメントの上から順に進めて、以下ができれば導入完了です。

- WSL2 + Ubuntu が使える
- Python / venv が動く
- Terraform が入っている
- AWS CLI が必要なら使える
- Git / GitHub へ push できる
- `terraform-portfolio` の最小構成がある
- GitHub Actions の最小 CI がある
- フロント HTML をローカルで開ける

