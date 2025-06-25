
# 📅 unita

複数組織に対応した Web ベースの予定出欠管理システムです。  
Sinatra（Ruby）+ SQLite3 で構成された軽量アプリケーションです。

---

## 🚀 特長

- ユーザーは複数の組織に所属可能
- ロール（管理者・運営者・参加者）ごとのアクセス制御
- 予定（会議など）の作成、出欠登録、コメント機能
- 出欠の締切設定と回答制限
- 管理者による代理出欠入力
- iCal形式でのカレンダー出力（`.ics`）
- Tailwind CSS によるモダンなUI

---

## 🔧 技術スタック

| 技術       | 内容                     |
|------------|--------------------------|
| Ruby       | 3.x（Sinatra）           |
| DB         | SQLite3 + Sequel ORM     |
| 認証       | セッションベース認証     |
| フロント   | Tailwind CSS + ERB       |
| カレンダー | iCalendar出力（RFC5545） |

---

## 📦 インストール手順

### 1. 必要環境

- Ruby 3.x
- SQLite3

### 2. セットアップ

Ubuntuの場合

```bash
sudo apt install -y ruby-sinatra ruby-sinatra-contrib ruby-sequel ruby-bcrypt ruby-icalendar ruby-sqlite3
git clone https://github.com/shinob/unita.git
cd unita
cp config/setting.rb.sample config/setting.rb
# config/setting.rb を環境に合わせて修正
```

### 3. 起動

```bash
ruby app.rb
```

- 標準ポート: `http://localhost:1234`

---

## 🧑‍💼 ロール別の使い方

| ロール         | 機能概要                                                                 |
|----------------|--------------------------------------------------------------------------|
| 管理者         | 組織管理・ユーザー検索・ダッシュボード操作                               |
| 組織管理者     | 組織内のユーザー・予定の管理、出欠代理入力                                |
| 運営者         | 予定作成・編集・無効化                                                   |
| 参加者         | 出欠の登録・コメント記入、自分のプロフィール編集                         |

👉 詳細な使い方は [`USAGE.md`](./USAGE.md) を参照してください。

---

## 📆 iCal連携

組織ごとに iCal URL を提供しています：

```
/org/:organization_id/:ical_token.ics
```

Google カレンダー等に取り込むことで予定を自動反映可能です。

---

## 📂 ディレクトリ構成（抜粋）

```
.
├── app.rb                 # メインアプリケーション
├── config/
│   └── setting.rb         # 設定ファイル
├── models/                # DBモデル
├── routes/                # 各機能のルーティング
├── views/                 # ERBテンプレート
├── public/                # 静的ファイル（CSS等）
├── scripts/               # テストデータ生成用
└── README.md              # このファイル
```

---

## 📄 ライセンス

MIT License  
© 2025 blueOmega

---
