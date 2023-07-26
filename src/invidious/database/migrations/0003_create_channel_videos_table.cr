module Invidious::Database::Migrations
  class CreateChannelVideosTable < Migration
    version 3

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS channel_videos
      (
        id text NOT NULL,
        title text,
        published timestamp with time zone,
        updated timestamp with time zone,
        ucid text,
        author text,
        length_seconds integer,
        live_now boolean,
        premiere_timestamp timestamp with time zone,
        views bigint,
        CONSTRAINT channel_videos_id_key UNIQUE (id)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE channel_videos TO current_user;
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS channel_videos_ucid_idx
        ON channel_videos
        USING btree
        (ucid COLLATE pg_catalog."default");
      SQL
    end
  end
end
