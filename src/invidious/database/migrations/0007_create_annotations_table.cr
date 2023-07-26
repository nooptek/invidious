module Invidious::Database::Migrations
  class CreateAnnotationsTable < Migration
    version 7

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS annotations
      (
        id text NOT NULL,
        annotations text,
        CONSTRAINT annotations_id_key UNIQUE (id)
      );
      SQL
    end
  end
end
