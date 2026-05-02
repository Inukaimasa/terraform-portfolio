# Trivy / tfsec インストール手順

## 目的

AWS / Terraform / Docker / Gitリポジトリのセキュリティ確認に使うスキャンツールを導入する。

この手順では以下を扱う。

| ツール | 用途 |
|---|---|
| `trivy` | コンテナイメージ、ファイルシステム、Gitリポジトリ、Terraformなどのセキュリティスキャン |
| `tfsec` | Terraformコードのセキュリティ静的解析 |
| `curl` | URLからファイルやスクリプトを取得 |
| `wget` | URLからファイルを取得 |
| `gnupg` | aptリポジトリ用の署名鍵を扱う |

---

## 1. Trivyとは

Trivyは、Aqua Securityが提供しているセキュリティスキャナ。

主に以下を確認できる。

- Dockerイメージの脆弱性
- ローカルファイルシステムの脆弱性
- Gitリポジトリ内の脆弱性やシークレット
- TerraformなどIaCの設定不備
- Kubernetesマニフェストの設定不備

Terraformポートフォリオでは、以下の用途で使う。

```text
Terraformコードに危険な設定がないか確認する
Dockerイメージに脆弱性がないか確認する
リポジトリ全体に秘密情報や脆弱性がないか確認する
```

---

## 2. Trivyインストール手順

### 2-1. 必要パッケージをインストールする

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y wget gnupg
```

---

### 2-2. Trivyの公開鍵を登録する

```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
```

このコマンドの意味。

| 部分 | 意味 |
|---|---|
| `wget -qO -` | URLの内容を取得して標準出力に流す |
| `https://aquasecurity.github.io/trivy-repo/deb/public.key` | Trivyリポジトリの公開鍵 |
| `gpg --dearmor` | aptで使える形式に変換 |
| `sudo tee /usr/share/keyrings/trivy.gpg` | 鍵ファイルとして保存 |

---

### 2-3. Trivyのaptリポジトリを追加する

```bash
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee /etc/apt/sources.list.d/trivy.list
```

このコマンドの意味。

| 部分 | 意味 |
|---|---|
| `echo "deb ..."` | aptリポジトリの設定内容を作る |
| `signed-by=/usr/share/keyrings/trivy.gpg` | 登録した公開鍵で検証する |
| `sudo tee /etc/apt/sources.list.d/trivy.list` | Trivy用のリポジトリ設定ファイルを作る |

---

### 2-4. aptを更新する

```bash
sudo apt-get update
```

---

### 2-5. Trivyをインストールする

```bash
sudo apt-get install -y trivy
```

実行場所はどこでもよい。

例えば以下の場所で実行しても問題ない。

```text
~/terraform-portfolio/terraform
```

`sudo apt-get install -y trivy` は、現在のディレクトリにファイルを作るのではなく、Ubuntu / WSL全体に `trivy` コマンドをインストールする。

---

### 2-6. Trivyのインストール確認

```bash
trivy --version
```

バージョンが表示されれば成功。

---

## 3. Trivyの使い方

### 3-1. Terraformコードをスキャンする

Terraformディレクトリに移動する。

```bash
cd ~/terraform-portfolio/terraform
```

Terraform設定をチェックする。

```bash
trivy config .
```

意味。

```text
現在のディレクトリ配下のTerraformコードをセキュリティ観点でチェックする
```

---

### 3-2. リポジトリ全体をスキャンする

```bash
cd ~/terraform-portfolio
```

```bash
trivy fs .
```

意味。

```text
現在のディレクトリ配下のファイルシステム全体をスキャンする
```

---

### 3-3. Dockerイメージをスキャンする

例として `nginx:latest` をスキャンする。

```bash
trivy image nginx:latest
```

自分で作成したDockerイメージを確認する場合は、イメージ名を指定する。

```bash
trivy image イメージ名:タグ
```

---

## 4. tfsecとは

tfsecは、Terraformコードのセキュリティ静的解析ツール。

主に以下を確認できる。

- S3バケットが公開されていないか
- Security Groupが広く開きすぎていないか
- IAM権限が広すぎないか
- 暗号化設定が不足していないか
- ログ設定が不足していないか

ただし、現在はTrivy側への移行が案内されているため、新しく使う場合はTrivyを優先する。

このREADMEでは、tfsecは以下の位置づけにする。

```text
Trivy：メインのセキュリティスキャンツール
tfsec：Terraform専用チェックの補助・比較用
```

---

## 5. tfsecインストール手順

### 5-1. curlをインストールする

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y curl
```

---

### 5-2. tfsecをインストールする

```bash
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

このコマンドの意味。

| 部分 | 意味 |
|---|---|
| `curl` | URLからデータを取得する |
| `-s` | 進捗表示を出さない |
| `https://raw.githubusercontent.com/.../install_linux.sh` | tfsecのLinux用インストールスクリプト |
| `|` | 左の出力を右のコマンドへ渡す |
| `bash` | 取得したスクリプトを実行する |

つまり、以下の意味。

```text
GitHub上のtfsecインストールスクリプトを取得して、そのままbashで実行する
```

---

## 6. tfsecのインストール確認

```bash
tfsec --version
```

バージョンが表示されれば成功。

---

## 7. tfsecの使い方

Terraformディレクトリに移動する。

```bash
cd ~/terraform-portfolio/terraform
```

tfsecを実行する。

```bash
tfsec .
```

意味。

```text
現在のディレクトリ配下のTerraformコードをセキュリティ観点でチェックする
```

---

## 8. Trivyとtfsecの使い分け

| ツール | 対象 | 使い方 |
|---|---|---|
| Trivy | Terraform / Docker / ファイル / Gitリポジトリ | メインで使う |
| tfsec | Terraform | 補助・比較用 |

基本方針。

```text
Terraformチェックは trivy config . を優先する
必要に応じて tfsec . でも比較する
Dockerイメージの脆弱性確認は trivy image を使う
リポジトリ全体確認は trivy fs . を使う
```

---

## 9. よく使うコマンドまとめ

### Trivy確認

```bash
trivy --version
```

### Terraformスキャン

```bash
cd ~/terraform-portfolio/terraform
trivy config .
```

### リポジトリ全体スキャン

```bash
cd ~/terraform-portfolio
trivy fs .
```

### Dockerイメージスキャン

```bash
trivy image nginx:latest
```

### tfsec確認

```bash
tfsec --version
```

### tfsecでTerraformスキャン

```bash
cd ~/terraform-portfolio/terraform
tfsec .
```

---

## 10. トラブルシュート

### URLやファイル名に空白を入れない

以下は間違い。

```text
install_linux. sh
```

正しくは以下。

```text
install_linux.sh
```

以下も間違い。

```text
aquasecurity. github. io
```

正しくは以下。

```text
aquasecurity.github.io
```

---

### `wget -q0` は間違い

以下は間違い。

```bash
wget -q0 -
```

正しくは、大文字の `O` を使う。

```bash
wget -qO -
```

`-qO -` の意味。

```text
静かに取得して、取得内容を標準出力へ出す
```

---

### `curl ... | bash` の注意

```bash
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

この形式は、外部から取得したスクリプトをそのまま実行する。

そのため、信頼できる公式リポジトリ以外では使わない。

---

### Trivyインストールはどこのディレクトリで実行してもよい

以下のような場所で実行しても問題ない。

```text
~/terraform-portfolio/terraform
```

理由。

```text
sudo apt-get install -y trivy はUbuntu / WSL全体にtrivyを入れる処理であり、
現在のディレクトリに依存しないため。
```

---

## 11. ポートフォリオでの説明文

READMEや職務経歴書では、以下のように説明できる。

```text
Terraformで作成したAWS環境に対して、TrivyによるIaCセキュリティチェックを実施。
また、必要に応じてtfsecでもTerraformコードを静的解析し、S3、Security Group、IAM、暗号化設定などの設定不備を確認した。
Dockerイメージに対してはTrivy image scanを実施し、コンテナ利用時の脆弱性確認も行える構成とした。
```

---

## 12. 今回の位置づけ

この導入により、以下の確認ができるようになる。

| 確認内容 | 使用ツール |
|---|---|
| Terraformの設定不備 | `trivy config .` |
| Terraform専用の静的解析 | `tfsec .` |
| Dockerイメージの脆弱性 | `trivy image` |
| リポジトリ全体のスキャン | `trivy fs .` |

Terraform / ECS / Docker / CI/CD の学習において、セキュリティ確認まで含めた実務寄りの検証ができる。