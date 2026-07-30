package com.fryfrog.hub.ui.videos

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.LinkOff
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.material3.HorizontalDivider
import androidx.compose.runtime.*
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.model.TmdbSearchResult
import com.fryfrog.hub.data.model.VideoActor
import com.fryfrog.hub.data.model.VideoDTO
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary
import com.fryfrog.hub.ui.theme.Success
import com.fryfrog.hub.ui.theme.Warning
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.delay

@Composable
fun VideoDetailScreen(
    viewModel: VideoDetailViewModel,
    onBackClick: () -> Unit,
    onPlayClick: (Long, Boolean) -> Unit = { _, _ -> }
) {
    val uiState by viewModel.uiState.collectAsState()
    var showScrapeSheet by remember { mutableStateOf(false) }
    var showUnbindConfirm by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }

    // Snackbar auto-dismiss
    LaunchedEffect(uiState.snackbarMessage) {
        uiState.snackbarMessage?.let { message ->
            snackbarHostState.showSnackbar(message)
            viewModel.clearSnackbarMessage()
        }
    }

    // Bind/unbind/refresh 后自动返回列表
    LaunchedEffect(uiState.shouldNavigateBack) {
        if (uiState.shouldNavigateBack) {
            viewModel.clearNavigateBack()
            onBackClick()
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (uiState.error != null) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = uiState.error ?: stringResource(R.string.unknown_error),
                    color = MaterialTheme.colorScheme.error
                )
            }
        } else {
            uiState.series?.let { series ->
                VideoDetailContent(
                    series = series,
                    actors = uiState.actors,
                    progress = uiState.progress,
                    viewModel = viewModel,
                    onBackClick = onBackClick,
                    onPlayEpisode = onPlayClick,
                    onSearchTmdb = { showScrapeSheet = true },
                    onRefreshTmdb = { viewModel.refreshTmdb() },
                    onUnbindTmdb = { showUnbindConfirm = true }
                )
            }
        }

        // Snackbar at bottom
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(Dimens.spacingLg)
        )
    }

    if (showScrapeSheet) {
        TmdbScrapeSheet(
            uiState = uiState,
            onDismiss = {
                showScrapeSheet = false
                viewModel.clearTmdbSearchResults()
            },
            onSearch = viewModel::searchTmdb,
            onClearSearch = viewModel::clearTmdbSearchResults,
            onBind = { tmdbId, mediaType ->
                viewModel.bindTmdb(tmdbId, mediaType)
                showScrapeSheet = false
            },
            onUnbind = {
                showScrapeSheet = false
                showUnbindConfirm = true
            },
            onRefresh = {
                viewModel.refreshTmdb()
                showScrapeSheet = false
            }
        )
    }

    // 解绑确认弹窗
    if (showUnbindConfirm) {
        AlertDialog(
            onDismissRequest = { showUnbindConfirm = false },
            title = { Text(stringResource(R.string.unbind_confirm_title)) },
            text = { Text(stringResource(R.string.unbind_confirm_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showUnbindConfirm = false
                        viewModel.unbindTmdb()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text(stringResource(R.string.confirm))
                }
            },
            dismissButton = {
                TextButton(onClick = { showUnbindConfirm = false }) {
                    Text(stringResource(R.string.cancel))
                }
            }
        )
    }
}

@Composable
private fun VideoDetailContent(
    series: SeriesDTO,
    actors: List<VideoActor>,
    progress: com.fryfrog.hub.data.model.WatchProgressDTO? = null,
    viewModel: VideoDetailViewModel,
    onBackClick: () -> Unit,
    onPlayEpisode: (Long, Boolean) -> Unit = { _, _ -> },
    onToggleWatched: () -> Unit = {},
    onSearchTmdb: () -> Unit,
    onRefreshTmdb: () -> Unit,
    onUnbindTmdb: () -> Unit
) {
    // 选集状态：初始 0 表示选中第一集
    var selectedEpisodeIndex by remember { mutableIntStateOf(0) }

    // 季选择状态
    val allEpisodes = series.episodes.orEmpty()
    val seasons = remember(allEpisodes) {
        allEpisodes.mapNotNull { it.seasonNumber }.distinct().sorted()
    }
    val hasMultipleSeasons = seasons.size > 1
    var selectedSeason by remember { mutableIntStateOf(seasons.firstOrNull() ?: 1) }

    // 当前季的剧集
    val currentSeasonEpisodes = remember(allEpisodes, selectedSeason) {
        if (hasMultipleSeasons) {
            allEpisodes.filter { it.seasonNumber == selectedSeason }
        } else {
            allEpisodes
        }
    }

    val selectedEpisode = selectedEpisodeIndex.takeIf { it >= 0 }?.let { currentSeasonEpisodes.getOrNull(it) }

    // 切换季时重置选集索引
    LaunchedEffect(selectedSeason) {
        selectedEpisodeIndex = 0
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize()
        ) {
            // Hero Area
            item {
                HeroSection(
                    series = series,
                    selectedEpisode = selectedEpisode,
                    progress = progress,
                    onPlayClick = {
                        val ep = selectedEpisode ?: currentSeasonEpisodes.firstOrNull()
                        ep?.let {
                            val epProgress = viewModel.episodeProgress[it.id]
                            val isCompleted = epProgress?.completed == true
                            if (isCompleted) {
                                viewModel.toggleWatched {
                                    onPlayEpisode(it.id, true)
                                }
                            } else {
                                onPlayEpisode(it.id, false)
                            }
                        }
                    },
                    onToggleWatched = onToggleWatched,
                    onSearchTmdb = onSearchTmdb,
                    onRefreshTmdb = onRefreshTmdb,
                    onUnbindTmdb = onUnbindTmdb
                )
            }

            // Video Info
            item {
                VideoInfoSection(
                    series = series,
                    selectedEpisode = selectedEpisode
                )
            }

            // Actors Section
            if (actors.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(Dimens.spacingXl))
                    SectionHeader(title = stringResource(R.string.actors))
                }
                item {
                    ActorsRow(actors = actors)
                }
            }

            // Episodes Section
            if (currentSeasonEpisodes.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(Dimens.spacingXl))
                    SectionHeader(title = stringResource(R.string.episodes))
                }

                // Season Tabs (only show when multiple seasons exist)
                if (hasMultipleSeasons) {
                    item {
                        SeasonTabRow(
                            seasons = seasons,
                            selectedSeason = selectedSeason,
                            onSeasonSelected = { season ->
                                selectedSeason = season
                            }
                        )
                    }
                }

                item {
                    EpisodeGrid(
                        episodes = currentSeasonEpisodes,
                        selectedIndex = selectedEpisodeIndex,
                        onEpisodeClick = { index ->
                            if (selectedEpisodeIndex == index) {
                                // 第二次点击同一集 → 播放
                                onPlayEpisode(currentSeasonEpisodes[index].id, false)
                            } else {
                                // 第一次点击或切换集数 → 选中并加载该集进度
                                selectedEpisodeIndex = index
                                viewModel.loadEpisodeProgress(currentSeasonEpisodes[index].id)
                            }
                        }
                    )
                }
            }

            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXxl))
            }
        }
    }
}

@Composable
private fun HeroSection(
    series: SeriesDTO,
    selectedEpisode: VideoDTO? = null,
    progress: com.fryfrog.hub.data.model.WatchProgressDTO? = null,
    onPlayClick: () -> Unit,
    onToggleWatched: () -> Unit = {},
    onSearchTmdb: () -> Unit,
    onRefreshTmdb: () -> Unit,
    onUnbindTmdb: () -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }
    val bannerUrl = selectedEpisode?.fanartUrl ?: selectedEpisode?.coverUrl
        ?: series.fanartUrl ?: series.coverUrl
    val configuration = LocalConfiguration.current
    val isTablet = configuration.screenWidthDp >= 600
    val heroHeight = if (isTablet) 400.dp else 320.dp

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(heroHeight)
    ) {
        if (bannerUrl != null) {
            AsyncImage(
                model = bannerUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        }

        // Gradient overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.3f),
                            Color.Black.copy(alpha = 0.8f)
                        )
                    )
                )
        )

        // Top-right menu
        Box(modifier = Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(Dimens.spacingMd)) {
            IconButton(
                onClick = { showMenu = true },
                modifier = Modifier.background(
                    Color.Black.copy(alpha = Dimens.alphaOverlay),
                    CircleShape
                )
            ) {
                Icon(
                    imageVector = Icons.Default.MoreVert,
                    contentDescription = stringResource(R.string.more),
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }

            DropdownMenu(
                expanded = showMenu,
                onDismissRequest = { showMenu = false },
                modifier = Modifier
                    .width(180.dp)
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(Dimens.radiusMd))
            ) {
                TmdbMenuItem(
                    icon = Icons.Default.Search,
                    label = stringResource(R.string.tmdb_search),
                    onClick = { showMenu = false; onSearchTmdb() }
                )
                HorizontalDivider(
                    modifier = Modifier.padding(horizontal = Dimens.spacingMd),
                    color = MaterialTheme.colorScheme.outlineVariant
                )
                TmdbMenuItem(
                    icon = Icons.Default.Refresh,
                    label = stringResource(R.string.tmdb_refresh),
                    onClick = { showMenu = false; onRefreshTmdb() }
                )
                if (series.tmdbId != null) {
                    HorizontalDivider(
                        modifier = Modifier.padding(horizontal = Dimens.spacingMd),
                        color = MaterialTheme.colorScheme.outlineVariant
                    )
                    TmdbMenuItem(
                        icon = Icons.Default.LinkOff,
                        label = stringResource(R.string.tmdb_unbind),
                        tint = MaterialTheme.colorScheme.error,
                        onClick = { showMenu = false; onUnbindTmdb() }
                    )
                }
            }
        }

        // Title and tags
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(Dimens.spacingLg)
        ) {
            // Tags row
            Row(
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
                modifier = Modifier.padding(bottom = Dimens.spacingSm)
            ) {
                // 类型标签
                val typeLabel = when (series.mediaType) {
                    "movie" -> "电影"
                    "tv" -> "电视剧"
                    else -> null
                }
                typeLabel?.let { label ->
                    Surface(
                        color = MaterialTheme.colorScheme.primary,
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = label,
                            modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                }

                // 成人内容标签
                if (series.isAdult == true) {
                    Surface(
                        color = Color(0xFFFF4D4F),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = "R-18",
                            modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White
                        )
                    }
                }
            }

            Text(
                text = series.title,
                style = MaterialTheme.typography.headlineMedium,
                color = Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )

            series.originalTitle?.let { originalTitle ->
                if (originalTitle != series.title) {
                    Text(
                        text = originalTitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = Dimens.alphaSubtle),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            Spacer(modifier = Modifier.height(Dimens.spacingMd))

            Row(
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Button(
                    onClick = onPlayClick,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.PlayArrow,
                        contentDescription = null,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(Dimens.spacingSm))
                    Text(
                        when {
                            progress == null || progress.progressPercent == 0.0 -> stringResource(R.string.play)
                            progress.completed -> stringResource(R.string.play_from_start)
                            else -> stringResource(R.string.resume_play)
                        }
                    )
                }

                // Watched toggle
                if (progress != null && progress.progressPercent > 0) {
                    Surface(
                        onClick = onToggleWatched,
                        color = if (progress.completed) MaterialTheme.colorScheme.tertiary.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(Dimens.spacingXs)
                        ) {
                            Icon(
                                imageVector = if (progress.completed) Icons.Default.Check else Icons.Default.Check,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = if (progress.completed) MaterialTheme.colorScheme.tertiary else Color.White.copy(alpha = 0.7f)
                            )
                            Text(
                                text = if (progress.completed) stringResource(R.string.watched) else stringResource(R.string.watched_percent, String.format("%.0f", progress.progressPercent)),
                                style = MaterialTheme.typography.labelMedium,
                                color = if (progress.completed) MaterialTheme.colorScheme.tertiary else Color.White.copy(alpha = 0.7f)
                            )
                        }
                    }
                }

                // Rating badge
                series.rating?.let { rating ->
                    Surface(
                        color = Color.Black.copy(alpha = Dimens.alphaOverlay),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = String.format("%.1f", rating),
                            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                            style = MaterialTheme.typography.titleMedium,
                            color = Color.White
                        )
                    }
                }

                // Year
                (selectedEpisode?.year ?: series.year)?.let { year ->
                    Surface(
                        color = Color.Black.copy(alpha = Dimens.alphaOverlay),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = year.toString(),
                            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                            style = MaterialTheme.typography.labelMedium,
                            color = Color.White
                        )
                    }
                }

                // Episode count
                series.episodeCount?.let { count ->
                    Surface(
                        color = Color.Black.copy(alpha = Dimens.alphaOverlay),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = "$count ${stringResource(R.string.episodes)}",
                            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                            style = MaterialTheme.typography.labelMedium,
                            color = Color.White
                        )
                    }
                }

                // Genre tag
                selectedEpisode?.genre?.let { genre ->
                    Surface(
                        color = Color.Black.copy(alpha = Dimens.alphaOverlay),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = genre,
                            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                            style = MaterialTheme.typography.labelMedium,
                            color = Color.White,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }

        }
    }
}

@Composable
private fun VideoInfoSection(
    series: SeriesDTO,
    selectedEpisode: VideoDTO? = null
) {
    val episode = selectedEpisode ?: series.episodes?.firstOrNull()

    Column(
        modifier = Modifier.padding(Dimens.spacingLg)
    ) {
        // Duration
        episode?.durationMinutes?.let { duration ->
            Text(
                text = "${duration} ${stringResource(R.string.minutes)}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Original File Name
        series.originalFileName?.let { fileName ->
            if (fileName.isNotBlank()) {
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Text(
                    text = fileName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Director
        episode?.director?.let { director ->
            Spacer(modifier = Modifier.height(Dimens.spacingXs))
            Text(
                text = "${stringResource(R.string.director)}: $director",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Overview - 固定高度，避免切换剧集时下方内容位移
        val overview = selectedEpisode?.overview ?: series.overview
        overview?.let {
            Spacer(modifier = Modifier.height(Dimens.spacingLg))
            Box(modifier = Modifier.height(110.dp)) {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 5,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier.padding(horizontal = Dimens.spacingLg)
    )
}

@Composable
private fun ActorsRow(actors: List<VideoActor>) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
    ) {
        items(actors) { actor ->
            ActorCard(actor = actor)
        }
    }
}

@Composable
private fun ActorCard(actor: VideoActor) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(80.dp)
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center
        ) {
            if (actor.imageUrl != null) {
                AsyncImage(
                    model = actor.imageUrl,
                    contentDescription = actor.name,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )
            } else {
                Icon(
                    imageVector = Icons.Default.Person,
                    contentDescription = actor.name,
                    modifier = Modifier.size(32.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Spacer(modifier = Modifier.height(Dimens.spacingXs))

        Text(
            text = actor.name,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        actor.character?.let { character ->
            Text(
                text = character,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun EpisodeCard(
    episode: VideoDTO,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(Dimens.radiusMd)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Episode thumbnail
            Box(
                modifier = Modifier
                    .size(80.dp, 50.dp)
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (episode.coverUrl != null) {
                    AsyncImage(
                        model = episode.coverUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                }

                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .size(24.dp)
                )
            }

            Spacer(modifier = Modifier.width(Dimens.spacingMd))

            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = episode.title,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                episode.durationMinutes?.let { duration ->
                    Text(
                        text = "${duration} ${stringResource(R.string.minutes)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun EpisodeGrid(
    episodes: List<VideoDTO>,
    selectedIndex: Int = -1,
    episodeProgress: Map<Long, com.fryfrog.hub.data.model.WatchProgressDTO> = emptyMap(),
    onEpisodeClick: (Int) -> Unit
) {
    val columns = 6
    val rows = (episodes.size + columns - 1) / columns

    Column(
        modifier = Modifier.padding(horizontal = Dimens.spacingLg)
    ) {
        for (row in 0 until rows) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
            ) {
                for (col in 0 until columns) {
                    val index = row * columns + col
                    if (index < episodes.size) {
                        val episode = episodes[index]
                        val epProgress = episodeProgress[episode.id]
                        EpisodeNumberBlock(
                            number = episode.episodeNumber ?: (index + 1),
                            isSelected = index == selectedIndex,
                            progressPercent = epProgress?.progressPercent?.toFloat() ?: 0f,
                            isCompleted = epProgress?.completed == true,
                            onClick = { onEpisodeClick(index) },
                            modifier = Modifier.weight(1f)
                        )
                    } else {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
            if (row < rows - 1) {
                Spacer(modifier = Modifier.height(Dimens.spacingXs))
            }
        }
    }
}

@Composable
private fun TmdbMenuItem(
    icon: ImageVector,
    label: String,
    tint: Color = MaterialTheme.colorScheme.onSurface,
    onClick: () -> Unit
) {
    DropdownMenuItem(
        text = {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = tint
            )
        },
        onClick = onClick,
        leadingIcon = {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = tint
            )
        },
        contentPadding = PaddingValues(horizontal = Dimens.spacingMd, vertical = Dimens.spacingSm)
    )
}

@Composable
private fun EpisodeNumberBlock(
    number: Int,
    isSelected: Boolean = false,
    progressPercent: Float = 0f,
    isCompleted: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(Dimens.radiusSm))
            .background(
                if (isSelected) Primary
                else MaterialTheme.colorScheme.surfaceVariant
            )
            .clickable(onClick = onClick)
            .padding(vertical = Dimens.spacingSm),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "$number",
            style = MaterialTheme.typography.bodyMedium,
            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
        )
        if (progressPercent > 0f) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(2.dp)
                    .background(Color.Black.copy(alpha = 0.3f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(fraction = (progressPercent / 100f).coerceIn(0f, 1f))
                        .fillMaxHeight()
                        .background(
                            if (isCompleted) com.fryfrog.hub.ui.theme.Success
                            else com.fryfrog.hub.ui.theme.Primary
                        )
                )
            }
        }
    }
}

@Composable
private fun SeasonTabRow(
    seasons: List<Int>,
    selectedSeason: Int,
    onSeasonSelected: (Int) -> Unit
) {
    val selectedIndex = seasons.indexOf(selectedSeason).coerceAtLeast(0)

    ScrollableTabRow(
        selectedTabIndex = selectedIndex,
        modifier = Modifier.padding(horizontal = Dimens.spacingLg),
        edgePadding = Dimens.spacingSm,
        containerColor = Color.Transparent,
        divider = {},
        indicator = { }
    ) {
        seasons.forEach { season ->
            Tab(
                selected = season == selectedSeason,
                onClick = { onSeasonSelected(season) },
                text = {
                    Text(
                        text = stringResource(R.string.season_label, season),
                        style = if (season == selectedSeason) {
                            MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold)
                        } else {
                            MaterialTheme.typography.labelLarge
                        },
                        color = if (season == selectedSeason) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        }
                    )
                }
            )
        }
    }
}
@Composable
private fun TmdbScrapeSheet(
    uiState: VideoDetailUiState,
    onDismiss: () -> Unit,
    onSearch: (String) -> Unit,
    onClearSearch: () -> Unit,
    onBind: (Long, String) -> Unit,
    onUnbind: () -> Unit,
    onRefresh: () -> Unit
) {
    var searchQuery by remember { mutableStateOf(uiState.series?.originalFileName ?: uiState.series?.title ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .width(4.dp)
                        .height(20.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(Primary)
                )
                Spacer(modifier = Modifier.width(Dimens.spacingSm))
                Text(
                    text = stringResource(R.string.tmdb_scrape),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
            }
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth()) {
                // Current binding card
                uiState.series?.let { series ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(Dimens.radiusMd),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                        )
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(Dimens.spacingMd),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (series.tmdbId != null) Success.copy(alpha = 0.1f)
                                        else MaterialTheme.colorScheme.surfaceVariant
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = if (series.tmdbId != null) Icons.Default.Check else Icons.Default.Close,
                                    contentDescription = null,
                                    tint = if (series.tmdbId != null) Success else MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(18.dp)
                                )
                            }

                            Spacer(modifier = Modifier.width(Dimens.spacingMd))

                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = stringResource(R.string.tmdb_current_binding),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Spacer(modifier = Modifier.height(Dimens.spacingXxs))
                                if (series.tmdbId != null) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(
                                            text = "TMDB #${series.tmdbId}",
                                            style = MaterialTheme.typography.bodyMedium,
                                            fontWeight = FontWeight.Medium
                                        )
                                        Spacer(modifier = Modifier.width(Dimens.spacingSm))
                                        Surface(
                                            color = Primary.copy(alpha = 0.1f),
                                            shape = RoundedCornerShape(Dimens.radiusSm)
                                        ) {
                                            Text(
                                                text = (series.mediaType ?: "tv").uppercase(),
                                                modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                                                style = MaterialTheme.typography.labelSmall,
                                                color = Primary
                                            )
                                        }
                                    }
                                } else {
                                    Text(
                                        text = stringResource(R.string.tmdb_not_bound),
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(Dimens.spacingLg))

                // Search section
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .width(4.dp)
                            .height(16.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(Primary)
                    )
                    Spacer(modifier = Modifier.width(Dimens.spacingSm))
                    Text(
                        text = stringResource(R.string.tmdb_search),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Spacer(modifier = Modifier.height(Dimens.spacingMd))

                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text(stringResource(R.string.tmdb_search_hint)) },
                    singleLine = true,
                    trailingIcon = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (searchQuery.isNotEmpty()) {
                                IconButton(
                                    onClick = {
                                        searchQuery = ""
                                        onClearSearch()
                                    }
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Close,
                                        contentDescription = stringResource(R.string.clear_search)
                                    )
                                }
                            }
                            if (uiState.isSearchingTmdb) {
                                CircularProgressIndicator(
                                    modifier = Modifier
                                        .padding(horizontal = Dimens.spacingMd)
                                        .size(Dimens.iconSize),
                                    strokeWidth = 2.dp,
                                    color = Primary
                                )
                            } else {
                                IconButton(
                                    onClick = { onSearch(searchQuery) },
                                    enabled = searchQuery.isNotBlank()
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Search,
                                        contentDescription = stringResource(R.string.tmdb_search),
                                        tint = if (searchQuery.isNotBlank()) Primary else MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                        }
                    }
                )

                // Search results
                if (uiState.tmdbSearchResults.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(Dimens.spacingMd))

                    Surface(
                        color = Primary.copy(alpha = 0.1f),
                        shape = RoundedCornerShape(Dimens.radiusSm)
                    ) {
                        Text(
                            text = stringResource(R.string.tmdb_search_results, uiState.tmdbSearchResults.size),
                            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                            style = MaterialTheme.typography.labelSmall,
                            color = Primary
                        )
                    }

                    Spacer(modifier = Modifier.height(Dimens.spacingSm))

                    LazyColumn(
                        modifier = Modifier.heightIn(max = 300.dp),
                        verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                    ) {
                        items(uiState.tmdbSearchResults) { result ->
                            TmdbSearchResultItem(
                                result = result,
                                isBinding = uiState.isBindingTmdb,
                                onBind = { onBind(result.id, result.mediaType ?: "tv") }
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (uiState.series?.tmdbId != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)) {
                    TextButton(
                        onClick = onRefresh,
                        enabled = !uiState.isRefreshingTmdb
                    ) {
                        if (uiState.isRefreshingTmdb) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(Dimens.spacingXs))
                            Text(stringResource(R.string.tmdb_refresh))
                        }
                    }
                    TextButton(
                        onClick = onUnbind,
                        enabled = !uiState.isUnbindingTmdb,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        if (uiState.isUnbindingTmdb) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = MaterialTheme.colorScheme.error)
                        } else {
                            Icon(Icons.Default.LinkOff, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(Dimens.spacingXs))
                            Text(stringResource(R.string.tmdb_unbind))
                        }
                    }
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun TmdbSearchResultItem(
    result: TmdbSearchResult,
    isBinding: Boolean,
    onBind: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        onClick = { if (!isBinding) onBind() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Poster thumbnail - consistent with VolumeCard pattern
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                result.posterPath?.let { path ->
                    val imageUrl = if (path.startsWith("http")) path else "https://image.tmdb.org/t/p/w200$path"
                    AsyncImage(
                        model = imageUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                }
            }

            Spacer(modifier = Modifier.width(Dimens.spacingMd))

            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = result.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                result.originalTitle?.let { originalTitle ->
                    if (originalTitle != result.title) {
                        Text(
                            text = originalTitle,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                Spacer(modifier = Modifier.height(Dimens.spacingXxs))

                // Info chips row - matching InfoChip pattern
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    result.releaseDate?.let { date ->
                        if (date.length >= 4) {
                            Text(
                                text = date.substring(0, 4),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                    result.voteAverage?.let { rating ->
                        Surface(
                            color = Warning.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(Dimens.radiusSm)
                        ) {
                            Text(
                                text = String.format("%.1f", rating),
                                modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                                style = MaterialTheme.typography.labelSmall,
                                color = Warning
                            )
                        }
                    }
                    result.mediaType?.let { type ->
                        Surface(
                            color = Primary.copy(alpha = 0.1f),
                            shape = RoundedCornerShape(Dimens.radiusSm)
                        ) {
                            Text(
                                text = type.uppercase(),
                                modifier = Modifier.padding(horizontal = Dimens.spacingXs, vertical = Dimens.spacingXxs),
                                style = MaterialTheme.typography.labelSmall,
                                color = Primary
                            )
                        }
                    }
                }
            }

            // Bind indicator
            if (isBinding) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    strokeWidth = 2.dp,
                    color = Primary
                )
            } else {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Primary,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}
