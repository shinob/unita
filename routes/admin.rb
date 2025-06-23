# routes/admin.rb
require 'sinatra/base'
require_relative '../models/organization'
require_relative '../models/user'
require_relative '../helpers/auth_helper'

class AdminRoutes < Sinatra::Base
  use Rack::Session::Cookie,
      key: COOKIE_KEY,
      path: '/',
      secret: COOKIE_SERCRET,
      expire_after: COOKIE_EXPIRE,
      same_site: :lax

  helpers AuthHelper
  set :views, File.expand_path('../../views', __FILE__)

  before do
    require_admin!
    if request.env['HTTP_X_FORWARDED_PREFIX']
      request.script_name = request.env['HTTP_X_FORWARDED_PREFIX']
    end
  end

  # ダッシュボード画面
  get '/admin/dashboard' do
    @organizations = Organization.all
    @user_count = User.count
    @meeting_count = Meeting.count
    erb :admin_dashboard, layout: :layout
  end

  # 組織の作成
  post '/admin/orgs/create' do
    name = params[:org_name].to_s.strip
    if name.empty?
      @error = "組織名を入力してください"
      redirect to('/admin/dashboard')
    end

    unless Organization.first(name: name)
      Organization.create(name: name)
    end

    redirect to('/admin/dashboard')
  end

  # 組織の削除
  post '/admin/orgs/:id/delete' do
    org = Organization[params[:id]]
    if org
      org.memberships.each(&:destroy)
      org.meetings.each do |m|
        m.participants.each(&:destroy)
        m.destroy
      end
      org.destroy
    end
    redirect to('/admin/dashboard')
  end

  # ユーザー検索
  get '/admin/users/search' do
    query = params[:query].to_s.strip
    if query.empty?
      @search_results = []
    else
      @search_results = User.where(Sequel.like(:name, "%#{query}%")).
                        or(Sequel.like(:email, "%#{query}%")).
                        all
    end
    @organizations = Organization.all
    @user_count = User.count
    @meeting_count = Meeting.count
    erb :admin_dashboard, layout: :layout
  end
end
