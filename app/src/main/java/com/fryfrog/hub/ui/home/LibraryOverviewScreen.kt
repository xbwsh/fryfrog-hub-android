package com.fryfrog.hub.ui.home

import android.content.Context
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.ui.components.MediaCard
import com.fryfrog.hub.ui.components.WideMediaCard
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.util.PrefsManager

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryOverviewScreen(
    libraryId: Long?,
    libraryName: String,
    libraryItems: List<SeriesDTO>,
    onBackClick: () -> Unit,
    onVideoClick: (Long, String) -> Unit,
    onRefresh: () -> Unit = {}
) {
    val context = LocalContext.current
    val prefs = remember { PrefsManager(context) }
    val effectiveLibraryId = libraryId ?: 0L
    var isPortrait by remember(effectiveLibraryId) {
        mutableStateOf(prefs.getLibraryViewMode(effectiveLibraryId) == "portrait")
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(libraryName) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = {
                        isPortrait = !isPortrait
                        prefs.setLibraryViewMode(effectiveLibraryId, if (isPortrait) "portrait" else "landscape")
                    }) {
                        Icon(
                            imageVector = if (isPortrait) Icons.Default.GridView else Icons.AutoMirrored.Filled.ViewList,
                            contentDescription = if (isPortrait) stringResource(R.string.landscape_cover) else stringResource(R.string.portrait_cover),
                            tint = MaterialTheme.colorScheme.onBackground
                        )
                    }
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = stringResource(R.string.refresh),
                            tint = MaterialTheme.colorScheme.onBackground
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (libraryItems.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(Dimens.spacingLg),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        stringResource(R.string.no_videos),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                if (isPortrait) {
                    PortraitGrid(
                        items = libraryItems,
                        onVideoClick = onVideoClick
                    )
                } else {
                    LandscapeList(
                        items = libraryItems,
                        onVideoClick = onVideoClick
                    )
                }
            }
        }
    }
}

@Composable
private fun PortraitGrid(
    items: List<com.fryfrog.hub.data.model.SeriesDTO>,
    onVideoClick: (Long, String) -> Unit
) {
    val configuration = LocalConfiguration.current
    // 平板横屏（宽屏）7 列，平板竖屏 5 列，手机 5 列
    val columns = when {
        configuration.screenWidthDp >= 900 -> 7
        configuration.screenWidthDp >= 600 -> 5
        else -> 5
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = Dimens.spacingSm,
            end = Dimens.spacingSm,
            bottom = Dimens.spacingLg
        ),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
    ) {
        items(items, key = { it.id }) { series ->
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                MediaCard(
                    title = series.title,
                    subtitle = series.year?.toString(),
                    coverUrl = series.coverUrl,
                    rating = series.rating,
                    resolutions = series.resolutions,
                    onClick = { onVideoClick(series.id, series.type ?: "series") }
                )
            }
        }
    }
}

@Composable
private fun LandscapeList(
    items: List<com.fryfrog.hub.data.model.SeriesDTO>,
    onVideoClick: (Long, String) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            start = Dimens.spacingSm,
            end = Dimens.spacingSm,
            bottom = Dimens.spacingLg
        ),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
    ) {
        items(items, key = { it.id }) { series ->
            WideMediaCard(
                title = series.title,
                subtitle = series.year?.toString(),
                coverUrl = series.fanartUrl ?: series.coverUrl,
                resolutions = series.resolutions,
                onClick = { onVideoClick(series.id, series.type ?: "series") },
                fixedSize = false,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(16f / 9f)
            )
        }
    }
}
