module Razor
  module CLI
    class Error < RuntimeError; end

    class NavigationError < Error
      def initialize(url, key, doc)
        @key = key; @doc = doc
        if key.is_a?(Array)
          super "Could not navigate to '#{key.join(" ")}' from #{url}"
        else
          super "Could not find entry '#{key}' in document at #{url}"
        end
      end
    end
    
    class RazorApiUrlError < Error
      def initialize(type, url)
        case type
        when "ENV"          
          super "Api Url '#{url}' in ENV variable RAZOR_API_URL is not valid"
        when "-U"
          super "Api Url '#{url}' provided by -U or --url is not valid"
        else
          super "Api Url '#{url}' is not valid"            
        end
      end
    end
    
  end
end

require_relative 'cli/navigate'
require_relative 'cli/parse'
require_relative 'cli/format'
