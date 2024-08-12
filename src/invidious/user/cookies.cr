require "http/cookie"

struct Invidious::User
  module Cookies
    extend self

    SECURE = !!(Kemal.config.ssl || CONFIG.https_only || CONFIG.login_required)

    # Session ID (SID) cookie
    # Parameter "domain" comes from the global config
    def sid(domain : String?, sid) : HTTP::Cookie
      return HTTP::Cookie.new(
        name: "SID",
        domain: domain,
        value: sid,
        expires: Time.utc + 2.years,
        secure: SECURE,
        http_only: true,
        samesite: CONFIG.login_required ? HTTP::Cookie::SameSite::None : HTTP::Cookie::SameSite::Lax
      )
    end

    # Preferences (PREFS) cookie
    # Parameter "domain" comes from the global config
    def prefs(domain : String?, preferences : Preferences) : HTTP::Cookie
      return HTTP::Cookie.new(
        name: "PREFS",
        domain: domain,
        value: URI.encode_www_form(preferences.to_json),
        expires: Time.utc + 2.years,
        secure: SECURE,
        http_only: false,
        samesite: HTTP::Cookie::SameSite::None
      )
    end
  end
end
