module Razor::CLI
  module Transforms
    module_function
    def identity(any)
      any
    end
    def if_present(obj)
      obj.nil? ? "---" : obj
    end
    def join_names(arr)
      (arr.nil? or arr.empty?) ? '(none)' : arr.map { |item| item['name'] }.join(", ")
    end
    def nested(nested_obj)
      (nested_obj.nil? or nested_obj.empty?) ? '(none)' : nested_obj.to_s
    end
    def shallow_hash(hash)
      (hash.nil? or hash.empty?) ? '(none)' :
          hash.map {|key, val| "#{key}: #{val}"}.join(', ')
    end
    def select_name(item)
      item and item['name'] or "---"
    end
    def mac(mac)
      mac ? mac.gsub(/-/, ":") : "---"
    end
    def name(obj)
      obj ? obj['name'] : "---"
    end
    def name_if_present(obj)
      obj ? obj['name'] : "---"
    end
    def count_column(hash)
      hash['count']
    end
    def count(arr)
      arr.size
    end
    def count_hash(hash)
      hash.is_a?(Hash) ? hash.keys.size : 0
    end
  end
end