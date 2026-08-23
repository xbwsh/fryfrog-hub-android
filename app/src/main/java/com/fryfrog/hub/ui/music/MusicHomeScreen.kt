package com.fryfrog.hub.ui.music

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicAlbumDTO
import com.fryfrog.hub.data.model.MusicArtistDTO
import com.fryfrog.hub.data.model.MusicLibraryGroupDTO
import com.fryfrog.hub.data.model.MusicPlaylist
import com.fryfrog.hub.data.model.MusicSongDTO
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.playback.MusicPlaybackManager
import com.fryfrog.hub.ui.components.FryfrogTextField
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// ==================== ViewModel ====================

data class MusicHomeUiState(
    val isLoading: Boolean = false,
    val error: String? = null,
    // 首页（按库分组）
    val groups: List<MusicLibraryGroupDTO> = emptyList(),
    // 专辑 / 歌手
    val albums: List<MusicAlbumDTO> = emptyList(),
    val artists: List<MusicArtistDTO> = emptyList(),
    // 歌曲（搜索 + 流派过滤）
    val songs: List<MusicSongDTO> = emptyList(),
    val genres: List<String> = emptyList(),
    val selectedGenre: String? = null,
    val searchQuery: String = "",
    val isSearching: Boolean = false,
    // 播放列表
    val playlists: List<MusicPlaylist> = emptyList(),
    val playlistsLoading: Boolean = false,
    // 上次播放恢复
    val savedQueueIds: List<Long> = emptyList(),
    val savedCurrentIndex: Int = -1,
    val savedPositionSeconds: Double = 0.0,
    val restoringQueue: Boolean = false
)

class MusicHomeViewModel : ViewModel() {

    private val repository = MusicRepository()

    private val _uiState = MutableStateFlow(MusicHomeUiState())
    val uiState: StateFlow<MusicHomeUiState> = _uiState.asStateFlow()

    private var searchJob: Job? = null

    init {
        loadAll()
    }

    fun loadAll() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            repository.getHome().onSuccess { groups ->
                _uiState.update { it.copy(groups = groups) }
            }
            repository.getAlbums().onSuccess { albums ->
                _uiState.update { it.copy(albums = albums) }
            }
            repository.getArtists().onSuccess { artists ->
                _uiState.update { it.copy(artists = artists) }
            }
            repository.getGenres().onSuccess { genres ->
                _uiState.update { it.copy(genres = genres) }
            }
            loadPlaylists()
            loadSavedQueue()
            doSearch()
            _uiState.update { it.copy(isLoading = false) }
        }
    }

    fun loadPlaylists() {
        viewModelScope.launch {
            _uiState.update { it.copy(playlistsLoading = true) }
            repository.getPlaylists().fold(
                onSuccess = { playlists ->
                    _uiState.update { it.copy(playlists = playlists, playlistsLoading = false) }
                },
                onFailure = { e ->
                    _uiState.update { it.copy(playlistsLoading = false, error = e.message ?: "") }
                }
            )
        }
    }

    private suspend fun loadSavedQueue() {
        val queue = repository.getPlayQueue().getOrNull() ?: return
        val ids = queue.songIds()
        _uiState.update {
            it.copy(
                savedQueueIds = ids,
                savedCurrentIndex = ids.indexOfFirst { id -> id == queue.currentSongId },
                savedPositionSeconds = queue.positionSeconds ?: 0.0
            )
        }
    }

    // ===== 歌曲搜索 =====

    fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300)
            doSearch()
        }
    }

    fun selectGenre(genre: String?) {
        _uiState.update { it.copy(selectedGenre = genre) }
        searchJob?.cancel()
        searchJob = viewModelScope.launch { doSearch() }
    }

    private suspend fun doSearch() {
        val snapshot = _uiState.value
        _uiState.update { it.copy(isSearching = true) }
        repository.getSongs(
            q = snapshot.searchQuery.takeIf { q -> q.isNotBlank() },
            genre = snapshot.selectedGenre
        ).fold(
            onSuccess = { songs -> _uiState.update { it.copy(songs = songs, isSearching = false) } },
            onFailure = { e -> _uiState.update { it.copy(isSearching = false, error = e.message ?: "") } }
        )
    }

    // ===== 收藏 =====

    fun toggleSongStar(song: MusicSongDTO) = mutateSong(song.id) { it.copy(starred = !(it.starred ?: false)) }
        .also { fireStar("songs", song.id, !(song.starred ?: false)) }

    fun toggleAlbumStar(album: MusicAlbumDTO) = mutateAlbum(album.id) { it.copy(starred = !(it.starred ?: false)) }
        .also { fireStar("albums", album.id, !(album.starred ?: false)) }

    fun toggleArtistStar(artist: MusicArtistDTO) = mutateArtist(artist.id) { it.copy(starred = !(it.starred ?: false)) }
        .also { fireStar("artists", artist.id, !(artist.starred ?: false)) }

    private fun fireStar(type: String, id: Long, status: Boolean) {
        viewModelScope.launch { repository.setStar(type, id, status) }
    }

    private fun mutateSong(id: Long, transform: (MusicSongDTO) -> MusicSongDTO) {
        _uiState.update { st -> st.copy(songs = st.songs.map { if (it.id == id) transform(it) else it }) }
    }

    private fun mutateAlbum(id: Long, transform: (MusicAlbumDTO) -> MusicAlbumDTO) {
        _uiState.update { st ->
            st.copy(
                albums = st.albums.map { if (it.id == id) transform(it) else it },
                groups = st.groups.map { g ->
                    g.copy(albums = g.albums.orEmpty().map { if (it.id == id) transform(it) else it })
                }
            )
        }
    }

    private fun mutateArtist(id: Long, transform: (MusicArtistDTO) -> MusicArtistDTO) {
        _uiState.update { st ->
            st.copy(
                artists = st.artists.map { if (it.id == id) transform(it) else it },
                groups = st.groups.map { g ->
                    g.copy(artists = g.artists.orEmpty().map { if (it.id == id) transform(it) else it })
                }
            )
        }
    }

    // ===== 播放列表 =====

    fun createPlaylist(name: String) {
        viewModelScope.launch {
            repository.createPlaylist(name, null, null).fold(
                onSuccess = { loadPlaylists() },
                onFailure = { e -> _uiState.update { it.copy(error = e.message ?: "") } }
            )
        }
    }

    fun deletePlaylist(id: Long) {
        viewModelScope.launch {
            repository.deletePlaylist(id).fold(
                onSuccess = { loadPlaylists() },
                onFailure = { e -> _uiState.update { it.copy(error = e.message ?: "") } }
            )
        }
    }

    // ===== 恢复上次播放：逐个拉取详情刷新预签名 URL 后入队 =====

    fun restoreSavedQueue(maxSongs: Int = 50) {
        val snapshot = _uiState.value
        if (snapshot.savedQueueIds.isEmpty() || snapshot.restoringQueue) return
        viewModelScope.launch {
            _uiState.update { it.copy(restoringQueue = true) }
            val ids = snapshot.savedQueueIds.take(maxSongs)
            val songs = ids.mapNotNull { id -> repository.getSong(id).getOrNull() }
            if (songs.isNotEmpty()) {
                val startIndex = snapshot.savedCurrentIndex.coerceIn(0, songs.lastIndex)
                MusicPlaybackManager.playSongs(
                    songs = songs,
                    startIndex = startIndex,
                    startPositionMs = (snapshot.savedPositionSeconds * 1000).toLong()
                )
            }
            _uiState.update { it.copy(restoringQueue = false) }
        }
    }

    // ===== 管理 =====

    fun scanMusic(libraryId: Long?) {
        viewModelScope.launch {
            repository.scanLibraries(libraryId)
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

// ==================== Screen ====================

private enum class MusicTab(val titleResId: Int) {
    Home(R.string.music_tab_home),
    Albums(R.string.music_tab_albums),
    Artists(R.string.music_tab_artists),
    Songs(R.string.music_tab_songs),
    Playlists(R.string.music_tab_playlists)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MusicHomeScreen(
    isAdmin: Boolean = false,
    onOpenArtist: (Long) -> Unit,
    onOpenAlbum: (Long) -> Unit,
    onOpenPlaylist: (Long) -> Unit,
    onOpenPlayer: () -> Unit,
    viewModel: MusicHomeViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val playbackState by MusicPlaybackManager.state.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) }
    var showMenu by remember { mutableStateOf(false) }
    var showCreatePlaylistDialog by remember { mutableStateOf(false) }
    var deletePlaylistTarget by remember { mutableStateOf<MusicPlaylist?>(null) }

    // 首次进入音乐页请求通知权限（Android 13+ 后台播放通知需要）
    val context = LocalContext.current
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}
    LaunchedEffect(Unit) {
        if (android.os.Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            delay(3000)
            viewModel.clearError()
        }
    }

    Scaffold(
        contentWindowInsets = androidx.compose.foundation.layout.WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.section_music)) },
                actions = {
                    if (isAdmin) {
                        IconButton(onClick = { showMenu = true }) {
                            Icon(Icons.Default.MoreVert, contentDescription = stringResource(R.string.more))
                        }
                        DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.music_scan_all_libraries)) },
                                onClick = {
                                    showMenu = false
                                    viewModel.scanMusic(null)
                                },
                                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(Dimens.smallIconSize)) }
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            TabRow(selectedTabIndex = selectedTab) {
                MusicTab.entries.forEachIndexed { index, tab ->
                    Tab(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        text = { Text(stringResource(tab.titleResId), maxLines = 1, overflow = TextOverflow.Ellipsis) }
                    )
                }
            }

            Box(modifier = Modifier.fillMaxSize()) {
                when (MusicTab.entries[selectedTab]) {
                    MusicTab.Home -> MusicGroupsTab(
                        uiState = uiState,
                        isAdmin = isAdmin,
                        onOpenArtist = onOpenArtist,
                        onOpenAlbum = onOpenAlbum,
                        onScanLibrary = { viewModel.scanMusic(it) },
                        onResumeQueue = { viewModel.restoreSavedQueue() },
                        hasActivePlayback = playbackState.hasQueue
                    )
                    MusicTab.Albums -> MusicAlbumsTab(
                        uiState = uiState,
                        onOpenAlbum = onOpenAlbum,
                        onToggleStar = viewModel::toggleAlbumStar
                    )
                    MusicTab.Artists -> MusicArtistsTab(
                        uiState = uiState,
                        onOpenArtist = onOpenArtist,
                        onToggleStar = viewModel::toggleArtistStar
                    )
                    MusicTab.Songs -> MusicSongsTab(
                        uiState = uiState,
                        onQueryChange = viewModel::updateSearchQuery,
                        onGenreSelect = viewModel::selectGenre,
                        onToggleStar = viewModel::toggleSongStar,
                        onOpenPlayer = onOpenPlayer
                    )
                    MusicTab.Playlists -> MusicPlaylistsTab(
                        uiState = uiState,
                        onOpenPlaylist = onOpenPlaylist,
                        onCreateClick = { showCreatePlaylistDialog = true },
                        onDeleteClick = { deletePlaylistTarget = it }
                    )
                }

                // 错误提示
                uiState.error?.let { message ->
                    Snackbar(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(Dimens.spacingLg),
                        containerColor = MaterialTheme.colorScheme.errorContainer,
                        contentColor = MaterialTheme.colorScheme.onErrorContainer
                    ) {
                        Text(message, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }

    if (showCreatePlaylistDialog) {
        CreatePlaylistDialog(
            onCreate = { name ->
                viewModel.createPlaylist(name)
                showCreatePlaylistDialog = false
            },
            onDismiss = { showCreatePlaylistDialog = false }
        )
    }

    deletePlaylistTarget?.let { playlist ->
        com.fryfrog.hub.ui.components.FryfrogDialog(
            onDismissRequest = { deletePlaylistTarget = null },
            icon = Icons.Default.Delete,
            title = stringResource(R.string.music_delete_playlist),
            message = stringResource(R.string.music_delete_playlist_confirm, playlist.displayName),
            confirmText = stringResource(R.string.delete),
            confirmColor = MaterialTheme.colorScheme.error,
            onConfirm = {
                viewModel.deletePlaylist(playlist.id)
                deletePlaylistTarget = null
            },
            onDismiss = { deletePlaylistTarget = null }
        )
    }
}

// ===== 首页 Tab：按库分组 =====

@Composable
private fun MusicGroupsTab(
    uiState: MusicHomeUiState,
    isAdmin: Boolean,
    hasActivePlayback: Boolean,
    onOpenArtist: (Long) -> Unit,
    onOpenAlbum: (Long) -> Unit,
    onScanLibrary: (Long) -> Unit,
    onResumeQueue: () -> Unit
) {
    if (uiState.isLoading) {
        LoadingBox()
        return
    }
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = Dimens.pageHorizontalPadding,
            end = Dimens.pageHorizontalPadding,
            top = Dimens.spacingSm,
            bottom = Dimens.bottomNavReserve
        ),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingXl)
    ) {
        // 恢复上次播放横幅（当前无播放队列时显示）
        if (!hasActivePlayback && uiState.savedQueueIds.isNotEmpty()) {
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Dimens.radiusLg))
                        .clickable(enabled = !uiState.restoringQueue, onClick = onResumeQueue),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                ) {
                    Row(
                        modifier = Modifier.padding(Dimens.spacingMd),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        if (uiState.restoringQueue) {
                            CircularProgressIndicator(modifier = Modifier.size(Dimens.iconSize), strokeWidth = Dimens.spacingXxs)
                        } else {
                            Icon(Icons.Default.History, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                        Spacer(Modifier.width(Dimens.spacingMd))
                        Text(
                            text = stringResource(R.string.music_restore_queue),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                }
            }
        }

        if (uiState.groups.isEmpty() && !uiState.isLoading) {
            item { EmptyHint(text = stringResource(R.string.music_no_content)) }
        }

        items(uiState.groups, key = { it.libraryId ?: -1L - it.hashCode() }) { group ->
            MusicGroupSection(
                group = group,
                isAdmin = isAdmin,
                onOpenArtist = onOpenArtist,
                onOpenAlbum = onOpenAlbum,
                onScanLibrary = onScanLibrary
            )
        }
    }
}

@Composable
private fun MusicGroupSection(
    group: MusicLibraryGroupDTO,
    isAdmin: Boolean,
    onOpenArtist: (Long) -> Unit,
    onOpenAlbum: (Long) -> Unit,
    onScanLibrary: (Long) -> Unit
) {
    val albums = group.albums.orEmpty()
    val artists = group.artists.orEmpty()
    if (albums.isEmpty() && artists.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = group.displayLibraryName,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = stringResource(
                    R.string.music_library_counts,
                    group.albumCount ?: albums.size,
                    group.artistCount ?: artists.size
                ),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (isAdmin) {
                IconButton(onClick = { group.libraryId?.let(onScanLibrary) }) {
                    Icon(
                        Icons.Default.Search,
                        contentDescription = stringResource(R.string.music_scan_this_library),
                        modifier = Modifier.size(Dimens.iconSize),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        if (albums.isNotEmpty()) {
            Text(
                text = stringResource(R.string.music_tab_albums),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            LazyRow(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)) {
                items(albums, key = { "album_${it.id}" }) { album ->
                    MusicAlbumCard(
                        title = album.displayTitle,
                        subtitle = album.artistName,
                        coverUrl = album.coverUrl,
                        size = 120.dp,
                        starred = album.starred == true,
                        onClick = { onOpenAlbum(album.id) }
                    )
                }
            }
        }

        if (artists.isNotEmpty()) {
            Text(
                text = stringResource(R.string.music_tab_artists),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            LazyRow(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingXl)) {
                items(artists, key = { "artist_${it.id}" }) { artist ->
                    MusicArtistCard(
                        name = artist.displayName,
                        coverUrl = artist.coverUrl,
                        avatarSize = 72.dp,
                        starred = artist.starred == true,
                        onClick = { onOpenArtist(artist.id) }
                    )
                }
            }
        }
    }
}

// ===== 专辑 Tab =====

@Composable
private fun MusicAlbumsTab(
    uiState: MusicHomeUiState,
    onOpenAlbum: (Long) -> Unit,
    onToggleStar: (MusicAlbumDTO) -> Unit
) {
    if (uiState.isLoading) {
        LoadingBox()
        return
    }
    if (uiState.albums.isEmpty()) {
        EmptyHint(text = stringResource(R.string.music_no_albums))
        return
    }
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = Dimens.gridMinCardWidth * 1.4f),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = Dimens.pageHorizontalPadding,
            end = Dimens.pageHorizontalPadding,
            top = Dimens.spacingMd,
            bottom = Dimens.bottomNavReserve
        ),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg)
    ) {
        gridItems(uiState.albums, key = { it.id }) { album ->
            MusicAlbumCard(
                title = album.displayTitle,
                subtitle = listOfNotNull(
                    album.artistName,
                    album.year?.toString()
                ).joinToString(" · "),
                coverUrl = album.coverUrl,
                size = Dimens.cardWideWidthTablet,
                starred = album.starred == true,
                onClick = { onOpenAlbum(album.id) }
            )
        }
    }
}

// ===== 歌手 Tab =====

@Composable
private fun MusicArtistsTab(
    uiState: MusicHomeUiState,
    onOpenArtist: (Long) -> Unit,
    onToggleStar: (MusicArtistDTO) -> Unit
) {
    if (uiState.isLoading) {
        LoadingBox()
        return
    }
    if (uiState.artists.isEmpty()) {
        EmptyHint(text = stringResource(R.string.music_no_artists))
        return
    }
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = Dimens.gridMinCardWidth * 1.2f),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = Dimens.pageHorizontalPadding,
            end = Dimens.pageHorizontalPadding,
            top = Dimens.spacingMd,
            bottom = Dimens.bottomNavReserve
        ),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingLg)
    ) {
        gridItems(uiState.artists, key = { it.id }) { artist ->
            MusicArtistCard(
                name = artist.displayName,
                coverUrl = artist.coverUrl,
                avatarSize = Dimens.posterHeight * 0.6f,
                starred = artist.starred == true,
                onClick = { onOpenArtist(artist.id) }
            )
        }
    }
}

// ===== 歌曲 Tab：搜索 + 流派筛选 =====

@Composable
private fun MusicSongsTab(
    uiState: MusicHomeUiState,
    onQueryChange: (String) -> Unit,
    onGenreSelect: (String?) -> Unit,
    onToggleStar: (MusicSongDTO) -> Unit,
    onOpenPlayer: () -> Unit
) {
    val playbackState by MusicPlaybackManager.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        FryfrogTextField(
            value = uiState.searchQuery,
            onValueChange = onQueryChange,
            label = { Text(stringResource(R.string.music_search_hint)) },
            singleLine = true,
            leadingIcon = {
                Icon(Icons.Default.Search, contentDescription = null, modifier = Modifier.size(Dimens.iconSize))
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Dimens.pageHorizontalPadding, vertical = Dimens.spacingSm)
        )

        if (uiState.genres.isNotEmpty()) {
            LazyRow(
                contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
            ) {
                item {
                    FilterChip(
                        selected = uiState.selectedGenre == null,
                        onClick = { onGenreSelect(null) },
                        label = { Text(stringResource(R.string.filter_all)) }
                    )
                }
                items(uiState.genres, key = { it }) { genre ->
                    FilterChip(
                        selected = uiState.selectedGenre == genre,
                        onClick = { onGenreSelect(if (uiState.selectedGenre == genre) null else genre) },
                        label = { Text(genre) }
                    )
                }
            }
        }

        Box(modifier = Modifier.fillMaxSize()) {
            if (uiState.isSearching && uiState.songs.isEmpty()) {
                LoadingBox()
            } else if (uiState.songs.isEmpty()) {
                EmptyHint(text = stringResource(R.string.search_no_results))
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = Dimens.pageHorizontalPadding,
                        end = Dimens.pageHorizontalPadding,
                        top = Dimens.spacingXs,
                        bottom = Dimens.bottomNavReserve
                    )
                ) {
                    itemsIndexed(
                        uiState.songs,
                        key = { _, song -> song.id }
                    ) { index, song ->
                        SongRow(
                            song = song,
                            index = index + 1,
                            isCurrent = playbackState.currentSong?.id == song.id,
                            showAlbum = true,
                            onClick = {
                                // 列表刚拉取，预签名 URL 有效；直接整列入队
                                MusicPlaybackManager.playOrSeek(song, uiState.songs)
                                onOpenPlayer()
                            },
                            onToggleStar = { onToggleStar(song) }
                        )
                    }
                }
            }
        }
    }
}

// ===== 播放列表 Tab =====

@Composable
private fun MusicPlaylistsTab(
    uiState: MusicHomeUiState,
    onOpenPlaylist: (Long) -> Unit,
    onCreateClick: () -> Unit,
    onDeleteClick: (MusicPlaylist) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = Dimens.pageHorizontalPadding, vertical = Dimens.spacingSm),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.music_playlists_count, uiState.playlists.size),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f)
            )
            androidx.compose.material3.FilledTonalButton(onClick = onCreateClick) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(Dimens.smallIconSize))
                Spacer(Modifier.width(Dimens.spacingXs))
                Text(stringResource(R.string.music_new_playlist))
            }
        }

        if (uiState.playlistsLoading) {
            LoadingBox()
        } else if (uiState.playlists.isEmpty()) {
            EmptyHint(text = stringResource(R.string.music_no_playlists))
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = Dimens.pageHorizontalPadding,
                    end = Dimens.pageHorizontalPadding,
                    top = Dimens.spacingXs,
                    bottom = Dimens.bottomNavReserve
                ),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingXs)
            ) {
                items(uiState.playlists, key = { it.id }) { playlist ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(Dimens.radiusMd))
                            .clickable { onOpenPlaylist(playlist.id) },
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
                    ) {
                        Row(
                            modifier = Modifier.padding(Dimens.spacingMd),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Default.QueueMusic,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(Dimens.dialogAvatarSize)
                            )
                            Spacer(Modifier.width(Dimens.spacingMd))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = playlist.displayName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                                if (!playlist.comment.isNullOrBlank()) {
                                    Text(
                                        text = playlist.comment!!,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }
                            IconButton(onClick = { onDeleteClick(playlist) }) {
                                Icon(
                                    Icons.Default.Delete,
                                    contentDescription = stringResource(R.string.delete),
                                    tint = MaterialTheme.colorScheme.error,
                                    modifier = Modifier.size(Dimens.smallIconSize)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ===== 公共小件 =====

@Composable
private fun LoadingBox() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun EmptyHint(text: String) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun CreatePlaylistDialog(
    onCreate: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(Icons.Default.QueueMusic, contentDescription = null) },
        title = { Text(stringResource(R.string.music_create_playlist)) },
        text = {
            FryfrogTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text(stringResource(R.string.music_playlist_name)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
        },
        confirmButton = {
            androidx.compose.material3.TextButton(
                onClick = { onCreate(name.trim()) },
                enabled = name.isNotBlank()
            ) { Text(stringResource(R.string.create)) }
        },
        dismissButton = {
            androidx.compose.material3.TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}
