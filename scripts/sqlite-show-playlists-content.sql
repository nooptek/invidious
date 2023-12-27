SELECT playlists.author,
	playlists.title,
	playlist_videos.id,
	playlist_videos.title
FROM playlists, json_each(playlists.[index]), playlist_videos
WHERE playlists.id = playlist_videos.plid AND
	json_each.value = playlist_videos.[index]
ORDER BY playlists.created, json_each.key
