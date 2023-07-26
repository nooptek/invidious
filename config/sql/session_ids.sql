-- Table: session_ids

-- DROP TABLE session_ids;

CREATE TABLE IF NOT EXISTS session_ids
(
  id text NOT NULL,
  email text,
  issued timestamp with time zone,
  CONSTRAINT session_ids_pkey PRIMARY KEY (id)
);

-- Index: session_ids_id_idx

-- DROP INDEX session_ids_id_idx;

CREATE INDEX IF NOT EXISTS session_ids_id_idx
  ON session_ids
  (id COLLATE pg_catalog."default");

