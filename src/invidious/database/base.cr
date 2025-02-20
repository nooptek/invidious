require "pg"
require "sqlite3"

module Invidious::Database
  extend self

  # Checks table integrity
  #
  # Note: config is passed as a parameter to avoid complex
  # dependencies between different parts of the software.
  def check_integrity(cfg)
    return if !cfg.check_tables

    Invidious::Database.check_table("channels", InvidiousChannel)
    Invidious::Database.check_table("channel_videos", ChannelVideo)
    Invidious::Database.check_table("playlists", InvidiousPlaylist)
    Invidious::Database.check_table("playlist_videos", PlaylistVideo)
    Invidious::Database.check_table("nonces", Nonce)
    Invidious::Database.check_table("session_ids", SessionId)
    Invidious::Database.check_table("users", User)
    Invidious::Database.check_table("videos", Video)

    if cfg.cache_annotations
      Invidious::Database.check_table("annotations", Annotation)
    end
  end

  #
  # Table/enum integrity checks
  #

  def check_table(table_name, struct_type = nil)
    # Create table if it doesn't exist
    begin
      PG_DB.exec("SELECT * FROM #{table_name} LIMIT 0")
    rescue ex
      LOGGER.info("check_table: check_table: CREATE TABLE #{table_name}")

      sql = File.read("#{SQL_DATA_DIR}/sql/#{table_name}.sql")
      PG_DB.using_connection do |conn|
        case conn
        when PG::Connection
          conn.exec_all(sql)
        when SQLite3::Connection
          sql = sql.gsub(/\bUNLOGGED\b/i, "TEMP")
          conn.exec(sql)
        else
          raise "Unsupported DB engine"
        end
      end
    end

    return if !struct_type

    struct_array = struct_type.type_array
    column_array = get_column_array(PG_DB, table_name)
    column_types = File.read("#{SQL_DATA_DIR}/sql/#{table_name}.sql").match(/CREATE TABLE #{table_name}\n\((?<types>[\d\D]*?)\);/)
      .try &.["types"].split(",").map(&.strip).reject &.starts_with?("CONSTRAINT")

    return if !column_types

    struct_array.each_with_index do |name, i|
      if name != column_array[i]?
        if !column_array[i]?
          new_column = column_types.select(&.starts_with?(name))[0]
          LOGGER.info("check_table: ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
          PG_DB.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
          next
        end

        # Column doesn't exist
        if !column_array.includes? name
          new_column = column_types.select(&.starts_with?(name))[0]
          PG_DB.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
        end

        # Column exists but in the wrong position, rotate
        if struct_array.includes? column_array[i]
          until name == column_array[i]
            new_column = column_types.select(&.starts_with?(column_array[i]))[0]?.try &.gsub("#{column_array[i]}", "#{column_array[i]}_new")

            # There's a column we didn't expect
            if !new_column
              LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]}")
              PG_DB.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

              column_array = get_column_array(PG_DB, table_name)
              next
            end

            LOGGER.info("check_table: ALTER TABLE #{table_name} ADD COLUMN #{new_column}")
            PG_DB.exec("ALTER TABLE #{table_name} ADD COLUMN #{new_column}")

            LOGGER.info("check_table: UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")
            PG_DB.exec("UPDATE #{table_name} SET #{column_array[i]}_new=#{column_array[i]}")

            LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
            PG_DB.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")

            LOGGER.info("check_table: ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")
            PG_DB.exec("ALTER TABLE #{table_name} RENAME COLUMN #{column_array[i]}_new TO #{column_array[i]}")

            column_array = get_column_array(PG_DB, table_name)
          end
        else
          LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
          PG_DB.exec("ALTER TABLE #{table_name} DROP COLUMN #{column_array[i]} CASCADE")
        end
      end
    end

    return if column_array.size <= struct_array.size

    column_array.each do |column|
      if !struct_array.includes? column
        LOGGER.info("check_table: ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
        PG_DB.exec("ALTER TABLE #{table_name} DROP COLUMN #{column} CASCADE")
      end
    end
  end

  def get_column_array(db, table_name)
    column_array = [] of String
    PG_DB.query("SELECT * FROM #{table_name} LIMIT 0") do |rs|
      rs.column_count.times do |i|
        column_array << case rs
        when SQLite3::ResultSet then rs.column_name(i)
        when PG::ResultSet then rs.field(i).name
        else raise "Invalid DB result type"
        end
      end
    end

    return column_array
  end
end
