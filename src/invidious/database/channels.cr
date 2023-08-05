require "./base.cr"

#
# This module contains functions related to the "channels" table.
#
module Invidious::Database::Channels
  extend self

  # -------------------
  #  Insert / delete
  # -------------------

  def insert(channel : InvidiousChannel, update_on_conflict : Bool = false)
    channel_array = channel.to_a

    request = <<-SQL
      INSERT INTO channels
      VALUES (#{arg_array(channel_array)})
    SQL

    if update_on_conflict
      request += <<-SQL
        ON CONFLICT (id) DO UPDATE
        SET author = $2, updated = $3
      SQL
    end

    PG_DB.exec(request, args: channel_array)
  end

  # -------------------
  #  Update
  # -------------------

  def update_author(id : String, author : String)
    request = <<-SQL
      UPDATE channels
      SET updated = $1, author = $2, deleted = false
      WHERE id = $3
    SQL

    PG_DB.exec(request, Time.utc, author, id)
  end

  def update_subscription_time(id : String)
    request = <<-SQL
      UPDATE channels
      SET subscribed = $1
      WHERE id = $2
    SQL

    PG_DB.exec(request, Time.utc, id)
  end

  def update_mark_deleted(id : String)
    request = <<-SQL
      UPDATE channels
      SET updated = $1, deleted = true
      WHERE id = $2
    SQL

    PG_DB.exec(request, Time.utc, id)
  end

  # -------------------
  #  Select
  # -------------------

  def select(id : String) : InvidiousChannel?
    request = <<-SQL
      SELECT * FROM channels
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: InvidiousChannel)
  end

  def select(ids : Array(String)) : Array(InvidiousChannel)?
    return [] of InvidiousChannel if ids.empty?

    request = <<-SQL
      SELECT channels.* FROM channels, json_each($1)
      WHERE channels.id = json_each.value
    SQL

    return PG_DB.query_all(request, ids.to_json, as: InvidiousChannel)
  end
end

#
# This module contains functions related to the "channel_videos" table.
#
module Invidious::Database::ChannelVideos
  extend self

  # -------------------
  #  Insert
  # -------------------

  # This function returns the status of the query (i.e: success?)
  def insert(video : ChannelVideo, with_premiere_timestamp : Bool = false) : Bool
    if with_premiere_timestamp
      last_items = "premiere_timestamp = $9, views = $10"
    else
      last_items = "views = $10"
    end

    request = <<-SQL
      INSERT INTO channel_videos
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      ON CONFLICT (id) DO UPDATE
      SET title = $2, published = $3, updated = $4, ucid = $5,
          author = $6, length_seconds = $7, live_now = $8, #{last_items}
    SQL

    was_insert = false
    PG_DB.transaction do |t|
      cx = t.connection

      old_rows = cx.query_one("SELECT count(*) FROM channel_videos", as: Int64)
      cx.exec(request, *video.to_tuple)
      new_rows = cx.query_one("SELECT count(*) FROM channel_videos", as: Int64)

      was_insert = (new_rows != old_rows)
    end

    return was_insert
  end

  # -------------------
  #  Select
  # -------------------

  def select(ids : Array(String)) : Array(ChannelVideo)
    return [] of ChannelVideo if ids.empty?

    request = <<-SQL
      SELECT channels_videos.* FROM channels_videos, json_each($1)
      WHERE channel_videos.id = json_each.value
      ORDER BY published DESC
    SQL

    return PG_DB.query_all(request, ids.to_json, as: ChannelVideo)
  end

  def select_notifications(ucid : String, since : Time) : Array(ChannelVideo)
    request = <<-SQL
      SELECT * FROM channel_videos
      WHERE ucid = $1 AND published > $2
      ORDER BY published DESC
      LIMIT 15
    SQL

    return PG_DB.query_all(request, ucid, since, as: ChannelVideo)
  end

  def select_popular_videos : Array(ChannelVideo)
    request = <<-SQL
      SELECT DISTINCT ON (ucid) *
      FROM channel_videos
      WHERE ucid IN (SELECT channel FROM (SELECT UNNEST(subscriptions) AS channel FROM users) AS d
      GROUP BY channel ORDER BY COUNT(channel) DESC LIMIT 40)
      ORDER BY ucid, published DESC
    SQL

    PG_DB.query_all(request, as: ChannelVideo)
  end
end
