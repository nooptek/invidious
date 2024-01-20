{% skip_file if flag?(:api_only) %}

require "digest/sha256"

module Invidious::Routes::SponsorBlock
  def self.get(env)
    env.response.content_type = "application/json"

    id = env.params.url["id"]

    hash = Digest::SHA256.new
    hash << id
    hash = hash.final[0..1].hexstring

    query = {
      "category" => SB_CATEGORIES.to_a
    }
    query = URI::Params.encode(query)
    query = "/api/skipSegments/#{hash}?#{query}"

    chan = ::Channel(Int32 | JSON::Any).new

    CONFIG.sponsorblock_urls.each do |url|
      spawn do
        result = nil
        begin
          make_client(url) do |client|
            client.connect_timeout = 1.seconds
            client.read_timeout = 3.seconds
            result = client.get(query)
          end
        rescue
        end

        ret = 500
        if result.nil?
          # error
        elsif result.status_code < 200
          # 1xx
        elsif result.status_code < 300
          # 2xx ok, continue
          begin
            segments = JSON.parse(result.body)
            segments.as_a.each do |vid|
              if vid["videoID"] == id
                ret = vid["segments"]
              end
            end
            raise "not found"
          rescue
          else
            ret = 404
          end
        elsif result.status_code < 400
          # 3xx
        else
          # >= 4xx
          ret = result.status_code
        end

        chan.send ret
      end
    end

    ret = 500
    CONFIG.sponsorblock_urls.size.times do
      ret = chan.receive
      case ret
      in Int32
      in JSON::Any then return ret.to_json
      end
    end

    haltf env, ret
  end
end
