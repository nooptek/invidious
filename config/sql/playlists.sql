-- Type: privacy

-- DROP TYPE privacy;

CREATE TYPE privacy AS ENUM
(
    'Public',
    'Unlisted',
    'Private'
);

-- Table: playlists

-- DROP TABLE playlists;

CREATE TABLE IF NOT EXISTS playlists
(
    title text,
    id text primary key,
    author text,
    description text,
    video_count integer,
    created timestamptz,
    updated timestamptz,
    privacy privacy,
    index int8[]
);
