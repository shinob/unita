# routes/meeting.rb
require 'sinatra/base'
require_relative '../models/meeting'
require_relative '../models/participant'
require_relative '../helpers/auth_helper'

class MeetingRoutes < Sinatra::Base
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

  get '/org/meetings' do
    redirect to(url('/login')) unless logged_in?
    halt(403, 'Access denied') unless current_organization
    
    ical_token
    
    cutoff_time = Time.now - (7 * 24 * 60 * 60)
    #@meetings = Meeting.where(organization_id: current_organization.id)
    #                   .where { scheduled_at > cutoff_time }
    #                   .order(:scheduled_at)
    #                   .all
    @meetings = Meeting.where(organization_id: current_organization.id)
                        .enabled
                        .where { scheduled_at > cutoff_time }
                        .order(:scheduled_at)
                        .all

    erb :meetings_list, layout: :layout
  end

  get '/org/meetings/all' do
    redirect to(url('/login')) unless logged_in?
    halt(403, 'Access denied') unless current_organization
    
    ical_token
        
    @meetings = Meeting.where(organization_id: current_organization.id)
      .enabled
      .order(:scheduled_at)
      .all
      
    erb :meetings_list, layout: :layout
  end

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

    user_ids = current_organization.memberships.map(&:user_id).uniq
    user_ids.each do |user_id|
      Participant.find_or_create(meeting_id: meeting.id, user_id: user_id) do |p|
        p.status = 'undecided'
      end
    end

    redirect to(url("/org/meetings/#{meeting.id}"))
  end

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

  get '/org/meetings/:id/edit' do
    require_organizer!
    @meeting = Meeting[params[:id]]
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

  post '/org/meetings/:id/respond' do
    meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless meeting.organization_id == current_organization.id

    participant = Participant.where(meeting_id: meeting.id, user_id: current_user.id).first
    halt(403, 'Access denied') unless participant
    halt(403, 'Only users in the same organization can respond') unless same_organization?(current_user)

    if meeting.deadline_at && Time.now > meeting.deadline_at && !current_user.roles_for(current_organization.id).include?('org_admin')
      halt(403, 'The deadline for responses has passed')
    end

    participant.set(status: params[:status], comment: params[:comment])
    participant.save

    redirect to(url("/org/meetings/#{meeting.id}"))
  end

  get '/org/meetings/:id/respond_admin' do
    require_org_admin!
    @meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless @meeting.organization_id == current_organization.id

    @members = current_organization.memberships.map(&:user)
    @participants = @meeting.participants_dataset.eager(:user).all.select do |p|
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
      participant.set(status: data["status"], comment: data["comment"])
      participant.save
    end

    redirect to(url("/org/meetings/#{@meeting.id}"))
  end
  
  post '/org/meetings/:id/disable' do
    require_organizer!
    meeting = Meeting[params[:id]]
    halt(403, 'Access denied') unless meeting.organization_id == current_organization.id
    meeting.update(disabled: true)
    redirect to(url('/org/meetings'))
  end
  
end
