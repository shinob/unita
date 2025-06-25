# routes/user.rb
require 'sinatra/base'

require_relative '../config/setting'
require_relative '../models/user'
require_relative '../helpers/auth_helper'

class UserRoutes < Sinatra::Base
  #enable :sessions
  use Rack::Session::Cookie,
    key: COOKIE_KEY,
    path: '/',
    secret: COOKIE_SECRET,
    expire_after: COOKIE_EXPIRE,
    same_site: :lax

  helpers AuthHelper
  set :views, File.expand_path('../../views', __FILE__)
  
  get '/org/users' do
    #require_org_admin!
    require_login
    @organization = current_organization
    @users = @organization.memberships.map(&:user) #.sort_by(&:name)
    #@org_users = @organization.memberships.map(&:user)
    #@org_users = current_organization.organization_users.includes(:user)
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
    halt(404, 'User not found') unless @user
    halt(403, 'Access denied') unless same_organization?(@user)
    
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

  get '/profile' do
    require_login
    @user = current_user
    erb :profile, layout: :layout
  end
  
  post '/profile/update' do
    require_login
    user = current_user
  
    user.set(
      name: params[:name],
      email: params[:email],
      company_name: params[:company_name],
      department: params[:department],
      position: params[:position],
      phone: params[:phone],
      address: params[:address],
      notes: params[:notes]
    )
  
    user.password = params[:password] unless params[:password].to_s.strip.empty?
    user.save
  
    @message = "プロフィールを更新しました。"
    @user = user
    erb :profile, layout: :layout
  end
  
=begin
  get '/org/users/:id' do
    require_login
    @user = User[params[:id]]
    halt 404, "User not found" unless @user
    halt 403, "Access denied" unless same_organization?(@user)
  
    @membership = Membership.where(user_id: @user.id, organization_id: current_organization.id).first
    erb :show_user_profile, layout: :layout
  end
=end
  
  get '/org/users/:id' do
    require_login
    @user = User[params[:id]]
    halt 404, "User not found" unless @user
    halt 403, "Access denied" unless same_organization?(@user)
  
    @membership = Membership.where(user_id: @user.id, organization_id: current_organization.id).first
  
    # 出欠データを取得（DBフィルタ + eager読み込み）
    @participations = Participant
      .where(user_id: @user.id)
      .join(:meetings, id: :meeting_id)
      .where(Sequel[:meetings][:organization_id] => current_organization.id)
      .order(Sequel[:meetings][:scheduled_at])  # ← ソート追加
      .select_all(:participants)
      .eager(:meeting)
      .all
    
    erb :show_user_profile, layout: :layout
  end
  
end
