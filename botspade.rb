############################################################################
#
#   BotSpade
#
#   Copyright (c) 2014 by Jason Preston under MIT License
#   A Twitch Chat Bot
#   Version 0.7 - 7/08/2014
#
#   Feel free to use for your own nefarious purposes

require 'isaac'
require 'json'
require 'sqlite3'
require "./botconfig"
require './db_module'



on :connect do  # initializations
  join @botchan

  # Lets open up Sqlite3 Database
  @db = SQLite3::Database.new "botspade.db"

  # Initial Tables - points / checkin / viewers / games / bets
  #
  # We will generate a custom user table so we have a relational ID for other tables.
  @db.execute "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, points INT, first_seen BIGINT, last_seen BIGINT, profile TEXT, admin INT)"
  @db.execute "CREATE UNIQUE INDEX IF NOT EXISTS username ON users (username)"
  
  # migration assist - will remove eventually
  # @db.execute "ALTER TABLE users ADD COLUMN admin INT;"

  # Each checkin will have its own row, With related ID from users table and timestamp of when.
  @db.execute "CREATE TABLE IF NOT EXISTS checkins (id INTEGER PRIMARY KEY, user_id INT, timestamp BIGINT)"
  # Change win (1) / lose (2) / tie (3) to INTs for database optimisation.
  @db.execute "CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, status TINYINT, timestamp BIGINT)"

  # Create a DB table that tracks bets. bet: 1 - win / 2 - loss / 3 - tie. result: 0 - no result yet, 
  # 1 - correct bet, 2 - incorrect bet
  @db.execute "CREATE TABLE IF NOT EXISTS bets (id INTEGER PRIMARY KEY, user_id INT, bet INT, bet_amount INT, result INT, timestamp BIGINT)"
  
  # Create a table for custom user-generated call and response.
  # @db.execute "CREATE TABLE IF NOT EXISTS commands (id INTEGER PRIMARY KEY, command TEXT, response TEXT, timestamp BIGINT)"

  # Establish a database of Spade's viewers
  # e.g. {viewer => {country => USA, strength => 12}}
  #@viewerdb = {}
  #if File::exists?('viewerdb.txt')
  #  viewerfile = File.read('viewerdb.txt')
  #  @viewerdb = JSON.parse(viewerfile)
  #end


  # Track bets made. Resets every time bets are tallied.
  @betsdb = {}

  # Toggle whether or not bets are allowed
  @betsopen = FALSE

  # Set initial uptime
  @stream_start_time = "none"

end

############################################################################
#
# Helpers
#

helpers do

  # An expensive way to pretend like I have a daemon
  # check for latent processes and execute them
  def fake_daemon
    if Time.now.utc.to_i > @betstimer.to_i + 300 && @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Bets are now closed. GL."
    end
  end

  def save_data
    msg channel, "success" if File.write('pointsdb.txt', @pointsdb.to_json) && File.write('checkindb.txt', @checkindb.to_json) && File.write('viewerdb.txt', @viewerdb.to_json) && File.write('gamesdb.txt', @gamesdb.to_json)
  end

  def save_data_silent
    File.write('pointsdb.txt', @pointsdb.to_json) && File.write('checkindb.txt', @checkindb.to_json) && File.write('viewerdb.txt', @viewerdb.to_json) && File.write('gamesdb.txt', @gamesdb.to_json)
    fake_daemon
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

  def user_is_an_admin?(user)
    if @admins_array.include?(user)
      return true
    else
      return false
    end
  end
end


############################################################################
#
# Basic Call & Response presets
#



on :channel, /^!changelog/i do
  msg channel, "v0.7: SQLite implemented. !bet checks for input. !update, !lookup, !remove working. Fixed db crashes."
end

on :channel, /^!beard/i do
  msg channel, "#{@botmaster} wears a beard because it's awesome. He trims with a Panasonic ER-GB40 and shaves the lower whiskers with a safety razor, which is badass."
end

on :channel, /^!commands/i do
  msg channel, "Some commands include: !points, !bet, !top, !leaderboard, !changelog, !points, !welcome, !shave, !getpoints, !minispade, !twitter, !spade, !tweet, !follow, !help. There are others."
end

on :channel, /^!welcome/i do
  msg channel, "Welcome to #{@botmaster}'s stream! Don't forget to !checkin for #{@botmaster} Points. Type !help for more options."
  fake_daemon
end

on :channel, /^!getpoints/i do
  msg channel, "You can get #{@botmaster} Points by checking in (!checkin), donating, tweeting (!tweet), & winning bets (!bet for usage). Or you can be given points (!give)."
end

on :channel, /^!buffering/i do
  msg channel, "Possibly try the external stream program, http://tards.net/ this has helped a few reduce buffering issues."
end


on :channel, /^!minispade/i do
  msg channel, "Spade has a just-about two year old son: minispade."
end

on :channel, /^!follow/i do
  msg channel, "Earn five points for following the stream (first time only!!), five points for following @jasonp on Twitter (first time only!!)"
end

on :channel, /^!tweet/i do
  msg channel, "Earn five points for tweeting: Watching Spade stream some CSGO! http://twitch.tv/watchspade cc @jasonp"
end

on :channel, /^!spade$/i do
  msg channel, "When Alexander Graham Bell invented the telephone, he had three missed calls from Spade."
end

on :channel, /^!spadeout/i do
  if user_is_an_admin?(nick)
    @stream_start_time = "none"
  end
  msg channel, "Spaaaaaaaaade out."
end

on :channel, /^!botspade/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss/tie], !checkin, !points, and a few other surprises."
end

on :channel, /^!help/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss/tie], !checkin, !points, and a few other surprises."
end

on :channel, /^!madeby/i do
  msg channel, "#{@botmaster} uses BotSpade. Get your own bot: http://github.com/jasonp/botspade"
end

on :channel, /^!stats$/i do
  wins_losses = get_wins_losses
  wincount = wins_losses[0]
  losscount = wins_losses[1]
  tiecount = wins_losses[2]
  wlratio = wins_losses[3]
  msg channel, "#{@botmaster} has reported #{wincount} wins, #{losscount} losses, and #{tiecount} ties. W/L ratio: #{wlratio}"
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
  fake_daemon
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
  user = get_user(nick)
  db_get_all_open_bets
  msg channel, "Dumped"
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
          msg channel, "Sorry, nothing in the viewer database for that!"
        end
      else
        msg channel, "#{person}: Empty profile!"
      end # if person_hash
    end
  else
    msg channel, "Sorry, nothing in the viewer database for that!"  
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
        msg channel, "I don't see anything to remove!"
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
  fake_daemon
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
            msg channel, "#{nick}: Bet recorded."
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
  fake_daemon
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
      msg channel, "Betting is now open for 5 minutes. Place your bets: !bet [points] [win/loss/tie]"
    elsif @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Betting is now closed. GL."
    end
  end
end

#on :channel, /^!1v1$/i do
#  msg channel, "Usage: !1v1 [win/loss] - all 1v1 bets are for 2 points, but cost nothing"
#end

# Method for users to give points to other viewers
# !give user points

on :channel, /^!give (.*) (.*)/i do |first, last|
  person = first.downcase
  points = last.to_i
  if user_is_an_admin?(nick)
    if get_user(person)
      give_points(person, points)
      msg channel, "#{nick} has given #{person} #{points} #{@botmaster} Points"
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

on :channel, /^!give$/i do
  msg channel, "Usage: !give [username] [points]."
end


# Method for Spade to take points from naughty viewers
# !take user points
on :channel, /^!take (.*) (.*)/i do |first, last|
  if user_is_an_admin?(nick)
    person = first.downcase
    points = last.to_i
    take_points(person, points)
  end
end

on :channel, /^!savedata/i do
  if user_is_an_admin?(nick)
    save_data
  end
end

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
          give_points(nick, 14)
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
# This must eventually be re-written as a loop somehow...

on :channel, /^!purchase (.*)/i do |protopurchase|
  purchase = protopurchase.downcase
  if purchase == "fedora"
    if person_has_enough_points(nick, 20)
      take_points(nick, 20)
      msg channel, "#{nick} has forced #{@botmaster} to wear a Fedora for the rest of this stream. [-20sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
    end
  elsif purchase == "bdp"
    if person_has_enough_points(nick, 10)
      take_points(nick, 10)
      msg channel, "#{nick} has demanded that Spade make a Big Dick Play. Here goes nothing. [-10sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
    end
  elsif purchase == "suit"
    if person_has_enough_points(nick, 10)
      take_points(nick, 10)
      msg channel, "#{nick} has bribed Spade to wear a suit for the rest of this stream. Oh boy. [-100sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough #{@botmaster} Points!"
    end
  elsif purchase == "menu"
    msg channel, "SpadeStore Menu: !fedora (20sp - Spade wears fedora), !bdp (10sp - Spade tries a big dick play), !suit (100sp - Spade wears a suit)"
  end
end

on :channel, /^!purchase$/i do
  msg channel, "SpadeStore Menu: !fedora (20sp - Spade wears fedora), !bdp (10sp - Spade tries a big dick play), !suit (100sp - Spade wears a suit)"
end

# Elaborate on what you can buy

on :channel, /^!fedora/i do
  msg channel, "You can make #{@botmaster} wear a fedora by spending 20 #{@botmaster} Points. Type !purchase fedora to activate."
end

on :channel, /^!suit/i do
  msg channel, "You can make #{@botmaster} wear a suit by spending 100 #{@botmaster} Points. Type !purchase suit to activate."
end

on :channel, /^!bdp/i do
  msg channel, "BDP stands for Big Dick Play. You can make #{@botmaster} attempt a BDP for 10 points with !purchase bdp"
end

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
      msg channel, "#{nick} checked in already, no #{@botmaster} Points given."
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
      msg channel, "#{nick} has #{userpoints} #{@botmaster} Points."
    else
      msg channel, "Sorry, it doesn't look like you have any #{@botmaster} Points!"
    end
  else
    if write_user(nick)
      newuser = get_user(nick)
      if db_checkins_get(newuser[0])
        give_points(nick, @checkin_points)
        msg channel, "#{nick}: Welcome! You have been checked-in and given #{@checkin_points} #{@botmaster} Points! [Total check-ins: 1]"
      end
    end
  end  
  fake_daemon
end


on :channel, /^!leaderboard/i do
  points = db_points(5)
  s = "Leaderboard: "
  points.each do |name, points|
    s << "#{name} (#{points} points), "
  end
  msg channel, s
  fake_daemon
end

on :channel, /^!top/i do
  checkins = db_checkins(5)
  s = "Top Viewers: "
  checkins.each do |name, amount|
    s << "#{name} (#{amount} checkins), "
  end
  msg channel, s
  fake_daemon
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
    msg channel, "#{nick}: #{checkins} checkins! Winning bets ratio: #{ratio} with #{correct_bets} correct bets and #{incorrect_bets} incorrect bets."
  end
end

# build functions (helpers) for common DB calls, e.g. if_user_has_checkins(user), etc

# bet on 1v1
# get & set a status message?
# split out a separate file for variables & customization, leave engine in main file
# bet on other aspects: ace, 4k, 3k, 2k, 1k, pistol something, beat average stats, & so on

# week-long lottery type of thing? reward for most check-ins? (I don't track this currently)
# !game starts game of clues with !command subsequent, winner gets 50 points or something.
# refactor / generalize: admins array, make Spade Points a variable, etc.
# !bitcoin / !gaben / !esea / !CEVO / !altpug
# make points given for checkin, etc, variables to be set via chat command via moderators.
# make store modifiable via chat commands?

# old changelog:
# v0.3: Removed points fee on !give. Added !commands command. Can bet on tie. Added !top. Added Viewer DB !lookup & !update
# v0.5: Bets now toggle off automatically. Added !uptime. Fixed bug in !give and merged Etheco's code (thanks Etheco!)
