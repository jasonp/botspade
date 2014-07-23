<?php
#
#  You need to set the correct path for the database file on line 61
#  for this to work! Place this file in a web-accessible part of your server, 
#  e.g. /var/www/example.com/public_html/leaderboard/index.php
#

?>

<html>
<head>
<title>Points Leaderboard</title>

<style type="text/css">

body {font-family: Georgia, Times, 'Times New Roman', Serif;}
h1, h2, h3, h4 {font-family: 'Helvetica Neue', Helvetica, Arial, Sans-Serif;}
	h4 {padding-left: .5em; margin-bottom: .2em;}
	

section {display: block; margin: auto; padding-top: 20px; width: 820px; font-size: 1.2em; line-height: 135%; border-left: 1px dotted #444; border-right: 1px dotted #444; padding-left: 15px;}
.dotted_header {background: url('dotted-jut.png') repeat-y; padding-left: 50px;}
	.sched {padding-left: 1em;}

p {text-align: justify; padding-left: .5em; padding-right: 1em; color: #232323;}
.notyet {color: #888;}

.subhead {color: #666; margin-bottom: 25px; margin-top: -10px;}

.points-header, .username-header {text-decoration: bold; color: #003366; border-bottom: 1px solid #003366; margin-right: 5px; float:left;}
.points-header {width: 100px;}
.username-header {width: 600px;}

.user {width: 100%; height: 30px;}
.points {width: 100px; margin-right: 5px; float: left;}
.username {display: inline; float: left;}

a {color: #999; text-decoration: underline;}
a:hover {text-decoration: none; color: #bbb;}

	

</style>

</head>
<body>
	<section>
		<?php
				echo '<h1>Points Leaderboard</h1>';				
				?> 
				<div class="subhead">Hit ctrl+f to find your name.</div>
				
				<div class="user"> 
			 		<div class="points-header"> Points </div>
					<div class="username-header"> Viewer </div>
				</div> <?php

				#
				# Set this to the sqlite database file's location
				#
				$dir = 'sqlite:/home/jason/botspade/botspade.db';
				$dbh  = new PDO($dir) or die("cannot open the database");
				$query =  "SELECT * FROM users ORDER BY points DESC";
				foreach ($dbh->query($query) as $row)
				{
					?> <div class="user"> 
				 		<div class="points"> <?php echo $row[2]; ?> </div>
						<div class="username"> <?php echo $row[1]; 
					?></div> </div> <?php
				}
		?>
	</section>
</body>
