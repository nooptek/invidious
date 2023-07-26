require "./base.cr"

module Invidious::Database::Users
  extend self

  # -------------------
  #  Insert / delete
  # -------------------

  def insert(user : User, update_on_conflict : Bool = false)
    user_array = user.to_a
    user_array[1] = user_array[1].to_json # notifications
    user_array[2] = user_array[2].to_json # subscriptions
    user_array[4] = user_array[4].to_json # User preferences
    user_array[7] = user_array[7].to_json # watched

    request = <<-SQL
      INSERT INTO users
      VALUES (#{arg_array(user_array)})
    SQL

    if update_on_conflict
      request += <<-SQL
        ON CONFLICT (email) DO UPDATE
        SET updated = $1, subscriptions = $3
      SQL
    end

    PG_DB.exec(request, args: user_array)
  end

  def delete(user : User)
    request = <<-SQL
      DELETE FROM users
      WHERE email = $1
    SQL

    PG_DB.exec(request, user.email)
  end

  # -------------------
  #  Update (history)
  # -------------------

  def update_watch_history(user : User)
    request = <<-SQL
      UPDATE users
      SET watched = $1
      WHERE email = $2
    SQL

    PG_DB.exec(request, user.watched.to_json, user.email)
  end

  def mark_watched(user : User, vid : String)
    request = <<-SQL
      UPDATE users
      SET watched = (
        SELECT json_group_array(DISTINCT value)
        FROM json_each(json_insert(watched, '$[#]', $1))
      )
      WHERE email = $2
    SQL

    PG_DB.exec(request, vid, user.email)
  end

  def mark_unwatched(user : User, vid : String)
    request = <<-SQL
      UPDATE users
      SET watched = (
        SELECT json_group_array(value)
        FROM json_each(watched)
        WHERE value != $1
      )
      WHERE email = $2
    SQL

    PG_DB.exec(request, vid, user.email)
  end

  def clear_watch_history(user : User)
    request = <<-SQL
      UPDATE users
      SET watched = '[]'
      WHERE email = $1
    SQL

    PG_DB.exec(request, user.email)
  end

  # -------------------
  #  Update (channels)
  # -------------------

  def update_subscriptions(user : User)
    request = <<-SQL
      UPDATE users
      SET feed_needs_update = true, subscriptions = $1
      WHERE email = $2
    SQL

    PG_DB.exec(request, user.subscriptions.to_json, user.email)
  end

  def subscribe_channel(user : User, ucid : String)
    request = <<-SQL
      UPDATE users
      SET feed_needs_update = true,
          subscriptions = json_insert(subscriptions, '$[#]', $1)
      WHERE email = $2
    SQL

    PG_DB.exec(request, ucid, user.email)
  end

  def unsubscribe_channel(user : User, ucid : String)
    request = <<-SQL
      UPDATE users
      SET feed_needs_update = true,
          subscriptions = (
            SELECT json_group_array(value)
            FROM json_each(subscriptions)
            WHERE value != $1
          )
      WHERE email = $2
    SQL

    PG_DB.exec(request, ucid, user.email)
  end

  # -------------------
  #  Update (notifs)
  # -------------------

  def add_notification(video : ChannelVideo)
    request = <<-SQL
      UPDATE users
      SET notifications = json_insert(notifications, '$[#]', $1),
          feed_needs_update = true
      WHERE EXISTS (
        SELECT value
        FROM json_each(subscriptions)
        WHERE value = $2
      )
    SQL

    PG_DB.exec(request, video.id, video.ucid)
  end

  def remove_notification(user : User, vid : String)
    request = <<-SQL
      UPDATE users
      SET notifications = (
        SELECT json_group_array(value)
        FROM json_each(notifications)
        WHERE value != $1
      )
      WHERE email = $2
    SQL

    PG_DB.exec(request, vid, user.email)
  end

  def clear_notifications(user : User)
    request = <<-SQL
      UPDATE users
      SET notifications = '[]', updated = $1
      WHERE email = $2
    SQL

    PG_DB.exec(request, Time.utc, user.email)
  end

  # -------------------
  #  Update (misc)
  # -------------------

  def feed_needs_update(video : ChannelVideo)
    request = <<-SQL
      UPDATE users
      SET feed_needs_update = true
      WHERE EXISTS (
        SELECT value
        FROM json_each(subscriptions)
        WHERE value = $1
      )
    SQL

    PG_DB.exec(request, video.ucid)
  end

  def update_preferences(user : User)
    request = <<-SQL
      UPDATE users
      SET preferences = $1
      WHERE email = $2
    SQL

    PG_DB.exec(request, user.preferences.to_json, user.email)
  end

  def update_password(user : User, pass : String)
    request = <<-SQL
      UPDATE users
      SET password = $1
      WHERE email = $2
    SQL

    PG_DB.exec(request, pass, user.email)
  end

  # -------------------
  #  Select
  # -------------------

  def select(*, email : String) : User?
    request = <<-SQL
      SELECT * FROM users
      WHERE email = $1
    SQL

    return PG_DB.query_one?(request, email, as: User)
  end

  # Same as select, but can raise an exception
  def select!(*, email : String) : User
    request = <<-SQL
      SELECT * FROM users
      WHERE email = $1
    SQL

    return PG_DB.query_one(request, email, as: User)
  end

  def select(*, token : String) : User?
    request = <<-SQL
      SELECT * FROM users
      WHERE token = $1
    SQL

    return PG_DB.query_one?(request, token, as: User)
  end

  def select_all : Array(User)
    request = <<-SQL
      SELECT * FROM users
    SQL

    PG_DB.query_all(request, as: User)
  end

  def select_notifications(user : User) : Array(String)
    request = <<-SQL
      SELECT notifications
      FROM users
      WHERE email = $1
    SQL

    ret = PG_DB.query_one(request, user.email, as: String)
    return Array(String).from_json(ret)
  end
end
