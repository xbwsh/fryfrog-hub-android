@file:OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)

package com.fryfrog.hub.ui.ebooks

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.EbookDTO
import com.fryfrog.hub.data.model.EbookSeries
import com.fryfrog.hub.data.model.MediaCharacter
import com.fryfrog.hub.ui.components.*
import com.fryfrog.hub.ui.theme.*

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EbookDetailScreen(
    series: EbookSeries?,
    characters: List<MediaCharacter>,
    onBackClick: () -> Unit,
    onEbookClick: (Long) -> Unit
) {
    if (series == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    val configuration = LocalConfiguration.current
    val isLandscape = configuration.screenWidthDp > configuration.screenHeightDp

    if (isLandscape) {
        // 横屏布局：左侧封面，右侧信息+角色+书目
        Row(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // 左侧：封面
            Box(
                modifier = Modifier
                    .weight(1f)
                    .padding(Dimens.spacingLg)
                    .clip(RoundedCornerShape(Dimens.radiusLg))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (series.coverUrl != null) {
                    AsyncImage(
                        model = series.coverUrl,
                        contentDescription = series.name,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                        alignment = Alignment.TopCenter
                    )
                }
            }

            // 右侧：标题、作者、简介 → 角色 → 书目
            Column(
                modifier = Modifier
                    .weight(1.5f)
                    .verticalScroll(rememberScrollState())
            ) {
                // 标题、作者、简介
                Column(modifier = Modifier.padding(Dimens.spacingLg)) {
                    Text(
                        text = series.name ?: "",
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold
                    )
                    series.author?.let {
                        Spacer(modifier = Modifier.height(Dimens.spacingXs))
                        Text(
                            text = it,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    series.seriesSummary?.let { summary ->
                        Spacer(modifier = Modifier.height(Dimens.spacingSm))
                        Text(
                            text = summary,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                // 角色信息
                if (characters.isNotEmpty()) {
                    SectionTitle(
                        title = stringResource(R.string.characters),
                        modifier = Modifier.padding(horizontal = Dimens.spacingLg)
                    )
                    CharactersRow(characters = characters)
                    Spacer(modifier = Modifier.height(Dimens.spacingLg))
                }

                // 书目网格
                if (!series.books.isNullOrEmpty()) {
                    val title = buildString {
                        append(stringResource(R.string.ebook_volumes))
                        series.volumeCount?.let { append(" ($it)") }
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingMd),
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
                            text = title,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    EbookVolumeLandscapeGrid(
                        books = series.books,
                        onEbookClick = onEbookClick
                    )
                }
            }
        }
    } else {
        // 竖屏布局：使用 LazyVerticalGrid 实现固定4列
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding(),
            contentPadding = PaddingValues(Dimens.spacingLg),
            horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
            verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
        ) {
            // 系列封面卡片 - 占满整行
            item(span = { GridItemSpan(3) }) {
                ModernSeriesCard(
                    coverUrl = series.coverUrl,
                    title = series.name ?: "",
                    subtitle = series.author,
                    summary = series.seriesSummary
                )
            }

            // 角色信息 - 占满整行
            if (characters.isNotEmpty()) {
                item(span = { GridItemSpan(3) }) {
                    SectionTitle(title = stringResource(R.string.characters))
                }
                item(span = { GridItemSpan(3) }) {
                    CharactersRow(characters = characters)
                }
            }

            // 书目标题 - 占满整行
            if (!series.books.isNullOrEmpty()) {
                item(span = { GridItemSpan(3) }) {
                    val title = buildString {
                        append(stringResource(R.string.ebook_volumes))
                        series.volumeCount?.let { append(" ($it)") }
                    }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth(),
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
                            text = title,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                // 书目封面 - 每个占1列
                items(series.books, key = { it.id }) { book ->
                    EbookVolumeGridItem(
                        book = book,
                        onClick = { onEbookClick(book.id) }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EbookVolumeFlowGrid(
    books: List<EbookDTO>,
    onEbookClick: (Long) -> Unit
) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
    ) {
        books.forEach { book ->
            EbookVolumeGridItem(
                book = book,
                onClick = { onEbookClick(book.id) }
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun EbookVolumeLandscapeGrid(
    books: List<EbookDTO>,
    onEbookClick: (Long) -> Unit
) {
    FlowRow(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm),
        verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
    ) {
        books.forEach { book ->
            Box(modifier = Modifier.width(100.dp)) {
                EbookVolumeGridItem(
                    book = book,
                    onClick = { onEbookClick(book.id) }
                )
            }
        }
    }
}

@Composable
private fun EbookVolumeGridItem(
    book: EbookDTO,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier.clickable(onClick = onClick)
    ) {
        // 封面
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f)
                .clip(RoundedCornerShape(Dimens.radiusMd))
                .shadow(
                    elevation = 4.dp,
                    shape = RoundedCornerShape(Dimens.radiusMd),
                    ambientColor = Primary.copy(alpha = 0.1f)
                )
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (book.coverUrl != null) {
                AsyncImage(
                    model = book.coverUrl,
                    contentDescription = book.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter
                )
            }

            // 卷号标签 - 右上角
            book.volume?.let { volume ->
                Surface(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(Dimens.spacingXs),
                    color = Primary,
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = "Vol.$volume",
                        modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = androidx.compose.ui.graphics.Color.White
                    )
                }
            }
        }

        // 标题
        Spacer(modifier = Modifier.height(Dimens.spacingXs))
        Text(
            text = book.title,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}
