############################################################################
#
#   BotSpade
#
#   Copyright (c) 2014 by Jason Preston
#   A Twitch Chat Bot
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
    msg channel, "success" if File.write('pointsdb.txt', @pointsdb.to_json) && File.write('pointsgivendb.txt', @pointsgivendb.to_json)
  end
  
  def save_data_silent
    File.write('pointsdb.txt', @pointsdb.to_json) && File.write('pointsgivendb.txt', @pointsgivendb.to_json)
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
  @pointsgivendb = {}
  if File::exists?('pointsgivendb.txt')
    pointsgivenfile = File.read('pointsgivendb.txt') 
    @pointsgivendb = JSON.parse(pointsgivenfile)
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

on :channel, /^!beard/i do
  msg channel, "Spade wears a beard because it's awesome. He trims with a Panasonic ER-GB40 and shaves the lower whiskers with a safety razor, which is badass."
end

on :channel, /^!spade/i do
  msg channel, "When Alexander Graham Bell invented the telephone, he had three missed calls from Spade."
end

on :channel, /^!fedora/i do
  msg channel, "You can make Spade wear a fedora by spending 20 Spade Points. Type !purchase fedora to activate."
end

on :channel, /^!botspade/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss], !checkin, !points, and a few other surprises."
end
on :channel, /^!help/i do
  msg channel, "I respond to !beard, !bet [points] [win/loss], !checkin, !points, and a few other surprises."
end

on :channel, /^!points/i do
  if @pointsdb.key?(nick)
    userpoints = @pointsdb[nick].to_s
    msg channel, "#{nick} has #{userpoints} Spade Points."
  else
    msg channel, "Sorry, it doesn't look like you have any Spade Points!"  
  end
end

on :channel, /^!betusage/i do
  msg channel, "Usage: !bet [points] [win/loss] e.g. !bet 15 loss"
end

on :channel, /^!leaderboard/i do
  protoboard = @pointsdb.sort_by { |nick, points| points }
  leaderboard = protoboard.reverse
  msg channel, "Leaderboard: #{leaderboard[0]}, #{leaderboard[1]}, #{leaderboard[2]}, #{leaderboard[3]}, #{leaderboard[4]}"
end

on :channel, /^!top/i do
  protoboard = @pointsdb.sort_by { |nick, points| points }
  leaderboard = protoboard.reverse
  msg channel, "Leaderboard: #{leaderboard[0]}, #{leaderboard[1]}, #{leaderboard[2]}"
end

############################################################################
#
# Dealing with betting
#

on :channel, /^!bet (.*) (.*)/i do |first, last|
  # `first` will contain the first regexp capture,
  # `last` the second.
  bet_amount = first.to_i
  win_loss = last
  if @betsopen == TRUE
    if @pointsdb.key?(nick)
      points_available = @pointsdb[nick]
      if points_available < bet_amount
        msg channel, "Whoops, you're trying to bet more points than you have!"
      else
        @betsdb[nick] = [bet_amount, win_loss]
        take_points(nick, bet_amount)
        #@pointsdb[nick] = points_available - bet_amount
        msg channel, "#{nick}: Bet recorded."
      end
    else
      msg channel, "Whoops, #{nick} it looks like you don't have any points!"
    end
  else
    msg channel, "Sorry, bets aren't open right now. #{win_loss}"
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
          current_points = @pointsdb[bettor]
          @pointsdb[bettor] = current_points + winnings
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
          current_points = @pointsdb[bettor]
          @pointsdb[bettor] = current_points + winnings
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
      msg channel, "Betting is now open. Place your bets: !bet [points] [win/loss]"
    elsif @betsopen == TRUE
      @betsopen = FALSE
      msg channel, "Betting is now closed. GL."
    end
  end
end

# Method for Spade to give points to good viewers
# !give user points
on :channel, /^!give (.*) (.*)/i do |first, last|
  if nick == "watchspade"
    person = first
    points = last.to_i
    give_points(person, points)
  end  
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
  if @pointsgivendb.key?(nick)
    last_checkin = @pointsgivendb[nick]
    allowed_checkin = Time.now.utc - 43200
    if last_checkin > allowed_checkin.to_i
      msg channel, "#{nick} checked in already, no Spade Points given."
    else 
      @pointsivendb[nick] = Time.now.utc.to_i
      give_points(nick, 4)
      msg channel, "Thanks for checking in, #{nick}! You have been given 4 Spade Points!"
    end
  else
    give_points(nick, 4)
    @pointsgivendb[nick] = Time.now.utc.to_i
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
    take_points(nick, 20)
    msg channel, "#{nick} has forced Spade to wear a Fedora for the rest of this stream. [-20sp]"
  elsif purchase == "bdp"
    take_points(nick, 10)
    msg channel, "#{nick} has demanded that Spade make a Big Dick Play. Here goes nothing. [-10sp]"  
  elsif purchase == "menu"
    msg channel, "SpadeStore Menu: !fedora (20sp - Spade wears fedora), !bdp (10sp - Spade tries a big dick play)"
  end
end


# !purchase menu/fedora/BDP/etc

# !minispade
# timed helper reminding people to checkin
# welcome msg timed?
# build my own raffle?
# week-long lottery type of thing? reward for most check-ins? (I don't track this currently)



