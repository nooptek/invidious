module Invidious::Database::Migrations
  class MakeVideosUnlogged < Migration
    version 10

    def up(conn : DB::Connection)
      return if conn.is_a?(SQLite3::Connection)

      conn.exec <<-SQL
      ALTER TABLE videos SET UNLOGGED;
      SQL
    end
  end
end
