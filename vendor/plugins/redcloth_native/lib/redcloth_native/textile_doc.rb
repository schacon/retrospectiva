require 'action_controller'

class RedCloth
  class TextileDoc < RedCloth

    def to(*args)
      sanitized = HTML::WhiteListSanitizer.new.sanitize(self)
      RedCloth.new(sanitized, [:sanitize_html, :filter_styles, :filter_classes, :filter_ids]).to_html.gsub(/>[\n\t]*</, ">\n<")
    end

    def clean_html( text, allowed_tags = { 'br' => [] })
      super
    end

    
  end
end
