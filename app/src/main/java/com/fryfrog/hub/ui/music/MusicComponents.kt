package com.fryfrog.hub.ui.music

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Album
import androidx.compose.material.icons.filled.Audiotrack
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PlaylistAdd
import androidx.compose.material.icons.filled.QueueMusic
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MusicPlaylist
import com.fryfrog.hub.data.model.MusicPlaylistUpdateRequest
import com.fryfrog.hub.data.model.MusicSongDTO
import com.fryfrog.hub.data.repository.MusicRepository
import com.fryfrog.hub.ui.components.FryfrogTextField
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Gold
import kotlinx.coroutines.launch

// ===== 工具 =====

fun formatDuration(totalSeconds: Double?): String {
    if (totalSeconds == null || totalSeconds <= 0) return "--:--"
    val total = totalSeconds.toLong()
    val minutes = total / 60
    val seconds = total % 60
    return "%d:%02d".format(minutes, seconds)
}

fun formatDurationMs(ms: Long): String {
    if (ms <= 0) return "0:00"
    val total = ms / 1000
    return "%d:%02d".format(total / 60, total % 60)
}

// ===== 封面 =====

@Composable
fun MusicCover(
    url: String?,
    modifier: Modifier = Modifier,
    shape: RoundedCornerShape = RoundedCornerShape(Dimens.radiusMd),
    fallbackIcon: ImageVector = Icons.Default.Audiotrack
) {
    Box(
        modifier = modifier.clip(shape).background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center
    ) {
        if (url != null) {
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.matchParentSize()
            )
        } else {
            Icon(
                imageVector = fallbackIcon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = Dimens.alphaDisabled),
                modifier = Modifier.size(28.dp)
            )
        }
    }
}

// ===== 专辑卡片（网格/LazyRow 用） =====

@Composable
fun MusicAlbumCard(
    title: String,
    subtitle: String?,
    coverUrl: String?,
    size: Dp,
    onClick: () -> Unit,
    starred: Boolean = false,
    fallbackIcon: ImageVector = Icons.Default.Album
) {
    Column(
        modifier = Modifier
            .width(size)
            .clickable(onClick = onClick)
    ) {
        Box {
            MusicCover(
                url = coverUrl,
                modifier = Modifier.size(size),
                shape = RoundedCornerShape(Dimens.radiusLg),
                fallbackIcon = fallbackIcon
            )
            if (starred) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = stringResource(R.string.music_starred),
                    tint = Gold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(Dimens.spacingXs)
                        .size(Dimens.smallIconSize)
                )
            }
        }
        Spacer(Modifier.height(Dimens.spacingXs))
        Text(
            text = title,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        if (!subtitle.isNullOrBlank()) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

// ===== 歌手卡片 =====

@Composable
fun MusicArtistCard(
    name: String,
    coverUrl: String?,
    avatarSize: Dp,
    onClick: () -> Unit,
    starred: Boolean = false
) {
    Column(
        modifier = Modifier
            .width(avatarSize + Dimens.spacingLg * 2)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box {
            MusicCover(
                url = coverUrl,
                modifier = Modifier.size(avatarSize),
                shape = CircleShape,
                fallbackIcon = Icons.Default.Person
            )
            if (starred) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = stringResource(R.string.music_starred),
                    tint = Gold,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .size(Dimens.smallIconSize)
                )
            }
        }
        Spacer(Modifier.height(Dimens.spacingXs))
        Text(
            text = name,
            style = MaterialTheme.typography.labelMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

// ===== 歌曲行 =====

@Composable
fun SongRow(
    song: MusicSongDTO,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    index: Int? = null,
    isCurrent: Boolean = false,
    showAlbum: Boolean = false,
    onToggleStar: () -> Unit = {},
    trailingContent: @Composable (RowScope.() -> Unit)? = null
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(Dimens.radiusMd))
            .clickable(onClick = onClick)
            .padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingSm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // 序号或封面缩略图
        if (index != null) {
            Text(
                text = index.toString(),
                style = MaterialTheme.typography.labelLarge,
                color = if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.width(Dimens.cardWideWidth / 4)
            )
        } else {
            MusicCover(
                url = song.coverUrl,
                modifier = Modifier.size(Dimens.avatarSize),
                fallbackIcon = Icons.Default.Audiotrack
            )
            Spacer(Modifier.width(Dimens.spacingMd))
        }

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = song.displayTitle,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            val sub = listOfNotNull(
                song.displayArtist.takeIf { it.isNotBlank() },
                song.albumName?.takeIf { it.isNotBlank() && showAlbum }
            ).joinToString(" · ")
            if (sub.isNotBlank()) {
                Text(
                    text = sub,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        IconButton(onClick = onToggleStar, modifier = Modifier.size(Dimens.buttonHeight)) {
            Icon(
                imageVector = if (song.starred == true) Icons.Default.Star else Icons.Default.StarBorder,
                contentDescription = stringResource(
                    if (song.starred == true) R.string.music_starred else R.string.music_add_star
                ),
                tint = if (song.starred == true) Gold else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(Dimens.iconSize)
            )
        }

        Text(
            text = formatDuration(song.durationSeconds),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(Dimens.logoPortraitMaxWidth / 2)
        )

        trailingContent?.invoke(this)
    }
}

// ===== 收藏按钮 =====

@Composable
fun StarButton(starred: Boolean, onToggle: () -> Unit, size: Dp = Dimens.dialogIconSize) {
    IconButton(onClick = onToggle) {
        Icon(
            imageVector = if (starred) Icons.Default.Star else Icons.Default.StarBorder,
            contentDescription = stringResource(if (starred) R.string.music_starred else R.string.music_add_star),
            tint = if (starred) Gold else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(size)
        )
    }
}

// ===== 评分条（1-5，点击当前值清除） =====

@Composable
fun RatingStars(rating: Int?, enabled: Boolean = true, onRate: (Int) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        (1..5).forEach { star ->
            IconButton(
                onClick = { onRate(if (star == rating) 0 else star) },
                enabled = enabled,
                modifier = Modifier.size(Dimens.switchHeight + Dimens.spacingSm)
            ) {
                Icon(
                    imageVector = if (star <= (rating ?: 0)) Icons.Default.Star else Icons.Default.StarBorder,
                    contentDescription = star.toString(),
                    tint = if (star <= (rating ?: 0)) Gold else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = Dimens.alphaDisabled),
                    modifier = Modifier.size(Dimens.chipIconSize + Dimens.spacingXxs)
                )
            }
        }
    }
}

// ===== 迷你播放条 =====

@Composable
fun MiniPlayerBar(
    song: MusicSongDTO?,
    isPlaying: Boolean,
    progress: Float,
    onClick: () -> Unit,
    onPlayPause: () -> Unit,
    onNext: () -> Unit
) {
    if (song == null) return
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = Dimens.spacingLg)
            .clip(RoundedCornerShape(Dimens.radiusXl)),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.97f),
        tonalElevation = 4.dp,
        shadowElevation = 8.dp
    ) {
        Column {
            LinearProgressIndicator(
                progress = { progress.coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth().height(Dimens.spacingXxs),
                drawStopIndicator = {}
            )
            Row(
                modifier = Modifier
                    .clickable(onClick = onClick)
                    .padding(horizontal = Dimens.spacingMd, vertical = Dimens.spacingSm),
                verticalAlignment = Alignment.CenterVertically
            ) {
                MusicCover(
                    url = song.coverUrl,
                    modifier = Modifier.size(Dimens.dialogAvatarSize),
                    fallbackIcon = Icons.Default.Audiotrack
                )
                Spacer(Modifier.width(Dimens.spacingMd))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = song.displayTitle,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = song.displayArtist.ifBlank { song.albumName ?: "" },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                IconButton(onClick = onPlayPause) {
                    Icon(
                        imageVector = if (isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = stringResource(if (isPlaying) R.string.pause else R.string.play),
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(Dimens.dialogIconSize)
                    )
                }
                IconButton(onClick = onNext) {
                    Icon(
                        imageVector = Icons.Default.SkipNext,
                        contentDescription = stringResource(R.string.next),
                        tint = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.size(Dimens.dialogIconSize)
                    )
                }
            }
        }
    }
}

// ===== 添加到播放列表对话框 =====

@Composable
fun AddToPlaylistDialog(
    playlists: List<MusicPlaylist>,
    isLoading: Boolean,
    onSelect: (Long) -> Unit,
    onCreate: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var creating by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(Icons.Default.QueueMusic, contentDescription = null) },
        title = { Text(stringResource(R.string.music_add_to_playlist)) },
        text = {
            Column {
                if (creating) {
                    FryfrogTextField(
                        value = newName,
                        onValueChange = { newName = it },
                        label = { Text(stringResource(R.string.music_playlist_name)) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                } else {
                    if (isLoading) {
                        Box(Modifier.fillMaxWidth().height(Dimens.listMaxHeight / 2), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    } else if (playlists.isEmpty()) {
                        Text(
                            stringResource(R.string.music_no_playlists),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(vertical = Dimens.spacingLg)
                        )
                    } else {
                        Column(
                            modifier = Modifier.height(Dimens.listMaxHeight),
                            verticalArrangement = Arrangement.spacedBy(Dimens.spacingXxs)
                        ) {
                            playlists.forEach { playlist ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(Dimens.radiusMd))
                                        .clickable { onSelect(playlist.id) }
                                        .padding(vertical = Dimens.spacingXs, horizontal = Dimens.spacingXs),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    RadioButton(selected = false, onClick = { onSelect(playlist.id) })
                                    Spacer(Modifier.width(Dimens.spacingXs))
                                    Column {
                                        Text(playlist.displayName, style = MaterialTheme.typography.bodyMedium)
                                        Text(
                                            playlist.comment.orEmpty(),
                                            style = MaterialTheme.typography.labelSmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (creating) {
                TextButton(
                    onClick = { if (newName.isNotBlank()) onCreate(newName.trim()) },
                    enabled = newName.isNotBlank()
                ) { Text(stringResource(R.string.create)) }
            } else {
                TextButton(onClick = { creating = true }) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(Dimens.smallIconSize))
                    Spacer(Modifier.width(Dimens.spacingXxs))
                    Text(stringResource(R.string.music_new_playlist))
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) }
        }
    )
}

// ===== 加入播放列表对话框宿主：自加载播放列表，可直接在任意歌曲场景使用 =====

@Composable
fun AddToPlaylistDialogHost(
    songIds: List<Long>,
    onDismiss: () -> Unit,
    onSuccess: (String) -> Unit = {}
) {
    val repository = remember { MusicRepository() }
    val scope = rememberCoroutineScope()
    var playlists by remember { mutableStateOf<List<MusicPlaylist>?>(null) }

    LaunchedEffect(Unit) {
        playlists = repository.getPlaylists().getOrDefault(emptyList())
    }

    AddToPlaylistDialog(
        playlists = playlists ?: emptyList(),
        isLoading = playlists == null,
        onSelect = { id ->
            scope.launch {
                repository.updatePlaylist(id, MusicPlaylistUpdateRequest(songIdsToAdd = songIds))
                    .onSuccess { onSuccess(it.displayName) }
                onDismiss()
            }
        },
        onCreate = { name ->
            scope.launch {
                val created = repository.createPlaylist(name, null, null, songIds).getOrNull()
                if (created != null) {
                    onSuccess(created.displayName)
                    onDismiss()
                }
            }
        },
        onDismiss = onDismiss
    )
}

// ===== 歌曲行"加入播放列表"按钮 =====

@Composable
fun PlaylistAddButton(onClick: () -> Unit) {
    IconButton(onClick = onClick) {
        Icon(
            imageVector = Icons.Default.PlaylistAdd,
            contentDescription = stringResource(R.string.music_add_to_playlist),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(Dimens.iconSize)
        )
    }
}
