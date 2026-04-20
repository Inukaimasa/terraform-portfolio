# Terraform S3 backend 化メモ

## 概要

このプロジェクトでは、Terraform の state 保存先をローカルファイルから S3 に移行した。

変更前は local backend により、手元PC上の `terraform.tfstate` を使っていた。  
変更後は S3 backend を使い、AWS 上の S3 bucket に state を保存する構成にした。

この変更により、state の保存先が手元環境依存ではなくなり、将来的な再利用、共有、自動化、復旧がしやすくなった。

---

## 今回の目的

今回の目的は次の通り。

- Terraform state をローカルから S3 に移す
- state 保存先 bucket を事前に用意する
- 本体 Terraform が S3 backend を使うように変更する
- 既存 local state を S3 に migrate する
- Git に必要な設定ファイルのみ残し、生成物は除外する

---

## フォルダ構成と役割

### 全体像

```text
terraform/
├─ bootstrap/        # backend用S3 bucketを先に作るためのTerraform
├─ versions.tf       # 本体Terraformのバージョン定義 + backend宣言
├─ backend.hcl       # S3 backend の具体設定
├─ s3.tf             # 本体側のS3関連定義
├─ cloudfront.tf     # CloudFront定義
├─ lambda.tf         # Lambda定義
├─ dynamodb.tf       # DynamoDB定義
├─ iam.tf            # IAM定義
└─ outputs.tf        # apply後に表示するoutput

frontend/            # HTML / CSS / JS の静的ファイル
backend/             # LambdaのPythonコード
docs/                # 作業メモ、手順書
.github/workflows/   # CI/CD
```

---

## どのフォルダがどこと紐づいているか

### 1. `terraform/bootstrap/` と `terraform/`

この2つが今回の backend 化で最重要。

#### `terraform/bootstrap/`
Terraform 本体が使う **state 保存用 S3 bucket** を先に作る場所。

#### `terraform/`
実際の本体インフラを管理する場所。  
Lambda、DynamoDB、S3、CloudFront などをここで管理している。

### 関係

```text
terraform/bootstrap/
  ↓ backend用のS3 bucketを作る
terraform/
  ↓ そのbucketをbackendとして使い、本体stateをS3に保存する
```

つまり `bootstrap` は本体 Terraform の土台作成用。

---

### 2. `backend/` と `terraform/lambda.tf`

#### `backend/`
Lambda の中で動く Python コード本体。

#### `terraform/lambda.tf`
そのコードを AWS Lambda として作成・更新するための Terraform 定義。

### 関係

```text
backend/   = Lambdaの処理本体
terraform/ = LambdaをAWSに作る定義
```

---

### 3. `frontend/` と `terraform/s3.tf` `terraform/cloudfront.tf`

#### `frontend/`
画面側の静的ファイル。

#### `terraform/s3.tf`
フロント配信用の S3 関連定義。

#### `terraform/cloudfront.tf`
CloudFront 配信関連定義。

### 関係

```text
frontend/  = 画面ファイル
terraform/ = 画面を公開するAWSインフラ定義
```

---

## 今回 backend 化で触ったファイル

### `terraform/bootstrap/main.tf`
役割:
- backend 用 S3 bucket を作る
- bucket versioning を有効にする

### `terraform/bootstrap/versions.tf`
役割:
- bootstrap 側で使う Terraform / Provider バージョン定義

### `terraform/versions.tf`
役割:
- 本体 Terraform に `backend "s3" {}` を追加し、S3 backend を使う宣言をする

### `terraform/backend.hcl`
役割:
- S3 backend の具体設定を書く

例:

```hcl
bucket       = "my-protfolio-tfstate-20260420"
region       = "ap-northeast-1"
key          = "portfolio/dev/terraform.tfstate"
use_lockfile = true
```

意味:
- `bucket`: state を保存する S3 bucket 名
- `region`: bucket のリージョン
- `key`: bucket 内の保存パス
- `use_lockfile = true`: state 更新時のロック設定

---

## なぜ `bootstrap/` が必要なのか

S3 backend は、保存先 bucket が **先に存在している必要** がある。

つまり、本体 Terraform が

「state を S3 に保存します」

と設定する前に、その S3 bucket 自体を AWS 上に作っておかなければならない。

そのため、まず `terraform/bootstrap/` で backend 用 bucket を作り、そのあとで本体側 `terraform/` を S3 backend 化した。

---

## 実行した流れ

### 1. bootstrap 側で backend 用 bucket を作成

実行場所:

```text
terraform/bootstrap/
```

実行:

```bash
terraform init
terraform plan
terraform apply
```

ここでは backend 用 S3 bucket と versioning を作成した。

---

### 2. 本体側に S3 backend 宣言を追加

対象ファイル:

```text
terraform/versions.tf
```

追加内容:

```hcl
terraform {
  backend "s3" {}
}
```

これにより、本体 Terraform は S3 backend を使う前提になった。

---

### 3. backend.hcl を作成

対象ファイル:

```text
terraform/backend.hcl
```

ここで backend の具体値を定義した。

---

### 4. local state を S3 に migrate

実行場所:

```text
terraform/
```

実行:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

このコマンドでやったこと:

- backend を local から s3 に切り替える
- 既存の local state を S3 に移動する

実行中に表示された

```text
Do you want to copy existing state to the new backend?
```

は、

「今までローカルにあった state を、新しい S3 backend にコピーしてよいか」

という意味。ここでは `yes` を選択した。

---

## 移行後に確認したこと

### 1. S3 に state ができていること

S3 bucket 内に次のオブジェクトが作成された。

```text
portfolio/dev/terraform.tfstate
```

これにより、state の保存先が S3 に変わったことを確認できた。

---

### 2. `terraform state list` が通ること

実行:

```bash
terraform state list
```

ここで Lambda、DynamoDB、IAM、S3 などのリソースが表示された。

つまり、state を S3 に移したあとも、Terraform は既存インフラを正しく認識できている。

---

### 3. `terraform plan` が通ること

実行:

```bash
terraform plan
```

差分確認ができる状態になっており、backend 切り替え後も Terraform が正常に動いていることを確認した。

---

### 4. `terraform apply` が完了すること

apply 後に `Outputs:` が表示されたため、apply は正常終了と判断した。

---

## 途中で出たエラーの意味

### `Invalid multi-line string`
原因:
- `backend.hcl` の文字列の閉じダブルクォート `"` 抜け

つまり HCL の書式ミス。

---

### `NoSuchBucket`
原因:
- `backend.hcl` に書いた bucket 名と
- `bootstrap/main.tf` で作った bucket 名

が一致していなかったため。

今回の学び:
- backend 用 bucket 名は完全一致が必要
- 1文字違っても別 bucket と判断される

---

## Git 管理で整理したこと

### commit したもの
- `.gitignore`
- `terraform/versions.tf`
- `terraform/backend.hcl`
- `terraform/bootstrap/main.tf`
- `terraform/bootstrap/versions.tf`
- `terraform/bootstrap/.terraform.lock.hcl`

### commit しないもの
- `.terraform/`
- `*.tfstate`
- `tfplan`
- zip 生成物
- `__pycache__/`

### 考え方
- 再現に必要な設定ファイルは commit
- 実行時に生成されるファイルは ignore

---

## 今の状態

現在は次の状態になっている。

- backend 用 S3 bucket 作成済み
- bucket versioning 有効化済み
- 本体 Terraform は S3 backend を使用する設定
- local state は S3 に migrate 済み
- `terraform state list` が通る
- `terraform plan` / `terraform apply` が通る
- Git commit 済み

つまり、**Terraform の S3 backend 化は完了**している。

---

## 今回の理解ポイントまとめ

### state とは
Terraform が何を管理しているかの記録。

### backend とは
その state をどこに保存するかの仕組み。

### なぜ S3 backend にするのか
ローカル依存を減らし、共有・再利用・自動化・復旧をしやすくするため。

### なぜ bootstrap が必要なのか
S3 backend の保存先 bucket は事前作成が必要だから。

### `backend.hcl` とは
S3 backend の具体設定を外出ししたファイル。

### `-migrate-state` とは
既存 local state を新しい backend に移すためのオプション。

---

## 一言まとめ

今回やったことは、

**Terraform 本体を動かす前に、state の置き場所となる S3 bucket を bootstrap で作り、その後に本体 state を local から S3 に移した**

という作業である。