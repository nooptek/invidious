-- Table: videos

-- DROP TABLE videos;

CREATE UNLOGGED TABLE IF NOT EXISTS videos
(
  id text NOT NULL,
  info text,
  updated text,
  CONSTRAINT videos_pkey PRIMARY KEY (id)
);

-- Index: id_idx

-- DROP INDEX id_idx;

CREATE UNIQUE INDEX IF NOT EXISTS id_idx
  ON videos
  (id);

