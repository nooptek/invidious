module Invidious::Database::Migrations
  class CreateChannelsTable < Migration
    version 1

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS channels
      (
        id text NOT NULL,
        author text,
        updated text,
        deleted boolean,
        subscribed text,
        CONSTRAINT channels_id_key UNIQUE (id)
      );
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS channels_id_idx
        ON channels
        (id);
      SQL
    end
  end
end
