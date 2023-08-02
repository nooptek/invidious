-- Table: playlists

-- DROP TABLE playlists;

CREATE TABLE IF NOT EXISTS playlists
(
    title text,
    id text primary key,
    author text,
    description text,
    video_count integer,
    created text,
    updated text,
    privacy text check(privacy in ('Public', 'Unlisted', 'Private')),
    [index] int8[]
);
