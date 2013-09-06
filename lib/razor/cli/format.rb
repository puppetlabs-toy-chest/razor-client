require 'terminal-table'

module Razor::CLI
  module Format
    PriorityKeys = %w[ id name ]
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

    def format_document(doc)
      case doc
      when Array then format_objects(doc)
      when Hash then format_object(doc)
      else doc.to_s
      end.chomp
    end

    # We assume that all collections are homogenous
    def format_objects(objects, indent = 0)
      objects.map do |obj|
        obj.is_a?(Hash) ? format_object(obj, indent) : ' '*indent + obj.inspect
      end.join "\n\n"
    end

    def format_reference_object(ref, indent = 0)
      output = ' '* indent + "#{ref['name']} => #{ref['id'].to_s.ljust 4}"
    end


    def format_object(object, indent = 0)
      if object.keys == ["id", "name"]
        format_reference_object(object, indent)
      else
        format_default_object(object, indent)
      end
    end

    def format_default_object(object, indent = 0 )
      fields = (PriorityKeys & object.keys) + (object.keys - PriorityKeys)
      key_indent = indent + fields.map {|f| f.length}.max
      output = ""
      fields.map do |f|
        value = object[f]
        output = "#{f.rjust key_indent + 2}: "
        output << case value
        when Hash
          "\n" + format_object(value, key_indent + 4).rstrip
        when Array
           if value.all? { |v| v.is_a?(String) }
             "[" + value.map(&:inspect).join(",") + "]"
           else
             "[\n" + format_objects(value, key_indent + 6) + ("\n"+' '*(key_indent+4)+"]")
           end
        else
          case f
          when "spec" then "\"#{Format.spec_name(value)}\""
          else value.inspect
          end
        end
      end.join "\n"
    end
  end
end
