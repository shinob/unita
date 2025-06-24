# app.rb
require 'sinatra'
require 'sinatra/reloader' if development?
require 'dotenv/load'
require 'sequel'
require 'bcrypt'
require 'json'
require 'icalendar'
require 'time'

#enable :sessions

require_relative './config/setting'

set :bind, '0.0.0.0'
set :port, APP_PORT
#set :public_folder, File.expand_path('public', __dir__)
set :public_folder, 'public'
set :views, 'views'

use Rack::Session::Cookie,
  key: COOKIE_KEY,
  path: '/',
  secret: COOKIE_SERCRET,
  expire_after: COOKIE_EXPIRE,
  same_site: :lax

DB = Sequel.sqlite(DB_PATH)
#Sequel::Model.db = DB

# --- DB定義（完全版） ---
DB.create_table? :users do
  primary_key :id
  String :name
  String :email, unique: true
  String :password_digest
  TrueClass :system_admin, default: false
  
  String :phone
  String :company_name
  String :department
  String :position
  String :address
  String :notes
  DateTime :last_login_at
  DateTime :created_at
  DateTime :updated_at
end

DB.create_table? :organizations do
  primary_key :id
  String :name
  String :ical_token
end

DB.create_table? :memberships do
  primary_key :id
  foreign_key :user_id, :users
  foreign_key :organization_id, :organizations
  String :role # 'org_admin', 'organizer'
end

DB.create_table? :meetings do
  primary_key :id
  foreign_key :organization_id, :organizations
  foreign_key :organizer_id, :users
  String :title
  String :description
  DateTime :scheduled_at
  DateTime :ended_at
  DateTime :deadline_at
  TrueClass :disabled, default: false
end

DB.create_table? :participants do
  primary_key :id
  foreign_key :meeting_id, :meetings
  foreign_key :user_id, :users
  String :status # 'attending', 'absent', 'undecided'
  String :comment
end

# model
require_relative './models/user'
require_relative './models/organization'
require_relative './models/membership'
require_relative './models/meeting'
require_relative './models/participant'

# helper
require_relative './helpers/auth_helper'
helpers AuthHelper  # ここでヘルパーを有効にする

# route
require_relative './routes/auth'
use AuthRoutes

require_relative './routes/organization'
use OrganizationRoutes

require_relative './routes/user'
use UserRoutes

require_relative './routes/meeting'
use MeetingRoutes

require_relative './routes/admin'
use AdminRoutes

# --- 認証ヘルパー ---
  
=begin
helpers do
end
=end  

before do
  if request.env['HTTP_X_FORWARDED_PREFIX']
    request.script_name = request.env['HTTP_X_FORWARDED_PREFIX']
  end
end

def test_form()
  session[:i] = 0 unless session[:i]
  session[:i] += 1
  <<EOF
test: #{session[:i]}
<form method=post action="/schedule/">
  <input type="submit" value="test" />
</form>
EOF
end

# --- ルーティング ---

get '/' do
  if current_user
    if current_user.system_admin?
      redirect to(url('/admin/dashboard'))
    else
      redirect to(url('/org/meetings'))
    end
  else
    redirect to(url('/login'))
  end
end

post '/' do
  #test_form()
end

get '/unita/' do
  "Hello from /unita/"
end

get '/debug_session' do
  
  unless current_user
    admin = false
  else
    admin = current_user.system_admin?
  end
  
  text = <<~EOF
  <pre>
    session[:user_id] = #{session[:user_id].inspect}
    session[:role] = #{session[:role].inspect}
  </pre>
  <pre>
    #{current_user.name}
  </pre>
  <pre>
    admin = #{admin}
    org_admin = #{org_admin?}
  </pre>
  EOF
  
  text
end

get '/dashboard' do
  require_login
  "ダッシュボード"
end

# --- iCal出力 ---
get '/org/:id/:token.ics' do
  org = Organization[params[:id]]
  #org.ical_token
  
  halt 404, 'Organization not found' unless org
  halt 403, 'Invalid token' unless org.ical_token == params[:token]

  meetings = org.meetings_dataset.order(:scheduled_at).all

  cal = Icalendar::Calendar.new
  meetings.each do |m|
    cal.event do |e|
      e.dtstart     = Icalendar::Values::DateTime.new(m.scheduled_at, 'tzid' => 'Asia/Tokyo')
      e.dtend       = Icalendar::Values::DateTime.new(m.ended_at, 'tzid' => 'Asia/Tokyo') if m.ended_at
      e.summary     = m.title
      e.description = m.description
      e.created     = Icalendar::Values::DateTime.new(m.created_at, 'tzid' => 'Asia/Tokyo') if m.respond_to?(:created_at)
    end
  end

  content_type 'text/calendar'
  cal.to_ical
  
end

