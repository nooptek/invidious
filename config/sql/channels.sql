-- Table: channels

-- DROP TABLE channels;

CREATE TABLE IF NOT EXISTS channels
(
  id text NOT NULL,
  author text,
  updated text,
  deleted boolean,
  subscribed text,
  CONSTRAINT channels_id_key UNIQUE (id)
);

-- Index: channels_id_idx

-- DROP INDEX channels_id_idx;

CREATE INDEX IF NOT EXISTS channels_id_idx
  ON channels
  (id);

