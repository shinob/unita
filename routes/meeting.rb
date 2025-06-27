# routes/meeting.rb
require 'sinatra/base'
require 'csv'

require_relative '../models/meeting'
require_relative '../models/participant'
require_relative '../helpers/auth_helper'

class MeetingRoutes < Sinatra::Base
  use Rack::Session::Cookie,
    key: COOKIE_KEY,
    path: '/',
    secret: COOKIE_SECRET,
    expire_after: COOKIE_EXPIRE,
    same_site: :lax

  helpers AuthHelper
  set :views, File.expand_path('../../views', __FILE__)

  before do
    if request.env['HTTP_X_FORWARDED_PREFIX']
      request.script_name = request.env['HTTP_X_FORWARDED_PREFIX']
    end
  end
  
  # ダッシュボード用ミーティング一覧
  get '/org/meetings' do
    redirect to(url('/login')) unless logged_in?
    halt(403, 'Access denied') unless current_organization
    
    ical_token
    
    # d日経過した予定は表示しない
    d = 1
    cutoff_time = Time.now - (d * 24 * 60 * 60)
    @meetings = Meeting.where(organization_id: current_organization.id)
                        .enabled
                        .where { scheduled_at > cutoff_time }
                        .order(:scheduled_at)
                        .all

    erb :meetings_list, layout: :layout
  end

  get '/org/meetings/all' do
    require_login
    halt(403, 'Access denied') unless current_organization
    ical_token
  
    dataset = Meeting.where(organization_id: current_organization.id)
                     .enabled
  
    # フィルタ処理
    if params[:keyword] && !params[:keyword].strip.empty?
      keyword = "%#{params[:keyword].strip}%"
      dataset = dataset.where(Sequel.like(:title, keyword)).or(Sequel.like(:description, keyword))
    end
  
    if params[:from] && !params[:from].empty?
      from_time = Time.parse(params[:from]) rescue nil
      dataset = dataset.where { scheduled_at >= from_time } if from_time
    end
  
    if params[:to] && !params[:to].empty?
      to_time = Time.parse(params[:to]) + 86400 rescue nil
      dataset = dataset.where { scheduled_at <= to_time } if to_time
    end
  
    @meetings = dataset.order(:scheduled_at).all
    erb :meetings_list, layout: :layout
  end

  # 新規予定フォーム
  get '/org/meetings/new' do
    require_organizer!
    erb :new_meeting, layout: :layout
  end

  # 予定追加
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

    user_ids = current_organization.memberships.map(&:user_id).uniq
    user_ids.each do |user_id|
      Participant.find_or_create(meeting_id: meeting.id, user_id: user_id) do |p|
        p.status = 'undecided'
      end
    end

    redirect to(url("/org/meetings/#{meeting.id}"))
  end

  # 予定詳細表示
  get '/org/meetings/:id' do
    @meeting = Meeting[params[:id]]
    halt(404, 'Meeting not found') unless @meeting
    halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id

    current_organization.memberships.map(&:user_id).uniq.each do |user_id|
      Participant.find_or_create(meeting_id: @meeting.id, user_id: user_id) do |p|
        p.status = 'undecided'
      end
    end

    @participants = @meeting.participants.select { |p| same_organization?(p.user) }
    @participant = @participants.find { |p| p.user_id == current_user.id }

    erb :show_meeting, layout: :layout
  end

  # 予定編集フォーム
  get '/org/meetings/:id/edit' do
    require_organizer!
    @meeting = Meeting[params[:id]]
    halt(404, 'Meeting not found') unless @meeting
    halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id
    erb :edit_meeting, layout: :layout
  end

  # 予定更新
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

  # 出欠回答
  post '/org/meetings/:id/respond' do
    meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless meeting.organization_id == current_organization.id

    participant = Participant.where(meeting_id: meeting.id, user_id: current_user.id).first
    halt(403, 'Access denied') unless participant
    halt(403, 'Only users in the same organization can respond') unless same_organization?(current_user)

    #if meeting.deadline_at && Time.now > meeting.deadline_at && !current_user.roles_for(current_organization.id).include?('org_admin')
    #  halt(403, 'The deadline for responses has passed')
    #end

    if meeting.deadline_at && Time.now > meeting.deadline_at && !current_user.roles_for(current_organization.id).include?('org_admin')
      redirect to(url("/org/meetings/#{meeting.id}?error=deadline"))
    end
    
    participant.set(status: params[:status], comment: params[:comment])
    participant.save

    redirect to(url("/org/meetings/#{meeting.id}"))
  end

  # 管理者による出欠登録フォーム
  get '/org/meetings/:id/respond_admin' do
    #require_org_admin!
    require_organizer_or_admin!
    
    @meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id

    @members = current_organization.memberships.map(&:user)
    @participants = @meeting.participants_dataset.eager(:user).all.select do |p|
      current_organization.users.include?(p.user)
    end
    erb :admin_respond_meeting, layout: :layout
  end

  # 管理者による出欠登録
  post '/org/meetings/:id/respond_admin' do
    #require_org_admin!
    require_organizer_or_admin!
    
    @meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id

    params[:responses]&.each do |user_id, data|
      participant = Participant.where(meeting_id: @meeting.id, user_id: user_id).first
      next unless participant
      participant.set(status: data["status"], comment: data["comment"])
      participant.save
    end

    redirect to(url("/org/meetings/#{@meeting.id}"))
  end
  
  # 管理者による出欠登録
  post '/org/meetings/:id/disable' do
    require_organizer!
    meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless meeting.organization_id == current_organization.id
    meeting.update(disabled: true)
    redirect to(url('/org/meetings'))
  end
  
  # 出欠データのCSVダウンロード
  get '/org/meetings/:id/export_csv' do
    #require_organizer!  # または require_org_admin!
    require_organizer_or_admin!
  
    meeting = Meeting[params[:id]]
    halt(404, 'Meeting not found') unless meeting
    halt(403, 'Access denied') unless meeting.organization_id == current_organization.id
  
    participants = meeting.participants_dataset.eager(:user).all
  
    content_type 'text/csv'
    attachment "meeting_#{meeting.id}_participants.csv"
  
    bom = "\uFEFF"  # UTF-8 BOM
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['ユーザー名', 'メールアドレス', '出欠ステータス', 'コメント']
      participants.each do |p|
        csv << [
          p.user.name,
          p.user.email,
          { 'attending' => '出席', 'absent' => '欠席', 'undecided' => '未定' }[p.status],
          p.comment
        ]
      end
    end
  
    bom + csv_data  # BOMを先頭に付けて返す
  end
  
end
