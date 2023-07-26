-- Table: nonces

-- DROP TABLE nonces;

CREATE TABLE IF NOT EXISTS nonces
(
  nonce text,
  expire timestamp with time zone,
  CONSTRAINT nonces_id_key UNIQUE (nonce)
);

-- Index: nonces_nonce_idx

-- DROP INDEX nonces_nonce_idx;

CREATE INDEX IF NOT EXISTS nonces_nonce_idx
  ON nonces
  (nonce);

