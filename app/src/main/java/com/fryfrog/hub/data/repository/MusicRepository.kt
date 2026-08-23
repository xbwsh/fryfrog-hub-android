package com.fryfrog.hub.data.repository

import com.fryfrog.hub.data.model.*
import com.fryfrog.hub.data.remote.ApiClient
import com.google.gson.Gson
import kotlinx.coroutines.CancellationException

class MusicRepository {

    private val api get() = ApiClient.getApi()
    private val baseUrl get() = ApiClient.getBaseUrl()
    private val gson = Gson()

    private fun fixUrl(url: String?): String? {
        if (url == null) return null
        if (url.startsWith("http")) return url
        return "$baseUrl$url"
    }

    // 预签名 URL 失效时兜底：直接构造带鉴权头的流地址（播放器侧附加 Bearer）
    fun buildStreamUrl(songId: Long): String = "$baseUrl/api/v1/music/songs/$songId/stream"

    private fun fixSong(song: MusicSongDTO): MusicSongDTO = song.copy(
        streamUrl = fixUrl(song.streamUrl) ?: buildStreamUrl(song.id),
        coverUrl = fixUrl(song.coverUrl)
    )

    private fun fixAlbum(album: MusicAlbumDTO): MusicAlbumDTO = album.copy(
        coverUrl = fixUrl(album.coverUrl),
        songs = album.songs?.map(::fixSong)
    )

    private fun fixArtist(artist: MusicArtistDTO): MusicArtistDTO = artist.copy(
        coverUrl = fixUrl(artist.coverUrl),
        albums = artist.albums?.map(::fixAlbum)
    )

    // ===== 浏览 =====

    suspend fun getHome(): Result<List<MusicLibraryGroupDTO>> = safeApiCall {
        api.getMusicHome().data?.map { group ->
            group.copy(
                albums = group.albums?.map(::fixAlbum),
                artists = group.artists?.map(::fixArtist)
            )
        } ?: emptyList()
    }

    suspend fun getArtists(): Result<List<MusicArtistDTO>> = safeApiCall {
        api.getMusicArtists().data?.map(::fixArtist) ?: emptyList()
    }

    suspend fun getArtist(id: Long): Result<MusicArtistDTO> = safeApiCall {
        api.getMusicArtist(id).data?.let(::fixArtist) ?: throw Exception("Artist not found")
    }

    suspend fun getAlbums(): Result<List<MusicAlbumDTO>> = safeApiCall {
        api.getMusicAlbums().data?.map(::fixAlbum) ?: emptyList()
    }

    suspend fun getAlbum(id: Long): Result<MusicAlbumDTO> = safeApiCall {
        api.getMusicAlbum(id).data?.let(::fixAlbum) ?: throw Exception("Album not found")
    }

    suspend fun getSongs(q: String? = null, genre: String? = null, limit: Int = 50): Result<List<MusicSongDTO>> = safeApiCall {
        api.searchMusicSongs(q, genre, limit).data?.map(::fixSong) ?: emptyList()
    }

    // 播放前重新拉取详情，确保预签名 URL 有效
    suspend fun getSong(id: Long): Result<MusicSongDTO> = safeApiCall {
        api.getMusicSong(id).data?.let(::fixSong) ?: throw Exception("Song not found")
    }

    suspend fun getGenres(): Result<List<String>> = safeApiCall {
        api.getMusicGenres().data ?: emptyList()
    }

    // ===== 收藏 / 评分 =====

    suspend fun setStar(type: String, id: Long, status: Boolean): Result<Unit> = safeApiCall {
        val response = api.setMusicStar(type, id, status)
        if (!response.success) throw Exception(response.message ?: "Failed to set star")
    }

    suspend fun setRating(type: String, id: Long, rating: Int): Result<Unit> = safeApiCall {
        val response = api.setMusicRating(type, id, rating)
        if (!response.success) throw Exception(response.message ?: "Failed to set rating")
    }

    // ===== 歌词（原始文本，.lrc 或内嵌） =====

    suspend fun getLyrics(songId: Long): Result<String> = safeApiCall {
        val response = api.getMusicLyrics(songId)
        if (!response.isSuccessful) throw Exception("No lyrics")
        response.body()?.string() ?: ""
    }

    // ===== 播放列表 =====

    suspend fun getPlaylists(): Result<List<MusicPlaylist>> = safeApiCall {
        api.getMusicPlaylists().data ?: emptyList()
    }

    suspend fun createPlaylist(name: String, comment: String?, isPublic: Boolean?, songIds: List<Long>? = null): Result<MusicPlaylist> = safeApiCall {
        api.createMusicPlaylist(MusicPlaylistRequest(name, comment, isPublic, songIds)).data
            ?: throw Exception("Failed to create playlist")
    }

    /**
     * 详情接口返回 playlist + 曲目（Map 结构），兼容多种 key：
     * playlist/info + songs/tracks/items/content
     */
    suspend fun getPlaylistDetail(id: Long): Result<Pair<MusicPlaylist?, List<MusicSongDTO>>> = safeApiCall {
        val data = api.getMusicPlaylistDetail(id).data
            ?: throw Exception("Playlist not found")

        val playlistObj = data["playlist"] ?: data["info"] ?: data["playlistInfo"]
        val playlist: MusicPlaylist? = playlistObj?.let { obj ->
            runCatching { gson.fromJson(gson.toJson(obj), MusicPlaylist::class.java) }.getOrNull()
        } ?: runCatching {
            // 整个 data 本身可能就是 playlist 结构（含 songs 字段）
            gson.fromJson(gson.toJson(data), MusicPlaylist::class.java)
        }.getOrNull()

        val songsArray = (data["songs"] ?: data["tracks"] ?: data["items"] ?: data["content"])
            as? List<*>
        val songs = songsArray?.mapNotNull { item ->
            runCatching { gson.fromJson(gson.toJson(item), MusicSongDTO::class.java) }.getOrNull()
        }?.map(::fixSong) ?: emptyList()

        playlist to songs
    }

    suspend fun updatePlaylist(id: Long, body: MusicPlaylistUpdateRequest): Result<MusicPlaylist> = safeApiCall {
        api.updateMusicPlaylist(id, body).data ?: throw Exception("Failed to update playlist")
    }

    suspend fun deletePlaylist(id: Long): Result<Unit> = safeApiCall {
        val response = api.deleteMusicPlaylist(id)
        if (!response.success) throw Exception(response.message ?: "Failed to delete playlist")
    }

    // ===== 播放队列 =====

    suspend fun getPlayQueue(): Result<MusicPlayQueue?> = safeApiCall {
        api.getMusicPlayQueue().data
    }

    suspend fun savePlayQueue(songIds: List<Long>, currentSongId: Long?, positionSeconds: Double): Result<Unit> = safeApiCall {
        val response = api.saveMusicPlayQueue(MusicPlayQueueRequest(songIds, currentSongId, positionSeconds))
        if (!response.success) throw Exception(response.message ?: "Failed to save play queue")
    }

    // ===== Scrobble / 书签 =====

    suspend fun scrobble(songId: Long, submission: Boolean): Result<Unit> = safeApiCall {
        api.scrobbleMusic(MusicScrobbleRequest(songId, submission, System.currentTimeMillis()))
        Unit
    }

    suspend fun getBookmarks(): Result<List<MusicBookmark>> = safeApiCall {
        api.getMusicBookmarks().data?.map { bookmark ->
            bookmark.copy(song = bookmark.song?.let(::fixSong))
        } ?: emptyList()
    }

    suspend fun createBookmark(songId: Long, positionSeconds: Double, comment: String? = null): Result<MusicBookmark> = safeApiCall {
        api.createMusicBookmark(MusicBookmarkRequest(songId, positionSeconds, comment)).data
            ?: throw Exception("Failed to create bookmark")
    }

    suspend fun deleteBookmark(songId: Long): Result<Unit> = safeApiCall {
        val response = api.deleteMusicBookmark(songId)
        if (!response.success) throw Exception(response.message ?: "Failed to delete bookmark")
    }

    // ===== 管理 =====

    suspend fun scanLibraries(libraryId: Long? = null): Result<Map<String, Any>> = safeApiCall {
        api.scanMusicLibraries(libraryId).data ?: emptyMap()
    }

    suspend fun organize(libraryId: Long, dryRun: Boolean): Result<Map<String, Any>> = safeApiCall {
        api.organizeMusicLibrary(libraryId, dryRun).data ?: emptyMap()
    }

    private suspend fun <T> safeApiCall(call: suspend () -> T): Result<T> {
        return try {
            Result.success(call())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            android.util.Log.e("MusicRepository", "API call failed", e)
            Result.failure(e)
        }
    }
}
