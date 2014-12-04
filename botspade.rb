############################################################################
#
#   BotSpade
#
#   Copyright (c) 2014 by Jason Preston under MIT License
#   A Twitch Chat Bot
#   Version 1.0 - 10/17/2014
#
#   Feel free to use for your own nefarious purposes

require 'isaac'
require 'json'
require 'sqlite3'
require "./botconfig"
require './db_module'

require 'net/http'



on :connect do  # initializations
  join @botchan

  # Lets open up Sqlite3 Database
  @db = SQLite3::Database.new "botspade.db"

  # Initial Tables - points / checkin / viewers / games / bets
  #
  # We will generate a custom user table so we have a relational ID for other tables.
  @db.execute "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, points INT, first_seen BIGINT, last_seen BIGINT, profile TEXT, admin INT)"
  @db.execute "CREATE UNIQUE INDEX IF NOT EXISTS username ON users (username)"

  # Each checkin will have its own row, With related ID from users table and timestamp of when.
  @db.execute "CREATE TABLE IF NOT EXISTS checkins (id INTEGER PRIMARY KEY, user_id INT, timestamp BIGINT)"
  # Change win (1) / lose (2) / tie (3) to INTs for database optimisation.
  @db.execute "CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, status TINYINT, timestamp BIGINT)"

  # Create a DB table that tracks bets. bet: 1 - win / 2 - loss / 3 - tie. result: 0 - no result yet, 
  # 1 - correct bet, 2 - incorrect bet
  @db.execute "CREATE TABLE IF NOT EXISTS bets (id INTEGER PRIMARY KEY, user_id INT, bet INT, bet_amount INT, result INT, timestamp BIGINT)"
  
  # Create a table for custom user-generated call and response.
  @db.execute "CREATE TABLE IF NOT EXISTS commands (id INTEGER PRIMARY KEY, command TEXT, response TEXT, timestamp BIGINT)"
  
  # Create a table for custom user-generated items.
  @db.execute "CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT, description TEXT, price INT, ownable INT, timestamp BIGINT)"
  @db.execute "CREATE TABLE IF NOT EXISTS inventory (id INTEGER PRIMARY KEY, user_id INT, item_id INT, timestamp BIGINT)"
  @db.execute "CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY, item_id INT, timestamp BIGINT)"

  # Create a table for initializations and options/settings.
  @db.execute "CREATE TABLE IF NOT EXISTS options (id INTEGER PRIMARY KEY, option TEXT, value TEXT, timestamp BIGINT)"

  #####################
  #
  # Migration Manager - poor man's attempt to make upgrading painless
  # Any DB changes/upgrades from 9/29/2014 -> go in this section & must reference a migration point
  #
  #
  
  @migration_level = db_get_migration_level
  if @migration_level < 1
    
    # Fill options table with first info
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["migration", "1", Time.now.utc.to_i])
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["checkin_points", @checkin_points.to_s, Time.now.utc.to_i])
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["bets_auto_close_in", @bets_auto_close_in.to_s, Time.now.utc.to_i])
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["talkative", @talkative.to_s, Time.now.utc.to_i])

    # bugfix on items & inventory
    @db.execute "ALTER TABLE items ADD COLUMN live TEXT;"
  end
  
  puts "check migration level: #{@migration_level}"
  if @migration_level < 2  # how is this not true??
    puts "migration level less than 2"
    # Create a table for raffles
    @db.execute "CREATE TABLE IF NOT EXISTS raffles (id INTEGER PRIMARY KEY, keyword TEXT, status TEXT, winner TEXT, users TEXT, timestamp BIGINT)"
    @db.execute( "UPDATE options SET value = ? WHERE option = ?", [2, "migration"] )
    
  end
  
  puts "check migration level: #{@migration_level}"
  if @migration_level < 3 
    puts "migration level less than 3"
    # Add more options to the options table - 11/4/2014
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["idle_points", 2, Time.now.utc.to_i])
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["idle_interval", 5, Time.now.utc.to_i])
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["enable_idle_points", "true", Time.now.utc.to_i])
    @db.execute( "INSERT INTO options ( option, value, timestamp ) VALUES ( ?, ?, ? )", ["last_points_issued_at", Time.now.utc.to_i, Time.now.utc.to_i])
    
    # beginning to track time on stream
    @db.execute "ALTER TABLE users ADD COLUMN streamtime INT;"
    
    @db.execute( "UPDATE options SET value = ? WHERE option = ?", [3, "migration"] )
    
  end
  

  # Toggle whether or not bets are allowed
  @betsopen = FALSE

  # Set initial uptime
  @stream_start_time = "none"
  
  # Calculate the streamer's name, for initial admin
  @streamer = @botchan.to_s
  @streamer[0] = ''

  # Raffle in memory
  @current_raffle_users = []


end

############################################################################
#
# Helpers
#

helpers do

  # An expensive way to pretend like I have a daemon
  # check for latent processes and execute them
  def fake_daemon
    
    # The toggle bets timer
    @timegap = @bets_auto_close_in * 60
    if Time.now.utc.to_i > @betstimer.to_i + @timegap.to_i && @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Bets are now closed. GL."
    end
    
  end

  def take_points(person, points)
    # Newer Fancy Way
    user = get_user(person)
    if (user)
      newpoints = user[2] - points
      db_checkins_save(user[0], newpoints)
    end
  end

  def give_points(person, points)
    # Newer Fancy Way
    user = get_user(person)
    if (user)
      newpoints = user[2] + points
      db_checkins_save(user[0], newpoints) 
    end  
  end

  def person_has_enough_points(nick, points_required)
    # Newer Fancy Way
    user = get_user(nick)
    if (user)
      if user[2] < points_required
        return FALSE
      else
        return TRUE
      end
    else
      return FALSE
    end
  end
  
  def item_is_ownable?(item)
    return true if item[4] == 1
  end
  
  def bet_converts_to_number(string)
    if string == "win"
      return 1 
    elsif string == "loss"
      return 2
    elsif string == "tie"
      return 3
    else 
      return false
    end
  end

  def pretty_uptime
    if @stream_start_time == "none"
      return 0
    else
      uptime = Time.now.utc.to_i - @stream_start_time.to_i
      if uptime < 60
        return "#{uptime} seconds"
      elsif uptime > 60 && uptime < 3600
        uptime_in_minutes = uptime / 60
        return "#{uptime_in_minutes} minutes"
      elsif uptime > 3600 && uptime < 86400
        uptime_in_hours = uptime / 3600
        calc_remainder = uptime_in_hours.to_i * 3600
        remainder = uptime - calc_remainder
        remainder_in_minutes = remainder / 60
        return "#{uptime_in_hours.to_i} hours and #{remainder_in_minutes} minutes"
      else
        return "#{uptime} seconds"
      end
    end
  end
  
  # Ugly, not-DRY, arg:
  def make_pretty_time(time_in_seconds)
    if time_in_seconds < 60
      return "#{time_in_seconds} seconds"
    elsif time_in_seconds > 60 && time_in_seconds < 3600
      time_in_minutes = time_in_seconds / 60
      return "#{time_in_minutes} minutes"
    elsif time_in_seconds > 3600 && time_in_seconds < 999999999
      time_in_hours = time_in_seconds / 3600
      calc_remainder = time_in_hours.to_i * 3600
      remainder = time_in_seconds - calc_remainder
      remainder_in_minutes = remainder / 60
      return "#{time_in_hours.to_i} hours and #{remainder_in_minutes} minutes"
    else
      return "#{uptime} seconds"
    end
  end

  def user_is_an_admin?(user)
    puts "checking admin for: #{@streamer}"
    check_this_user = get_user(user)
    if (check_this_user)
      if (check_this_user[6] == 1) || user == @streamer
        return true
      else
        return false
      end
    end
  end
  
  def talkative?
    if @talkative == true
      return true
    else
      return false
    end
  end
  
  def respond_to_commands(message)
    commands = db_get_all_commands
    if (commands)
      commands.each do |command|
        if message == command[1]
          response = command[2]
          msg channel, "#{response}"
        end
      end
    end
    
  end
  
  def check_for_raffle_entry(message, nick)
    raffle = db_get_latest_raffle
    if (raffle)
      if raffle[2] == "live"
        if message == raffle[1]
          if !@current_raffle_users.include?(nick)
            @current_raffle_users << nick
            db_set_raffle_users(@current_raffle_users, raffle[0])
          end
        elsif message == "!pass"
          if raffle[3] == nick
            potential_winners = @current_raffle_users
            potential_winners.delete(nick)
            winner = potential_winners.sample
            db_set_raffle_winner(winner, raffle[0])
            msg channel, "Redrawing... the new winner is #{winner}! (type !pass to pass or !accept to win)"
          end
        elsif message == "!accept"
          if raffle[3] == nick
            db_set_raffle_status("closed", raffle[0])
            @current_raffle_users = nil
            msg channel, "Winner confirmed and recorded for posterity. The raffle is now closed. "
          end        
        end
      end #live raffle check
    end # check for non-nil
  end
  
  def get_all_users_in_channel
    url_string = "https://tmi.twitch.tv/group/user/"+ @streamer + "/chatters"
    puts url_string
    result = Net::HTTP.get(URI.parse(url_string))
    parsed = JSON.parse(result)

    all_users_in_channel = []
    parsed["chatters"]["moderators"].each do |p|
      all_users_in_channel << p
    end
    parsed["chatters"]["viewers"].each do |p|
      all_users_in_channel << p
    end
    
    puts "Users here:" + all_users_in_channel.to_s
    return all_users_in_channel
  end
  
  def give_idle_points_and_track_stream_time
    
    # variables:
    last_points_issued_at = db_get_option("last_points_issued_at").first.to_i
    interval = db_get_option("idle_interval").first.to_i * 60
    points_to_give = db_get_option("idle_points").first.to_i
    gateway = last_points_issued_at + interval
    
    # how long ago did we give points?
    time_since_last_points = Time.now.utc.to_i - last_points_issued_at
    
    # if NOW is BIGGER than the gateway...
    if Time.now.utc.to_i > gateway
      puts "time to update idle points & timers"
      all_users_in_channel = get_all_users_in_channel
    
      all_users_in_channel.each do |u|
        user = get_user(u)
        if user == nil
          puts "created new user: #{u}" if write_user(u)
        end # check for user in DB
        if db_get_option("enable_idle_points").first == "true"
          give_points(u, points_to_give)
          puts "#{points_to_give} idle points given to #{u}" 
        end 
        streamtime = db_get_streamtime(u).first || 0
        new_streamtime = streamtime.to_i + time_since_last_points.to_i
        puts "updated streamtime for #{u}" if db_update_streamtime(new_streamtime, u)
      end # all users loop
      
      # now SET the freaking last_points_issued_at time
      db_set_option(Time.now.utc.to_i, "last_points_issued_at")
      
    end # timer check

  end
  
end


############################################################################
#
# Adding and removing user commands to the DB
#

on :channel, /^!addcommand/i do 
  if user_is_an_admin?(nick)
    newmessage = message.gsub("!addcommand ", "")
    new_command = newmessage.split(' ')[0].downcase
    response = newmessage.split(' ').drop(1).join(' ')
    msg channel, "success" if db_set_command(new_command, response)
  end 
end

on :channel, /^!removecommand/i do
  if user_is_an_admin?(nick)
    newmessage = message.gsub("!removecommand ", "")
    command_to_remove = newmessage.split(' ')[0].downcase
    puts "#{command_to_remove}"
    command = db_get_command(command_to_remove)[0]
    puts "about to delete command"
    msg channel, "success" if db_remove_command(command[0])  
  end
end


############################################################################
#
# Adding and removing user item "specials" to the DB
#

on :channel, /^!addspecial/i do 
  if user_is_an_admin?(nick)
    newmessage = message.gsub("!addspecial ", "")
    new_item = newmessage.match(/\[.*\]/i).to_s
    item_description_and_price = newmessage.gsub(new_item + " ", "")    
    new_item_price = item_description_and_price.split(' ')[0]
    item_description = item_description_and_price.gsub(new_item_price + " ", "")
    msg channel, "success" if db_set_item(new_item, item_description, new_item_price, 0, "true")
  end
end

on :channel, /^!addspecial$/i do 
  if user_is_an_admin?(nick)
    msg channel, "Use: !addspecial [Fedora] 20 Force Spade to wear a fedora for the rest of this stream. Items must have [] around them."
  end
end


on :channel, /^!removespecial/i do
  if user_is_an_admin?(nick)  
    newmessage = message.gsub("!removespecial ", "")
    special_to_remove = newmessage.match(/\[.*\]/i).to_s
    puts "finding #{special_to_remove}"
    item = db_get_item(special_to_remove)
    if (item)
      puts "#{item}"
      msg channel, "success" if db_remove_item(item[0])  
    else
      puts "no item to remove"
    end
  end
end

############################################################################
#
# Adding and removing user item "items" to the DB
#

on :channel, /^!additem/i do 
  if user_is_an_admin?(nick)
    newmessage = message.gsub("!additem ", "")
    new_item = newmessage.match(/\[.*\]/i).to_s
    item_description_and_price = newmessage.gsub(new_item + " ", "")    
    new_item_price = item_description_and_price.split(' ')[0]
    item_description = item_description_and_price.gsub(new_item_price + " ", "")
    msg channel, "success" if db_set_item(new_item, item_description, new_item_price, 1, "true")
  end
end

on :channel, /^!additem$/i do 
  if user_is_an_admin?(nick)
    msg channel, "Use: !additem [Fedora] 20 Force Spade to wear a fedora for the rest of this stream. Items must have [] around them."
  end
end


on :channel, /^!removeitem/i do
  if user_is_an_admin?(nick)  
    newmessage = message.gsub("!removeitem ", "")
    item_to_remove = newmessage.match(/\[.*\]/i).to_s
    puts "finding #{item_to_remove}"
    item = db_get_item(item_to_remove)
    if (item)
      puts "#{item}"
      msg channel, "success" if db_remove_item(item[0])  
    else
      puts "no item to remove"
    end
  end
end



############################################################################
#
# Dynamic item shop / some will have to be presets
# Items are surrounded by [], e.g. [Spade's Fedora]
#

on :channel, /^!shop (.*)/i do |first|
  item_name = first.downcase
  item = db_get_item(item_name)
  if (item)
    msg channel, "#{item[1]}: #{item[2]}"
  end
end

on :channel, /^!shop$/i do
  if talkative?
    item_list = db_get_all_items
    item_names = []
    item_list.each do |item|
      store_listing = item[1].to_s + " (" + item[3].to_s + "pts)" 
      item_names << store_listing if item[6] == "true"
    end
    store_inventory = item_names.join(', ')
    msg channel, "Shop menu: #{store_inventory} (use !shop [item] for more info)"
  else
    msg channel, "Shop is closed."
  end
end

on :channel, /^!buy (.*)/i do |first|
  item_name = first.downcase
  item = db_get_item(item_name)
  user = get_user(nick)
  if (user)
    if (item)
      if person_has_enough_points(nick, item[3].to_i)
        take_points(nick, item[3].to_i)
        puts "adding #{item[0]} to #{user[0]} user inventory"
        db_add_item_to_inventory(user[0], item[0]) if item_is_ownable?(item)
        db_add_item_to_queue(item[0]) unless item_is_ownable?(item)
        msg channel, "#{nick} has purchased #{item[1]}." if talkative?
      end
    end #  item
  end #  user
end

############################################################################
#
# Managing the queue
#

on :channel, /^!queue/i do
  if user_is_an_admin?(nick)
    queue = db_get_queue
    the_queue = ""
    if (queue)
      queue.each do |item|
        the_item = db_get_item_by_id(item[1])
        puts "Db found: #{the_item[1]}"
        the_queue << the_item[1].to_s + " "
      end
      msg channel, "In the queue: #{the_queue}"
    end
  end
end

on :channel, /^!popq$/i do
  if user_is_an_admin?(nick)
    queue = db_get_queue
    if (queue)
      queue_entry_id = queue[-1][0]
      db_remove_item_from_queue(queue_entry_id)
      msg channel, "Removed last item from queue."
    end
  end
end

############################################################################
#
# Raffles
#

on :channel, /^!raffle (.*)/i do |first|
  if user_is_an_admin?(nick)
    key = first.downcase
    # are we drawing a winner?
    if key == "draw"
      raffle = db_get_latest_raffle
      if (raffle)
        potential_winners = @current_raffle_users
        winner = potential_winners.sample
        db_set_raffle_winner(winner, raffle[0])
        msg channel, "he total, honest-to-God, completely and utterly randomly selected winner is #{@botmaster}. Oh, oops, *ahem* Just Kidding.. it’s #{winner}! (type !pass to pass or !accept to win)"
      end
    else
      if db_set_raffle(key, "live", "")
        msg channel, "Raffle created. Type #{key} to enter the Raffle!"
      end
    end #check for "draw"
  end
end

on :channel, /^!raffle$/i do
  msg channel, "Admin can create a raffle, e.g.: !raffle !keyword"
end

############################################################################
#
# Idling Points
#

on :channel, /^!idlepoints (.*)/i do |first|
  if user_is_an_admin?(nick)
    points_to_set = first
    interval = db_get_option("idle_interval").first
    if db_set_option(points_to_set, "idle_points")
      msg channel, "Users will get #{points_to_set} #{@botmaster} Points every #{interval} minutes"
    end
  end
end

on :channel, /^!idlepoints$/i do
  points = db_get_option("idle_points").first
  interval = db_get_option("idle_interval").first
  msg channel, "Users in chat get #{points} points every #{interval} minutes."
end

on :channel, /^!interval (.*)/i do |first|
  if user_is_an_admin?(nick)
    interval_for_points = first
    points = db_get_option("idle_points").first
    if db_set_option(interval_for_points, "idle_interval")
      msg channel, "Users will get #{points} #{@botmaster} Points every #{interval_for_points} minutes"
    end
  end
end

on :channel, /^!interval$/i do
  points = db_get_option("idle_points").first
  interval = db_get_option("idle_interval").first
  msg channel, "Users in chat get #{points} points every #{interval} minutes."
end

## NOT WORKING YET

on :channel, /^!toggleidle/i do
  if user_is_an_admin?(nick)
    points_enabled = db_get_option("enable_idle_points").first
    puts "#{points_enabled}"
    if points_enabled == "true"
      db_set_option("false", "enable_idle_points")
      msg channel, "Idle points disabled"
    else
      db_set_option("true", "enable_idle_points")
      msg channel, "Idle points enabled"
    end  
  end
end


############################################################################
#
# Basic Call & Response presets, toggles
#

on :channel, /^!changelog/i do
  msg channel, "v1.0: Added raffles, fixed some bugs"
end


on :channel, /^!madeby/i do
  msg channel, "#{@botmaster} uses BotSpade by http://twitch.tv/watchspade. Get your own bot: http://github.com/jasonp/botspade"
end

on :channel, /^!makeadmin (.*)/i do |first|
  if user_is_an_admin?(nick)
    user_to_make_admin = first.downcase
    user = get_user(user_to_make_admin)
    admin_value = 1  
    if (user)
      if set_user_admin_value(admin_value, user[0])
        msg channel, "success"
      end
    end
  end
end

on :channel, /^!list$/i do
  if talkative?
    if user_is_an_admin?(nick)
      commands = db_get_all_commands
      if (commands)
        list_of_commands = []
        commands.each do |command|
          list_of_commands << command[1] + " "
        end
        msg channel, "#{list_of_commands}"
      end
    end
  end
end

on :channel, /^!removeadmin (.*)/i do |first|
  if user_is_an_admin?(nick)
    user_to_make_admin = first.downcase
    user = get_user(user_to_make_admin)
    admin_value = 0  
    if (user)
      if set_user_admin_value(admin_value, user[0])
        msg channel, "success"
      end
    end
  end
end

on :channel, /^!talkative/i do
  if user_is_an_admin?(nick)
    if @talkative == true
      @talkative = false
      msg channel, "Talkative mode off."
    else
      @talkative = true
      msg channel, "Talkative mode on."
    end
  end
end

on :channel, /^!stats$/i do
  wins_losses = get_wins_losses
  wincount = wins_losses[0]
  losscount = wins_losses[1]
  tiecount = wins_losses[2]
  wlratio = wins_losses[3]
  msg channel, "#{@botmaster} has reported #{wincount} wins, #{losscount} losses, and #{tiecount} ties. W/L ratio: #{wlratio}"
end

on :channel, /^!inventory/i do
  user = get_user(nick)
  if (user)
    inventory = db_get_inventory_for(user[0])
    if (inventory)
      inventory_string = ""
      inventory.each do |i|
        item = db_get_item_by_id(i[2])
        inventory_string << item[1] + " "
      end
      msg channel, "Inventory for #{nick}: #{inventory_string}"
    end
  end
end

############################################################################
#
# Uptime
#

on :channel, /^!startstream/i do
  if user_is_an_admin?(nick)
    @stream_start_time = Time.now.utc
    msg channel, "Stream started."
  end
end

on :channel, /^!endstream/i do
  if user_is_an_admin?(nick)
    @stream_start_time = "none"
    msg channel, "Stream ended."
  end
end

on :channel, /^!uptime/i do
  @uptime_for_display = pretty_uptime
  if @uptime_for_display != 0
    msg channel, "#{@botmaster} has been streaming for #{@uptime_for_display}."
  else
    msg channel, "Whoops, #{@botmaster} forgot to start the timer! Starting it now..."
    @stream_start_time = Time.now.utc
  end
  
end

############################################################################
#
# Viewer DB
#

on :channel, /^!update (.*) (.*)/i do |first, second|
  attribute = first.downcase
  value = second.downcase
  user = get_user(nick)
  if (user)
    person_hash = db_get_profile(user[0])
    if (person_hash)
      person_hash[attribute] = value
      if db_set_profile(user[0], person_hash)
        msg channel, "#{attribute} updated for #{nick}"
      end
    else
      person_hash = {}
      person_hash[attribute] = value
      if db_set_profile(user[0], person_hash)
        msg channel, "#{attribute} updated for #{nick}"
      end
    end
  else
    if write_user(nick)
      newuser = get_user(nick)
      person_hash = {}
      person_hash[attribute] = value
      if db_set_profile(newuser[0], person_hash)
        msg channel, "#{attribute} updated for #{nick}"
      end
    end
  end

end

on :channel, /^!update$/i do
  msg channel, "Add info to your file in the Viewer db. Usage: !update [attribute] [value], e.g. !update country USA"
end

on :channel, /^!dump$/i do
  if user_is_an_admin?(nick)
    get_all_users_in_channel
    msg channel, "Dumped"
  end
end

on :channel, /^!lookup (.*) (.*)/i do |first, last|
  person = first.downcase
  attribute = last.downcase
  user = get_user(person)
  if (user)
    person_hash = db_get_profile(user[0])
    if attribute == "index"
      if (person_hash)
        person_array = person_hash.keys
        msg channel, "#{person}: #{person_array}"
      else
        msg channel, "#{person}: Empty profile!"
      end
    else 
      if (person_hash)
        if (person_hash[attribute])
          lookup_value = person_hash[attribute]
          msg channel, "#{person}: #{lookup_value}"
        else
          msg channel, "Sorry, nothing in the viewer database for that!" if talkative?
        end
      else
        msg channel, "#{person}: Empty profile!" if talkative?
      end # if person_hash
    end
  else
    msg channel, "Sorry, nothing in the viewer database for that!" if talkative?
  end
end

on :channel, /^!lookup$/i do
  msg channel, "Lookup other viewers. Usage: !lookup [username] [attribute]. You can also do !lookup [username] index to see what attributes are available."
end

on :channel, /^!remove (.*)/i do |first|
  attribute = first.downcase
  user = get_user(nick)  
  if (user)
    person_hash = db_get_profile(user[0])
    if (person_hash)
      if person_hash.delete(attribute)
        db_set_profile(user[0], person_hash)
        msg channel, "#{attribute} removed for #{nick}"
      else
        msg channel, "I don't see anything to remove!" if talkative?
      end
    end
  end
end

on :channel, /^!remove$/i do
  msg channel, "Remove info from your profile. Usage: !remove [attribute], e.g. !remove country"
end


############################################################################
#
# Dealing with betting
#

on :channel, /^!bet$/i do
  bet_status = ""
  if @betsopen == TRUE
    bet_status = "(Bets are open right now)"
  else
    bet_status = "(Bets are closed right now)"
  end
  msg channel, "Usage: !bet [points] [win/loss/tie] e.g. !bet 15 loss #{bet_status}"
end

on :channel, /^!bet (.*) (.*)/i do |first, last|
  
  bet_amount = first.to_i
  win_loss = last.downcase
  user = get_user(nick)
  if @betsopen == TRUE
    if first.to_f < 1
      msg channel, "Sorry, you can't bet in fractions/phrases... whole numbers only!"    
    else
      numerical_bet = bet_converts_to_number(win_loss)
      if (numerical_bet)
        if person_has_enough_points(nick, bet_amount)
          previous_bet = db_get_latest_bet_from_user(user[0]) if (db_get_latest_bet_from_user(user[0]))
          if (previous_bet) && previous_bet[4] == 0
            msg channel, "#{nick}: Bet Refused, You have already bet"
          else
            db_create_bet(user[0], numerical_bet, bet_amount, 0)
            take_points(nick, bet_amount)
            msg channel, "#{nick}: Bet recorded." if talkative?
          end
        else
          msg channel, "Whoops, #{nick} it looks like you don't have enough points!"
        end
      else
        msg channel, "You can only bet for: win, loss, tie. Check spelling!" 
      end #check for not win/loss/tie  
    end
  else
    msg channel, "Sorry, bets aren't open right now."
  end
end

on :channel, /^!reportgame (.*)/i do |first|
  if user_is_an_admin?(nick)
    protoresult = first.downcase
    total_won = 0
    winner_count = 0
    total_lost = 0
    number_of_bettors = 0
    report = bet_converts_to_number(protoresult)
    if (report)
      puts "game reported as #{report}"
      db_set_game(report)
      open_bets = db_get_all_open_bets
      if (open_bets)
        number_of_bettors = open_bets.count 
        open_bets.each do |open_bet|
          user = get_user_by_id(open_bet[1])
          if (user)
            puts "We found #{user[1]} betting"
            if open_bet[2] == report
              puts "they bet correctly"
              winnings = open_bet[3] * 2
              puts "they get #{winnings.to_s} points"
              total_won = total_won + winnings
              puts "total won is now #{total_won.to_s}"
              winner_count = winner_count + 1
              puts "winner count is #{winner_count.to_s}"
              give_points(user[1], winnings)
              db_set_bet(open_bet[0], 1)
            else
              puts "they bet incorrectly"
              total_lost = total_lost + open_bet[3]
              puts "total lost is #{total_lost.to_s}"
              db_set_bet(open_bet[0], 2)
            end 
          end # if user
        end # open bets loop
      end # if open_bets
    end # if report

    msg channel, "Bets tallied. #{total_won.to_s} #{@botmaster} Points won and #{total_lost.to_s} #{@botmaster} Points lost by #{number_of_bettors} gambler(s)."
  end
end

on :channel, /^!togglebets/i do
  if user_is_an_admin?(nick)
    if @betsopen == FALSE
      @betsopen = TRUE
      @betstimer = Time.now.utc
      msg channel, "Betting is now open for #{@bets_auto_close_in} minutes. Place your bets: !bet [points] [win/loss/tie]"
    elsif @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Betting is now closed. GL."
    end
  end
end

on :channel, /^!ratio/i do
  open_bets = db_get_all_open_bets
  number_of_win_bets = 0
  number_of_loss_bets = 0
  number_of_tie_bets = 0
  number_of_bets = open_bets.count
  if number_of_bets == 0
    msg channel, "There are no outstanding bets."
  else
    open_bets.each do |open_bet|
      if open_bet[2] == 1
        number_of_win_bets = number_of_win_bets + 1
      elsif open_bet[2] == 2
        number_of_loss_bets = number_of_loss_bets + 1
      elsif open_bet[2] == 3
        number_of_tie_bets = number_of_tie_bets + 1
      end    
    end
    win_bet_ratio = number_of_win_bets.to_f / number_of_bets.to_f * 100
    loss_bet_ratio = number_of_loss_bets.to_f / number_of_bets.to_f * 100
    tie_bet_ratio = number_of_tie_bets.to_f / number_of_bets.to_f * 100
    msg channel, "Bets ratio: #{win_bet_ratio}% bet win, #{loss_bet_ratio}% bet loss, #{tie_bet_ratio}% bet tie."
  end
end

# Method for users to give points to other viewers
# !give user points

on :channel, /^!give (.*) (.*)/i do |first, last|
  person = first.downcase
  points = last.to_i
  if points > 0 
    if user_is_an_admin?(nick)
      if get_user(person)
        if person == nick
          msg channel, "#{nick}, you can't give yourself points like this!"
        else
          give_points(person, points)
          msg channel, "#{nick} has given #{person} #{points} #{@botmaster} Points"
        end
      else
        msg channel, "You can only give points to someone who has checked in at least once!"
      end
    else
      if get_user(person)
          if person_has_enough_points(nick, points)
              give_points(person, points)
              take_points(nick, points)
              msg channel, "#{nick} has given #{person} #{points} #{@botmaster} Points"
          else
            msg channel, "I'm sorry #{nick}, you don't have enough #{@botmaster} Points!"
          end
      else
        msg channel, "You can only give points to someone who has checked in at least once!"
      end
    end
  end  
end

on :channel, /^!give$/i do
  msg channel, "Usage: !give [username] [points]."
end


# Method for Spade to take points from naughty viewers
# !take user points
on :channel, /^!take (.*) (.*)/i do |first, last|
  person = first.downcase
  points = last.to_i
  if user_is_an_admin?(nick) && points > 0
    take_points(person, points)
  end
end

# Deprecated and slated for removal in later version
#on :channel, /^!savedata/i do
#  if user_is_an_admin?(nick)
#    save_data
#  end
#end

############################################################################
#
# Referrals
#

on :channel, /^!referredby$/i do
  msg channel, "You & someone new each get 10 #{@botmaster} Points! New viewer must enter: !referredby [your username]"
end

on :channel, /^!referredby (.*)/i do |first|
  referrer = first.downcase
  user = get_user(nick)
  if (user)
     msg channel, "Hmm, looks like you've checked in here before! Sorry, you only get to be new once!"
  else
    if db_user_generate(nick)
      newuser = get_user(nick)
      if (newuser)
        if db_checkins_get(newuser[0])
          total_checkins = db_user_checkins_count(newuser[0])
          points_for_checking_in = 10 + @checkin_points
          give_points(nick, points_for_checking_in)
          give_points(referrer, 10)
          msg channel, "Welcome #{nick}! You & #{referrer} have been awarded 10 #{@botmaster} Points! You have also been checked in for 4 #{@botmaster} Points."
        end
      end # if newuser
    end # user_generate
  end # if user
end

############################################################################
#
# The Spade Points Store
#
#
# Deprecating...

#on :channel, /^!purchase (.*)/i do |protopurchase|
#  purchase = protopurchase.downcase
#  if purchase == "fedora"
#    if person_has_enough_points(nick, 20)
#      take_points(nick, 20)
#      msg channel, "#{nick} has forced #{@botmaster} to wear a Fedora for the rest of this stream. [-20sp]"
#    else
#      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
#    end
# elsif purchase == "bdp"
#    if person_has_enough_points(nick, 10)
#      take_points(nick, 10)
#      msg channel, "#{nick} has demanded that Spade make a Big Dick Play. Here goes nothing. [-10sp]"
#    else
#      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
#    end
#  elsif purchase == "suit"
#    if person_has_enough_points(nick, 10)
#     take_points(nick, 10)
#      msg channel, "#{nick} has bribed Spade to wear a suit for the rest of this stream. Oh boy. [-100sp]"
#   else
#      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
#    end
#  elsif purchase == "menu"
#    msg channel, "SpadeStore Menu: !fedora (20sp - Spade wears fedora), !bdp (10sp - Spade tries a big dick play), #suit (100sp - Spade wears a suit)"
#  end
#end

on :channel, /^!purchase$/i do
  msg channel, "New - use !shop"
end

# Elaborate on what you can buy

#on :channel, /^!fedora/i do
#  msg channel, "You can make #{@botmaster} wear a fedora by spending 20 #{@botmaster} Points. Type !purchase fedora #to activate."
#end

#on :channel, /^!suit/i do
#  msg channel, "You can make #{@botmaster} wear a suit by spending 100 #{@botmaster} Points. Type !purchase suit to #activate."
#end

#on :channel, /^!bdp/i do
#  msg channel, "BDP stands for Big Dick Play. You can make #{@botmaster} attempt a BDP for 10 points with !purchase bdp"
#end

# Method to give points for chat activity
# Check to see if points have been given yet today

# The Rewrites for database on functions below.
on :channel, /^!checkin/i do
  user = get_user(nick)
  if (user)
    if db_checkins_get(user[0]) # hasn't checked in in past 12 hrs
      give_points(nick, @checkin_points)
      total_checkins = db_user_checkins_count(user[0])
      if total_checkins == 50
        msg channel, "#{nick} this is your 50th check-in! You Rock (and get 50 points)"
        give_points(nick, 50)
      else
        msg channel, "Thanks for checking in, #{nick}! You have been given #{@checkin_points} #{@botmaster} Points! [Total check-ins: #{total_checkins}]"
      end  
    else
      msg channel, "#{nick} checked in already, no #{@botmaster} Points given." if talkative?
    end  
  else
    if write_user(nick)
      newuser = get_user(nick)
      if db_checkins_get(newuser[0])
        give_points(nick, @checkin_points)
        msg channel, "Thanks for checking in, #{nick}! You have been given #{@checkin_points} #{@botmaster} Points! [Total check-ins: 1]"
      end
    end
  end
end

on :channel, /^!points/i do
  user = get_user(nick)
  if (user)
    if user[2] > 0
      userpoints = user[2].to_s
      msg channel, "#{nick} has #{userpoints} #{@botmaster} Points." if talkative?
    else
      msg channel, "Sorry, it doesn't look like you have any #{@botmaster} Points!" if talkative?
    end
  else
    if write_user(nick)
      newuser = get_user(nick)
      if db_checkins_get(newuser[0])
        give_points(nick, @checkin_points)
        msg channel, "#{nick}: Welcome! You have been checked-in and given #{@checkin_points} #{@botmaster} Points! [Total check-ins: 1]" if talkative?
      end
    end
  end 
  if !talkative? 
    msg channel, "You can check your points here: #{@leaderboard_location}"
  end
  
end


on :channel, /^!leaderboard$/i do
  points = db_points(5)
  s = "Leaderboard: "
  points.each do |name, points|
    s << "#{name} (#{points} points), "
  end
  msg channel, s
  
end

on :channel, /^!top$/i do
  checkins = db_checkins(5)
  s = "Top Viewers: "
  checkins.each do |name, amount|
    s << "#{name} (#{amount} checkins), "
  end
  msg channel, s 
end

on :channel, /^!time$/i do
  viewers = db_streamtime(5)
  s = "Most Time on Stream: "
  viewers.each do |name, streamtime|
    pretty_time = make_pretty_time(streamtime.to_i)
    s << "#{name} (#{pretty_time}), "
  end
  msg channel, s 
end

on :channel, /^!statsme/i do
  user = get_user(nick)
  if (user)
    checkins = db_user_checkins_count(user[0])
    correct_bets = 0
    past_bets = db_get_all_bets_from_user(user[0])
    past_bets.each do |past_bet|
      if past_bet[4] == 1
        correct_bets = correct_bets + 1
      end
    end
    ratio = correct_bets.to_f / past_bets.count.to_f
    incorrect_bets = past_bets.count - correct_bets
    pretty_time = make_pretty_time(user[7].to_i)
    msg channel, "#{nick}: #{pretty_time} in stream, & #{checkins} checkins! Winning bets ratio: #{ratio} with #{correct_bets} correct bets and #{incorrect_bets} incorrect bets."
  end
end

############################################################################
#
# Capture all remaining chat
# This has to be last or it will prevent all prior listens
#

on :channel, // do
  respond_to_commands(message)
  check_for_raffle_entry(message, nick)
  give_idle_points_and_track_stream_time
  fake_daemon
end



# week-long lottery type of thing? reward for most check-ins? 
# !game starts game of clues with !command subsequent, winner gets 50 points or something.


# old changelog:
# v0.3: Removed points fee on !give. Added !commands command. Can bet on tie. Added !top. Added Viewer DB !lookup & !update
# v0.5: Bets now toggle off automatically. Added !uptime. Fixed bug in !give and merged Etheco's code (thanks Etheco!)
