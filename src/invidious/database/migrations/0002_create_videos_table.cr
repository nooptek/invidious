module Invidious::Database::Migrations
  class CreateVideosTable < Migration
    version 2

    def up(conn : DB::Connection)
      case conn
      when SQLite3::Connection
        spec = "TEMP"
      else # assume PGSQL
        spec = "UNLOGGED"
      end

      conn.exec <<-SQL
      CREATE #{spec} TABLE IF NOT EXISTS videos
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
