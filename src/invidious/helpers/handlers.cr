module HTTP::Handler
  @@exclude_routes_tree = Radix::Tree(String).new

  macro exclude(paths, method = "GET")
      class_name = {{@type.name}}
      method_downcase = {{method.downcase}}
      class_name_method = "#{class_name}/#{method_downcase}"
      ({{paths}}).each do |path|
        @@exclude_routes_tree.add class_name_method + path, '/' + method_downcase + path
      end
    end

  def exclude_match?(env : HTTP::Server::Context)
    @@exclude_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
  end

  private def radix_path(method : String, path : String)
    "#{self.class}/#{method.downcase}#{path}"
  end
end

class Kemal::RouteHandler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
    exclude ["/api/v1/*"], {{method}}
  {% end %}

  # Processes the route if it's a match. Otherwise renders 404.
  private def process_request(context)
    raise Kemal::Exceptions::RouteNotFound.new(context) unless context.route_found?
    content = context.route.handler.call(context)

    if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(context.response.status_code) && exclude_match?(context)
      raise Kemal::Exceptions::CustomException.new(context)
    end

    if context.request.method == "HEAD" && context.request.path.ends_with? ".jpg"
      context.response.headers["Content-Type"] = "image/jpeg"
    end

    context.response.print(content)
    context
  end
end

class Kemal::ExceptionHandler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
    exclude ["/api/v1/*"], {{method}}
  {% end %}

  private def call_exception_with_status_code(context : HTTP::Server::Context, exception : Exception, status_code : Int32)
    return if context.response.closed?
    return if exclude_match? context

    if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(status_code)
      context.response.content_type = "text/html" unless context.response.headers.has_key?("Content-Type")
      context.response.status_code = status_code
      context.response.print Kemal.config.error_handlers[status_code].call(context, exception)
      context
    end
  end
end

class FilteredCompressHandler < Kemal::Handler
  exclude ["/videoplayback", "/videoplayback/*", "/vi/*", "/sb/*", "/ggpht/*", "/api/v1/auth/notifications"]
  exclude ["/api/v1/auth/notifications", "/data_control"], "POST"

  def call(env)
    return call_next env if exclude_match? env

    {% if flag?(:without_zlib) %}
      call_next env
    {% else %}
      request_headers = env.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        env.response.output = Compress::Gzip::Writer.new(env.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        env.response.output = Compress::Deflate::Writer.new(env.response.output, sync_close: true)
      end

      call_next env
    {% end %}
  end
end

class AuthHandler < Kemal::Handler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
    only ["/api/v1/*"], {{method}}
  {% end %}
  exclude ["/feed/webhook/*", "/feed/private"]

  private def call_api(env)
    return call_next env unless CONFIG.login_required || env.request.resource.starts_with? "/api/v1/auth/"

    begin
      if token = env.request.headers["Authorization"]?
        token = JSON.parse(URI.decode_www_form(token.lchop("Bearer ")))
        session = URI.decode_www_form(token["session"].as_s)
        scopes, _, _ = validate_request(token, session, env.request, HMAC_KEY, nil)

        if email = Invidious::Database::SessionIDs.select_email(session)
          user = Invidious::Database::Users.select!(email: email)
        end
      elsif sid = env.request.cookies["SID"]?.try &.value
        if sid.starts_with? "v1:"
          raise "Cannot use token as SID"
        end

        if email = Invidious::Database::SessionIDs.select_email(sid)
          user = Invidious::Database::Users.select!(email: email)
        end

        scopes = [":*"]
        session = sid
      end

      if !user
        raise "Request must be authenticated"
      end

      env.set "scopes", scopes
      env.set "user", user
      env.set "session", session

      call_next env
    rescue ex
      env.response.content_type = "application/json"

      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 403
      env.response.print error_message
    end
  end

  private def call_other(env)
    unregistered_path = {
      "/sb/",
      "/vi/",
      "/s_p/",
      "/yts/",
      "/ggpht/",
      "/api/manifest/",
      "/videoplayback",
      "/latest_version",
      "/download",
      "/ivsb/",
    }

    if unregistered_path.any? { |r| env.request.resource.starts_with? r }
      env.set "unregistered_path", true
      return call_next env if !CONFIG.login_required
    end

    if env.request.cookies.has_key? "SID"
      sid = env.request.cookies["SID"].value

      if sid.starts_with? "v1:"
        raise "Cannot use token as SID"
      end

      if email = Invidious::Database::SessionIDs.select_email(sid)
        user = Invidious::Database::Users.select!(email: email)
        csrf_token = generate_response(sid, {
          ":authorize_token",
          ":playlist_ajax",
          ":signout",
          ":subscription_ajax",
          ":token_ajax",
          ":watch_ajax",
        }, HMAC_KEY, 1.week)

        preferences = user.preferences
        env.set "preferences", preferences

        env.set "sid", sid
        env.set "csrf_token", csrf_token
        env.set "user", user
      end
    end

    if CONFIG.login_required && !env.get?("user") && env.request.path != "/login"
      env.response.headers["Location"] = "/login"
      env.response.status_code = 302
    else
      call_next env
    end
  end

  def call(env)
    if exclude_match? env
      # those paths already have their own verification mechanisms
      call_next env
    elsif only_match? env
      call_api env
    else
      call_other env
    end
  end
end

class APIHandler < Kemal::Handler
  {% for method in %w(GET POST PUT HEAD DELETE PATCH OPTIONS) %}
  only ["/api/v1/*"], {{method}}
  {% end %}
  exclude ["/api/v1/auth/notifications"], "GET"
  exclude ["/api/v1/auth/notifications"], "POST"

  def call(env)
    env.response.headers["Access-Control-Allow-Origin"] = "*" if only_match?(env)
    call_next env
  end
end

class DenyFrame < Kemal::Handler
  exclude ["/embed/*"]

  def call(env)
    return call_next env if exclude_match? env

    env.response.headers["X-Frame-Options"] = "sameorigin"
    call_next env
  end
end

module SQLite3
  # this is the format used by SQLite's datetime()
  DATE_FORMAT2 = "%F %T"
end

class SQLite3::ResultSet
  private def conv_time(v : String) : Time
    last_ex = uninitialized ::Exception
    {SQLite3::DATE_FORMAT, SQLite3::DATE_FORMAT2}.each do |fmt|
      begin
        return Time.parse(v, fmt, SQLite3::TIME_ZONE)
      rescue ex
        last_ex = ex
      end
    end
    raise last_ex
  end

  def read(t : Time.class) : Time
    conv_time read(String)
  end

  def read(t : Time?.class) : Time?
    read(String?).try { |v| conv_time v }
  end
end
