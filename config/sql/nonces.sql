-- Table: nonces

-- DROP TABLE nonces;

CREATE TABLE IF NOT EXISTS nonces
(
  nonce text,
  expire timestamp with time zone,
  CONSTRAINT nonces_id_key UNIQUE (nonce)
);

GRANT ALL ON TABLE nonces TO current_user;

-- Index: nonces_nonce_idx

-- DROP INDEX nonces_nonce_idx;

CREATE INDEX IF NOT EXISTS nonces_nonce_idx
  ON nonces
  USING btree
  (nonce COLLATE pg_catalog."default");

