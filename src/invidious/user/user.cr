require "db"

struct Invidious::User
  include DB::Serializable

  property updated : Time
  @[DB::Field(converter: Invidious::User::StringArrayConverter)]
  property notifications : Array(String)
  @[DB::Field(converter: Invidious::User::StringArrayConverter)]
  property subscriptions : Array(String)
  property email : String

  @[DB::Field(converter: Invidious::User::PreferencesConverter)]
  property preferences : Preferences
  property password : String?
  property token : String
  @[DB::Field(converter: Invidious::User::StringArrayConverter)]
  property watched : Array(String)
  property feed_needs_update : Bool?

  module PreferencesConverter
    def self.from_rs(rs)
      begin
        Preferences.from_json(rs.read(String))
      rescue ex
        Preferences.from_json("[]")
      end
    end
  end

  module StringArrayConverter
    def self.from_rs(rs)
      begin
        Array(String).from_json(rs.read(String))
      rescue ex
        Array(String).from_json("[]")
      end
    end
  end
end
