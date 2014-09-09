<?php

$f3=require('app/lib/base.php');

$f3->set('AUTOLOAD','app/classes/');

$f3->set('DEBUG',1);
if ((float)PCRE_VERSION<7.9)
	trigger_error('PCRE version is out of date');

$f3->config('app/config.ini');
$f3->config('app/globals.ini');

// Open Database
$db=new DB\SQL('sqlite:' . $f3->get('DB_FILE'));
// Lets make sessions use database.
new Session();
new \DB\SQL\Session($db);

if($f3->get('SESSION.user_id')) {
	$f3->set('user_id', $f3->get('SESSION.user_id'));
	$f3->set('username', $f3->get('SESSION.twitch_username'));
}

$f3->route('GET /',
	function($f3) {
		// This will be moved to its own class.
		$db=new DB\SQL('sqlite:botspade.db');
		$f3->set('results',$db->exec('SELECT u.username, u.points FROM users AS u ORDER BY points DESC'));

		$f3->set('content','welcome.htm');

		echo View::instance()->render('layout.htm');
	}
);

$f3->route('GET /userref',
	function($f3) {
		$f3->set('content','userref.htm');
		echo View::instance()->render('layout.htm');
	}
);



$f3->run();
