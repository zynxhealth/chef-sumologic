require 'net/https'
require 'json'
require 'zlib'

class Sumologic
  class ApiError < RuntimeError; end

  def self.collector_exists?(node_name, id, key, api_timeout = nil)
    collector = Sumologic::Collector.new(
      name: node_name,
      api_id: id,
      api_key: key,
      api_timeout: api_timeout
    )
    collector.exist?
  end

  class Collector
    attr_reader :name, :api_id, :api_key, :api_timeout

    def initialize(opts = {})
      @name = opts[:name]
      @api_id = opts[:api_id]
      @api_key = opts[:api_key]
      @api_timeout = opts[:api_timeout] || 60
      @api = false
    end

    def api_endpoint
      'https://api.sumologic.com/api/v1'
    end

    def sources
      @sources ||= fetch_source_data
    end

    def metadata
      collectors['collectors'].find { |c| c['name'] == name }
    end

    def exist?
      !!metadata
    end

    def api_request(options = {})
      response = nil
      parse_json = options.key?(:parse_json) ? options[:parse_json] : true
      if !api_timeout.nil?
        response = api_request_timeout(options)
      else
        response = api_request_http_call(options)
      end

      if parse_json
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError => e
          Chef::Log.warn('Sumlogic sent something that does not appear to be JSON, here it is...')
          Chef::Log.warn("status code: #{response.code}")
          Chef::Log.warn(response.body)
          raise e
        end
      else
        response
      end
    end

    def file_sources()
      sources = {}
      sources = { "sources" => [] }
      Dir.glob("/etc/sumo.json/*json") do |file|
        source = File.read(file)
        source_data = JSON.parse(source)
        sources['sources'] <<  source_data['source']
      end
      sources
    end

    def refresh!
      @collectors ||= list_collectors
      @sources = fetch_source_data
      nil
    end

    def list_collectors
      if @api
        uri = URI.parse(api_endpoint + '/collectors')
        request = Net::HTTP::Get.new(uri.request_uri)
        api_request(uri: uri, request: request)
      else
        local_collector = { "collectors" => [ { "id" => "1", "name" => "local" } ] }
      end
    end

    def collectors
      @collectors ||= list_collectors
    end

    def id
      metadata['id']
    end

    def fetch_source_data
      if @api
        u = URI.parse(api_endpoint + "/collectors/#{id}/sources")
        request = Net::HTTP::Get.new(u.request_uri)
        details = api_request(uri: u, request: request)
      else
        details = file_sources()
      end
      details['sources']
    end

    def source_exist?(source_name)
      sources.any? { |c| c['name'] == source_name }
    end

    def source(source_name)
      sources.find { |c| c['name'] == source_name }
    end

    def add_source!(source_data)
      if @api
        u = URI.parse(api_endpoint + "/collectors/#{id}/sources")
        request = Net::HTTP::Post.new(u.request_uri)
        request.body = JSON.dump({ source: source_data })
        request.content_type = 'application/json'
        response = api_request(uri: u, request: request, parse_json: false)
        response
      else
        source_data['id'] = Zlib::crc32(source_data[:name])
        data = { "api.version" => "v1", "source" => source_data }
        File.open("/etc/sumo.json/#{source_data[:name]}.json", "w") do |f|
          f.write(JSON.pretty_generate(data))
        end
      end
    end

    def delete_source!(source_id)
      if @api
      u = URI.parse(api_endpoint + "/collectors/#{source_id}")
      request = Net::HTTP::Delete.new(u.request_uri)
      response = api_request(uri: u, request: request, parse_json: false)
      response
      else
        source = @sources.find { |c| c['id'] == source_id }
        File.delete("/etc/sumo.json/#{source['name']}.json")
      end
    end

    def update_source!(source_id, source_data)
      if @api
        u = URI.parse("https://api.sumologic.com/api/v1/collectors/#{id}/sources/#{source_id}")
        request = Net::HTTP::Put.new(u.request_uri)
        request.body = JSON.dump({ source: source_data.merge(id: source_id) })
        request.content_type = 'application/json'
        request['If-Match'] = get_etag(source_id)
        response = api_request(uri: u, request: request, parse_json: false)
        response
      else
        source_data['id'] = Zlib::crc32(source_data[:name])
        data = { "api.version" => "v1", "source" => source_data }
        File.open("/etc/sumo.json/#{source_data[:name]}.json", "w") do |f|
          f.write(JSON.pretty_generate(data))
        end

      end
    end

    def get_etag(source_id)
      u = URI.parse("https://api.sumologic.com/api/v1/collectors/#{id}/sources/#{source_id}")
      request = Net::HTTP::Get.new(u.request_uri)
      response = api_request(uri: u, request: request, parse_json: false)
      response['etag']
    end

    private

    def api_request_http_call(options = {})
      uri = options[:uri]
      request = options[:request]
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request.basic_auth(api_id, api_key)
      response = http.request(request)
      raise ApiError, "Unable to get source list #{response.inspect}" unless response.is_a?(Net::HTTPSuccess)
      response
    end

    def api_request_timeout(options = {})
      response = nil
      Timeout.timeout(options[:api_timeout]) do
        sleep_to = 0
        begin
          response = api_request_http_call(options)
        rescue Errno::ETIMEDOUT
          Chef::Log.warn("Sumologic api timedout... retrying in #{sleep_to}s")
          sleep sleep_to
          sleep_to += 10
          retry
        end
      end
      response
    end
  end
end
