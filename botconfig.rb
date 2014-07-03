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

configure do |c|
  c.nick    = "botspade"
  c.server  = "irc.twitch.tv"
  c.port    = 6667
  c.password = "" # Get yours here: http://twitchapps.com/tmi/
  c.verbose = true
end

#############
#
# Whose bot is this? Let's set some customizeations. How many points should people get when
# they check in? What is your name, so that the bot customizes?

helpers do

  # Name of the streamer. e.g. Spade, results in: "user has 57 Spade Points"
  @botmaster = "Spade"

  # How many points should a user be given when they !checkin to your stream?
  @checkin_points = 4

  # Bot admins. Which users will be able to !togglebets, !savedata, and other admin-only commands?
  # follow the example below to add as many admins as you'd like to.
  @admins_array = []
  @admins_array << "watchspade" # << "another_admin" << "another_one"

end

#############
#
# Let's add some custom commands and responses. Sorry for the syntax, but it can be very powerful!
# Here's how it works. Each command has a block of code that looks like this:
#
# on :channel, /^!testme/i do    <---- this is the command the user types in chat, e.g. !points
#   msg channel, "Here's the info I want to put in response."   <--- Here is how the bot responds
# end
#
# To create custom commands, replace the "testme" with the command you want to make, e.g. "gaben"
# Put the bot's response in the quotes. To make more commands, copy + pase a new block of code.
#
# GLHF.


on :channel, /^!replaceme/i do
  msg channel, "Put the bot's response here. You can use the name of the user who triggered the command with: #{nick}"
end

on :channel, /^!twitter/i do
  msg channel, "Spade's twitter is http://twitter.com/jasonp"
end

on :channel, /^!shave/i do
  msg channel, "If the stream reaches 75 concurrent viewers, Spade will shave his beard off. On stream."
end
