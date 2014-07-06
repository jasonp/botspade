############################################################################
# Bot Spade SQLite3
helpers do
  # Lets open up Sqlite3 Database
  @db = SQLite3::Database.new "botspade.db"

  # Initial Tables - points / checkin / viewers / games / bets
  # We will generate a custom user table so we have a relational ID for other tables.
  @db.execute "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, points INT, first_seen BIGINT, last_seen BIGINT)"
  @db.execute "CREATE UNIQUE INDEX IF NOT EXISTS username ON users (username)"

  # Each checkin will have its own row, With related ID from users table and timestamp of when.
  @db.execute "CREATE TABLE IF NOT EXISTS checkins (id INTEGER PRIMARY KEY, user_id INT, timestamp BIGINT)"
  # Change win (1) / lose (2) / tie (3) to INTs for database optimisation.
  @db.execute "CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, status TINYINT, timestamp BIGINT)"


  def db_user_generate(username)
    user = @db.execute( "SELECT id, points FROM users WHERE username = ? LIMIT 1", [username] ).first
    if (user)
       return user
    else
      begin
        @db.execute( "INSERT INTO users ( username, points, first_seen, last_seen ) VALUES ( ?, ?, ?, ? )", [username, 0, Time.now.to_i, Time.now.to_i])
        return [@db.last_insert_row_id, 0]
      rescue SQLite3::Exception => e
      end
    end
  end

  def db_checkins_get(user_id)
    checkin = @db.execute( "SELECT timestamp FROM checkins WHERE user_id = ? LIMIT 1", [user_id] ).first

    if !checkin or Time.now.to_i >= checkin[0].to_i + 43200 # 12hours
      @db.execute( "INSERT INTO checkins ( user_id, timestamp ) VALUES ( ?, ? )", [user_id, Time.now.to_i])
      return true
    else
      return false
    end
  end

  def db_checkins_save(user)
    @db.execute( "UPDATE users SET points = ? WHERE id = ?", [user[1], user[0]] )
  end

  def db_checkins(limit)
    checkins = @db.execute( "SELECT u.username, COUNT(1) as count FROM checkins AS c JOIN users AS u ON u.id = c.user_id GROUP BY user_id ORDER BY count DESC LIMIT ?", [limit] )
    return checkins
  end

  def db_points(limit)
    points = @db.execute( "SELECT username, points FROM users ORDER BY points DESC LIMIT ?", [limit] )
    return points
  end

  def db_user_checkins_count(user_id)
    checkin = @db.execute( "SELECT COUNT(1) FROM checkins WHERE user_id = ?", [user_id] ).first
    return checkin[0]
  end

end
