class ApplicationController < ActionController::Base
  protect_from_forgery
  filter_parameter_logging :password
  
  before_filter :authenticate
  before_filter :set_locale
  before_filter :set_time_zone
  after_filter  :reset_request_cache!

  delegate :permitted?, :to => :'User.current'
  protected :permitted?
  
  helper_method :layout_markers, :permitted?

  def self.enable_private_rss!(options = {})
    pos = before_filters.index(:authorize) || before_filters.size
    filter_chain.send :update_filter_chain, options, :before, pos do |controller|
    
      if controller.request.format.rss? and controller.params[:private].present? and User.current.public?
        user = User.active.find_by_private_key controller.params[:private]      
        User.current = user if user            
      end
      true
    
    end
  end

  protected
    
    def reset_request_cache!
      User.current = nil
      Project.current = nil
    end

    # Set locale
    def set_locale
      I18n.locale = RetroCM[:general][:basic][:locale]    
    end

    def set_time_zone
      Time.zone = User.current.time_zone
    end

    def cached_user_attribute(name, fallback = '')
      if User.current.public?
        cookie_cache[name.to_s] ||  fallback
      else
        User.current.send(name)
      end
    end

    def cache_user_attributes!(attributes)
      value = cookie_cache.merge(attributes.stringify_keys)
      cookies["retrospectiva__c"] = { 'value' => value.to_yaml, 'expires' => 6.months.from_now }
    end
    
    def cookie_cache
      value = YAML.load(CGI::unescape(cookies["retrospectiva__c"].to_s)) rescue nil
      value.is_a?(Hash) ? value : {}      
    end

    def load_channels(restriction = :present?, project = Project.current)
      Retrospectiva::Previewable.klasses.select(&restriction).group_by do |klass|
        channel = klass.previewable.channel(:project => project)
        User.current.has_access?(channel.path) ? channel : nil
      end.delete_if {|k, | k.nil? }
    end

    # Override ActionController::Base method to prevent invalid format calls (causes 500 error)
    # 
    # Previously: /ticket/123.xml => 500
    # Override:   /ticket/123.xml => 406
    def default_render
      response.content_type.blank? ? respond_to(:html) : super 
    end

    def rescue_action_in_public(exception) #:doc:
      status_code = response_code_for_rescue(exception)
      case status_code
      when :internal_server_error
        ExceptionNotifier.deliver_exception_notification(exception, self, request, {})
      end
      render_optional_error_file(status_code)    
    end

  private  

    def layout_markers
      @layout_markers ||= {
        :header => RetroCM[:content][:custom][:header].to_s,
        :footer => RetroCM[:content][:custom][:footer].to_s,
        :content_styles => ''
      }
    end

    def render_optional_error_file(status_code)
      status = interpret_status(status_code)
      path = "#{RAILS_ROOT}/app/views/rescue/#{status[0,3]}.html.erb"
      if File.exist?(path) and request.format.html?
        render :file => path, :layout => 'application', :status => status
      else
        head status
      end
    end
    
end
