package com.fryfrog.hub.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.ui.unit.IntOffset
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.fryfrog.hub.data.model.MediaCharacter
import com.fryfrog.hub.ui.theme.*

/**
 * 现代系列封面卡片 - 左侧封面 + 右侧简介
 */
@Composable
fun ModernSeriesCard(
    coverUrl: String?,
    title: String,
    subtitle: String? = null,
    summary: String? = null,
    infoChips: @Composable RowScope.() -> Unit = {},
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .shadow(
                elevation = 8.dp,
                shape = RoundedCornerShape(Dimens.radiusLg),
                ambientColor = Primary.copy(alpha = 0.1f)
            ),
        shape = RoundedCornerShape(Dimens.radiusLg),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            // 左侧封面
            Box(
                modifier = Modifier
                    .width(140.dp)
                    .aspectRatio(0.7f)
                    .clip(RoundedCornerShape(topStart = Dimens.radiusLg, bottomStart = Dimens.radiusLg))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (coverUrl != null) {
                    AsyncImage(
                        model = coverUrl,
                        contentDescription = title,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                        alignment = Alignment.TopCenter
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Book,
                        contentDescription = null,
                        modifier = Modifier
                            .size(48.dp)
                            .align(Alignment.Center),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                    )
                }
            }

            // 右侧信息
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(Dimens.spacingMd)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                subtitle?.let {
                    Spacer(modifier = Modifier.height(Dimens.spacingXs))
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // 信息标签
                Row(
                    modifier = Modifier.padding(top = Dimens.spacingSm),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    infoChips()
                }

                summary?.let {
                    Spacer(modifier = Modifier.height(Dimens.spacingSm))
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 4,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }
    }
}

/**
 * 信息标签 - 品牌色圆角标签
 */
@Composable
fun InfoChip(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        color = Primary.copy(alpha = 0.1f),
        shape = RoundedCornerShape(Dimens.radiusSm)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs)
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = Primary
            )
            Text(
                text = value,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

/**
 * 区域标题 - 带品牌色图标
 */
@Composable
fun SectionTitle(
    title: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.padding(vertical = Dimens.spacingMd),
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

/**
 * 角色行 - 水平滚动的角色列表
 */
@Composable
fun CharactersRow(
    characters: List<MediaCharacter>,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        contentPadding = PaddingValues(start = 0.dp, end = Dimens.spacingLg),
        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
    ) {
        items(characters) { character ->
            CharacterAvatar(character = character)
        }
    }
}

/**
 * 角色头像卡片 - 圆形，显示上半部分
 * 对应 Web 的 object-fit: cover + object-position: top
 */
@Composable
fun CharacterAvatar(
    character: MediaCharacter,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.width(80.dp)
    ) {
        Box(
            modifier = Modifier
                .size(68.dp)
                .clip(CircleShape)
                .border(2.dp, Primary, CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.TopCenter
        ) {
            if (character.imageUrl != null) {
                AsyncImage(
                    model = character.imageUrl,
                    contentDescription = character.name,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    alignment = Alignment.TopCenter
                )
            } else {
                Icon(
                    imageVector = Icons.Default.Person,
                    contentDescription = null,
                    modifier = Modifier.size(32.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Spacer(modifier = Modifier.height(Dimens.spacingSm))
        Text(
            text = character.name,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        character.originalName?.let { origName ->
            if (origName != character.name) {
                Text(
                    text = origName,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * 卷/册列表卡片 - 现代设计
 */
@Composable
fun VolumeCard(
    coverUrl: String?,
    title: String,
    volumeLabel: String? = null,
    pageCount: Int? = null,
    format: String? = null,
    rating: Double? = null,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg, vertical = Dimens.spacingSm)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 2.dp
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 封面缩略图
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (coverUrl != null) {
                    AsyncImage(
                        model = coverUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                }
            }

            // 信息
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = Dimens.spacingMd)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    volumeLabel?.let {
                        Text(
                            text = it,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    pageCount?.let {
                        Text(
                            text = "${it}页",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    format?.let {
                        Text(
                            text = it,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // 评分
            rating?.let {
                Surface(
                    color = Primary.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(Dimens.radiusSm)
                ) {
                    Text(
                        text = String.format("%.1f", it),
                        modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXs),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold,
                        color = Primary
                    )
                }
            }
        }
    }
}
