require 'forwardable'
require 'command_line_reporter'

module Razor::CLI
  module Format
    extend Forwardable
    PriorityKeys = %w[ id name spec ]
    SpecNames = {
      "/spec/object/policy" => "Policy",
      "/spec/object/tag" => "Tag",
      "/spec/object/reference" => "reference"
    }

    def self.spec_name(spec)
      path = spec && URI.parse(spec).path
      SpecNames[path] || path
    rescue => e
      spec
    end

    def format_document(doc, parse = nil)
      format = parse && parse.format
      arguments = parse && parse.stripped_args
      doc = Razor::CLI::Document.new(doc, format)

      return _("There are no items for this query.") if doc.items.empty?
      return format_command_help(doc, parse.show_api_help?) if parse && parse.show_command_help?

      case (doc.format_view['+layout'] or 'list')
      when 'list'
        format_objects(doc.items) + String(additional_details(doc, parse, arguments)).chomp
      when 'table'
        case doc.items
          when Array then
            get_table(doc.items, doc.format_view) + String(additional_details(doc, parse, arguments))
          else doc.to_s
        end
      else
        raise ArgumentError, _("Unrecognized view format %{format_name}") % {format_name: doc.format_view['+layout']}
      end
    end

    private
    def get_table(doc, formatting)
      # Use the formatting if it exists, otherwise build from the data.
      column_overrides = formatting['+show'] && formatting['+show'].keys
      Razor::CLI::TableFormat.new.run(doc, column_overrides)
    end

    # We assume that all collections are homogenous
    def format_objects(objects, indent = 0)
      objects.map do |obj|
        obj.is_a?(Hash) ? format_object(obj, indent) : ' '*indent + obj.to_s
      end.join "\n\n"
    end

    def format_object(object, indent = 0)
      if object.has_key?('help') and object.has_key?('name')
        object['help']['full']
      else
        format_default_object(object, indent)
      end
    end

    def format_command_help(doc, show_api_help)
      item = doc.items.first
      raise Razor::CLI::Error, _('Could not find help for that entry') unless item.has_key?('help')
      if item['help'].has_key?('examples')
        if show_api_help && item['help']['examples'].has_key?('api')
          format_composed_help(item, item['help']['examples']['api']).chomp
        else
          format_composed_help(item).chomp
        end
      else
        format_full_help(item['help']).chomp
      end
    end

    def positional_args_usage(object)
      object['schema'].map do |k, v|
        [v['position'], k] if v.has_key?('position')
      end.compact.sort.map(&:last).
          map {|attr| "[#{attr.gsub('_', '-')}] " }.join.strip
    end
    def format_composed_help(object, examples = object['help']['examples']['cli'])
      help_obj = object['help']
      ret = ''
      ret = ret + _(<<-USAGE) % {command: object['name'], arguments: positional_args_usage(object)}
# USAGE

  razor %{command} %{arguments} <flags>

      USAGE
      ret = ret + _(<<-SYNOPSIS) % {summary: help_obj['summary']} if help_obj.has_key?('summary')
# SYNOPSIS
%{summary}

      SYNOPSIS
      ret = ret + _(<<-DESCRIPTION) % {description: help_obj['description'], schema: help_obj['schema']} if help_obj.has_key?('description')
# DESCRIPTION
%{description}

%{schema}
      DESCRIPTION
      ret = ret + _(<<-RETURNS) % {returns: help_obj['returns'].gsub(/^/, '  ')} if help_obj.has_key?('returns')
# RETURNS
%{returns}
      RETURNS
      ret = ret + _(<<-EXAMPLES) % {examples: examples.gsub(/^/, '  ')} if examples
# EXAMPLES

%{examples}
      EXAMPLES
      ret
    end

    def format_full_help(object)
      object['full']
    end

    def format_default_object(object, indent = 0 )
      fields = display_fields(object)
      key_indent = indent + fields.map {|f| f.length}.max
      output = ""
      fields.map do |f|
        value = object[f]
        output = "#{f.rjust key_indent + 2}: "
        output << case value
        when Hash
          if value.empty?
            "{}"
          else
            "\n" + format_object(value, key_indent + 4).rstrip
          end
        when Array
          if value.all? { |v| v.is_a?(String) }
            "[" + value.map(&:to_s).join(",") + "]"
          else
            "[\n" + format_objects(value, key_indent + 6) + ("\n"+' '*(key_indent+4)+"]")
          end
        when String
          value
        else
          case f
          when "spec" then "\"#{Format.spec_name(value)}\""
          else value.to_s # Could be `false` or `nil` possibly
          end
        end
      end.join "\n"
    end

    def display_fields(object)
      keys = object.respond_to?(:keys) ? object.keys : []
      (PriorityKeys & keys) + (keys - PriorityKeys) - ['+spec']
    end

    def additional_details(doc, parse, arguments)
      objects = doc.original_items
      if objects.empty? or (parse and not parse.query?)
        ""
      elsif doc.is_list? and objects.all? { |it| it.is_a?(Hash) && it.has_key?('name')}
        # If every element has the 'name' key, it has nested elements.
        _("\n\nQuery an entry by including its name, e.g. `razor %{arguments} %{name}`") % {arguments: arguments.join(' '), name: objects.first['name']}
      elsif objects.any?
        object = objects.first
        fields = display_fields(object) - PriorityKeys
        list = fields.select do |f|
          object[f].is_a?(Hash) or object[f].is_a?(Array)
        end.sort
        if list.any?
          _("\n\nQuery additional details via: `razor %{arguments} [%{options}]`") % {arguments: arguments.join(' '), options: list.join(', ')}
        end
      end
    end
  end
end
