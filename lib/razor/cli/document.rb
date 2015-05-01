require 'forwardable'

module Razor::CLI
  class HideColumnError < RuntimeError; end
  class Document
      extend Forwardable
    attr_reader 'spec', 'items', 'format_view', 'original_items'
    def initialize(doc, format_type)
      if doc['spec'].is_a?(Array)
        @spec, @remaining_navigation = doc['spec']
      else
        @spec = doc['spec']
      end
      @command = doc['command']
      if doc.has_key?('items')
        @type = :list
      else
        @type = :single
      end
      @items = doc['items'] || Array[doc]
      @format_view = Razor::CLI::Views.find_formatting(@spec, format_type, @remaining_navigation)

      # Untransformed and unordered for displaying nested views.
      @original_items = @items
      @items = hide_or_transform_elements!(items, format_view)
    end

    def is_list?
      @type == :list
    end

    private
    # This method:
    # - rearranges columns per Razor::CLI::Views.
    # - hides columns per Razor::CLI::Views.
    # - transforms data using both Razor::CLI::Views and its `TRANSFORMS`.
    def hide_or_transform_elements!(items, format_view)
      if format_view.has_key?('+show')
        items.map do |item|
          Hash[
            format_view['+show'].map do |item_format_spec|
              # Allow both '+column' as overrides.
              item_spec = (item_format_spec[1] or {})
              item_label = item_format_spec[0]
              begin
                value = if item_spec.has_key?('+all-columns')
                          Razor::CLI::Views.transform(item, item_spec['+format'])
                        else
                          item_column = (item_spec['+column'] or item_label)
                          Razor::CLI::Views.transform(item[item_column], item_spec['+format'])
                        end
                [item_label, value]
              rescue Razor::CLI::HideColumnError
                nil
              end
            end.reject {|k| k.nil? }
          ].tap do |hash|
            # Re-add the special 'command' key and value if the key isn't already there.
            hash['command'] = @command if @command and not hash.has_key?('command')
          end
        end
      else
        items
      end
    end
  end
end