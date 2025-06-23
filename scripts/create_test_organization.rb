# usage
# ruby scripts/create_test_organization.rb

require 'sequel'
require 'bcrypt'

require_relative '../config/setting'

DB = Sequel.sqlite(DB_PATH) # または .sqlite3 のパスを合わせる

def create_user_and_organization(email, name, password, admin, org_name, role)
  
  # ユーザー確認または作成
  user = DB[:users].first(email: email)
  unless user
    password_digest = BCrypt::Password.create(password)
    user_id = DB[:users].insert(
      name: name,
      email: email,
      password_digest: password_digest,
      system_admin: admin
    )
    user = DB[:users][id: user_id]
  end
  
  # 組織作成（存在しなければ）
  org = DB[:organizations].first(name: org_name)
  unless org
    org_id = DB[:organizations].insert(name: org_name)
    org = DB[:organizations][id: org_id]
  else
    org_id = org[:id]
  end
  
  # メンバーシップ確認または作成
  unless DB[:memberships].first(user_id: user[:id], organization_id: org_id)
    DB[:memberships].insert(
      user_id: user[:id],
      organization_id: org_id,
      #role: 'org_admin' # または 'organizer'
      #role: 'organizer' # または 'organizer'
      role: role
    )
  end
  
  puts "ユーザー '#{user[:email]}' を組織 '#{org[:name]}' に登録しました（役割: #{role}）"
  
end

  
