@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.comics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.ComicDTO
import com.fryfrog.hub.data.model.ComicSeries
import com.fryfrog.hub.data.model.MediaCharacter
import com.fryfrog.hub.ui.theme.Dimens

@Composable
fun ComicDetailScreen(
    series: ComicSeries?,
    characters: List<MediaCharacter>,
    onBackClick: () -> Unit,
    onComicClick: (Long) -> Unit
) {
    if (series == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 48.dp)
        ) {
            // 系列封面卡片（左侧封面 + 右侧简介）
            item { SeriesInfoCard(series = series) }

            // 角色信息（在卷数上面）
            if (characters.isNotEmpty()) {
                item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                item { SectionHeader(title = stringResource(R.string.characters)) }
                item { CharactersRow(characters = characters) }
            }

            // 漫画列表
            if (!series.comics.isNullOrEmpty()) {
                item { Spacer(modifier = Modifier.height(Dimens.spacingXl)) }
                item { SectionHeader(title = stringResource(R.string.comic_volumes)) }
                items(series.comics) { comic ->
                    ComicVolumeCard(comic = comic, onClick = { onComicClick(comic.id) })
                }
            }

            item { Spacer(modifier = Modifier.height(Dimens.spacingXxl)) }
        }
    }
}

@Composable
private fun SeriesInfoCard(series: ComicSeries) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(Dimens.spacingLg),
        shape = RoundedCornerShape(Dimens.radiusMd)
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            Box(
                modifier = Modifier
                    .width(140.dp)
                    .aspectRatio(0.7f)
                    .clip(RoundedCornerShape(topStart = Dimens.radiusMd, bottomStart = Dimens.radiusMd))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (series.coverUrl != null) {
                    AsyncImage(model = series.coverUrl, contentDescription = series.name, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                }
            }
            Column(modifier = Modifier.weight(1f).padding(Dimens.spacingMd)) {
                Text(text = series.name ?: "", style = MaterialTheme.typography.titleLarge, maxLines = 2, overflow = TextOverflow.Ellipsis)
                series.author?.let {
                    Spacer(modifier = Modifier.height(Dimens.spacingXs))
                    Text(text = it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Row(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)) {
                    series.volumeCount?.let { InfoChip(label = stringResource(R.string.volumes), value = "${it}卷") }
                    series.serializationStart?.let { InfoChip(label = stringResource(R.string.start_date), value = it) }
                }
                series.seriesSummary?.let { summary ->
                    Spacer(modifier = Modifier.height(Dimens.spacingSm))
                    Text(text = summary, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 4, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun InfoChip(label: String, value: String) {
    Surface(color = MaterialTheme.colorScheme.surfaceVariant, shape = RoundedCornerShape(Dimens.radiusSm)) {
        Column(modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs)) {
            Text(text = label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(text = value, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(text = title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingMd))
}

@Composable
private fun CharactersRow(characters: List<MediaCharacter>) {
    LazyRow(contentPadding = PaddingValues(horizontal = Dimens.spacingLg), horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)) {
        items(characters) { character -> CharacterCard(character = character) }
    }
}

@Composable
private fun CharacterCard(character: MediaCharacter) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.width(80.dp)) {
        Box(modifier = Modifier.size(64.dp).clip(RoundedCornerShape(Dimens.radiusMd)).background(MaterialTheme.colorScheme.surfaceVariant)) {
            if (character.imageUrl != null) {
                AsyncImage(model = character.imageUrl, contentDescription = character.name, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            }
        }
        Spacer(modifier = Modifier.height(Dimens.spacingXs))
        Text(text = character.name, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
        character.originalName?.let { origName ->
            if (origName != character.name) {
                Text(text = origName, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun ComicVolumeCard(comic: ComicDTO, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm).clickable(onClick = onClick), shape = RoundedCornerShape(Dimens.radiusMd)) {
        Row(modifier = Modifier.fillMaxWidth().padding(Dimens.spacingMd), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(60.dp).clip(RoundedCornerShape(Dimens.radiusSm)).background(MaterialTheme.colorScheme.surfaceVariant)) {
                if (comic.coverUrl != null) {
                    AsyncImage(model = comic.coverUrl, contentDescription = null, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                }
            }
            Spacer(modifier = Modifier.width(Dimens.spacingMd))
            Column(modifier = Modifier.weight(1f)) {
                Text(text = comic.title, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Row(horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)) {
                    comic.volume?.let { Text(text = "第${it}卷", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    comic.pageCount?.let { Text(text = "${it}页", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    comic.format?.let { Text(text = it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
            comic.rating?.let { Text(text = String.format("%.1f", it), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary) }
        }
    }
}
