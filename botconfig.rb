#
#  This file will not be touched by updates, so you can customize it to your heart's content
#  Just replace botspade.rb with the latest version when you wish to upgrade
#

configure do |c|
  c.nick    = "botspade"
  c.server  = "irc.twitch.tv"
  c.port    = 6667
  c.password = "oauth:cbr74bjxkfc5r24lqs0yph44fgbgam7"
  c.verbose = true
end

on :connect do  # initializations
  join "#watchspade"
  
  # Keeps track of a user's points. DB is persistent. 
  # e.g. {watchspade => 34}
  @pointsdb = {}
  if File::exists?('pointsdb.txt')
    pointsfile = File.read('pointsdb.txt') 
    @pointsdb = JSON.parse(pointsfile)
  end
  
  # Track whether or not we've given points today already. DB is persistent. 
  # e.g. {watchspade => [987239487234, 12398429837]}
  @checkindb = {}
  if File::exists?('checkindb.txt')
    checkinfile = File.read('checkindb.txt') 
    @checkindb = JSON.parse(checkinfile)
  end  
  
  # Establish a database of Spade's viewers
  # e.g. {viewer => {country => USA, strength => 12}}
  @viewerdb = {}
  if File::exists?('viewerdb.txt')
    viewerfile = File.read('viewerdb.txt') 
    @viewerdb = JSON.parse(viewerfile)
  end
  
  # Keeps track of wins / losses & maybe other stats eventually. 
  # e.g. {wincount => 5, losscount => 20, 298273429834 => win, 2094203498234 => loss}
  @gamesdb = {}
  if File::exists?('gamesdb.txt')
    gamesfile = File.read('gamesdb.txt') 
    @gamesdb = JSON.parse(gamesfile)
  end  
  
  # Track bets made. Resets every time bets are tallied.
  @betsdb = {}
  
  # Toggle whether or not bets are allowed
  @betsopen = FALSE 
  
  # Whose bot is this?
  @botmaster = "Spade"
  @checkin_points = 4
  
end