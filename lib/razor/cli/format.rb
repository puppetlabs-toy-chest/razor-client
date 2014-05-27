require 'forwardable'
require 'terminal-table'

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
      format = parse.format
      arguments = parse.args
      doc = Razor::CLI::Document.new(doc, format)

      return "There are no items for this query." if doc.items.empty?
      return format_objects(doc.items).chomp if parse.show_command_help?

      case (doc.format_view['+layout'] or 'list')
      when 'list'
        format_objects(doc.items) + String(additional_details(doc, arguments)).chomp
      when 'table'
        case doc.items
          when Array then
            get_table(doc.items, doc.format_view) + String(additional_details(doc, arguments))
          else doc.to_s
        end
      else
        raise ArgumentError, "Unrecognized view format #{doc.format_view['+layout']}"
      end
    end

    private
    def get_table(doc, formatting)
      # Use the formatting if it exists, otherwise build from the data.
      headings = (formatting['+show'] and formatting['+show'].keys or [])
      Terminal::Table.new do |t|
        t.rows = doc.map do |page|
          page.map do |item|
            headings << item[0] unless headings.include? item[0]
            item[1]
          end
        end
        t.headings = headings
      end.to_s
    end

    # We assume that all collections are homogenous
    def format_objects(objects, indent = 0)
      objects.map do |obj|
        obj.is_a?(Hash) ? format_object(obj, indent) : ' '*indent + obj.inspect
      end.join "\n\n"
    end

    def format_object(object, indent = 0)
      if object.has_key?('help') and object.has_key?('name')
        object['help']['full']
      else
        format_default_object(object, indent)
      end
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
          else value.inspect
          end
        end
      end.join "\n"
    end

    def display_fields(object)
      (PriorityKeys & object.keys) + (object.keys - PriorityKeys) - ['+spec']
    end

    def additional_details(doc, arguments)
      objects = doc.original_items
      # If every element has the 'name' key, it has nested elements.
      if doc.is_list? and objects.all? { |it| it.is_a?(Hash) && it.has_key?('name')}
        "\n\nQuery an entry by including its name, e.g. `razor #{arguments.join(' ')} #{objects.first['name']}`"
      elsif objects.any?
        object = objects.first
        fields = display_fields(object) - PriorityKeys
        list = fields.map do |f|
          case object[f]
            when Hash, Array
              f
          end
        end.compact.sort
        if list.any?
          "\n\nQuery additional details via: `razor #{arguments.join(' ')} [#{list.join(', ')}]`"
        end
      end
    end
  end
end
