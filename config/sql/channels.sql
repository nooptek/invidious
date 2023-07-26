-- Table: channels

-- DROP TABLE channels;

CREATE TABLE IF NOT EXISTS channels
(
  id text NOT NULL,
  author text,
  updated timestamp with time zone,
  deleted boolean,
  subscribed timestamp with time zone,
  CONSTRAINT channels_id_key UNIQUE (id)
);

-- Index: channels_id_idx

-- DROP INDEX channels_id_idx;

CREATE INDEX IF NOT EXISTS channels_id_idx
  ON channels
  (id COLLATE pg_catalog."default");

