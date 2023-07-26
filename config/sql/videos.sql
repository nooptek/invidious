-- Table: videos

-- DROP TABLE videos;

CREATE UNLOGGED TABLE IF NOT EXISTS videos
(
  id text NOT NULL,
  info text,
  updated timestamp with time zone,
  CONSTRAINT videos_pkey PRIMARY KEY (id)
);

GRANT ALL ON TABLE videos TO current_user;

-- Index: id_idx

-- DROP INDEX id_idx;

CREATE UNIQUE INDEX IF NOT EXISTS id_idx
  ON videos
  USING btree
  (id COLLATE pg_catalog."default");

