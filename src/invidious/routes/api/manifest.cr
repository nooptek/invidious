module Invidious::Routes::API::Manifest
  # /api/manifest/dash/id/:id
  def self.get_dash_video_id(env)
    env.response.headers.add("Access-Control-Allow-Origin", "*")
    env.response.content_type = "application/dash+xml"

    local = env.params.query["local"]?.try { |q| (q == "true" || q == "1") } || false
    id = env.params.url["id"]
    region = env.params.query["region"]?

    # Since some implementations create playlists based on resolution regardless of different codecs,
    # we can opt to only add a source to a representation if it has a unique height within that representation
    unique_res = env.params.query["unique_res"]?.try { |q| (q == "true" || q == "1") } || false

    acodecs = env.params.query["acodecs"]?
    vcodecs = env.params.query["vcodecs"]?

    listen = env.params.query["listen"]?.try { |q| (q == "true" || q == "1") } || false
    full = env.params.query["full"]?.try { |q| (q == "true" || q == "1") } || false
    hdr = env.params.query["hdr"]?.try { |q| (q == "true" || q == "1") } || false

    begin
      video = get_video(id, region: region)
    rescue ex : NotFoundException
      haltf env, status_code: 404
    rescue ex
      haltf env, status_code: 403
    end

    if dashmpd = video.dash_manifest_url
      response = YT_POOL.client &.get(URI.parse(dashmpd).request_target)

      if response.status_code != 200
        haltf env, status_code: response.status_code
      end

      manifest = response.body

      manifest = manifest.gsub(/<BaseURL>[^<]+<\/BaseURL>/) do |baseurl|
        url = baseurl.lchop("<BaseURL>")
        url = url.rchop("</BaseURL>")

        if local
          uri = URI.parse(url)
          url = "#{HOST_URL}#{uri.request_target}host/#{uri.host}/"
        end

        "<BaseURL>#{url}</BaseURL>"
      end

      return manifest
    end

    # Transform URLs for proxying
    if local
      video.adaptive_fmts.each do |fmt|
        fmt.url = "#{HOST_URL}#{URI.parse(fmt.url).request_target}"
      end
    end

    if full
      audio_streams = video.audio_streams_raw
    else
      audio_streams = video.audio_streams(acodecs)
    end
    if listen
      video_streams = [] of Invidious::Videos::AdaptativeVideoStream
    elsif full
      video_streams = video.video_streams_raw
    else
      video_streams = video.video_streams(vcodecs)
    end

    audio_streams = audio_streams.group_by do |stream|
      h = {} of Symbol => String | UInt64
      h[:mime] = stream.mime_type
      h[:tid] = stream.track_id.not_nil! if stream.is_a?(Invidious::Videos::AdaptativeAudioTrackStream)

      # Different representations of the same audio should be groupped into one AdaptationSet.
      # However, most players don't support auto quality switching, so we have to trick them
      # into providing a quality selector.
      # See https://github.com/iv-org/invidious/issues/3074 for more details.
      h[:unique] = stream.object_id if !full

      h
    end

    video_streams = video_streams.group_by do |stream|
      h = {} of Symbol => String | Invidious::Videos::ColorTransferType
      h[:mime] = stream.mime_type
      h[:transfer] = stream.video_transfer || Invidious::Videos::ColorTransferType::SDR
      h[:codec] = stream.codec_types[0] if full
      h
    end

    if !full
      # VideoJS HTTP Streaming (VHS) does not support webm container
      audio_streams.select! { |k, v| k[:mime] == "audio/mp4" }
      video_streams.select! { |k, v| k[:mime] == "video/mp4" }

      video_streams_hdr = video_streams.find { |k, v| k[:transfer] != Invidious::Videos::ColorTransferType::SDR }
      if !video_streams_hdr
        # ignore "hdr" parameter
      elsif hdr
        video_streams = {video_streams_hdr[0] => video_streams_hdr[1]}
      else
        video_streams.select! { |k, v| k[:transfer] == Invidious::Videos::ColorTransferType::SDR }
      end
    end

    audio_streams.reject! { |k, v| v.empty? }
    # OTF streams aren't supported yet (See https://github.com/TeamNewPipe/NewPipe/issues/2415)
    audio_streams.each_value &.reject! { |fmt| fmt.index_range.nil? || fmt.init_range.nil? }

    video_streams.reject! { |k, v| v.empty? }
    # OTF streams aren't supported yet (See https://github.com/TeamNewPipe/NewPipe/issues/2415)
    video_streams.each_value &.reject! { |fmt| fmt.index_range.nil? || fmt.init_range.nil? }
    video_streams.each_value &.uniq! &.label if unique_res

    # Build the manifest
    return XML.build(indent: "  ", encoding: "UTF-8") do |xml|
      xml.element("MPD", "xmlns": "urn:mpeg:dash:schema:mpd:2011",
        "profiles": "urn:mpeg:dash:profile:full:2011", minBufferTime: "PT1.5S", type: "static",
        mediaPresentationDuration: "PT#{video.length_seconds}S") do
        xml.element("Period") do
          i = 0

          audio_streams.each do |k, formats|
            props = {
              "id" => i,
              "mimeType" => k[:mime],
              "startWithSAP" => 1,
              "subsegmentAlignment" => true,
            }
            label = [] of String
            formats[0].as?(Invidious::Videos::AdaptativeAudioTrackStream).try do |track|
              props["lang"] = track.track_name
              label.push(track.track_name)
            end
            if !full
              label.push("#{formats[0].bitrate // 1000} kbps")
            end
            props["label"] = label.join(" ") unless label.empty?
            xml.element("AdaptationSet", props) do
              xml.element("Role", schemeIdUri: "urn:mpeg:dash:role:2011", value: i == 0 ? "main" : "alternate")
              formats.each do |fmt|
                xml.element("Representation", id: fmt.itag, codecs: fmt.codecs[0], bandwidth: fmt.bitrate) do
                  xml.element("AudioChannelConfiguration", schemeIdUri: "urn:mpeg:dash:23003:3:audio_channel_configuration:2011", value: fmt.audio_channels)
                  xml.element("BaseURL") { xml.text fmt.url }
                  xml.element("SegmentBase", indexRange: fmt.index_range.to_s) do
                    xml.element("Initialization", range: fmt.init_range.to_s)
                  end
                end
              end
            end

            i += 1
          end

          video_streams.each do |k, formats|
            xml.element("AdaptationSet", id: i, mimeType: k[:mime], startWithSAP: 1, subsegmentAlignment: true, scanType: "progressive") do
              transfer = k[:transfer].as(Invidious::Videos::ColorTransferType)
              if transfer != Invidious::Videos::ColorTransferType::SDR
                # according to ISO/IEC 23001-8
                transfer = case transfer
                when Invidious::Videos::ColorTransferType::PQ then 16
                when Invidious::Videos::ColorTransferType::HLG then 18
                else raise "Unsupported ColorTransferType"
                end
                xml.element("SupplementalProperty", schemeIdUri: "urn:mpeg:mpegB:cicp:TransferCharacteristics", value: transfer)
              end

              formats.each do |fmt|
                height = full ? fmt.video_height : fmt.label.to_i(strict: false)

                xml.element("Representation", id: fmt.itag, codecs: fmt.codecs[0], width: fmt.video_width, height: height,
                  startWithSAP: "1", maxPlayoutRate: "1", bandwidth: fmt.bitrate, frameRate: fmt.video_fps, label: fmt.label) do
                  xml.element("BaseURL") { xml.text fmt.url }
                  xml.element("SegmentBase", indexRange: fmt.index_range.to_s) do
                    xml.element("Initialization", range: fmt.init_range.to_s)
                  end
                end
              end
            end

            i += 1
          end
        end
      end
    end
  end

  # /api/manifest/dash/id/videoplayback
  def self.get_dash_video_playback(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.redirect "/videoplayback?#{env.params.query}"
  end

  # /api/manifest/dash/id/videoplayback/*
  def self.get_dash_video_playback_greedy(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.redirect env.request.path.lchop("/api/manifest/dash/id")
  end

  # /api/manifest/dash/id/videoplayback && /api/manifest/dash/id/videoplayback/*
  def self.options_dash_video_playback(env)
    env.response.headers.delete("Content-Type")
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
  end

  # /api/manifest/hls_playlist/*
  def self.get_hls_playlist(env)
    response = YT_POOL.client &.get(env.request.path)

    if response.status_code != 200
      haltf env, status_code: response.status_code
    end

    local = env.params.query["local"]?.try { |q| (q == "true" || q == "1") } || false

    env.response.content_type = "application/x-mpegURL"
    env.response.headers.add("Access-Control-Allow-Origin", "*")

    manifest = response.body

    if local
      manifest = manifest.gsub(/^https:\/\/\w+---.{11}\.c\.youtube\.com[^\n]*/m) do |match|
        path = URI.parse(match).path

        path = path.lchop("/videoplayback/")
        path = path.rchop("/")

        path = path.gsub(/mime\/\w+\/\w+/) do |mimetype|
          mimetype = mimetype.split("/")
          mimetype[0] + "/" + mimetype[1] + "%2F" + mimetype[2]
        end

        path = path.split("/")

        raw_params = {} of String => Array(String)
        path.each_slice(2) do |pair|
          key, value = pair
          value = URI.decode_www_form(value)

          if raw_params[key]?
            raw_params[key] << value
          else
            raw_params[key] = [value]
          end
        end

        raw_params = HTTP::Params.new(raw_params)
        if fvip = raw_params["hls_chunk_host"].match(/r(?<fvip>\d+)---/)
          raw_params["fvip"] = fvip["fvip"]
        end

        raw_params["local"] = "true"

        "#{HOST_URL}/videoplayback?#{raw_params}"
      end
    end

    manifest
  end

  # /api/manifest/hls_variant/*
  def self.get_hls_variant(env)
    response = YT_POOL.client &.get(env.request.path)

    if response.status_code != 200
      haltf env, status_code: response.status_code
    end

    local = env.params.query["local"]?.try { |q| (q == "true" || q == "1") } || false

    env.response.content_type = "application/x-mpegURL"
    env.response.headers.add("Access-Control-Allow-Origin", "*")

    manifest = response.body

    if local
      manifest = manifest.gsub("https://www.youtube.com", HOST_URL)
      manifest = manifest.gsub("index.m3u8", "index.m3u8?local=true")
    end

    manifest
  end
end
