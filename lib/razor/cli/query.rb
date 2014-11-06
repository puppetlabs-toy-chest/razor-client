class Razor::CLI::Query
  def initialize(parse, navigate, collections, segments)
    @parse = parse
    @navigate = navigate
    @collections = collections
    @segments = segments
  end

  def get_optparse
    @queryoptparse ||= OptionParser.new do |opts|
    end
  end

  def options
    {}.delete_if{|_, v| v.nil?}
  end

  def run
    @doc = @collections
    while @segments.any?
      nav = @segments.shift
      @segments = get_optparse.order(@segments)
      @doc = @navigate.move_to nav, @doc, options
    end

    # Get the next level if it's a list of objects.
    if @doc.is_a?(Hash) and @doc['items'].is_a?(Array)
      # Cache doc_resource since these queries are just for extra detail.
      temp_doc_resource = @navigate.doc_resource
      @doc['items'] = @doc['items'].map do |item|
        item.is_a?(Hash) && item.has_key?('id') ? @navigate.json_get(URI.parse(item['id'])) : item
      end
      @navigate.doc_resource = temp_doc_resource
    end
    @doc
  end
end