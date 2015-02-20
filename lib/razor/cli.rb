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

    class InvalidURIError < Error
      def initialize(url, type)
        case type
        when :env
          super "URL '#{url}' in ENV variable RAZOR_API is not valid"
        when :opts
          super "URL '#{url}' provided by -u or --url is not valid"
        else
          super "URL '#{url}' is not valid"
        end
      end
    end

    class InvalidCAFileError < Error
      def initialize(path)
        super "CA file '#{path}' in ENV variable RAZOR_CA_FILE does not exist"
      end
    end

    class VersionCompatibilityError < Error
      def initialize(reason)
        super "Server version is not compatible with client version: #{reason}"
      end
    end

  end
end

require_relative 'cli/version'
require_relative 'cli/navigate'
require_relative 'cli/parse'
require_relative 'cli/format'
require_relative 'cli/table_format'
require_relative 'cli/document'
require_relative 'cli/views'
require_relative 'cli/transforms'
require_relative 'cli/query'
require_relative 'cli/command'