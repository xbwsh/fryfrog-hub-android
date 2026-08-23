package com.fryfrog.hub.ui.music

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Album
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicArtistDTO
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ==================== ViewModel ====================

data class MusicArtistUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val artist: MusicArtistDTO? = null
)

class MusicArtistViewModel(private val artistId: Long) : ViewModel() {

    private val repository = MusicRepository()

    private val _uiState = MutableStateFlow(MusicArtistUiState())
    val uiState: StateFlow<MusicArtistUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            repository.getArtist(artistId).fold(
                onSuccess = { artist -> _uiState.update { it.copy(isLoading = false, artist = artist) } },
                onFailure = { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message ?: "") }
                }
            )
        }
    }

    fun toggleStar() {
        val artist = _uiState.value.artist ?: return
        val newStatus = !(artist.starred ?: false)
        _uiState.update { it.copy(artist = artist.copy(starred = newStatus)) }
        viewModelScope.launch {
            repository.setStar("artists", artist.id, newStatus)
        }
    }

    class Factory(private val artistId: Long) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            MusicArtistViewModel(artistId) as T
    }
}

// ==================== Screen ====================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MusicArtistScreen(
    artistId: Long,
    onBackClick: () -> Unit,
    onOpenAlbum: (Long) -> Unit,
    viewModel: MusicArtistViewModel = viewModel(factory = MusicArtistViewModel.Factory(artistId))
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(
            title = {
                Text(
                    text = uiState.artist?.displayName.orEmpty(),
                    maxLines = 1
                )
            },
            navigationIcon = {
                IconButton(onClick = onBackClick) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                }
            },
            actions = {
                StarButton(
                    starred = uiState.artist?.starred == true,
                    onToggle = viewModel::toggleStar
                )
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.background
            )
        )

        val artist = uiState.artist
        if (uiState.isLoading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (artist == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    stringResource(R.string.failed_to_load),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            val albums = artist.albums.orEmpty()
            LazyVerticalGrid(
                columns = GridCells.Adaptive(minSize = Dimens.gridMinCardWidth * 1.4f),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = Dimens.pageHorizontalPadding,
                    end = Dimens.pageHorizontalPadding,
                    top = Dimens.spacingSm,
                    bottom = Dimens.bottomNavReserve
                ),
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg)
            ) {
                item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        MusicCover(
                            url = artist.coverUrl,
                            modifier = Modifier.size(Dimens.carouselHeight / 2),
                            shape = androidx.compose.foundation.shape.CircleShape,
                            fallbackIcon = Icons.Default.Person
                        )
                        Spacer(Modifier.height(Dimens.spacingMd))
                        Text(
                            text = artist.displayName,
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.SemiBold,
                            textAlign = TextAlign.Center
                        )
                        Spacer(Modifier.height(Dimens.spacingXxs))
                        Text(
                            text = stringResource(R.string.music_album_count, albums.size),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(Dimens.spacingMd))
                        Text(
                            text = stringResource(R.string.music_tab_albums),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.align(Alignment.Start)
                        )
                    }
                }

                if (albums.isEmpty()) {
                    item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                        Text(
                            text = stringResource(R.string.music_no_albums),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                } else {
                    gridItems(albums, key = { it.id }) { album ->
                        MusicAlbumCard(
                            title = album.displayTitle,
                            subtitle = album.year?.toString(),
                            coverUrl = album.coverUrl,
                            size = Dimens.cardWideWidthTablet,
                            starred = album.starred == true,
                            onClick = { onOpenAlbum(album.id) },
                            fallbackIcon = Icons.Default.Album
                        )
                    }
                }
            }
        }
    }
}
