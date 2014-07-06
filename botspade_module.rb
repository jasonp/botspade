############################################################################
# Bot Spade SQLite3
helpers do
  def db_user_generate(username)
    user = @db.execute( "SELECT id, points FROM users WHERE username = ? LIMIT 1", [username] ).first
    if (user)
       return {'id' => user[0], 'points' => user[1]}
    else
      begin
        @db.execute( "INSERT INTO users ( username, points, first_seen, last_seen ) VALUES ( ?, ?, ?, ? )", [username, 0, Time.now.utc.to_i, Time.now.utc.to_i])
        return {'id' => @db.last_insert_row_id, 'points' => 0}
      rescue SQLite3::Exception => e
      end
    end
  end

  def db_checkins_get(user_id)
    checkin = @db.execute( "SELECT timestamp FROM checkins WHERE user_id = ? ORDER BY timestamp DESC LIMIT 1", [user_id] ).first
    time_now = Time.now.utc.to_i
    if !checkin or Time.now.utc.to_i > checkin[0].to_i + (60 * 60 * 12) # 12hours
      @db.execute( "INSERT INTO checkins ( user_id, timestamp ) VALUES ( ?, ? )", [user_id, Time.now.utc.to_i])
      return true
    else
      return false
    end
  end

  def db_checkins_save(user_id, points)
    @db.execute( "UPDATE users SET points = ? WHERE id = ?", [points, user_id] )
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
