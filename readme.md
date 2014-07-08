# BotSpade: A Customizable Twitch.tv Chat Bot

Allow your viewers to bet with virtual points on your wins and losses, and other things.

BotSpade can:
* Change its name to yours! e.g. "BotWarOwl"
* Provide basic call-and-response in chat, e.g. !settings
* Provide points to viewers when they check-in (!checkin)
* Allow users to bet on game results (win/loss/tie) using !bet
* Users can !give each other points
* Users can fill in profile info, e.g. !update watchspade country USA & view e.g. !lookup watchspade country
* Betting automatically closes after 5 minutes (note: need to make the timer customizable)
* Tracks !uptime if you remember to !startstream
* Other things...


Streamers using BotSpade:
* http://twitch.tv/watchspade
* YOU! :)

BotSpade is to Moobot/Nightbot as WordPress is to Blogger/Tumblr.

This is a work in progress, including the documentation. 

## Instructions

BotSpade runs in Ruby 2.1.0 on top of the Isaac IRC chat bot gem. It's best to run it on a server like the ones you can get for $5/month from [Digital Ocean](http://digitalocean.com), but you can also run it on your mac or Linux based system. You can run it on a PC, too, but it's a pain in the ass. 

On your server, I recommend using [RVM](http://rvm.io). To do this you will need to SSH in to your server, or on a Mac you need to open Terminal. Ultimately, I'll explain that here, but for now: Google. 

	\curl -sSL https://get.rvm.io | bash -s stable
	
If you have trouble, this is a great RVM [install cheat sheet](http://cheat.errtheblog.com/s/rvm). Once it is installed, get ruby 2.1.0:

	rvm install 2.1.0
	
and make sure you're using it

	rvm use 2.1.0
	
then install the gem dependencies for BotSpade:

	gem install isaac
	gem install json
	gem install sqlite3
	
and it's best to have screen:

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

to end your SSH session and your bot will still be running. 

### Contributing

If you'd like to help, I'd love it! Just fork the repository, and feel free to send pull requests and reach out to me about contributing. Please send pull requests to the "risky" branch, master is the "stable release."

Big thanks to @Etheco for his contributions so far. 

### MIT License

Share it, etc. I'll find and paste that license text in here someday. Please always include credit to Jason "Spade" Preston. 