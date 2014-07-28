#
#  This file will not be touched by updates, so you can customize it to your heart's content
#  Just replace botspade.rb with the latest version when you wish to upgrade
#
#  NOTE: RIGHT NOW, THAT IS A LIE, THIS FILE IS UNDER DEVELOPMENT
#

###############
#
# Basic connection and configuration info. First, make a Twitch account for your bot.
# Then set "c.nick" to your bot Twitch account's username. Mine is botspade. You'll need to
# set "c.password" to the oauth string you can get at the link provided below (visit the page
# while logged in to your bot's Twitch account).
#

#
# LIVE CONFIG INFO

configure do |c|
  c.nick    = "botspade"
  c.server  = "irc.twitch.tv"
  c.port    = 6667
  c.password = "oauth:cbr74bjxkfc5r24lqs0yph44fgbgam7" # Get yours here: http://twitchapps.com/tmi/
  c.verbose = true
end

#
# TEST CONFIG INFO

#configure do |c|
#  c.nick    = "botspade"
#  c.server  = "0.0.0.0"
#  c.port    = 6667
#  c.verbose = true
#end
#

#############
#
# Whose bot is this? Let's set some customizeations. How many points should people get when
# they check in? What is your name, so that the bot customizes?
#
# Note: need to move these to the DB / Options table

helpers do

  # Name of the streamer. e.g. Spade, results in: "user has 57 Spade Points"
  @botmaster = "Spade"

  # How many points should a user be given when they !checkin to your stream?
  @checkin_points = 4
  
  # How long should bets remain active before auto-closing? Default is 5 minutes.
  @bets_auto_close_in = 5         # time in minutes
  
  # What is your twitch username? This is the "channel" your bot needs to join. 
  # The channel MUST begin with '#'
  @botchan = "#watchspade"
  
  # If you turn talkative mode OFF (!talkative in chat to toggle), you also need to 
  # say where folks can see their points... where you put index.php!
  #
  @talkative = true
  @leaderboard_location = "http://watchspade.com/botspade/"


end




