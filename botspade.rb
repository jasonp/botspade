############################################################################
#
#   BotSpade
#
#   Copyright (c) 2014 by Jason Preston
#   A Twitch Chat Bot
#   Version 0.2 - 6/24/2014
#

require 'isaac'
require 'json'

configure do |c|
  c.nick    = "botspade"
  c.server  = "irc.twitch.tv"
  c.port    = 6667
  c.password = "oauth:cbr74bjxkfc5r24lqs0yph44fgbgam7"
  c.verbose = true
end

############################################################################
#
# Helpers
#

helpers do
  
  def save_data
    msg channel, "success" if File.write('pointsdb.txt', @pointsdb.to_json) && File.write('checkindb.txt', @checkindb.to_json) && File.write('viewerdb.txt', @viewerdb.to_json)
  end
  
  def save_data_silent
    File.write('pointsdb.txt', @pointsdb.to_json) && File.write('checkindb.txt', @checkindb.to_json) && File.write('viewerdb.txt', @viewerdb.to_json)
  end
  
  def take_points(nick, points)
    if @pointsdb.key?(nick)
      @pointsdb[nick] = @pointsdb[nick] - points
      save_data_silent
    else
      msg channel, "#{nick} does not have any Spade Points!"
    end
  end
  
  def give_points(nick, points)
    if @pointsdb.key?(nick)
      @pointsdb[nick] = @pointsdb[nick] + points
    else
      @pointsdb[nick] = points
    end
    save_data_silent
  end
  
  def person_has_enough_points(person, points_required)
    if @pointsdb.key?(person)
      points_available = @pointsdb[person]
      if points_available < points_required
        points_check_result = FALSE
      else
        points_check_result = TRUE
      end
    else
      points_check_result = FALSE
    end
    return points_check_result
  end
  
end

on :connect do  # initializations
  join "#watchspade"
  
  # Keeps track of a user's points. DB is persistent. 
  @pointsdb = {}
  if File::exists?('pointsdb.txt')
    pointsfile = File.read('pointsdb.txt') 
    @pointsdb = JSON.parse(pointsfile)
  end
  
  # Track whether or not we've given points today already. DB is persistent. 
  @checkindb = {}
  if File::exists?('checkindb.txt')
    checkinfile = File.read('checkindb.txt') 
    @checkindb = JSON.parse(checkinfile)
  end  
  
  # Establish a database of Spade's viewers
  @viewerdb = {}
  if File::exists?('viewerdb.txt')
    viewerfile = File.read('viewerdb.txt') 
    @viewerdb = JSON.parse(viewerfile)
  end
  
  # Track bets made. Resets every time bets are tallied.
  @betsdb = {}
  
  # Toggle whether or not bets are allowed
  @betsopen = FALSE 
end

############################################################################
#
# Basic Call & Response presets
#

on :channel, /^!changelog/i do
  msg channel, "v0.3: Removed points fee on !give. Added !commands command. Can bet on tie. Added !top. Added Viewer DB !lookup & !update"
end

on :channel, /^!beard/i do
  msg channel, "Spade wears a beard because it's awesome. He trims with a Panasonic ER-GB40 and shaves the lower whiskers with a safety razor, which is badass."
end

on :channel, /^!commands/i do
  msg channel, "Some commands include: !points, !bet, !leaderboard, !changelog, !points, !welcome, !shave, !getpoints, !minispade, !twitter, !spade, !help. There are others."
end

on :channel, /^!shave/i do
  msg channel, "If the stream reaches 75 concurrent viewers, Spade will shave his beard off. On stream."
end

on :channel, /^!welcome/i do
  msg channel, "Welcome to Spade's stream! Don't forget to !checkin for Spade Points. Type !help for more options."
end

on :channel, /^!getpoints/i do
  msg channel, "You can get Spade Points by checking in (!checkin), donating, and winning bets (!bet for usage). Or you can be given points (!give)."
end

on :channel, /^!minispade/i do
  msg channel, "Spade has a just-about two year old son: minispade."
end

on :channel, /^!twitter/i do
  msg channel, "Spade's twitter is http://twitter.com/jasonp"
end

on :channel, /^!spade$/i do
  msg channel, "When Alexander Graham Bell invented the telephone, he had three missed calls from Spade."
end

on :channel, /^!spadeout/i do
  msg channel, "Spaaaaaaaaade out."
end

on :channel, /^!botspade/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss/tie], !checkin, !points, and a few other surprises."
end

on :channel, /^!help/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss/tie], !checkin, !points, and a few other surprises."
end

on :channel, /^!points/i do
  if @pointsdb.key?(nick)
    userpoints = @pointsdb[nick].to_s
    msg channel, "#{nick} has #{userpoints} Spade Points."
  else
    msg channel, "Sorry, it doesn't look like you have any Spade Points!"  
  end
end

on :channel, /^!leaderboard/i do
  protoboard = @pointsdb.sort_by { |nick, points| points }
  leaderboard = protoboard.reverse
  msg channel, "Leaderboard: #{leaderboard[0]}, #{leaderboard[1]}, #{leaderboard[2]}, #{leaderboard[3]}, #{leaderboard[4]}"
end

on :channel, /^!top/i do
  topviewers = @checkindb.sort_by { |nick, checkin_array| checkin_array.count }
  top = topviewers.reverse
  string = []
  5.times do |i|
    amount = top[i.to_i][1].count
    name = top[i.to_i][0]
    string << name << amount
  end
  msg channel, "Top Viewers by !checkins: #{string[0]} (#{string[1]} checkins), #{string[2]} (#{string[3]} checkins), #{string[4]} (#{string[5]} checkins)"
end

############################################################################
#
# Viewer DB
#

on :channel, /^!update (.*) (.*) (.*)/i do |first, second, last|
  person = first
  attribute = second
  value = last
  if person == nick
    if @viewerdb.key?(person)
      person_hash = @viewerdb[person]
      person_hash[attribute] = value
      @viewerdb[person] = person_hash
      msg channel, "#{attribute} updated for #{nick}"
    else
      person_hash = {}
      person_hash[attribute] = value
      @viewerdb[person] = person_hash
      msg channel, "#{attribute} updated for #{nick}"  
    end
    save_data_silent
  end  
end

on :channel, /^!update$/i do
  msg channel, "Add info to your file in the Viewer db. Usage: !update [username] [attribute] [value], e.g. !update watchspade country USA"
end

on :channel, /^!lookup (.*) (.*)/i do |first, last|
  person = first
  attribute = last
  if @viewerdb.key?(person)
    if attribute == "index"
      person_hash = @viewerdb[person]
      person_array = person_hash.keys
      msg channel, "#{person}: #{person_array}"
    else
      person_hash = @viewerdb[person]
      lookup_value = person_hash[attribute]
      msg channel, "#{person}: #{lookup_value}"
    end  
  else
    msg channel, "Sorry, nothing in the viewer database for that!"  
  end    
end

on :channel, /^!lookup$/i do
  msg channel, "Lookup other viewers. Usage: !lookup [username] [attribute]. You can also do !lookup [username] index to see what attributes are available."
end

on :channel, /^!remove (.*) (.*)/i do |first, second|
  person = first
  attribute = second
  if person == nick
    if @viewerdb.key?(person)
      person_hash = @viewerdb[person]
      person_hash.delete(attribute)
      @viewerdb[person] = person_hash
      msg channel, "#{attribute} removed for #{nick}"
    else
      msg channle, "#{nick}: I don't see anything to remove!"
    end
    save_data_silent
  end  
end

on :channel, /^!remove$/i do
  msg channel, "Remove info from your file in the Viewer db. Usage: !remove [username] [attribute], e.g. !remove watchspade country"
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
  win_loss = last
  if @betsopen == TRUE
    if first.to_f < 1
      msg channel, "Sorry, you can't bet in fractions!"
    else  
      if person_has_enough_points(nick, bet_amount) 
        @betsdb[nick] = [bet_amount, win_loss]
        take_points(nick, bet_amount)
        msg channel, "#{nick}: Bet recorded."
      else
        msg channel, "Whoops, #{nick} it looks like you don't have enough points!"
      end
    end
  else
    msg channel, "Sorry, bets aren't open right now."
  end
end

on :channel, /^!reportgame (.*)/i do |first|
  if nick == "watchspade"
    total_won = 0
    winner_count = 0
    if first == "win"
      @betsdb.keys.each do |bettor|
        bet_amount = @betsdb[bettor][0]
        win_loss = @betsdb[bettor][1]
        if win_loss == "win"
          winnings = bet_amount * 2
          total_won = total_won + winnings
          winner_count = winner_count + 1
          give_points(bettor, winnings)
        end  
      end
      save_data_silent
    elsif first == "loss"
      @betsdb.keys.each do |bettor|
        bet_amount = @betsdb[bettor][0]
        win_loss = @betsdb[bettor][1]
        if win_loss == "loss"
          winnings = bet_amount * 2
          total_won = total_won + winnings
          winner_count = winner_count + 1
          give_points(bettor, winnings)
        end
      end
      save_data_silent
    elsif first == "tie"
      @betsdb.keys.each do |bettor|
        bet_amount = @betsdb[bettor][0]
        win_loss = @betsdb[bettor][1]
        if win_loss == "tie"
          winnings = bet_amount * 2
          total_won = total_won + winnings
          winner_count = winner_count + 1
          give_points(bettor, winnings)
        end
      end
      save_data_silent  
    end
    @betsdb = {}
    save_data_silent
    msg channel, "Bets tallied. #{total_won.to_s} Spade Points won by #{winner_count.to_s} gambler(s)."
  end  
end

on :channel, /^!togglebets/i do 
  if nick == "watchspade"  
    if @betsopen == FALSE
      @betsopen = TRUE
      msg channel, "Betting is now open. Place your bets: !bet [points] [win/loss/tie]"
    elsif @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Betting is now closed. GL."
    end
  end
end

# Method for users to give points to other viewers
# !give user points

on :channel, /^!give (.*) (.*)/i do |first, last|
  person = first
  points = last.to_i
  if nick == "watchspade"
    give_points(person, points)
    msg channel, "#{nick} has given #{person} #{points} Spade Points"
  else
    if person_has_enough_points(nick, points)
        give_points(person, points)
        take_points(nick, points)
        msg channel, "#{nick} has given #{person} #{points} Spade Points"
    else
      msg channel, "I'm sorry #{nick}, you don't have enough Spade Points!"
    end  
  end  
end

on :channel, /^!give$/i do 
  msg channel, "Usage: !give [username] [points]."
end


# Method for Spade to take points from naughty viewers
# !take user points
on :channel, /^!take (.*) (.*)/i do |first, last|
  if nick == "watchspade"
    person = first
    points = last.to_i
    take_points(person, points)
  end  
end

# Method to give points for chat activity
# Check to see if points have been given yet today
on :channel, /^!checkin/i do 
  if @checkindb.key?(nick)
    checkin_array = @checkindb[nick]
    last_checkin = checkin_array[-1]
    allowed_checkin = Time.now.utc - 43200
    if last_checkin > allowed_checkin.to_i
      msg channel, "#{nick} checked in already, no Spade Points given."
    else 
      checkin_array << Time.now.utc.to_i
      @checkindb[nick] = checkin_array
      give_points(nick, 4)
      msg channel, "Thanks for checking in, #{nick}! You have been given 4 Spade Points!"
      if checkin_array.count == 50
        msg channel, "#{nick} this is your 50th check-in! You Rock (and get 50 points)"
        give_points(nick, 50)
      end  
    end
  else
    checkin_array = []
    checkin_array << Time.now.utc.to_i
    give_points(nick, 4)
    @checkindb[nick] = checkin_array
    msg channel, "Thanks for checking in, #{nick}! You have been given 4 Spade Points!"
  end  
end

on :channel, /^!savedata/i do
  if nick == "watchspade"
    save_data
  end
end

############################################################################
#
# The Spade Points Store
#

on :channel, /^!purchase (.*)/i do |purchase|
  if purchase == "fedora"
    if person_has_enough_points(nick, 20)
      take_points(nick, 20)
      msg channel, "#{nick} has forced Spade to wear a Fedora for the rest of this stream. [-20sp]"
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough Spade Points!"
    end  
  elsif purchase == "bdp"
    if person_has_enough_points(nick, 10)
      take_points(nick, 10)
      msg channel, "#{nick} has demanded that Spade make a Big Dick Play. Here goes nothing. [-10sp]"  
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough Spade Points!"
    end  
  elsif purchase == "suit"
    if person_has_enough_points(nick, 10)
      take_points(nick, 10)
      msg channel, "#{nick} has bribed Spade to wear a suit for the rest of this stream. Oh boy. [-100sp]"  
    else
      msg channel, "I'm sorry, #{nick}, you don't have enough Spade Points!"
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
  msg channel, "You can make Spade wear a fedora by spending 20 Spade Points. Type !purchase fedora to activate."
end

on :channel, /^!suit/i do
  msg channel, "You can make Spade wear a suit by spending 100 Spade Points. Type !purchase suit to activate."
end

on :channel, /^!bdp/i do
  msg channel, "BDP stands for Big Dick Play. You can make Spade attempt a BDP for 10 points with !purchase bdp"
end


# build profile: !lookup [user] [attribute] - Country/Name/SteamID/Rank/Age
# !uptime
# !status (or something) - show check-ins, points, etc
# bet on other aspects: ace, 4k, 3k, 2k, 1k, pistol something, beat average stats, & so on
# check on checkin to see what number (100th checkin, etc)
# build my own raffle? allow people to "buy" extra tickets w/ points
# week-long lottery type of thing? reward for most check-ins? (I don't track this currently)
# viewerdb - save csgorank, name, other profile details hash within hash
# !game starts game of clues with !command subsequent, winner gets 50 points or something.
# give points for first use of a command?
# refactor / generalize: admins array, make Spade Points a variable, etc.
# 63 users have filled in their [country]


