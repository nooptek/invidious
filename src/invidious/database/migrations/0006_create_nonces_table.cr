module Invidious::Database::Migrations
  class CreateNoncesTable < Migration
    version 6

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS nonces
      (
        nonce text,
        expire text,
        CONSTRAINT nonces_id_key UNIQUE (nonce)
      );
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS nonces_nonce_idx
        ON nonces
        (nonce);
      SQL
    end
  end
end
