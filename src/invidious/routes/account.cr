{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Account
  extend self

  # -------------------
  #  Password update
  # -------------------

  # Show the password change interface (GET request)
  def get_change_password(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)

    moduser = env.params.query["email"]?
    if moduser # admin changes another user password
      if !CONFIG.admins.includes? user.email
        return error_template(401, "Only admins can change other user password.")
      end
      if CONFIG.registration_enabled
        return error_template(400, "User management is only allowed when registration is disabled.")
      end

      moduser = Invidious::Database::Users.select(email: moduser)
      if !moduser
        return error_template(400, "Non existing user.")
      end
      if CONFIG.admins.includes? moduser.email
        return error_template(401, "Admin account password cannot be changed by another user.")
      end
    end

    sid = sid.as(String)
    csrf_token = generate_response(sid, {":change_password"}, HMAC_KEY)

    templated "user/change_password"
  end

  # Handle the password change (POST request)
  def post_change_password(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    new_passwords = env.params.body.select { |k, _| k.match(/^new_password\[\d+\]$/) }.map { |_, v| v }

    moduser = env.params.body["email"]?
    if moduser # admin changes another user password
      if !CONFIG.admins.includes? user.email
        return error_template(400, "Only admins can change other user password.")
      end
      if CONFIG.registration_enabled
        return error_template(400, "User management is only allowed when registration is disabled.")
      end

      if new_passwords.size < 1
        return error_template(401, "New password is a required field")
      end

      moduser = Invidious::Database::Users.select(email: moduser)
      if !moduser
        return error_template(400, "Non existing user.")
      end
      if CONFIG.admins.includes? moduser.email
        return error_template(401, "Admin account password cannot be changed by another user.")
      end
    else # user changes its own password
      password = env.params.body["password"]?
      if password.nil? || password.empty?
        return error_template(401, "Password is a required field")
      end

      if new_passwords.size <= 1 || new_passwords.uniq.size != 1
        return error_template(400, "New passwords must match")
      end

      if !Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
        return error_template(401, "Incorrect password")
      end

      moduser = user
    end

    new_password = new_passwords.uniq[0]
    if new_password.empty?
      return error_template(401, "Password cannot be empty")
    end

    if new_password.bytesize > 55
      return error_template(400, "Password cannot be longer than 55 characters")
    end

    new_password = Crypto::Bcrypt::Password.create(new_password, cost: 10)
    Invidious::Database::Users.update_password(moduser, new_password.to_s)

    env.redirect referer
  end

  # -------------------
  #  Account deletion
  # -------------------

  # Show the account deletion confirmation prompt (GET request)
  def get_delete(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)

    moduser = env.params.query["email"]?
    if moduser # admin deletes other user account
      if !CONFIG.admins.includes? user.email
        return error_template(401, "Only admins can delete other user accounts.")
      end
      if CONFIG.registration_enabled
        return error_template(400, "User management is only allowed when registration is disabled.")
      end

      moduser = Invidious::Database::Users.select(email: moduser)
      if !moduser
        return error_template(400, "Non existing user.")
      end
      if CONFIG.admins.includes? moduser.email
        return error_template(401, "Admin account cannot be deleted by another user.")
      end
    else # user deletes its own account
      if CONFIG.admins.includes? user.email
        return error_template(400, "Admin account cannot be deleted.")
      end
      if !CONFIG.registration_enabled
        return error_template(400, "Accounts cannot be deleted when registration is disabled.")
      end
    end

    csrf_token = generate_response(sid, {":delete_account"}, HMAC_KEY)

    templated "user/delete_account"
  end

  # Handle the account deletion (POST request)
  def post_delete(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    moduser = env.params.body["email"]?
    if moduser # admin deletes other user account
      if !CONFIG.admins.includes? user.email
        return error_template(401, "Only admins can delete other user accounts.")
      end
      if CONFIG.registration_enabled
        return error_template(400, "User management is only allowed when registration is disabled.")
      end

      moduser = Invidious::Database::Users.select(email: moduser)
      if !moduser
        return error_template(400, "Non existing user.")
      end
      if CONFIG.admins.includes? moduser.email
        return error_template(401, "Admin accounts cannot be deleted by another user.")
      end
    else # user deletes its own account
      if CONFIG.admins.includes? user.email
        return error_template(400, "Admin account cannot be deleted.")
      end
      if !CONFIG.registration_enabled
        return error_template(400, "Accounts cannot be deleted when registration is disabled.")
      end

      env.request.cookies.each do |cookie|
        cookie.expires = Time.utc(1990, 1, 1)
        env.response.cookies << cookie
      end

      moduser = user
    end

    view_name = "subscriptions_#{sha256(moduser.email)}"
    Invidious::Database::Users.delete(moduser)
    Invidious::Database::SessionIDs.delete(email: moduser.email)
    Invidious::Database::Playlists.select_like_iv(moduser.email).each do |pl|
      Invidious::Database::Playlists.delete(pl.id)
    end
    PG_DB.exec("DROP MATERIALIZED VIEW #{view_name}")

    env.redirect referer
  end

  # Show the account creation prompt (GET request)
  def get_create(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)

    if !CONFIG.admins.includes? user.email
      return error_template(400, "Only admins can create users.")
    end
    if CONFIG.registration_enabled
      return error_template(400, "User management is only allowed when registration is disabled.")
    end

    csrf_token = generate_response(sid, {":create_account"}, HMAC_KEY)

    templated "user/create_account"
  end

  # Handle the account creation (POST request)
  def post_create(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    if !CONFIG.admins.includes? user.email
      return error_template(400, "Only admins can create users.")
    end
    if CONFIG.registration_enabled
      return error_template(400, "User management is only allowed when registration is disabled.")
    end

    # https://stackoverflow.com/a/574698
    email = env.params.body["email"]?.try &.downcase.byte_slice(0, 254)
    password = env.params.body["password"]?

    if email.nil? || email.empty?
      return error_template(401, "User ID is a required field")
    end

    if password.nil? || password.empty?
      return error_template(401, "Password is a required field")
    end

    # See https://security.stackexchange.com/a/39851
    if password.bytesize > 55
      return error_template(400, "Password cannot be longer than 55 characters")
    end

    password = password.byte_slice(0, 55)

    moduser = Invidious::Database::Users.select(email: email)
    if moduser
      return error_template(400, "Already existing user.")
    end

    moduser = create_user(email, password)

    Invidious::Database::Users.insert(moduser)

    view_name = "subscriptions_#{sha256(moduser.email)}"
    PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(moduser.email)}")

    env.redirect referer
  end

  # -------------------
  #  User manager
  # -------------------

  # Show the user manager page (GET request)
  def user_manager(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, "/preferences")

    if !user
      return env.redirect referer
    end

    user = user.as(User)

    if !CONFIG.admins.includes? user.email
      return error_template(400, "Only admins can manage users.")
    end
    if CONFIG.registration_enabled
      return error_template(400, "User management is only allowed when registration is disabled.")
    end

    users = Invidious::Database::Users.select_all

    templated "user/user_manager"
  end

  # -------------------
  #  Clear history
  # -------------------

  # Show the watch history deletion confirmation prompt (GET request)
  def get_clear_history(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":clear_watch_history"}, HMAC_KEY)

    templated "user/clear_watch_history"
  end

  # Handle the watch history clearing (POST request)
  def post_clear_history(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    Invidious::Database::Users.clear_watch_history(user)
    env.redirect referer
  end

  # -------------------
  #  Authorize tokens
  # -------------------

  # Show the "authorize token?" confirmation prompt (GET request)
  def get_authorize_token(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect "/login?referer=#{URI.encode_path_segment(env.request.resource)}"
    end

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":authorize_token"}, HMAC_KEY)

    scopes = env.params.query["scopes"]?.try &.split(",")
    scopes ||= [] of String

    callback_url = env.params.query["callback_url"]?
    if callback_url
      callback_url = URI.parse(callback_url)
    end

    expire = env.params.query["expire"]?.try &.to_i?

    templated "user/authorize_token"
  end

  # Handle token authorization (POST request)
  def post_authorize_token(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = env.get("user").as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    scopes = env.params.body.select { |k, _| k.match(/^scopes\[\d+\]$/) }.map { |_, v| v }
    callback_url = env.params.body["callbackUrl"]?
    expire = env.params.body["expire"]?.try &.to_i?

    access_token = generate_token(user.email, scopes, expire, HMAC_KEY)

    if callback_url
      access_token = URI.encode_www_form(access_token)
      url = URI.parse(callback_url)

      if url.query
        query = HTTP::Params.parse(url.query.not_nil!)
      else
        query = HTTP::Params.new
      end

      query["token"] = access_token
      query["username"] = URI.encode_path_segment(user.email)
      url.query = query.to_s

      env.redirect url.to_s
    else
      csrf_token = ""
      env.set "access_token", access_token
      templated "user/authorize_token"
    end
  end

  # -------------------
  #  Manage tokens
  # -------------------

  # Show the token manager page (GET request)
  def token_manager(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, "/subscription_manager")

    if !user
      return env.redirect referer
    end

    user = user.as(User)

    moduser = env.params.query["email"]?
    if moduser # admin manages other user tokens
      if !CONFIG.admins.includes? user.email
        return error_template(401, "Only admins can manage other user tokens.")
      end
      if CONFIG.registration_enabled
        return error_template(400, "User management is only allowed when registration is disabled.")
      end

      moduser = Invidious::Database::Users.select(email: moduser)
      if !moduser
        return error_template(400, "Non existing user.")
      end
      if CONFIG.admins.includes? moduser.email
        return error_template(401, "Admin tokens cannot be managed by another user.")
      end

      tokens = Invidious::Database::SessionIDs.select_all(moduser.email)
    else # user manages its own tokens
      tokens = Invidious::Database::SessionIDs.select_all(user.email)
    end

    templated "user/token_manager"
  end

  # -------------------
  #  AJAX for tokens
  # -------------------

  # Handle internal (non-API) token actions (POST request)
  def token_ajax(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    redirect = env.params.query["redirect"]?
    redirect ||= "true"
    redirect = redirect == "true"

    if !user
      if redirect
        return env.redirect referer
      else
        return error_json(403, "No such user")
      end
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      if redirect
        return error_template(400, ex)
      else
        return error_json(400, ex)
      end
    end

    if env.params.query["action_revoke_token"]?
      action = "action_revoke_token"
    else
      return env.redirect referer
    end

    session = env.params.query["session"]?
    session ||= ""

    moduser = env.params.query["email"]?
    if moduser # admin manages other user tokens
      if !CONFIG.admins.includes? user.email
        return error_template(401, "Only admins can manage other user tokens.")
      end
      if CONFIG.registration_enabled
        return error_template(400, "User management is only allowed when registration is disabled.")
      end

      moduser = Invidious::Database::Users.select(email: moduser)
      if !moduser
        return error_template(400, "Non existing user.")
      end
      if CONFIG.admins.includes? moduser.email
        return error_template(401, "Admin tokens cannot be managed by another user.")
      end
    else # user manages its own tokens
      moduser = user
    end

    case action
    when .starts_with? "action_revoke_token"
      Invidious::Database::SessionIDs.delete(sid: session, email: moduser.email)
    else
      return error_json(400, "Unsupported action #{action}")
    end

    if redirect
      return env.redirect referer
    else
      env.response.content_type = "application/json"
      return "{}"
    end
  end
end
