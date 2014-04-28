module Razor::CLI
  module Views
    module_function
    def views
      @views ||= YAML::load_file(File::join(File::dirname(__FILE__), "views.yaml"))
    end

    def transform(item, transform_name)
      Razor::CLI::Transforms.send(transform_name || 'identity', item)
    end

    def find_formatting(spec, format)
      # Scope will narrow by traversing the spec.
      scope = views
      spec = spec ? spec.split('/').drop_while { |i| i != 'collections'} : []
      while spec.any?
        val = spec.shift
        scope = (scope[val] or {})
      end
      scope["+#{format}"] or {}
    end
  end
end
