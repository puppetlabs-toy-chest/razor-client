class Razor::CLI::Query
  def initialize(parse, navigate, collections, segments)
    @parse = parse
    @navigate = navigate
    @collections = collections
    @segments = segments
    @stripped_segments = []
    @options = {}
  end

  def stripped_segments
    @stripped_segments.join
  end

  def get_optparse(doc, nav)
    # If the last document is an Array, we need to find
    # which element matches the given query. Once found,
    # return the 'params' section, if it has one.
    if doc.is_a?(Array)
      query = doc.find {|coll| coll['name'] == nav}
      params = (query && query['params']) || {}
    elsif doc.is_a?(Hash)
      params = (doc[nav].is_a?(Hash) && doc[nav].has_key?('params') &&
          doc[nav]['params'].is_a?(Hash) && doc[nav]['params']) || {}
    end
    @queryoptparse = OptionParser.new do |opts|
      opts.on "-f", "--full", "Show full details when viewing entities" do
        @parse.format = 'full'
      end

      opts.on "-s", "--short", "Show shortened details when viewing entities" do
        @parse.format = 'short'
      end

      params.each do |param, args|
        if args['type'] == 'boolean'
          opts.on "--#{param}" do
            @options[param] = true
          end
        else
          opts.on "--#{param} VALUE" do |value|
            @options[param] = value
          end
        end
      end
    end
  end

  def run
    @doc = @collections
    while @segments.any?
      nav = @segments.shift
      @parse.stripped_args << nav
      @segments = get_optparse(@doc, nav).order(@segments)
      @doc = @navigate.move_to nav, @doc, @options
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