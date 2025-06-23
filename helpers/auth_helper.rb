# helpers/auth_helper.rb
module AuthHelper

  def current_user
    @current_user ||= User[session[:user_id]] if session[:user_id]
  end
  
  def logged_in?
    !current_user.nil?
  end

  def require_login
    redirect to(url('/login')) unless logged_in?
  end

  def require_admin!
    redirect to(url('/login')) unless current_user&.system_admin?
  end
  
  def org_admin?
    current_user&.roles_for(current_organization&.id)&.include?('org_admin')
  end
  
  def organizer?
    current_user&.roles_for(current_organization&.id)&.include?('organizer')
  end
  
  def current_organization
    @current_organization ||= Organization[session[:organization_id]] if session[:organization_id]
  end
  
  def require_org_admin!
    halt(403, 'Access denied') unless current_user&.roles_for(current_organization&.id)&.include?('org_admin')
  end
  
  def require_organizer!
    halt(403, 'Access denied') unless current_user&.roles_for(current_organization&.id)&.include?('organizer')
  end
  
  def same_organization?(user)
    user.organizations.map(&:id).include?(current_organization&.id)
  end
  
end