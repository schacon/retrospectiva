require 'md5'

module ApplicationHelper
  include FormatHelper
  include FlashHelper
  include NavigationHelper
  include PlusForms::Helper
  
  def error_messages_for(*args)
    options = args.extract_options!.reverse_merge(:object_name => _("(#{args.first}_record)"))
    super(*(args << options))
  end

  def page_title(title = nil, options = {})
    title ||= @page_title
    title = escape_once(title) unless options[:escape] == false
    content_tag('div', title, :class => 'page-title')  
  end

  def content_styles(*args)    
    [args].flatten.each do |style_class|
      content_style(style_class)
    end
    layout_markers[:content_styles]
  end
  
  def content_style(style_class)    
    layout_markers[:content_styles] << " #{style_class}"
  end
  
  def slim_page
    content_style('slim')
  end
  
  def image_spacer(options = {})    
    image_tag 'clear.gif', options.reverse_merge(:size => '1x1', :alt => '')
  end

  def info_image(options = {})
    image_tag 'info.gif', options.reverse_merge(:class => 'help', :alt => _('Info'))
  end

  def _(*args)
    escape_once(super)
  end

  def view_extensions(*keys)
    view_extension_parts(*keys).join("\n")
  end

  def view_extension_parts(*keys)
    options = keys.extract_options!
    RetroEM::Views.extensions(*keys).map do |path|
      render(options.merge(:partial => path)).strip
    end.reject(&:blank?)
  end

  def content_header(class_names = '', &block)
    content = capture(&block)
    class_names = h(" #{class_names}") unless class_names.blank?
    concat "<div class=\"content-header#{class_names}\">#{content}</div>"
  end

  def content_footer(class_names = '', &block)
    content = capture(&block)
    class_names = h(" #{class_names}") unless class_names.blank?
    concat "<div class=\"content-footer#{class_names}\">#{content}</div>"
  end

  def site_name
    RetroCM[:general][:basic][:site_name].to_s
  end

  def author_gravatar(user, author, options = {})
    email = options.delete(:email) || "#{author}@#{request.host}"
    if user
      user_gravatar(user, options)
    else
      gravatar email, options.reverse_merge(:title => h(author), :alt => h(author))
    end
  end  

  def user_gravatar(user, options = {})
    gravatar user.email, options.reverse_merge(:title => h(user.name), :alt => h(user.name))
  end  

  def truncated_author(object, author_method = :author, email_method = :email)
    author, email = object.send(author_method), object.send(email_method)     
    value = h(truncate(author, :length => 20))
    email.blank? ? value : mail_to(email, value, :title => h(author), :encode => :enkoder)
  end
  
  def will_paginate_per_page(collection, options = {})
    label = options[:label] || _('Display') + ':'
    choices = options[:choices] || [10, 30, 100]
    
    links = ["<span class=\"intro\">#{label}</span>"] + choices.sort.uniq.map do |choice|
      path = url_for(params.except(:controller, :action, :format).merge(:project_id => Project.current.to_param, :per_page => choice, :only_path => true))
      link_to_unless(collection.per_page == choice, choice.to_s, path) do |current|
        "<span class=\"current\">#{current}</span>"
      end
    end
    content_tag :div, links.join(' '), :class => 'pagination'
  end
  
  def search_field_tag(name = :term, value = nil, options = {})    
    text_field_tag name, ( value || params[name] ), options.merge(:autocomplete => 'off')
  end


  def retro_in_place_editor(field_id, options = {})
    function =  "new Ajax.RetroInPlaceEditor("
    function << "'#{field_id}', "
    function << url_for(options[:url]).to_json

    callback = "Form.serialize(form)"
    if protect_against_forgery?
      callback += " + '&authenticity_token=' + encodeURIComponent('#{form_authenticity_token}')"
    end
    
    js_options = options.only(:rows, :cols, :size).stringify_keys.merge(
      'callback' => "function(form) { return #{callback} }",
      'okText' => _('Save').to_json,
      'cancelText' => _('Cancel').to_json,
      'loadingText' => _('Loading...').to_json,
      'savingText' => _('Saving...').to_json,
      'externalControl' => "#{field_id}-in-place-editor-external-control".to_json
    )
    if options[:text]
      js_options['text'] = options[:text].to_s.to_json 
    end
    function << (', ' + options_for_javascript(js_options))    
    function << ')'

    javascript_tag(function)
  end

  def toggle_pagination(page, term = params[:term])
    page << "$$('.pagination').each(function(el) { el.#{term.blank? ? 'show' : 'hide'}() });"    
  end

  # Modification of the built-in encryption 
  # Uses modified version of the hivelogic enkoder (original Copyright (c) 2006, Automatic Corp.)
  def mail_to(email_address, name = nil, html_options = {})
    html_options.symbolize_keys!
    if html_options[:encode] == :enkoder
      html_options.delete(:encode)
      enkode(super)
    else
      super
    end
  end

  protected
    
    def enkode(text)
      result = ''
      "document.write('#{escape_javascript(text.dup)}');".each_byte do |c|
        result << sprintf("%%%x", c)
      end
      result = "eval(decodeURIComponent('#{result}'))"
  
      logic  = random_enkode_logic     
      result = logic[:rb].call(result)
      result = "kode='#{escape_javascript(result)}';#{logic[:js]}"
      result = "function hl_enkoder(){var kode='#{h(escape_javascript(result))}'.unescapeHTML();var i,c,x;while(eval(kode));};hl_enkoder();"
      javascript_tag result      
    end

    def gravatar(email, options = {})
      size = options.delete(:size) || 40
      options.reverse_merge!(:class => 'frame')
      image_tag "http://www.gravatar.com/avatar/#{MD5::md5(email)}.png?s=#{size}", options
    end

  private
    
    def token_tag
      protect_against_forgery? ? enkode(super) : ''
    end  
  
    def random_enkode_logic
      kodes = [{
        :rb => lambda {|s| s.reverse },
        :js => "kode=kode.split('').reverse().join('')"
      }, {
        :rb => lambda {|s|
          result = ''
          s.each_byte { |b|
            b += 3
            b -= 128 if b > 127
            result << b.chr
          }
          result
        },
        :js => (
           "x='';for(i=0;i<kode.length;i++){c=kode.charCodeAt(i)-3;" +
           "if(c<0)c+=128;x+=String.fromCharCode(c)}kode=x"
        )
      }, {
        :rb => lambda {|s|
          for i in (0..s.length/2-1)
            s[i*2],s[i*2+1] = s[i*2+1],s[i*2]
          end
          s
        },
        :js => (
           "x='';for(i=0;i<(kode.length-1);i+=2){" +
           "x+=kode.charAt(i+1)+kode.charAt(i)};" +
           "kode=x+(i<kode.length?kode.charAt(kode.length-1):'');"
         )
      }]
      kodes[rand(kodes.size)]      
    end
  
end

