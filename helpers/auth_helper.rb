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
  
  def user?
    if logged_in?
      !current_user&.system_admin? && !org_admin? && !organizer?
    else
      false
    end
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
  
  def status?(meeting_id)
    participant = Participant.where(meeting_id: meeting_id, user_id: current_user.id).first
    unless participant
      "undecided"
    else
      participant.status
    end
  end
  
  def role_label(role)
    case role
    when 'org_admin' then '管理者'
    when 'organizer' then '運営者'
    else '参加者'
    end
  end
  
  def ical_token
    unless current_organization.ical_token
      current_organization.ical_token = SecureRandom.hex(16)
      current_organization.save
    end
    current_organization.ical_token
  end

