############################################################################
# Bot Spade SQLite3
helpers do
  def db_user_generate(protoname)
    username = protoname.downcase
    puts "#{username}" #debug
    user = @db.execute( "SELECT id, points FROM users WHERE username = ? LIMIT 1", [username] ).first
    if (user)
      puts "#{user}" #debug
       return {'id' => user[0], 'points' => user[1]}
    else
      begin
        @db.execute( "INSERT INTO users ( username, points, first_seen, last_seen ) VALUES ( ?, ?, ?, ? )", [username, 0, Time.now.utc.to_i, Time.now.utc.to_i])
        return {'id' => @db.last_insert_row_id, 'points' => 0}
      rescue SQLite3::Exception => e
      end
    end
  end

  #
  # WRITE USER function
  #
  def write_user(protoname)
    username = protoname.downcase
    puts "writing #{username}" #debug
    begin
      @db.execute( "INSERT INTO users ( username, points, first_seen, last_seen ) VALUES ( ?, ?, ?, ? )", [username, 0, Time.now.utc.to_i, Time.now.utc.to_i])
      return true
    rescue SQLite3::Exception => e
    end
  end


  #
  # GET USER function
  # result is an array: user[0] = id, user[1] = username, user[2] = points, 
  # user[3] = first_seen, user[4] = last_seen, user[5] = profile, user[6] = admin
  #
  def get_user(protoname)
    username = protoname.downcase
    puts "getting #{username}" #debug
    user = @db.execute( "SELECT * FROM users WHERE username LIKE ?", [username] ).first
    if (user)
      return user
    else
      puts "#{username} not found in db"
      return nil
    end
  end
  
  def get_user_by_id(user_id)
    puts "getting user number #{user_id}" #debug
    user = @db.execute( "SELECT * FROM users WHERE id = ?", [user_id] ).first
    if (user)
      return user
    else
      puts "#{user_id} not found in db"
      return nil
    end
  end
  
  #
  # Get win/loss function
  # returns an array: wins_losses, [0] = wins, [1] = losses, [2] = ties, [3] = ratio
  #
  def get_wins_losses
    wins = @db.execute( "SELECT COUNT(1) FROM games WHERE status = ?", 1 ).first
    puts "#{wins}"
    losses = @db.execute( "SELECT COUNT(1) FROM games WHERE status = ?", 2 ).first
    ties = @db.execute( "SELECT COUNT(1) FROM games WHERE status = ?", 3 ).first
    ratio = wins[0].to_f / losses[0].to_f
    wins_losses = []
    wins_losses << wins << losses << ties << ratio
    return wins_losses
  end

  def db_set_game(status)
    return true if @db.execute( "INSERT INTO games ( status, timestamp ) VALUES ( ?, ? )", [status, Time.now.utc.to_i])
  end
  
  # DB fucntions for betting
  # bet[0] = id, [1] = user_id, [2] = bet (0/1/2), [3] = bet_amount, [4] = result (was the bet a winner), [5] = timestamp
  
  def db_create_bet(user_id, bet, bet_amount, result)
    return true if @db.execute( "INSERT INTO bets ( user_id, bet, bet_amount, result, timestamp ) VALUES ( ?, ?, ?, ?, ? )", [user_id, bet, bet_amount, result, Time.now.utc.to_i])
  end

  def db_set_bet(bet_id, result)
    @db.execute( "UPDATE bets SET result = ? WHERE id = ?", [result, bet_id] )
  end

  def db_get_latest_bet_from_user(user_id)
    bet = @db.execute( "SELECT * FROM bets WHERE user_id = ? ORDER BY timestamp DESC LIMIT 1", [user_id] ).first
    if (bet)
      puts "#{bet}"
      return bet
    else
      puts "#{user_id} not found in bets db"
      return nil
    end
  end
  
  def db_get_all_open_bets
    bets = @db.execute( "SELECT * FROM bets WHERE result = ?", [0] )
    if (bets)
      puts "#{bets}"
      return bets
    else
      puts "None found in db"
      return nil
    end
  end
  
  def db_get_all_bets_from_user(user_id)
    bets = @db.execute( "SELECT * FROM bets WHERE user_id = ?", [user_id] )
    if (bets)
      puts "#{bets}"
      return bets
    else
      puts "#{user_id} not found in bets db"
      return nil
    end
  end
  
  # Some checkins fucntions
  #

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
  

  
  # Get & Set user profile info
  #
  
  def db_set_profile(user_id, protoprofile)
    profile = JSON.generate(protoprofile)
    return TRUE if @db.execute( "UPDATE users SET profile = ? WHERE id = ?", [profile, user_id] )
  end
  
  def db_get_profile(user_id)
    profile = @db.execute( "SELECT profile FROM users WHERE id = ?", [user_id] )
    puts "Profile: #{profile[0]}"
    if (profile[0][0]) && profile[0][0] != ""
      result = JSON.parse(profile[0][0])
      puts "hash: #{result}"
      return result
    else
      return nil
    end
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
