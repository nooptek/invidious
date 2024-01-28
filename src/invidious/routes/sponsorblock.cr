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

    result = nil
    begin
      make_client(CONFIG.sponsorblock_url) do |client|
        client.connect_timeout = 1.seconds
        client.read_timeout = 3.seconds
        result = client.get(query)
      end
    rescue
    end

    if result.nil?
      haltf env, 500
    elsif result.status_code < 200
      # 1xx
      haltf env, 500
    elsif result.status_code < 300
      # 2xx ok, continue
    elsif result.status_code < 400
      # 3xx
      haltf env, 500
    else
      # >= 4xx
      haltf env, result.status_code
    end

    begin
      segments = JSON.parse(result.body)
      segments.as_a.each do |vid|
        if vid["videoID"] == id
          return vid["segments"].to_json
        end
      end
      haltf env, 404
    rescue
      haltf env, 500
    end
  end
end
