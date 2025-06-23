# routes/auth.rb
require 'sinatra/base'

require_relative '../config/setting'
require_relative '../models/user'
require_relative '../helpers/auth_helper'

class OrganizationRoutes < Sinatra::Base
  #enable :sessions
  use Rack::Session::Cookie,
    key: COOKIE_KEY,
    path: '/',
    secret: COOKIE_SERCRET,
    expire_after: COOKIE_EXPIRE,
    same_site: :lax

  helpers AuthHelper
  set :views, File.expand_path('../../views', __FILE__)
  
  get '/select_organization' do
    halt(403, 'ログインしてください') unless current_user
    #@organizations = current_user.organizations
    @organizations = current_user.organizations.uniq { |org| org.id }
    erb :select_organization, layout: :layout
  end
  
  post '/select_organization' do
    org_id = params[:organization_id].to_i
    
    #puts "session user_id = #{session[:user_id]}"
    "現在のユーザー #{current_user} / #{session[:user_id]}"
    
    if current_user.organizations.map(&:id).include?(org_id)
      session[:organization_id] = org_id
      redirect to(url('/org/meetings'))
    else
      halt(403, '不正な組織選択')
    end
  end

end