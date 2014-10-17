# BotSpade: A Customizable Twitch.tv Chat Bot

Allow your viewers to bet with virtual points on your wins and losses, and other things. Watch or Star this GitHub to follow updates. 

See the [User's Guide / Quick Reference here](https://github.com/jasonp/botspade/wiki/User's-Guide) for a list of commands you and your users can make use of. 

BotSpade can:
* Change its name to yours! e.g. "BotEtheco"
* Provide basic call-and-response in chat, e.g. !settings
* Provide points to viewers when they check-in (!checkin)
* Allow users to bet on game results (win/loss/tie) using !bet
* Users can !give each other points
* Users can fill in profile info, e.g. !update watchspade country USA & view e.g. !lookup watchspade country
* Betting automatically closes after 5 minutes
* Tracks !uptime if you remember to !startstream
* Great !raffle interface, allows winners to !pass or !accept the prize
* Other things...


Streamers using BotSpade:
* http://twitch.tv/watchspade
* http://twitch.tv/fivves
* YOU! :)

BotSpade is to Moobot/Nightbot as WordPress is to Blogger/Tumblr.

This is a work in progress, including the documentation. 

## Instructions

> BotSpade requires Ruby AND PHP. Ruby for the bot, PHP for the web page where people can check their points when you have talkative mode turned off. If you don't care about talkative (i.e. you don't have many users), then PHP is not required.

BotSpade runs in Ruby 2.1.0 on top of the Isaac IRC chat bot gem. It's best to run it on a server like the ones you can get for $5/month from [Digital Ocean](http://digitalocean.com), but you can also run it on your PC, Mac, or Linux based system. 

**SERVER/MAC/LINUX**
On your server (or Mac/Linux), I recommend using [RVM](http://rvm.io). To do this you will need to SSH in to your server, or on a Mac you need to open Terminal. Ultimately, I'll explain that here, but for now: Google. 

	\curl -sSL https://get.rvm.io | bash -s stable
	
If you have trouble, this is a great RVM [install cheat sheet](http://cheat.errtheblog.com/s/rvm). Once it is installed, get ruby 2.1.0:

	rvm install 2.1.0
	
and make sure you're using it

	rvm use 2.1.0
	
**PC**	
If you're using a PC instead, head over to [Ruby Installer](http://rubyinstaller.org/downloads/) and download the installer for Ruby 2.0.0-p481. Run the installer file and run it, and make sure to **check all of the optional checkboxes** when you install it, especially the one about your path file. 	
	
then install the gem dependencies for BotSpade:

	gem install isaac
	gem install json
	gem install sqlite3
	
and it's best to have screen (not for PC):

	apt-get install screen
	
Now you are ready to set up BotSpade. Download botconfig.rb, botspade.rb, and botspade_module.rb from this repository. Open up botconfig.rb in your favorite editor and follow the configuration instructions in this file (this involves creating a dummy Twitch account for your bot). 

Now place them in your botspade directory, e.g. /home/username/botspade/. Now type:

	screen
	
to open a "window" in screen to run your bot. Type:

	ruby botspade.rb 

to run it. You should see the console status connect you to your Twitch chat, sometimes it takes a few minutes because Twitch servers can respond slowly. Now if you go to your channel and type !welcome in the chatroom, you should see BotSpade respond!

To keep your bot running after disconnecting from your server, you need to "detach" your screen session. Hit:

	ctrl+a d
	
Now you can type 

	exit

to end your SSH session and your bot will still be running. To get back to your "screen" later, SSH back in to the server and type:

	screen -r
	
You can exit (stop) the bot by typing:

	ctrl+c

### Use / Admin

All available use/admin related commands are now listed in the [user's guide](https://github.com/jasonp/botspade/wiki/User's-Guide).

### Contributing

If you'd like to help, I'd love it! Just fork the repository, and feel free to send pull requests and reach out to me about contributing. Please send pull requests to the "requests" branch, master is the "stable release" and "risky" is where I try my own things. 

Big thanks to @Etheco for his contributions so far. 

### MIT License

Copyright © 2014 Jason Preston

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.