-- Table: users

-- DROP TABLE users;

CREATE TABLE IF NOT EXISTS users
(
  updated text,
  notifications text,
  subscriptions text,
  email text NOT NULL,
  preferences text,
  password text,
  token text,
  watched text,
  feed_needs_update boolean,
  CONSTRAINT users_email_key UNIQUE (email)
);

-- Index: email_unique_idx

-- DROP INDEX email_unique_idx;

CREATE UNIQUE INDEX IF NOT EXISTS email_unique_idx
  ON users
  (lower(email));

