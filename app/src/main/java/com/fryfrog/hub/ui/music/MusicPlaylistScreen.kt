package com.fryfrog.hub.ui.music

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicPlaylist
import com.fryfrog.hub.data.model.MusicPlaylistUpdateRequest
import com.fryfrog.hub.data.model.MusicSongDTO
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.playback.MusicPlaybackManager
import com.fryfrog.hub.ui.components.FryfrogDialog
import com.fryfrog.hub.ui.components.FryfrogTextField
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ==================== ViewModel ====================

data class MusicPlaylistDetailUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val playlist: MusicPlaylist? = null,
    val songs: List<MusicSongDTO> = emptyList()
)

class MusicPlaylistDetailViewModel(private val playlistId: Long) : ViewModel() {

    private val repository = MusicRepository()

    private val _uiState = MutableStateFlow(MusicPlaylistDetailUiState())
    val uiState: StateFlow<MusicPlaylistDetailUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            repository.getPlaylistDetail(playlistId).fold(
                onSuccess = { (playlist, songs) ->
                    _uiState.update {
                        it.copy(isLoading = false, playlist = playlist, songs = songs)
                    }
                },
                onFailure = { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message ?: "") }
                }
            )
        }
    }

    /** 按位置移除歌曲（后端 0-based 下标），成功后重新加载 */
    fun removeSongAt(index: Int) {
        viewModelScope.launch {
            repository.updatePlaylist(playlistId, MusicPlaylistUpdateRequest(songIndexesToRemove = listOf(index)))
                .onSuccess { load() }
                .onFailure { e -> _uiState.update { it.copy(error = e.message ?: "") } }
        }
    }

    fun saveMeta(name: String, comment: String, isPublic: Boolean, onDone: () -> Unit) {
        viewModelScope.launch {
            repository.updatePlaylist(
                playlistId,
                MusicPlaylistUpdateRequest(
                    name = name.takeIf { it.isNotBlank() },
                    comment = comment.takeIf { it.isNotBlank() },
                    isPublic = isPublic
                )
            ).fold(
                onSuccess = {
                    load()
                    onDone()
                },
                onFailure = { e -> _uiState.update { it.copy(error = e.message ?: "") } }
            )
        }
    }

    fun deletePlaylist(onDone: () -> Unit) {
        viewModelScope.launch {
            repository.deletePlaylist(playlistId).fold(
                onSuccess = { onDone() },
                onFailure = { e -> _uiState.update { it.copy(error = e.message ?: "") } }
            )
        }
    }

    class Factory(private val playlistId: Long) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            MusicPlaylistDetailViewModel(playlistId) as T
    }
}

// ==================== Screen ====================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MusicPlaylistScreen(
    playlistId: Long,
    onBackClick: () -> Unit,
    onOpenPlayer: () -> Unit,
    viewModel: MusicPlaylistDetailViewModel = viewModel(factory = MusicPlaylistDetailViewModel.Factory(playlistId))
) {
    val uiState by viewModel.uiState.collectAsState()
    val playbackState by MusicPlaybackManager.state.collectAsState()

    var showEditDialog by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = {
                Text(
                    text = uiState.playlist?.displayName.orEmpty(),
                    maxLines = 1
                )
            },
            navigationIcon = {
                IconButton(onClick = onBackClick) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                }
            },
            actions = {
                IconButton(onClick = { showEditDialog = true }) {
                    Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.edit))
                }
                IconButton(onClick = { showDeleteDialog = true }) {
                    Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.delete), tint = MaterialTheme.colorScheme.error)
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )

        if (uiState.isLoading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (uiState.playlist == null && uiState.songs.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    text = uiState.error ?: stringResource(R.string.failed_to_load),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            Column(modifier = Modifier.fillMaxSize()) {
                val comment = uiState.playlist?.comment
                if (!comment.isNullOrBlank()) {
                    Text(
                        text = comment,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = Dimens.pageHorizontalPadding)
                    )
                }

                FilledTonalButton(
                    onClick = {
                        if (uiState.songs.isNotEmpty()) {
                            MusicPlaybackManager.playSongs(uiState.songs)
                            onOpenPlayer()
                        }
                    },
                    enabled = uiState.songs.isNotEmpty(),
                    modifier = Modifier.padding(horizontal = Dimens.pageHorizontalPadding, vertical = Dimens.spacingSm)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, modifier = Modifier.size(Dimens.iconSize))
                    Text("  " + stringResource(R.string.music_play_all_songs, uiState.songs.size))
                }

                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = Dimens.bottomNavReserve)
                ) {
                    itemsIndexed(uiState.songs, key = { _, song -> song.id }) { index, song ->
                        SongRow(
                            song = song,
                            index = index + 1,
                            isCurrent = playbackState.currentSong?.id == song.id,
                            onClick = {
                                MusicPlaybackManager.playSongs(uiState.songs, index)
                                onOpenPlayer()
                            },
                            trailingContent = {
                                IconButton(onClick = { viewModel.removeSongAt(index) }) {
                                    Icon(
                                        Icons.Default.Close,
                                        contentDescription = stringResource(R.string.music_remove_from_playlist),
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(Dimens.iconSize)
                                    )
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // 编辑播放列表信息
    if (showEditDialog) {
        EditPlaylistDialog(
            initialName = uiState.playlist?.displayName.orEmpty(),
            initialComment = uiState.playlist?.comment.orEmpty(),
            initialIsPublic = uiState.playlist?.isPublic == true,
            onSave = { name, comment, isPublic ->
                viewModel.saveMeta(name, comment, isPublic) { showEditDialog = false }
            },
            onDismiss = { showEditDialog = false }
        )
    }

    // 删除播放列表确认
    if (showDeleteDialog) {
        FryfrogDialog(
            onDismissRequest = { showDeleteDialog = false },
            icon = Icons.Default.Delete,
            title = stringResource(R.string.music_delete_playlist),
            message = stringResource(R.string.music_delete_playlist_confirm, uiState.playlist?.displayName ?: ""),
            confirmText = stringResource(R.string.delete),
            confirmColor = MaterialTheme.colorScheme.error,
            onConfirm = {
                showDeleteDialog = false
                viewModel.deletePlaylist(onDone = onBackClick)
            },
            onDismiss = { showDeleteDialog = false }
        )
    }
}

@Composable
private fun EditPlaylistDialog(
    initialName: String,
    initialComment: String,
    initialIsPublic: Boolean,
    onSave: (name: String, comment: String, isPublic: Boolean) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf(initialName) }
    var comment by remember { mutableStateOf(initialComment) }
    var isPublic by remember { mutableStateOf(initialIsPublic) }

    FryfrogDialog(
        onDismissRequest = onDismiss,
        icon = Icons.Default.Edit,
        title = stringResource(R.string.music_edit_playlist),
        content = {
            Column {
                FryfrogTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.music_playlist_name)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                FryfrogTextField(
                    value = comment,
                    onValueChange = { comment = it },
                    label = { Text(stringResource(R.string.description)) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = Dimens.spacingMd)
                )
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = Dimens.spacingMd),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.music_public_playlist),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f)
                    )
                    androidx.compose.material3.Switch(
                        checked = isPublic,
                        onCheckedChange = { isPublic = it }
                    )
                }
            }
        },
        confirmText = stringResource(R.string.save),
        confirmEnabled = name.isNotBlank(),
        onConfirm = { onSave(name.trim(), comment.trim(), isPublic) },
        onDismiss = onDismiss
    )
}
