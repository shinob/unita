# usage
# ruby scripts/create_test_user.rb

require 'sequel'
require 'bcrypt'

require_relative '../config/setting'

DB = Sequel.sqlite(DB_PATH) # または .sqlite3 のパスを合わせる

def create_user(email, name, password, admin)

  # 仮ユーザーがいなければ作成
  unless DB[:users].first(email: email)
    password_hash = BCrypt::Password.create(password)
    DB[:users].insert(
      name: name,
      email: email,
      password_digest: password_hash,
      system_admin: admin # システム管理者として作成（falseでもOK）
    )
    puts "仮ユーザーを登録しました: #{email} / #{password}"
  else
    puts "仮ユーザーは既に存在します"
  end
  
end
