SELECT playlists.author,
	playlists.title,
	SUM(playlist_videos.length_seconds)
FROM playlists, json_each(playlists.[index]), playlist_videos
WHERE playlists.id = playlist_videos.plid AND
	json_each.value = playlist_videos.[index]
GROUP BY playlists.id
ORDER BY playlists.created
