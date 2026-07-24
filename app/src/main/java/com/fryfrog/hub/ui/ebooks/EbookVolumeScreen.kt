@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.ebooks

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.*

@Composable
fun EbookVolumeScreen(
    viewModel: EbookVolumeViewModel = viewModel(),
    onBackClick: () -> Unit,
    onReadClick: (Long, String) -> Unit = { _, _ -> }
) {
    val uiState by viewModel.uiState.collectAsState()
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == android.content.res.Configuration.ORIENTATION_LANDSCAPE

    // 处理返回键
    BackHandler { onBackClick() }

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
            uiState.ebook?.let { ebook ->
                if (isLandscape) {
                    EbookVolumeLandscapeLayout(ebook = ebook, onReadClick = { onReadClick(ebook.id, ebook.title) })
                } else {
                    EbookVolumePortraitLayout(ebook = ebook, onReadClick = { onReadClick(ebook.id, ebook.title) })
                }
            }
        }
    }
}

@Composable
private fun EbookVolumePortraitLayout(
    ebook: com.fryfrog.hub.data.model.EbookDTO,
    onReadClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
    ) {
        // 封面 + 悬浮阅读按钮
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(0.7f)
                .padding(Dimens.spacingLg)
                .clip(RoundedCornerShape(Dimens.radiusLg))
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (ebook.coverUrl != null) {
                AsyncImage(
                    model = ebook.coverUrl,
                    contentDescription = ebook.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter
                )
            }

            // 悬浮阅读按钮
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(Dimens.spacingMd)
                    .size(48.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onReadClick),
                color = Primary,
                shape = CircleShape,
                shadowElevation = 4.dp
            ) {
                Icon(
                    imageVector = Icons.Default.MenuBook,
                    contentDescription = "阅读",
                    tint = androidx.compose.ui.graphics.Color.White,
                    modifier = Modifier
                        .padding(Dimens.spacingSm)
                        .fillMaxSize()
                )
            }
        }

        // 信息区域
        Column(
            modifier = Modifier.padding(Dimens.spacingLg)
        ) {
            Text(
                text = ebook.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )

            ebook.author?.let { author ->
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Text(
                    text = author,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(Dimens.spacingMd))
            Row(
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
            ) {
                ebook.volume?.let { vol ->
                    InfoChip(label = "Vol.$vol")
                }
                ebook.year?.let { year ->
                    InfoChip(label = year.toString())
                }
                ebook.pageCount?.let { pages ->
                    InfoChip(label = "${pages}页")
                }
                ebook.format?.let { format ->
                    InfoChip(label = format.uppercase())
                }
            }

            ebook.rating?.let { rating ->
                Spacer(modifier = Modifier.height(Dimens.spacingMd))
                Text(
                    text = String.format("%.1f", rating),
                    style = MaterialTheme.typography.titleLarge,
                    color = Primary,
                    fontWeight = FontWeight.Bold
                )
            }

            ebook.summary?.let { summary ->
                Spacer(modifier = Modifier.height(Dimens.spacingLg))
                Text(
                    text = stringResource(R.string.description),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Text(
                    text = summary,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(Dimens.spacingLg))
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                )
            ) {
                Column(modifier = Modifier.padding(Dimens.spacingMd)) {
                    ebook.fileName?.let { name ->
                        InfoRow(label = stringResource(R.string.file_name), value = name)
                    }
                    ebook.fileSize?.let { size ->
                        InfoRow(label = stringResource(R.string.file_size), value = formatFileSize(size))
                    }
                    ebook.genre?.let { genre ->
                        InfoRow(label = "类型", value = genre)
                    }
                }
            }

            Spacer(modifier = Modifier.height(Dimens.spacingXl))
        }
    }
}

@Composable
private fun EbookVolumeLandscapeLayout(
    ebook: com.fryfrog.hub.data.model.EbookDTO,
    onReadClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .padding(Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingLg)
    ) {
        Box(
            modifier = Modifier
                .width(200.dp)
                .aspectRatio(0.7f)
                .clip(RoundedCornerShape(Dimens.radiusLg))
                .background(MaterialTheme.colorScheme.surfaceVariant)
        ) {
            if (ebook.coverUrl != null) {
                AsyncImage(
                    model = ebook.coverUrl,
                    contentDescription = ebook.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter
                )
            }

            // 悬浮阅读按钮
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(Dimens.spacingSm)
                    .size(36.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onReadClick),
                color = Primary,
                shape = CircleShape,
                shadowElevation = 4.dp
            ) {
                Icon(
                    imageVector = Icons.Default.MenuBook,
                    contentDescription = "阅读",
                    tint = androidx.compose.ui.graphics.Color.White,
                    modifier = Modifier
                        .padding(Dimens.spacingXs)
                        .fillMaxSize()
                )
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = ebook.title,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )

            ebook.author?.let { author ->
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Text(
                    text = author,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(Dimens.spacingMd))
            Row(
                horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
            ) {
                ebook.volume?.let { vol ->
                    InfoChip(label = "Vol.$vol")
                }
                ebook.year?.let { year ->
                    InfoChip(label = year.toString())
                }
                ebook.pageCount?.let { pages ->
                    InfoChip(label = "${pages}页")
                }
            }

            ebook.summary?.let { summary ->
                Spacer(modifier = Modifier.height(Dimens.spacingLg))
                Text(
                    text = summary,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun InfoChip(label: String) {
    Surface(
        color = Primary.copy(alpha = 0.1f),
        shape = RoundedCornerShape(Dimens.radiusSm)
    ) {
        Text(
            text = label,
            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
            style = MaterialTheme.typography.labelSmall,
            color = Primary
        )
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = Dimens.spacingXs),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium
        )
    }
}

private fun formatFileSize(bytes: Long): String {
    return when {
        bytes < 1024 -> "${bytes}B"
        bytes < 1024 * 1024 -> "${bytes / 1024}KB"
        bytes < 1024 * 1024 * 1024 -> String.format("%.1fMB", bytes / (1024.0 * 1024.0))
        else -> String.format("%.1fGB", bytes / (1024.0 * 1024.0 * 1024.0))
    }
}
