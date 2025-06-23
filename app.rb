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
  String :adress
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
helpers do
  
=begin
  def status?(meeting_id)
    participant = Participant.where(meeting_id: meeting_id, user_id: current_user.id).first
    unless participant
      "undecided"
    else
      participant.status
    end
  end
  
  def ical_token
    unless current_organization.ical_token
      current_organization.ical_token = SecureRandom.hex(16)
      current_organization.save
    end
    current_organization.ical_token
  end
=end  
end

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

=begin
get '/admin' do
  "管理者メニュー"
end
=end

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

=begin
  cal = Icalendar::Calendar.new
  meetings.each do |m|
    cal.event do |e|
      e.dtstart     = Icalendar::Values::DateTime.new(m.scheduled_at.utc)
      e.dtend       = Icalendar::Values::DateTime.new(m.ended_at.utc) if m.ended_at
      e.summary     = m.title
      e.description = m.description
      e.created     = m.created_at if m.respond_to?(:created_at)
    end
  end
=end

  content_type 'text/calendar'
  cal.to_ical
  
end

# --- 組織管理者機能 ---
=begin
get '/org/users' do
  #require_org_admin!
  @organization = current_organization
  @users = @organization.memberships.map(&:user)
  erb :org_users, layout: :layout
end

post '/org/users/create' do
  require_org_admin!
  user = User.first(email: params[:email]) || User.new(name: params[:name], email: params[:email])
  user.password = params[:password] if user.new?
  user.save

  unless Membership.where(user_id: user.id, organization_id: current_organization.id).first
    Membership.create(user_id: user.id, organization_id: current_organization.id, role: params[:role])
  end

  redirect to(url('/org/users'))
end

get '/org/users/:id/edit' do
  require_org_admin!
  @user = User[params[:id]]
  @membership = Membership.where(user_id: @user.id, organization_id: current_organization.id).first
  halt(403, 'Access denied') unless @membership
  erb :edit_org_user, layout: :layout
end

post '/org/users/:id/update' do
  require_org_admin!
  user = User[params[:id]]
  membership = Membership.where(user_id: user.id, organization_id: current_organization.id).first
  halt(403, 'Access denied') unless membership

  user.name = params[:name]
  user.email = params[:email]
  user.password = params[:password] unless params[:password].empty?
  user.save

  membership.role = params[:role]
  membership.save

  redirect to(url('/org/users'))
end

post '/org/users/:id/delete' do
  require_org_admin!
  membership = Membership.where(user_id: params[:id], organization_id: current_organization.id).first
  membership&.destroy
  redirect to(url('/org/users'))
end
=end

# --- 会議一覧表示 ---
=begin
get '/org/meetings' do
  redirect to(url('/login')) unless logged_in?
  
  halt(403, 'Access denied') unless current_organization
  
  #@meetings = Meeting.where(organization_id: current_organization.id).order(:scheduled_at).all
  
  # 7日前より新しい会議のみ取得
  cutoff_time = Time.now - (7 * 24 * 60 * 60)
  @meetings = Meeting.where(organization_id: current_organization.id)
                     .where { scheduled_at > cutoff_time }
                     .order(:scheduled_at)
                     .all
  
  erb :meetings_list, layout: :layout
end

get '/org/meetings/all' do
  redirect to(url('/login')) unless logged_in?
  
  halt(403, 'Access denied') unless current_organization
  @meetings = Meeting.where(organization_id: current_organization.id).order(:scheduled_at).all
  erb :meetings_list, layout: :layout
end

get '/org/meetings/:id/edit' do
  require_organizer!
  @meeting = Meeting[params[:id]]
  #@meeting.ended_at.to_s
  halt(404, 'Meeting not found') unless @meeting
  halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id
  erb :edit_meeting, layout: :layout
end

post '/org/meetings/:id/update' do
  require_organizer!
  meeting = Meeting[params[:id]]
  halt(404, 'Meeting not found') unless meeting
  halt(403, 'Access denied') unless meeting.organization_id == current_organization.id

  meeting.set(
    title: params[:title],
    description: params[:description],
    scheduled_at: Time.parse(params[:scheduled_at]),
    ended_at: Time.parse(params[:ended_at]),
    deadline_at: Time.parse(params[:deadline_at])
  )
  meeting.save

  redirect to(url("/org/meetings/#{meeting.id}"))
end

# --- 会議運営者機能（会議作成・参加者募集） ---
get '/org/meetings/new' do
  require_organizer!
  erb :new_meeting, layout: :layout
end

post '/org/meetings/create' do
  require_organizer!
  meeting = Meeting.new(
    organization_id: current_organization.id,
    organizer_id: current_user.id,
    title: params[:title],
    description: params[:description],
    scheduled_at: Time.parse(params[:scheduled_at]),
    ended_at: Time.parse(params[:ended_at]),
    deadline_at: Time.parse(params[:deadline_at])
  )
  meeting.save

  # user_idをユニークにして重複登録を防止
  user_ids = current_organization.memberships.map(&:user_id).uniq

  user_ids.each do |user_id|
    next if Participant.where(meeting_id: meeting.id, user_id: user_id).first

    Participant.create(
      meeting_id: meeting.id,
      user_id: user_id,
      status: 'undecided'
    )
  end

  redirect to(url("/org/meetings/#{meeting.id}"))
end

get '/org/meetings/:id' do
  @meeting = Meeting[params[:id]]
  unless @meeting
    return erb :error, locals: { message: "指定されたミーティングID（#{params[:id]}）は存在しません。" }
  end
  halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id

  # ここで不足している参加者を自動登録
  current_organization.memberships.map(&:user_id).uniq.each do |user_id|
    unless Participant.where(meeting_id: @meeting.id, user_id: user_id).first
      Participant.create(meeting_id: @meeting.id, user_id: user_id, status: 'undecided')
    end
  end

  @participants = @meeting.participants.select do |p|
    same_organization?(p.user)
  end
  @participant = @participants.find { |p| p.user_id == current_user.id }
  erb :show_meeting, layout: :layout
end

post '/org/meetings/:id/respond' do
  meeting = Meeting[params[:id]]
  unless  meeting.organization_id == current_organization.id
    return erb :error, locals: { message: "指定されたミーティングID（#{params[:id]}）はこの組織のものではありません。" }
  end
  #halt(403, 'Access denied') unless meeting.organization_id == current_organization.id
  
  participant = Participant.where(meeting_id: meeting.id, user_id: current_user.id).first
  halt(403, 'Access denied') unless participant

  unless same_organization?(current_user)
    halt(403, 'Only users in the same organization can respond')
  end

  if meeting.deadline_at && Time.now > meeting.deadline_at && !current_user.roles_for(current_organization.id).include?('org_admin')
    halt(403, 'The deadline for responses has passed')
  end

  participant.status = params[:status]
  participant.comment = params[:comment]
  participant.save

  redirect to(url("/org/meetings/#{meeting.id}"))
end

get '/org/meetings/:id/respond_admin' do
  require_org_admin!
  @meeting = Meeting[params[:id]]
  halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id
  @members = current_organization.memberships.map(&:user)
  #@participants = @meeting.participants
  @participants = @meeting.participants_dataset.
    eager(:user).
    all

  @participants.select! do |p|
    current_organization.users.include?(p.user)
  end
  erb :admin_respond_meeting, layout: :layout
end

post '/org/meetings/:id/respond_admin' do
  require_org_admin!
  @meeting = Meeting[params[:id]]
  halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id

  params[:responses]&.each do |user_id, data|
    participant = Participant.where(meeting_id: @meeting.id, user_id: user_id).first
    next unless participant
    participant.status = data["status"]
    participant.comment = data["comment"]
    participant.save
  end

  redirect to(url("/org/meetings/#{@meeting.id}"))
end
=end