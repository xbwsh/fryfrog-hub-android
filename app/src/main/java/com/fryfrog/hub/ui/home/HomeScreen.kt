package com.fryfrog.hub.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.ViewModule
import androidx.compose.material.icons.filled.ViewList
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.LibraryGroup
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.ui.components.MediaCard
import com.fryfrog.hub.ui.components.SectionHeader
import com.fryfrog.hub.ui.components.WideMediaCard
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary
import kotlinx.coroutines.delay

private const val CAROUSEL_AUTO_SCROLL_DELAY = 3000L
private const val CAROUSEL_MAX_ITEMS = 5

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(),
    isAdultContentHidden: Boolean = true,
    isCarouselEnabled: Boolean = true,
    homeViewMode: String = "grouped",
    onViewModeChange: (String) -> Unit = {},
    onCalendarClick: () -> Unit = {},
    onFavoritesClick: () -> Unit = {},
    onVideoClick: (Long, String) -> Unit = { _, _ -> },
    onLibraryClick: (Long?, String) -> Unit = { _, _ -> }
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(isAdultContentHidden) {
        viewModel.setAdultContentHidden(isAdultContentHidden)
    }

    LaunchedEffect(homeViewMode) {
        viewModel.setViewMode(homeViewMode)
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0)
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().padding(paddingValues)) {
            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (uiState.error != null) {
                ErrorContent(
                    message = uiState.error ?: stringResource(R.string.unknown_error),
                    onRetry = { viewModel.loadHomeData() },
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                if (homeViewMode == "grouped") {
                    GroupedContent(
                        uiState = uiState,
                        isCarouselEnabled = isCarouselEnabled,
                        onVideoClick = onVideoClick,
                        onLibraryClick = onLibraryClick,
                        modifier = Modifier.fillMaxSize()
                    )
                } else {
                    OverviewContent(
                        uiState = uiState,
                        isCarouselEnabled = isCarouselEnabled,
                        onVideoClick = onVideoClick,
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(Dimens.topBarGradientHeight)
            ) {
                val gradientColors = listOf(
                    Color.Black.copy(alpha = 0.6f),
                    Color.Black.copy(alpha = 0.3f),
                    Color.Transparent
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Brush.verticalGradient(gradientColors))
                )

                Row(
                    modifier = Modifier
                        .fillMaxSize()
                        .statusBarsPadding()
                        .padding(horizontal = Dimens.spacingMd)
                ) {
                    Text(
                        text = stringResource(R.string.app_name),
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.weight(1f).align(Alignment.CenterVertically)
                    )
                    Row(modifier = Modifier.align(Alignment.CenterVertically)) {
                        IconButton(onClick = onFavoritesClick) {
                            Icon(
                                imageVector = Icons.Default.FavoriteBorder,
                                contentDescription = stringResource(R.string.favorites_title),
                                tint = Color.White
                            )
                        }
                        IconButton(onClick = onCalendarClick) {
                            Icon(
                                imageVector = Icons.Default.CalendarMonth,
                                contentDescription = stringResource(R.string.upcoming_calendar),
                                tint = Color.White
                            )
                        }
                        IconButton(onClick = {
                            val newMode = if (homeViewMode == "grouped") "overview" else "grouped"
                            onViewModeChange(newMode)
                        }) {
                            Icon(
                                imageVector = if (homeViewMode == "grouped") Icons.Default.ViewList else Icons.Default.ViewModule,
                                contentDescription = if (homeViewMode == "grouped") "总览模式" else "分组模式",
                                tint = Color.White
                            )
                        }
                        IconButton(onClick = { viewModel.loadHomeData() }) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = stringResource(R.string.refresh),
                                tint = Color.White
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GroupedContent(
    uiState: HomeUiState,
    isCarouselEnabled: Boolean,
    onVideoClick: (Long, String) -> Unit,
    onLibraryClick: (Long?, String) -> Unit,
    modifier: Modifier = Modifier
) {
    val carouselItems by remember(uiState.libraryGroups, isCarouselEnabled) {
        derivedStateOf {
            if (isCarouselEnabled) {
                uiState.allVideos.shuffled().take(CAROUSEL_MAX_ITEMS).map { item ->
                    CarouselItem(
                        title = item.title,
                        subtitle = item.year?.toString(),
                        coverUrl = item.fanartUrl ?: item.coverUrl,
                        onClick = { onVideoClick(item.id, item.type ?: "series") }
                    )
                }
            } else {
                emptyList()
            }
        }
    }

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Dimens.spacingLg)
    ) {
        // 轮播图
        if (isCarouselEnabled && carouselItems.isNotEmpty()) {
            item {
                CarouselSection(items = carouselItems)
            }
        }

        uiState.libraryGroups.forEach { group ->
            // 合并系列和独立视频为一个列表
            val allItems = group.series + group.standaloneVideos
            if (allItems.isNotEmpty()) {
                if (isCarouselEnabled && carouselItems.isNotEmpty()) {
                    item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                }

                item {
                    SectionHeader(
                        title = group.libraryName,
                        onTitleClick = { onLibraryClick(group.libraryId, group.libraryName) }
                    )
                }

                item {
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = Dimens.pageHorizontalPadding),
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                    ) {
                        items(
                            items = allItems,
                            key = { it.id }
                        ) { series ->
                            MediaCard(
                                title = series.title,
                                subtitle = series.year?.toString(),
                                coverUrl = series.coverUrl,
                                rating = series.rating,
                                onClick = { onVideoClick(series.id, series.type ?: "series") }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun OverviewContent(
    uiState: HomeUiState,
    isCarouselEnabled: Boolean,
    onVideoClick: (Long, String) -> Unit,
    modifier: Modifier = Modifier
) {
    val carouselItems by remember(uiState.allVideos, isCarouselEnabled) {
        derivedStateOf {
            if (isCarouselEnabled) {
                uiState.allVideos.shuffled().take(CAROUSEL_MAX_ITEMS).map { item ->
                    CarouselItem(
                        title = item.title,
                        subtitle = item.year?.toString(),
                        coverUrl = item.fanartUrl ?: item.coverUrl,
                        onClick = { onVideoClick(item.id, item.type ?: "series") }
                    )
                }
            } else {
                emptyList()
            }
        }
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(5),
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
    ) {
        // 轮播图占满整行
        if (isCarouselEnabled && carouselItems.isNotEmpty()) {
            item(span = { GridItemSpan(5) }) {
                CarouselSection(items = carouselItems)
            }
        }

        // 网格视频
        items(
            items = uiState.allVideos,
            key = { it.id }
        ) { series ->
            Box(modifier = Modifier.padding(horizontal = Dimens.spacingXs)) {
                MediaCard(
                    title = series.title,
                    subtitle = series.year?.toString(),
                    coverUrl = series.coverUrl,
                    rating = series.rating,
                    onClick = { onVideoClick(series.id, series.type ?: "series") }
                )
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
private fun CarouselSection(
    items: List<CarouselItem>,
    modifier: Modifier = Modifier
) {
    val pagerState = rememberPagerState(pageCount = { items.size })
    val configuration = LocalConfiguration.current
    val isTablet = configuration.screenWidthDp >= 600
    val carouselHeight = if (isTablet) Dimens.carouselHeightTablet else Dimens.carouselHeight

    LaunchedEffect(pagerState) {
        while (true) {
            delay(CAROUSEL_AUTO_SCROLL_DELAY)
            val nextPage = (pagerState.currentPage + 1) % items.size
            pagerState.animateScrollToPage(nextPage)
        }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        Box(modifier = Modifier.fillMaxWidth()) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(carouselHeight),
                pageSpacing = 0.dp
            ) { page ->
                val item = items[page]
                WideMediaCard(
                    title = item.title,
                    subtitle = item.subtitle,
                    coverUrl = item.coverUrl,
                    onClick = item.onClick,
                    modifier = Modifier
                        .fillMaxHeight(),
                    fixedSize = false,
                    clipShape = RectangleShape,
                    bottomContentPadding = Dimens.carouselFadeHeight
                )
            }

            // 底部渐变遮罩：轮播图柔和渐隐进背景
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(Dimens.carouselFadeHeight)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                MaterialTheme.colorScheme.background
                            )
                        )
                    )
            )
        }

        if (items.size > 1) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = Dimens.spacingXs),
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
