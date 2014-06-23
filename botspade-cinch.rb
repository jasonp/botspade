require 'cinch'

class Hello
  include Cinch::Plugin

  match "hello"

  def execute(m)
    m.reply "Hello, #{m.user.nick}"
  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.twitch.tv"
    c.port = "6667"
    c.password = "oauth:cbr74bjxkfc5r24lqs0yph44fgbgam7"
    c.nick = "botspade"
    c.channels = ["#watchspade"]
    c.plugins.plugins = [Hello]
  end
end

bot.start