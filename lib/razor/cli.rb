module Razor
  module CLI
    class Error < RuntimeError; end

    class NavigationError < Error
      def initialize(url, key, doc)
        @key = key; @doc = doc
        if key.is_a?(Array)
          super _("Could not navigate to '%{path}' from %{url}") % {path: key.join(" "), url: url}
        else
          super _("Could not find entry '%{key}' in document at %{url}") % {key: key, url: url}
        end
      end
    end

    class InvalidURIError < Error
      def initialize(url, type)
        case type
        when :env
          super _("URL '%{url}' in ENV variable RAZOR_API is not valid") % {url: url}
        when :opts
          super _("URL '%{url}' provided by -u or --url is not valid") % {url: url}
        else
          super _("URL '%{url}' is not valid") % {url: url}
        end
      end
    end

    class InvalidCAFileError < Error
      def initialize(path)
        super _("CA file '%{path}' in ENV variable RAZOR_CA_FILE does not exist") % {path: path}
      end
    end

    class VersionCompatibilityError < Error
      def initialize(reason)
        super _("Server version is not compatible with client version: %{reason}") % {reason: reason}
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