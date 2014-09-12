<?php

class Twitch {

  public function logout($var) {
    global $f3;
    $f3->set('SESSION.user_id', '');
    $f3->set('SESSION.twitch_token', '');
    $f3->set('SESSION.twitch_username', '');
    $f3->reroute('/?status=loggedout', false);
    exit;
  }

  public function connection($var) {
    global $f3, $db;
    if(isset($_GET['code'])) {

      if($f3->get('SESSION.user_id')) {
        $f3->reroute('/?status=loggedin', false);
      }

      $twitch = $var->get('twitch'); // Must grab twitch vars for functions.
      // Lets go ahead and get the oauth now the user has been posted back
      $postVars = array(
          'client_id' => $twitch['client_id'],
          'client_secret' => $twitch['client_secret'],
          'grant_type' => 'authorization_code',
          'redirect_uri' => $var->get('SCHEME').'://'.$var->get('HOST').$var->get('BASE').'/twitch_connection',
          'code' => $_GET['code']

      );
      $options = array(
          'method'  => 'POST',
          'content' => http_build_query($postVars),
      );
      $result = \Web::instance()->request($twitch['url_access_token'], $options);
      $token = json_decode($result['body']);

      if(isset($token->status)) {
        $f3->reroute('/?status='.$token->status, false);
        exit;
      }

      // Now we have the oauth token, Lets now go ahead and get the user data so we know who it is.
      $options = array(
          'method' => 'GET',
          'header' => array('Accept' => 'application/vnd.twitchtv.v3+json')
      );
      $result = \Web::instance()->request($twitch['url_user'] . '?oauth_token=' . $token->access_token, $options);
      $return_user = json_decode($result['body']);

      // Get the user, and if doesn't exist lets make the user on the users table.
      $user = $db->exec('SELECT id FROM users WHERE username=:username LIMIT 1', array(':username' => strtolower($return_user->display_name)));

      if(!$user) {
        $db->exec('INSERT INTO users (`username`, `points`) VALUES (:username, :points)', array(':username' => strtolower($return_user->display_name), ':points' => 0));
        $user = $db->exec('SELECT id FROM users WHERE username=? LIMIT 1', array(':username' => strtolower($return_user->display_name)));
      }

      // Lets see if the user already exists in our auth table.
      $user_auth = $db->exec('SELECT user_id FROM users_auth WHERE user_id=:user_id LIMIT 1', array(':user_id' => $user[0]['id']));
      if($user_auth) {
        $db->exec(
          'UPDATE users_auth SET access_token = :token',
          [':token' => $token->access_token]
        );
      } else {
      // Now we have the users ID lets insert the data we have :)
        $db->exec(
            'INSERT INTO users_auth (user_id, display_name, `name`, _id, type, bio, created_at, updated_at, logo, email, partnered, access_token) VALUES(:userid, :username, :name, :_id, :type, :bio, :created_at, :updated_at, :logo, :email, :partnered, :access_token)',
            [
              ':userid' => $user[0]['id'],
              ':username' => strtolower($return_user->display_name),
              ':name' => $return_user->name,
              ':_id' => $return_user->_id,
              ':type' => $return_user->type,
              ':bio' => $return_user->bio,
              ':created_at' => $return_user->created_at,
              ':updated_at' => $return_user->updated_at,
              ':logo' => $return_user->logo,
              ':email' => $return_user->email,
              ':partnered' => $return_user->partnered,
              ':access_token' => $token->access_token
            ]
        );
      }

      // Lets create session, So we know they are logged in.
      $f3->set('SESSION.user_id', $user[0]['id']);
      $f3->set('SESSION.twitch_token', $token->access_token);
      $f3->set('SESSION.twitch_username', $return_user->display_name);
      $f3->reroute('/?status=success', false);
      exit;
    }


  }

}
