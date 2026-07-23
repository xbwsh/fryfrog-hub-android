package com.fryfrog.hub.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.components.MediaCard
import com.fryfrog.hub.ui.components.SectionHeader
import com.fryfrog.hub.ui.components.WideMediaCard
import com.fryfrog.hub.ui.theme.Dimens
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val CAROUSEL_AUTO_SCROLL_DELAY = 3000L
private const val CAROUSEL_MAX_ITEMS = 5

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(),
    isAdultContentHidden: Boolean = true,
    sectionOrder: List<String> = listOf("videos", "music", "comics", "ebooks"),
    sectionVisible: Map<String, Boolean> = mapOf(
        "videos" to true, "music" to true, "comics" to true, "ebooks" to true
    ),
    carouselSource: String = "videos",
    isCarouselEnabled: Boolean = true,
    onVideoClick: (Long, String) -> Unit = { _, _ -> },
    onMusicClick: (Long) -> Unit = {},
    onComicClick: (Long) -> Unit = {},
    onEbookClick: (Long) -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name)) },
                modifier = Modifier.statusBarsPadding(),
                actions = {
                    IconButton(onClick = { viewModel.loadHomeData() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = stringResource(R.string.refresh)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        if (uiState.isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (uiState.error != null) {
            ErrorContent(
                message = uiState.error ?: stringResource(R.string.unknown_error),
                onRetry = { viewModel.loadHomeData() },
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            HomeContent(
                uiState = uiState,
                isAdultContentHidden = isAdultContentHidden,
                sectionOrder = sectionOrder,
                sectionVisible = sectionVisible,
                carouselSource = carouselSource,
                isCarouselEnabled = isCarouselEnabled,
                onVideoClick = onVideoClick,
                onMusicClick = onMusicClick,
                onComicClick = onComicClick,
                onEbookClick = onEbookClick,
                modifier = Modifier.padding(paddingValues)
            )
        }
    }
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    isAdultContentHidden: Boolean,
    sectionOrder: List<String>,
    sectionVisible: Map<String, Boolean>,
    carouselSource: String,
    isCarouselEnabled: Boolean,
    onVideoClick: (Long, String) -> Unit,
    onMusicClick: (Long) -> Unit,
    onComicClick: (Long) -> Unit,
    onEbookClick: (Long) -> Unit,
    modifier: Modifier = Modifier
) {
    val unknownTitle = stringResource(R.string.unknown)

    val filteredVideoSeries by remember(uiState.videoSeries, isAdultContentHidden) {
        derivedStateOf {
            if (isAdultContentHidden) {
                uiState.videoSeries.filter { it.isAdult != true }
            } else {
                uiState.videoSeries
            }
        }
    }

    // Build carousel items from the selected source with random shuffle
    val carouselItems by remember(filteredVideoSeries, uiState.musicAlbums, uiState.comicSeries, uiState.ebookSeries, carouselSource, isAdultContentHidden) {
        derivedStateOf {
            when (carouselSource) {
                "videos" -> filteredVideoSeries.shuffled().take(CAROUSEL_MAX_ITEMS).map { item ->
                    CarouselItem(
                        title = item.title,
                        subtitle = item.year?.toString(),
                        coverUrl = item.fanartUrl ?: item.coverUrl,
                        onClick = { onVideoClick(item.id, item.type ?: "series") }
                    )
                }
                "music" -> uiState.musicAlbums.shuffled().take(CAROUSEL_MAX_ITEMS).map { item ->
                    CarouselItem(
                        title = item.album ?: "",
                        subtitle = item.artist,
                        coverUrl = item.coverUrl,
                        onClick = { item.tracks?.firstOrNull()?.let { onMusicClick(it.id) } }
                    )
                }
                "comics" -> uiState.comicSeries.shuffled().take(CAROUSEL_MAX_ITEMS).map { item ->
                    CarouselItem(
                        title = item.name ?: unknownTitle,
                        subtitle = item.author,
                        coverUrl = item.coverUrl,
                        onClick = { item.seriesId?.let { onComicClick(it) } }
                    )
                }
                "ebooks" -> uiState.ebookSeries.shuffled().take(CAROUSEL_MAX_ITEMS).map { item ->
                    CarouselItem(
                        title = item.name ?: unknownTitle,
                        subtitle = item.author,
                        coverUrl = item.coverUrl,
                        onClick = { item.seriesId?.let { onEbookClick(it) } }
                    )
                }
                else -> emptyList()
            }
        }
    }

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Dimens.spacingLg)
    ) {
        // Carousel
        if (isCarouselEnabled && carouselItems.isNotEmpty()) {
            item {
                CarouselSection(items = carouselItems)
            }
        }

        // Dynamic sections based on order and visibility
        sectionOrder.forEachIndexed { index, sectionId ->
            if (sectionVisible[sectionId] != false) {
                when (sectionId) {
                    "videos" -> {
                        if (filteredVideoSeries.isNotEmpty()) {
                            if (index > 0 || (isCarouselEnabled && carouselItems.isNotEmpty())) {
                                item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                            }
                            item {
                                SectionHeader(title = stringResource(R.string.section_videos))
                            }
                            item {
                                LazyRow(
                                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                                ) {
                                    items(filteredVideoSeries) { series ->
                                        MediaCard(
                                            title = series.title,
                                            subtitle = series.year?.toString(),
                                            coverUrl = series.coverUrl,
                                            onClick = { onVideoClick(series.id, series.type ?: "series") }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    "music" -> {
                        if (uiState.musicAlbums.isNotEmpty()) {
                            if (index > 0) {
                                item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                            }
                            item {
                                SectionHeader(title = stringResource(R.string.section_music))
                            }
                            item {
                                LazyRow(
                                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                                ) {
                                    items(uiState.musicAlbums) { album ->
                                        MediaCard(
                                            title = album.album ?: stringResource(R.string.unknown_album),
                                            subtitle = album.artist,
                                            coverUrl = album.coverUrl,
                                            onClick = { album.tracks?.firstOrNull()?.let { onMusicClick(it.id) } },
                                            square = true
                                        )
                                    }
                                }
                            }
                        }
                    }
                    "comics" -> {
                        if (uiState.comicSeries.isNotEmpty()) {
                            if (index > 0) {
                                item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                            }
                            item {
                                SectionHeader(title = stringResource(R.string.section_comics))
                            }
                            item {
                                LazyRow(
                                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                                ) {
                                    items(uiState.comicSeries) { series ->
                                        MediaCard(
                                            title = series.name ?: unknownTitle,
                                            subtitle = series.author,
                                            coverUrl = series.coverUrl,
                                            onClick = { series.seriesId?.let { onComicClick(it) } }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    "ebooks" -> {
                        if (uiState.ebookSeries.isNotEmpty()) {
                            if (index > 0) {
                                item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                            }
                            item {
                                SectionHeader(title = stringResource(R.string.section_ebooks))
                            }
                            item {
                                LazyRow(
                                    contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                                ) {
                                    items(uiState.ebookSeries) { series ->
                                        MediaCard(
                                            title = series.name ?: unknownTitle,
                                            subtitle = series.author,
                                            coverUrl = series.coverUrl,
                                            onClick = { series.seriesId?.let { onEbookClick(it) } }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private data class CarouselItem(
    val title: String,
    val subtitle: String?,
    val coverUrl: String?,
    val onClick: () -> Unit
)

@Composable
private fun CarouselSection(items: List<CarouselItem>) {
    val pagerState = rememberPagerState(pageCount = { items.size })
    val scope = rememberCoroutineScope()

    // Auto-scroll
    LaunchedEffect(pagerState) {
        while (true) {
            delay(CAROUSEL_AUTO_SCROLL_DELAY)
            val nextPage = (pagerState.currentPage + 1) % items.size
            pagerState.animateScrollToPage(nextPage)
        }
    }

    Column {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .height(Dimens.carouselHeight),
            contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
            pageSpacing = Dimens.spacingMd
        ) { page ->
            val item = items[page]
            WideMediaCard(
                title = item.title,
                subtitle = item.subtitle,
                coverUrl = item.coverUrl,
                onClick = item.onClick,
                modifier = Modifier
                    .fillMaxHeight()
                    .padding(horizontal = Dimens.spacingXs),
                fixedSize = false
            )
        }

        // Page indicators
        if (items.size > 1) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = Dimens.spacingSm),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(items.size) { index ->
                    Box(
                        modifier = Modifier
                            .padding(horizontal = Dimens.indicatorSpacing)
                            .size(Dimens.indicatorSize)
                            .clip(CircleShape)
                            .background(
                                if (pagerState.currentPage == index) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.onSurface.copy(alpha = Dimens.alphaDisabled)
                                }
                            )
                    )
                }
            }
        }
    }
}

@Composable
private fun ErrorContent(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = stringResource(R.string.failed_to_load),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.error
        )

        Spacer(modifier = Modifier.height(Dimens.spacingSm))

        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(Dimens.spacingLg))

        Button(onClick = onRetry) {
            Text(stringResource(R.string.retry))
        }
    }
}
