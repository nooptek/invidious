module Invidious::Database::Migrations
  class CreateChannelVideosTable < Migration
    version 3

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS channel_videos
      (
        id text NOT NULL,
        title text,
        published text,
        updated text,
        ucid text,
        author text,
        length_seconds integer,
        live_now boolean,
        premiere_timestamp text,
        views bigint,
        CONSTRAINT channel_videos_id_key UNIQUE (id)
      );
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS channel_videos_ucid_idx
        ON channel_videos
        (ucid);
      SQL
    end
  end
end
