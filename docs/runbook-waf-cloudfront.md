# WAF / CloudFront Runbook

## 目的
CloudFront 配下の公開URLに対して、AWS WAF の動作確認を安全に実施するための手順をまとめる。

---

## 前提
- CloudFront Distribution の URL 例: `https://da7nx3d6w85y9.cloudfront.net/profile.html`
- CloudFront 用 WAF は **us-east-1** で扱う
- CloudWatch Logs のロググループも **us-east-1** に作成する
- ロググループ名は `aws-waf-logs-` で始める

---

## 用語整理

### CloudFront Distribution
ユーザーからのリクエストを最初に受ける入口。

### Web ACL
WAF のルールセット。IP 制御、GeoMatch、Rate limit などをまとめる。

### IP set
IP アドレスのリスト。自分のグローバルIPだけ許可／拒否したい時に使う。

---

## 今回の重要ポイント

### 1. 実際に効いている Web ACL
- `CreatedByCloudFront-29a83738`

### 2. 検証用に別で作った Web ACL
- `portfolio-geo-count`
- 現時点では **関連リソースなし**
- そのため、今の CloudFront URL には効かない

---

## us-east-1 を使う理由
CloudFront 用 WAF はグローバル扱いだが、実運用上は **us-east-1 基準**で管理する。

対象:
- WAF
- CloudWatch Logs
- AWS Config の CloudFront/WAF 関連確認

---

## CloudWatch Logs 設定

### 推奨設定
- ロググループ名: `aws-waf-logs-geo-test`
- 保持期間: `7日`
- ログクラス: `スタンダード`
- KMS: 空欄

### 注意
東京リージョンでロググループを作ると、CloudFront 用 WAF のログ送信先として使えない。

---

## GeoMatch の使いどころ

### CloudFront 地理制限
- 単純な国制限
- 追加料金なし
- 配信全体を一律に制御したい時向き

### WAF GeoMatch
- 国制限 + 他ルールの組み合わせ
- ログ／Sampled requests で観測できる
- 例外制御や将来拡張に向く

### 今回の学習設定
- `count_kr_au`
- Action: `Count`
- Country: `KR`, `AU`

---

## 自分のグローバルIPの確認

```bat
nslookup myip.opendns.com resolver1.opendns.com
```

表示された IP を `/32` 付きで使う。

例:

```text
203.0.113.10/32
```

---

## IP set を使った動作確認

### 目的
ローカルPCだけで、WAF の Allow / Block を確認する。

### 手順
1. 自分のグローバルIPを確認
2. WAF で IP set を作成
3. `CreatedByCloudFront-29a83738` に新ルール追加
4. `検査 = 以下の IP アドレスから発信されています`
5. IP set を選択
6. Action を `Block` にする

### 期待結果
- 自分のIPが IP set に含まれている
- その状態で CloudFront URL にアクセス
- **403 になる**

### 意味
WAF が CloudFront の入口でブロックした、ということ。

---

## 403 になった時の解釈
403 は失敗ではなく、**WAF のルールが正しく発動した証拠**。

流れ:
1. ブラウザから CloudFront URL にアクセス
2. CloudFront 前段の WAF がリクエストを評価
3. 自分のIPが Block ルールに一致
4. CloudFront が 403 を返す

---

## うまくいかない時の確認ポイント

### 1. 本当に効いている Web ACL を編集しているか
- `CreatedByCloudFront-29a83738` が実運用側
- `portfolio-geo-count` は現時点で未接続

### 2. 変更反映待ち
WAF 変更は数分かかることがある。

### 3. Logs / Sampled requests を確認
- Sampled requests
- CloudWatch Logs: `aws-waf-logs-geo-test`

---

## 推奨の検証順
1. `CreatedByCloudFront-29a83738` を確認
2. 自分のグローバルIPを調べる
3. IP set を作成
4. Block ルールを追加
5. CloudFront URL にアクセス
6. 403 を確認
7. ログで証跡確認
8. ルールを戻して再度アクセス確認

---

## 今後の展開
- GeoMatch を Count で再確認
- IP set 検証内容を Terraform 化
- README には要約だけ残し、詳細はこの Runbook に寄せる
