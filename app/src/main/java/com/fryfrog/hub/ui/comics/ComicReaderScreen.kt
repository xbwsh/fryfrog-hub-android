@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.comics

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ViewList
import androidx.compose.material.icons.filled.ViewModule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.fryfrog.hub.ui.theme.*
import com.fryfrog.hub.util.PrefsManager

enum class ReadingMode(val label: String) {
    HORIZONTAL_LTR("左→右"),
    HORIZONTAL_RTL("右→左"),
    VERTICAL("上下滚动");

    companion object {
        fun fromString(value: String): ReadingMode {
            return when (value) {
                "HORIZONTAL_RTL" -> HORIZONTAL_RTL
                "VERTICAL" -> VERTICAL
                else -> HORIZONTAL_LTR
            }
        }
    }
}

@Composable
fun ComicReaderScreen(
    comicId: Long,
    comicTitle: String,
    startPage: Int = 0,
    viewModel: ComicReaderViewModel = viewModel(factory = ComicReaderViewModelFactory(comicId)),
    onBackClick: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val prefs = remember { PrefsManager(context) }
    var readingMode by remember { mutableStateOf(ReadingMode.fromString(prefs.comicReadingMode)) }
    var showControls by remember { mutableStateOf(true) }

    // 继续阅读：设置初始页码
    LaunchedEffect(startPage, uiState.pages.size) {
        if (startPage > 0 && startPage < uiState.pages.size) {
            viewModel.setCurrentPage(startPage)
        }
    }

    BackHandler { onBackClick() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Color.White)
            }
        } else if (uiState.error != null) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = uiState.error ?: "加载失败",
                    color = Color.White
                )
            }
        } else if (uiState.pages.isNotEmpty()) {
            // 点击隐藏/显示控件的透明层
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() }
                    ) {
                        showControls = !showControls
                    }
            ) {
                when (readingMode) {
                    ReadingMode.HORIZONTAL_LTR -> {
                        HorizontalReadingMode(
                            pages = uiState.pages,
                            viewModel = viewModel,
                            context = context,
                            reverseDirection = false
                        )
                    }
                    ReadingMode.HORIZONTAL_RTL -> {
                        HorizontalReadingMode(
                            pages = uiState.pages,
                            viewModel = viewModel,
                            context = context,
                            reverseDirection = true
                        )
                    }
                    ReadingMode.VERTICAL -> {
                        VerticalReadingMode(
                            pages = uiState.pages,
                            viewModel = viewModel,
                            context = context
                        )
                    }
                }
            }

            // 控制层
            if (showControls) {
                // 顶部控制栏
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.TopCenter)
                        .background(Color.Black.copy(alpha = 0.7f))
                        .statusBarsPadding()
                        .padding(Dimens.spacingMd)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = comicTitle,
                            color = Color.White,
                            style = MaterialTheme.typography.bodyMedium
                        )

                        Row(
                            horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                        ) {
                            // 切换翻页方向
                            FilterChip(
                                selected = readingMode == ReadingMode.HORIZONTAL_LTR,
                                onClick = {
                                    readingMode = ReadingMode.HORIZONTAL_LTR
                                    prefs.comicReadingMode = "HORIZONTAL_LTR"
                                },
                                label = { Text("左→右", style = MaterialTheme.typography.labelSmall) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = Primary.copy(alpha = 0.3f)
                                )
                            )
                            FilterChip(
                                selected = readingMode == ReadingMode.HORIZONTAL_RTL,
                                onClick = {
                                    readingMode = ReadingMode.HORIZONTAL_RTL
                                    prefs.comicReadingMode = "HORIZONTAL_RTL"
                                },
                                label = { Text("右→左", style = MaterialTheme.typography.labelSmall) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = Primary.copy(alpha = 0.3f)
                                )
                            )
                            FilterChip(
                                selected = readingMode == ReadingMode.VERTICAL,
                                onClick = {
                                    readingMode = ReadingMode.VERTICAL
                                    prefs.comicReadingMode = "VERTICAL"
                                },
                                label = { Text("滚动", style = MaterialTheme.typography.labelSmall) },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = Primary.copy(alpha = 0.3f)
                                )
                            )
                        }
                    }
                }

                // 底部页码
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .align(Alignment.BottomCenter)
                        .background(Color.Black.copy(alpha = 0.7f))
                        .navigationBarsPadding()
                        .padding(Dimens.spacingMd)
                ) {
                    Text(
                        text = "${viewModel.uiState.value.currentPage + 1} / ${uiState.pages.size}",
                        color = Color.White,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
            }
        }
    }
}

@Composable
private fun HorizontalReadingMode(
    pages: List<com.fryfrog.hub.data.model.ComicPageInfo>,
    viewModel: ComicReaderViewModel,
    context: android.content.Context,
    reverseDirection: Boolean
) {
    val pageCount = pages.size
    val pagerState = rememberPagerState(
        initialPage = viewModel.uiState.value.currentPage.coerceIn(0, pageCount - 1)
    ) { pageCount }

    LaunchedEffect(pagerState.currentPage) {
        viewModel.setCurrentPage(pagerState.currentPage)
    }

    HorizontalPager(
        state = pagerState,
        modifier = Modifier.fillMaxSize(),
        reverseLayout = reverseDirection
    ) { page ->
        val pageInfo = pages[page]
        val pageUrl = viewModel.getPageUrl(pageInfo.pageNum)

        AsyncImage(
            model = ImageRequest.Builder(context)
                .data(pageUrl)
                .crossfade(true)
                .build(),
            contentDescription = "Page ${page + 1}",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Fit,
            alignment = Alignment.Center
        )
    }
}

@Composable
private fun VerticalReadingMode(
    pages: List<com.fryfrog.hub.data.model.ComicPageInfo>,
    viewModel: ComicReaderViewModel,
    context: android.content.Context
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize()
    ) {
        items(pages) { pageInfo ->
            val pageUrl = viewModel.getPageUrl(pageInfo.pageNum)

            AsyncImage(
                model = ImageRequest.Builder(context)
                    .data(pageUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "Page ${pageInfo.pageNum}",
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(0.7f),
                contentScale = ContentScale.FillWidth,
                alignment = Alignment.Center
            )
        }
    }
}
