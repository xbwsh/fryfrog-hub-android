package com.fryfrog.hub.ui.music

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Album
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicAlbumDTO
import com.fryfrog.hub.data.model.MusicPlaylistUpdateRequest
import com.fryfrog.hub.data.model.MusicSongDTO
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.playback.MusicPlaybackManager
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ==================== ViewModel ====================

data class MusicAlbumUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val album: MusicAlbumDTO? = null,
    // 加入播放列表的目标歌曲（空 = 不显示对话框）
    val addToPlaylistSongIds: List<Long> = emptyList(),
    val playlistNotice: String? = null
)

class MusicAlbumViewModel(private val albumId: Long) : ViewModel() {

    private val repository = MusicRepository()

    private val _uiState = MutableStateFlow(MusicAlbumUiState())
    val uiState: StateFlow<MusicAlbumUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            repository.getAlbum(albumId).fold(
                onSuccess = { album -> _uiState.update { it.copy(isLoading = false, album = album) } },
                onFailure = { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message ?: "") }
                }
            )
        }
    }

    fun toggleStar() {
        val album = _uiState.value.album ?: return
        val newStatus = !(album.starred ?: false)
        _uiState.update { it.copy(album = album.copy(starred = newStatus)) }
        viewModelScope.launch {
            repository.setStar("albums", album.id, newStatus)
        }
    }

    fun setRating(rating: Int) {
        val album = _uiState.value.album ?: return
        _uiState.update { it.copy(album = album.copy(rating = rating)) }
        viewModelScope.launch {
            repository.setRating("albums", album.id, rating)
        }
    }

    /** 整张专辑加入播放列表 */
    fun addAllToPlaylist() {
        val songs = _uiState.value.album?.songs.orEmpty()
        if (songs.isNotEmpty()) {
            _uiState.update { it.copy(addToPlaylistSongIds = songs.map { s -> s.id }) }
        }
    }

    fun setAddTarget(songId: Long) {
        _uiState.update { it.copy(addToPlaylistSongIds = listOf(songId)) }
    }

    /** 本地更新单曲收藏状态（乐观） */
    fun setSongStarLocal(songId: Long, starred: Boolean) {
        val album = _uiState.value.album ?: return
        _uiState.update {
            it.copy(album = album.copy(songs = album.songs.orEmpty().map { s ->
                if (s.id == songId) s.copy(starred = starred) else s
            }))
        }
        viewModelScope.launch {
            repository.setStar("songs", songId, starred)
        }
    }

    fun clearAddToPlaylist() {
        _uiState.update { it.copy(addToPlaylistSongIds = emptyList()) }
    }

    fun showPlaylistNotice(name: String) {
        _uiState.update { it.copy(playlistNotice = name) }
    }

    fun clearNotice() {
        _uiState.update { it.copy(playlistNotice = null) }
    }

    class Factory(private val albumId: Long) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            MusicAlbumViewModel(albumId) as T
    }
}

// ==================== Screen ====================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MusicAlbumScreen(
    albumId: Long,
    onBackClick: () -> Unit,
    onOpenArtist: (Long) -> Unit,
    onOpenPlayer: () -> Unit,
    viewModel: MusicAlbumViewModel = viewModel(factory = MusicAlbumViewModel.Factory(albumId))
) {
    val uiState by viewModel.uiState.collectAsState()
    val playbackState by MusicPlaybackManager.state.collectAsState()

    LaunchedEffect(uiState.playlistNotice) {
        if (uiState.playlistNotice != null) {
            delay(2500)
            viewModel.clearNotice()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = uiState.album?.displayTitle.orEmpty(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    // 整张专辑加入播放列表
                    PlaylistAddButton(onClick = viewModel::addAllToPlaylist)
                    StarButton(
                        starred = uiState.album?.starred == true,
                        onToggle = viewModel::toggleStar
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )

            val album = uiState.album
            if (uiState.isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (album == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        stringResource(R.string.failed_to_load),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                val songs = album.songs.orEmpty()
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = Dimens.bottomNavReserve),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    item {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = Dimens.spacingXxl, vertical = Dimens.spacingLg),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            MusicCover(
                                url = album.coverUrl,
                                modifier = Modifier.size(Dimens.carouselHeight / 2),
                                shape = RoundedCornerShape(Dimens.radiusXl),
                                fallbackIcon = Icons.Default.Album
                            )
                            Spacer(Modifier.height(Dimens.spacingMd))
                            Text(
                                text = album.displayTitle,
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.SemiBold,
                                textAlign = TextAlign.Center
                            )
                            Spacer(Modifier.height(Dimens.spacingXxs))
                            val artistLine = album.artistName.orEmpty()
                            val metaLine = listOfNotNull(
                                album.year?.toString(),
                                album.genre,
                                stringResource(R.string.music_track_count, album.trackCount ?: songs.size)
                            ).joinToString(" · ")
                            Text(
                                text = listOf(artistLine, metaLine)
                                    .filter { it.isNotBlank() }
                                    .joinToString(" · "),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center
                            )
                            Spacer(Modifier.height(Dimens.spacingSm))
                            RatingStars(rating = album.rating, onRate = viewModel::setRating)
                            Spacer(Modifier.height(Dimens.spacingSm))
                            FilledTonalButton(
                                onClick = {
                                    if (songs.isNotEmpty()) {
                                        MusicPlaybackManager.playSongs(songs)
                                        onOpenPlayer()
                                    }
                                },
                                enabled = songs.isNotEmpty(),
                                modifier = Modifier.width(Dimens.cardWideWidthTablet)
                            ) {
                                Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(Dimens.iconSize))
                                Spacer(Modifier.width(Dimens.spacingXs))
                                Text(stringResource(R.string.music_play_all))
                            }
                        }
                    }

                    itemsIndexed(songs, key = { _, song -> song.id }) { index, song ->
                        SongRow(
                            song = song,
                            index = index + 1,
                            isCurrent = playbackState.currentSong?.id == song.id,
                            onClick = {
                                MusicPlaybackManager.playSongs(songs, index)
                                onOpenPlayer()
                            },
                            onToggleStar = {
                                val newStatus = !(song.starred ?: false)
                                viewModel.setSongStarLocal(song.id, newStatus)
                            },
                            trailingContent = {
                                PlaylistAddButton(onClick = {
                                    viewModel.setAddTarget(song.id)
                                })
                            }
                        )
                    }
                }
            }
        }

        // 已加入播放列表提示
        uiState.playlistNotice?.let { name ->
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(Dimens.spacingLg)
                    .padding(bottom = Dimens.bottomNavReserve / 2)
            ) {
                Text(stringResource(R.string.music_added_to_playlist, name))
            }
        }
    }

    if (uiState.addToPlaylistSongIds.isNotEmpty()) {
        AddToPlaylistDialogHost(
            songIds = uiState.addToPlaylistSongIds,
            onDismiss = viewModel::clearAddToPlaylist,
            onSuccess = viewModel::showPlaylistNotice
        )
    }
}
