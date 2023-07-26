-- Table: annotations

-- DROP TABLE annotations;

CREATE TABLE IF NOT EXISTS annotations
(
  id text NOT NULL,
  annotations xml,
  CONSTRAINT annotations_id_key UNIQUE (id)
);

GRANT ALL ON TABLE annotations TO current_user;
