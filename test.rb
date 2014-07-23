############################################################################
#
#   BotSpade Tests
#
#   A really roundabout way to do tests: set up a local IRC server
#   using brew install ngircd, and simply use a bot to test the bot.
#   
#   This sucks a lot but whatever. Type "testme" into colloquy when both
#   bots are connected. Look for a crash. Best I can do. Ugh. 
#

require 'isaac'

configure do |c|
  c.nick    = "test"
  c.server  = "0.0.0.0"
  c.port    = 6667
  c.verbose = true
end

############################################################################
#
# Helpers
#

helpers do
  
  
  def test_it
    puts "referred by?"
    msg channel, "!referredby watchspade"
    
    puts "testing !checkin"
    msg channel, "!checkin"
    
    puts "testing !points"
    msg channel, "!points"
    
    puts "giving points"
    msg channel, "!give test 10"    
    
    puts "betting while not allowed"
    msg channel, "!bet 5 win"
    
    puts "toggleing bets"
    msg channel, "!togglebets"
    
    puts "making a bet to win"
    msg channel, "!bet 1 win"
    
    puts "reporting a win"
    msg channel, "!reportgame win"
    
    puts "making a bet to lose"
    msg channel, "!bet 1 loss"
    
    puts "reporting a loss"
    msg channel, "!reportgame loss"
    
    puts "betting on a tie"
    msg channel, "!bet 1 tie"
    
    puts "reporting a tie"
    msg channel, "!reportgame tie"
    
    puts "getting a bet wrong"
    msg channel, "!bet 1 loss"
    msg channel, "!reportgame win"
    
    puts "betting wrong syntax"
    msg channel, "!bet tie 5"
  
    puts "taking points"
    msg channel, "!take test 2"
    
    puts "time for viewer db"
    msg channel, "!update country USA"
    
    puts "lookup the value"
    msg channel, "!lookup test country"
    
    puts "lookup a nil value"
    msg channel, "!lookup misvak country"
    
    puts "get an index"
    msg channel, "!lookup index"
    
    puts "remove an item"
    msg channel, "!remove country"

    puts "starting stream"
    msg channel, "!startstream"
    
    puts "uptime"
    msg channel, "!uptime"
    
    puts "stop the clock"
    msg channel, "!endstream"
    
    puts "stats"
    msg channel, "!stats"
    
    puts "my own stats"
    msg channel, "!statsme"
    
    puts "talkative toggle"
    msg channel, "!talkative"
    
    puts "seeing if it talks"
    msg channel, "!checkin"
  end

  
end

on :connect do  # test the bot
  join "#watchspade"
  puts "connected to channel"
  
end

on :channel, /^testme/ do
  test_it
end
