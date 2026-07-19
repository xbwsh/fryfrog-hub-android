package com.fryfrog.hub.ui.videos

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.window.core.layout.WindowWidthSizeClass
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SeriesDTO
import com.fryfrog.hub.data.model.VideoActor
import com.fryfrog.hub.data.model.VideoDTO
import com.fryfrog.hub.ui.theme.Dimens

@Composable
fun VideoDetailScreen(
    viewModel: VideoDetailViewModel,
    onBackClick: () -> Unit,
    onPlayClick: (Long) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

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
                onBackClick = onBackClick,
                onPlayClick = { series.episodes?.firstOrNull()?.let { onPlayClick(it.id) } }
            )
        }
    }
}

@Composable
private fun VideoDetailContent(
    series: SeriesDTO,
    actors: List<VideoActor>,
    onBackClick: () -> Unit,
    onPlayClick: () -> Unit
) {
    val windowInsets = WindowInsets.statusBars
    val topPadding = with(LocalDensity.current) {
        WindowInsets.statusBars.getTop(LocalDensity.current).toDp()
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize()
        ) {
            // Hero Area with Back Button
            item {
                HeroSection(
                    series = series,
                    onPlayClick = onPlayClick
                )
            }

            // Video Info
            item {
                VideoInfoSection(series = series)
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
            if (!series.episodes.isNullOrEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(Dimens.spacingXl))
                    SectionHeader(title = stringResource(R.string.episodes))
                }
                items(series.episodes) { episode ->
                    EpisodeCard(
                        episode = episode,
                        onClick = { onPlayClick() }
                    )
                }
            }

            item {
                Spacer(modifier = Modifier.height(Dimens.spacingXxl))
            }
        }

        // Floating Back Button with status bar padding
        IconButton(
            onClick = onBackClick,
            modifier = Modifier
                .padding(start = Dimens.spacingMd, top = topPadding + Dimens.spacingSm)
                .align(Alignment.TopStart)
                .background(
                    color = Color.Black.copy(alpha = Dimens.alphaOverlay),
                    shape = CircleShape
                )
        ) {
            Icon(
                imageVector = Icons.Default.ArrowBack,
                contentDescription = stringResource(R.string.back),
                tint = Color.White
            )
        }
    }
}

@Composable
private fun HeroSection(
    series: SeriesDTO,
    onPlayClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(320.dp)
    ) {
        if (series.fanartUrl != null) {
            AsyncImage(
                model = series.fanartUrl,
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        } else if (series.coverUrl != null) {
            AsyncImage(
                model = series.coverUrl,
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

        // Title and play button
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(Dimens.spacingLg)
        ) {
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
                    Text(stringResource(R.string.play))
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
            }
        }
    }
}

@Composable
private fun VideoInfoSection(series: SeriesDTO) {
    Column(
        modifier = Modifier.padding(Dimens.spacingLg)
    ) {
        // Metadata row
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Dimens.spacingLg)
        ) {
            series.year?.let { year ->
                Text(
                    text = year.toString(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            series.episodeCount?.let { count ->
                Text(
                    text = "$count ${stringResource(R.string.episodes)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            series.episodes?.firstOrNull()?.durationMinutes?.let { duration ->
                Text(
                    text = "${duration} ${stringResource(R.string.minutes)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        // Genre
        series.episodes?.firstOrNull()?.genre?.let { genre ->
            Spacer(modifier = Modifier.height(Dimens.spacingSm))
            Text(
                text = genre,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Director
        series.episodes?.firstOrNull()?.director?.let { director ->
            Spacer(modifier = Modifier.height(Dimens.spacingXs))
            Text(
                text = "${stringResource(R.string.director)}: $director",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Overview
        series.overview?.let { overview ->
            Spacer(modifier = Modifier.height(Dimens.spacingLg))
            Text(
                text = overview,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
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
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (actor.imageUrl != null) {
                AsyncImage(
                    model = actor.imageUrl,
                    contentDescription = actor.name,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
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
