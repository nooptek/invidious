module Invidious::Database::Migrations
  class CreateVideosTable < Migration
    version 2

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE UNLOGGED TABLE IF NOT EXISTS videos
      (
        id text NOT NULL,
        info text,
        updated text,
        CONSTRAINT videos_pkey PRIMARY KEY (id)
      );
      SQL

      conn.exec <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS id_idx
        ON videos
        (id);
      SQL
    end
  end
end
