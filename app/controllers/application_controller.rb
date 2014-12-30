# Used to compare old browsers using useragent gem.
# see reject_old_browsers method
BrowserSpecificiation = Struct.new(:browser, :version)

class ApplicationController < ActionController::Base

  # Run authorization on all actions
  # check_authorization
  protect_from_forgery

  # What to do if authorization fails
  rescue_from CanCan::AccessDenied do |exception|
    redirect_to user_omniauth_authorize_path(Concord::AuthPortal.default.strategy_name), :alert => exception.message
  end
  before_filter :reject_old_browsers, :except => [:bad_browser]

  before_filter :set_locale

  # Try to set local from the request headers
  def set_locale
    logger.debug "* Accept-Language: #{request.env['HTTP_ACCEPT_LANGUAGE']}"
    I18n.locale = extract_locale_from_accept_language_header
    logger.debug "* Locale set to '#{I18n.locale}'"
  end
  private
  def extract_locale_from_accept_language_header
    lang_header = request.env['HTTP_ACCEPT_LANGUAGE']
    return "en" unless lang_header
    return lang_header.scan(/^[a-z]{2}/).first
  end
  public

  def test_mail
    recipient = "authoring-help@concord.org"
    MailTest.test(recipient, request).deliver
    flash[:notice]= "A test message has been sent to #{recipient}"
    redirect_to "/"
  end

  def test_error
    MailTest.test_error(request)
  end

  ### Log some data for 404s
  # This should be temporary, as debugging for an issue where links to an activity return 404 errors for
  # some people but not others.
  # See https://www.pivotaltracker.com/story/show/52313089
  # Turned off 21Oct2013 - pjm
  # rescue_from ActiveRecord::RecordNotFound, :with => :not_found
  #
  # def not_found(exception)
  #   ExceptionNotifier.notify_exception(exception,
  #     :env => request.env, :data => {:message => "raised a Not Found exception"})
  #   redirect_to root_url, :alert => exception.message
  # end

  # For modal edit windows. Source: https://gist.github.com/1456815
  layout Proc.new { |controller| controller.request.xhr? ? nil : 'application' }

  def update_activity_changed_by(activity=@activity)
    activity.changed_by = current_user
    begin
      activity.save
    rescue
      # We don't want to return a server error if this update fails; it's not important
      # enough to derail the user.
      logger.debug "changed_by update for Activity #{@activity.id} failed."
    end
  end

  def current_theme
    # Assigns @theme
    # This counts on @activity and/or @sequence being already assigned.
    if defined?(@sequence) && @sequence.theme
      @theme = @sequence.theme
    elsif defined?(@activity) && @activity.theme
      @theme = @activity.theme
    elsif defined?(@project) && @project.theme
      @theme = @project.theme
    else
      @theme = Theme.default
    end
    @theme
  end

  def current_project
    # Assigns @project
    # This counts on @activity and/or @sequence being already assigned.
    if defined?(@sequence) && @sequence.project
      # Sequence project overrides activity and default
      @project = @sequence.project
    elsif defined?(@activity) && @activity.project
      # Activity project overrides default
      @project = @activity.project
    else
      @project = Project.default
    end
    @project
  end

  def set_sequence
    # First, respect the sequence ID in the request params if one is provided
    if params[:sequence_id]
      @sequence = Sequence.find(params[:sequence_id])
      # Save this in the run
      if @sequence && @run
        @run.sequence = @sequence
        @run.save
      end
    # Second, if there's no sequence ID in the request params, there's an existing
    # run, and a sequence is set for that run, use that sequence
    elsif @run && @run.sequence
      @sequence ||= @run.sequence
    end
    @sequence
  end

  protected

  def update_portal_session(domain)
    sign_out(current_user)

    # the sign out creates a new session, so we need to set this after
    # signout. This way when we are called back this session info will be available
    session[:did_reauthenticate] = true

    # we set the origin here which will become request.env['omniauth.origin']
    # in the callback phase, by default omniauth will use use
    # the referer and that is not changed during redirects. More info:
    # https://github.com/intridea/omniauth/wiki/Saving-User-Location
    redirect_to user_omniauth_authorize_path(Concord::AuthPortal.strategy_name_for_url(domain), :origin => request.url)
  end

  def clear_session_response_key
    session.delete(:response_key)
  end

  def session_response_key(new_val=nil?)
    return nil unless current_user.nil?
    session[:response_key] ||= {}
    # If there is a response key in the session which doesn't match up to a
    # current run, return nil (as though there's no session key)
    if Run.for_key(session[:response_key][@activity.id], @activity).nil?
      return nil
    end
    session[:response_key][@activity.id] = new_val if new_val
    session[:response_key][@activity.id]
  end

  def set_response_key(key)
    @session_key = key
    session_response_key(@session_key)
  end

  def update_response_key
    set_response_key(params[:response_key] || session_response_key)
  end

  def set_run_key
    update_response_key

    if params[:domain] && !session.delete(:did_reauthenticate)
      update_portal_session(params[:domain]) and return
    end

    # Special case when collaborators_data_url is provided (usually as a GET param).
    # New collaboration will be created and setup and call finally returns collaboration owner
    if params[:collaborators_data_url] && params[:domain]
      cc = CreateCollaboration.new(params[:collaborators_data_url], params[:domain], current_user, @activity)
      @run = cc.call
    else
      portal = RemotePortal.new(params)
      # This creates a new key if one didn't exist before
      @run = Run.lookup(@session_key, @activity, current_user, portal, params[:sequence_id])
      # If activity is ran with "portal" params, it means that user wants to run it individually.
      # Note that "portal" refers to individual student data endpoint, this name should be updated.
      @run.disable_collaboration if portal.valid?
    end

    @sequence_run = @run.sequence_run if @run.sequence_run
    # This is redundant but necessary if the first pass through set_response_key returned nil
    set_response_key(@run.key)
  end
  
  # login to the portal provided in the parameters
  def portal_login
    if params[:domain] && !session.delete(:did_reauthenticate)
      update_portal_session(params[:domain]) and return
    end
  end 

  # override devise's built in method so we can go back to the path
  # from which authentication was initiated
  def after_sign_in_path_for(resource)
    clear_session_response_key
    request.env['omniauth.origin'] || stored_location_for(resource) || signed_in_root_path(resource)
  end
  
  
  def after_sign_out_path_for(resource)
    if params[:re_login] && params[:user_provider]
      provider = params[:user_provider]
      provider_id = provider.clone
      provider_id.slice! "cc_portal_"
      provider_id = provider_id.upcase
      redirect_url = "#{request.protocol}#{request.host_with_port}"
      params_hash = {
        :re_login => true,
        :redirect_uri => redirect_url,
        :provider => provider
      }  
    end
    params[:re_login] && params[:user_provider] ? "#{Concord::AuthPortal.url_for_portal(provider_id)}users/sign_out?#{params_hash.to_query}" : root_path 
  end

  def respond_with_edit_form
    respond_to do |format|
      format.js { render :json => { :html => render_to_string('edit')}, :content_type => 'text/json' }
      format.html
    end
  end

  def respond_with_nothing
    # This is useful for AJAX actions, because it returns a 200 status code but doesn't bother generating an actual response.
    respond_to do |format|
      format.js { render :nothing => true }
      format.html { render :nothing => true }
    end
  end

  def simple_update(subject)
    respond_to do |format|
      if subject.update_attributes(params[subject.class.to_s.downcase.to_sym]) # Surely there's a simpler way?
        format.html { redirect_to edit_polymorphic_url(subject), notice: "#{subject.class.to_s} was successfully updated." }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: subject.errors, status: :unprocessable_entity }
      end
    end
  end

  def reject_old_browsers
    user_agent = UserAgent.parse(request.user_agent)
    min_browser = BrowserSpecificiation.new("Internet Explorer", "9.0")
    if user_agent < min_browser
      @wide_content_layout = true
      @user_agent = user_agent
      redirect_to '/home/bad_browser'
    end
  end
end
