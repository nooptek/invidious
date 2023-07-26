module Invidious::Database::Migrations
  class CreatePlaylistsTable < Migration
    version 8

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS playlists
      (
        title text,
        id text primary key,
        author text,
        description text,
        video_count integer,
        created text,
        updated text,
        privacy text check(privacy in ('Public', 'Unlisted', 'Private')),
        index int8[]
      );
      SQL
    end
  end
end
