-- Table: channel_videos

-- DROP TABLE channel_videos;

CREATE TABLE IF NOT EXISTS channel_videos
(
  id text NOT NULL,
  title text,
  published text,
  updated text,
  ucid text,
  author text,
  length_seconds integer,
  live_now boolean,
  premiere_timestamp text,
  views bigint,
  CONSTRAINT channel_videos_id_key UNIQUE (id)
);

-- Index: channel_videos_ucid_published_idx

-- DROP INDEX channel_videos_ucid_published_idx;

CREATE INDEX IF NOT EXISTS channel_videos_ucid_published_idx
  ON channel_videos
  (ucid, published);

