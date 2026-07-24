@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.ebooks

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.FormatSize
import androidx.compose.material.icons.filled.List
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.*
import com.fryfrog.hub.util.PrefsManager

@Composable
fun EbookReaderScreen(
    ebookId: Long,
    ebookTitle: String,
    startChapter: Int = 0,
    viewModel: EbookReaderViewModel = viewModel(factory = EbookReaderViewModelFactory(ebookId)),
    onBackClick: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val prefs = remember { PrefsManager(context) }
    var showChapterList by remember { mutableStateOf(false) }
    var fontSize by remember { mutableFloatStateOf(prefs.ebookFontSize) }
    var showControls by remember { mutableStateOf(true) }
    val textColor = MaterialTheme.colorScheme.onSurface.toArgb()

    // 继续阅读：设置初始章节
    LaunchedEffect(startChapter, uiState.chapters.size) {
        if (startChapter > 0 && startChapter < uiState.chapters.size) {
            viewModel.loadChapter(startChapter)
        }
    }

    // 保存字体大小
    LaunchedEffect(fontSize) {
        prefs.ebookFontSize = fontSize
    }

    BackHandler { onBackClick() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 主内容区域
        Column(
            modifier = Modifier
                .fillMaxSize()
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() }
                ) {
                    showControls = !showControls
                }
        ) {
            // 控制栏
            AnimatedVisibility(visible = showControls) {
                TopAppBar(
                    title = {
                        val chapterTitle = if (uiState.chapters.isNotEmpty() && uiState.currentChapterIndex < uiState.chapters.size) {
                            uiState.chapters[uiState.currentChapterIndex].title
                        } else {
                            ebookTitle
                        }
                        Text(chapterTitle)
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface
                    ),
                    navigationIcon = {
                        IconButton(onClick = onBackClick) {
                            Icon(
                                Icons.Default.ArrowBack,
                                contentDescription = stringResource(R.string.back)
                            )
                        }
                    },
                    actions = {
                        IconButton(onClick = { fontSize = maxOf(12f, fontSize - 2f) }) {
                            Icon(
                                Icons.Default.FormatSize,
                                contentDescription = "缩小字体",
                                modifier = Modifier.size(18.dp)
                            )
                        }
                        Text(
                            text = "${fontSize.toInt()}",
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(horizontal = 4.dp)
                        )
                        IconButton(onClick = { fontSize = minOf(28f, fontSize + 2f) }) {
                            Icon(
                                Icons.Default.FormatSize,
                                contentDescription = "放大字体",
                                modifier = Modifier.size(24.dp)
                            )
                        }

                        IconButton(onClick = { showChapterList = true }) {
                            Icon(Icons.Default.List, contentDescription = "章节列表")
                        }
                    }
                )
            }

            // 内容区域
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
                        text = uiState.error ?: "加载失败",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(Dimens.spacingLg)
                ) {
                    // 内容
                    if (uiState.currentContent.contains("<") && uiState.currentContent.contains(">")) {
                        // HTML 内容 - 使用 WebView 渲染，支持图片
                        val baseUrl = com.fryfrog.hub.data.remote.ApiClient.getBaseUrl()
                        val ebookImageBaseUrl = "$baseUrl/api/v1/ebook/$ebookId/image?file="

                        // 替换 HTML 中的图片路径
                        val processedContent = uiState.currentContent
                            .replace(Regex("""src="([^"]+)"""")) { match ->
                                val imagePath = match.groupValues[1]
                                if (imagePath.startsWith("http")) {
                                    match.value
                                } else {
                                    """src="$ebookImageBaseUrl$imagePath""""
                                }
                            }
                            .replace(Regex("""src='([^']+)""")) { match ->
                                val imagePath = match.groupValues[1]
                                if (imagePath.startsWith("http")) {
                                    match.value
                                } else {
                                    """src='$ebookImageBaseUrl$imagePath'"""
                                }
                            }

                        val htmlContent = """
                            <!DOCTYPE html>
                            <html>
                            <head>
                                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                                <style>
                                    body {
                                        font-size: ${fontSize.toInt()}px;
                                        line-height: 1.6;
                                        color: ${if (uiState.currentContent.contains("color")) "" else "#000000"};
                                        padding: 0;
                                        margin: 0;
                                    }
                                    img {
                                        max-width: 100%;
                                        height: auto;
                                    }
                                </style>
                            </head>
                            <body>
                                $processedContent
                            </body>
                            </html>
                        """.trimIndent()

                        AndroidView(
                            factory = { context ->
                                WebView(context).apply {
                                    webViewClient = WebViewClient()
                                    settings.javaScriptEnabled = false
                                    settings.loadWithOverviewMode = true
                                    settings.useWideViewPort = true
                                }
                            },
                            update = { webView ->
                                webView.loadDataWithBaseURL(
                                    baseUrl,
                                    htmlContent,
                                    "text/html",
                                    "UTF-8",
                                    null
                                )
                            },
                            modifier = Modifier.fillMaxSize()
                        )
                    } else {
                        // 纯文本内容
                        Text(
                            text = uiState.currentContent,
                            style = MaterialTheme.typography.bodyLarge.copy(
                                fontSize = fontSize.sp,
                                lineHeight = (fontSize * 1.6).sp
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }

                    // 上一章/下一章
                    Spacer(modifier = Modifier.height(Dimens.spacingXl))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        if (uiState.currentChapterIndex > 0) {
                            OutlinedButton(
                                onClick = { viewModel.loadChapter(uiState.currentChapterIndex - 1) }
                            ) {
                                Text("上一章")
                            }
                        } else {
                            Spacer(modifier = Modifier.width(1.dp))
                        }
                        if (uiState.currentChapterIndex < uiState.chapters.size - 1) {
                            Button(
                                onClick = { viewModel.loadChapter(uiState.currentChapterIndex + 1) }
                            ) {
                                Text("下一章")
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(Dimens.spacingXl))
                }
            }
        }

        // 章节列表 - 从右侧滑入
        AnimatedVisibility(
            visible = showChapterList,
            enter = slideInHorizontally(initialOffsetX = { it }),
            exit = slideOutHorizontally(targetOffsetX = { it })
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.5f))
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() }
                    ) {
                        showChapterList = false
                    }
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(280.dp)
                        .align(Alignment.CenterEnd)
                        .background(MaterialTheme.colorScheme.surface)
                        .clickable(
                            indication = null,
                            interactionSource = remember { MutableInteractionSource() }
                        ) {
                            // 阻止点击穿透
                        }
                        .statusBarsPadding()
                        .navigationBarsPadding()
                ) {
                    // 标题栏
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(Dimens.spacingMd)
                    ) {
                        Text(
                            text = "章节列表",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    HorizontalDivider()

                    // 章节列表
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                    ) {
                        uiState.chapters.forEachIndexed { index, chapter ->
                            Surface(
                                modifier = Modifier.fillMaxWidth(),
                                color = if (index == uiState.currentChapterIndex) {
                                    Primary.copy(alpha = 0.1f)
                                } else {
                                    Color.Transparent
                                },
                                onClick = {
                                    viewModel.loadChapter(index)
                                    showChapterList = false
                                }
                            ) {
                                Text(
                                    text = chapter.title,
                                    modifier = Modifier.padding(Dimens.spacingMd),
                                    color = if (index == uiState.currentChapterIndex) {
                                        Primary
                                    } else {
                                        MaterialTheme.colorScheme.onSurface
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
