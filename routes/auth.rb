# routes/auth.rb
require 'sinatra/base'

require_relative '../config/setting'
require_relative '../models/user'
require_relative '../helpers/auth_helper'

class AuthRoutes < Sinatra::Base
  #enable :sessions
  use Rack::Session::Cookie,
    key: COOKIE_KEY,
    path: '/',
    secret: COOKIE_SERCRET,
    expire_after: COOKIE_EXPIRE,
    same_site: :lax
    
  helpers AuthHelper
  set :views, File.expand_path('../../views', __FILE__)
  
  before do
    if request.env['HTTP_X_FORWARDED_PREFIX']
      request.script_name = request.env['HTTP_X_FORWARDED_PREFIX']
    end
  end
  
  get '/login' do
    @css_display = "display_none"
    erb :login, layout: :layout
  end
  
  post '/login' do
    user = User.first(email: params[:email])
    
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      if user.system_admin?
        session[:role] = "admin"
      elsif org_admin?
        session[:role] = 'org_admin'
        #@ical_token = ical_token
      end
      
      @current_user = user
      
      debug = <<EOF
      <pre>
      #{@current_user.name}
      #{session[:user_id]}
      </pre>
EOF
      #debug
      
      if user.system_admin?
        redirect to(url('/admin'))
      end
      
      # 組織が1つしかない場合は自動選択
      unique_orgs = user.organizations.uniq { |org| org.id }
      if unique_orgs.count == 1
        session[:organization_id] = unique_orgs.first.id
        redirect to(url('/org/meetings'))
      else
        redirect to(url('/select_organization'))
      end
    else
      @error = 'メールアドレスまたはパスワードが間違っています'
      @css_display = "display_none"
      erb :login, layout: :layout
    end
    
  end
  
  get '/logout' do
    session.clear
    redirect to(url('/login'))
  end
  
end
