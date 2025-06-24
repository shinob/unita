# unita（ユニタ）

会員出欠管理アプリケーション

## 概要

**unita** は、複数の組織に対応した Web ベースの予定出欠管理システムです。  
ユーザーは複数の組織に所属でき、管理者・運営者・参加者のロールごとに役割を持ちます。  
各組織ごとに予定を作成し、出欠やコメントの収集が可能です。iCal形式でカレンダー出力にも対応しています。

---

## 主な機能

- ユーザー認証（ログイン / 新規登録）
- 組織の作成・選択・編集
- 予定（会議）の作成・編集・無効化・削除
- 出欠登録（参加者・管理者双方）
- 組織ユーザーの追加・編集・削除
- システム管理者向けダッシュボード
- iCal形式での予定公開 (`.ics` 出力)

---

## 技術構成

- **Sinatra**（Ruby Webフレームワーク）
- **Sequel**（ORM）
- **SQLite3**（データベース）
- **Tailwind CSS** + 独自CSS（フロントエンド）
- **iCalendar**（予定のICS出力）

---

## セットアップ方法

### 1. 必要環境

- Ruby 3.x
- Bundler
- SQLite3

### 2. インストール

Ubuntuの場合

```bash
sudo apt install -y ruby-sinatra ruby-sinatra-contrib ruby-sequel ruby-bcrypt ruby-icalendar ruby-sqlite3
```

ライブラリインストール後

```bash
git clone https://github.com/your-username/unita.git
cd unita
cp config/setting.rb.sample config/setting.rb
```

config/setting.rb を環境に合わせて編集してください。

### 3. 起動

```bash
ruby app.rb
```
