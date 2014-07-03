############################################################################
# Sqllite3 Related setup

# Lets open up Sqlite3 Database
db = SQLite3::Database.new "botspade.db"

# Initial Tables - points / checkin / viewers / games / bets
# We will generate a custom user table so we have a relational ID for other tables.
db.execute "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, points INT, first_seen BIGINT, last_seen BIGINT)"
db.execute "CREATE UNIQUE INDEX IF NOT EXISTS username ON users (username)"

# Each checkin will have its own row, With related ID from users table and timestamp of when.
db.execute "CREATE TABLE IF NOT EXISTS checkins (id INTEGER PRIMARY KEY, user_id INT, timestamp BIGINT)"
# Change win (1) / lose (2) / tie (3) to INTs for database optimisation.
db.execute "CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, status TINYINT, timestamp BIGINT)"
