package com.fryfrog.hub.ui.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringArrayResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SeriesCalendarItem
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpcomingCalendarScreen(
    onBackClick: () -> Unit,
    onVideoClick: (Long, String) -> Unit = { _, _ -> },
    viewModel: UpcomingCalendarViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var monthOffset by remember { mutableIntStateOf(0) }
    var selectedDate by remember { mutableStateOf<String?>(null) }

    val configuration = LocalConfiguration.current
    // 平板横屏（宽屏）左右分栏；手机/平板竖屏上下分屏
    val isWideTablet = configuration.screenWidthDp >= 900

    val calendar = remember(monthOffset) {
        Calendar.getInstance().apply { add(Calendar.MONTH, monthOffset) }
    }
    val year = calendar.get(Calendar.YEAR)
    val month = calendar.get(Calendar.MONTH)
    val firstOfMonth = remember(year, month) {
        Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month)
            set(Calendar.DAY_OF_MONTH, 1)
        }
    }
    // 周一作为一周起始：DAY_OF_WEEK 1=周日，偏移 = (weekday + 5) % 7
    val leadingBlanks = (firstOfMonth.get(Calendar.DAY_OF_WEEK) + 5) % 7
    val daysInMonth = firstOfMonth.getActualMaximum(Calendar.DAY_OF_MONTH)

    val byDate = remember(uiState.items) {
        uiState.items
            .filter { !it.nextEpisodeDate.isNullOrBlank() }
            .groupBy { it.nextEpisodeDate!! }
    }
    val todayStr = remember {
        SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    }

    // 默认选中今天；今天无更新则选中该月第一个有更新的日期
    LaunchedEffect(uiState.items, monthOffset) {
        val monthKey = "%04d-%02d".format(year, month + 1)
        selectedDate = byDate.keys.firstOrNull { it.startsWith(monthKey) }
            ?: todayStr.takeIf { it.startsWith(monthKey) }
            ?: byDate.keys.firstOrNull()
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.upcoming_calendar)) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.load() }) {
                        Icon(
                            Icons.Default.Refresh,
                            contentDescription = stringResource(R.string.refresh)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }

            uiState.error != null -> {
                val errorMessage = uiState.error ?: ""
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = errorMessage,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.height(Dimens.spacingLg))
                    Button(onClick = { viewModel.load() }) {
                        Text(stringResource(R.string.retry))
                    }
                }
            }

            else -> {
                val selectedItems = selectedDate?.let { byDate[it].orEmpty() }.orEmpty()
                if (isWideTablet) {
                    // 平板横屏：左侧月历 + 右侧当日详情
                    Row(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(paddingValues)
                    ) {
                        CalendarPanel(
                            year = year,
                            month = month,
                            leadingBlanks = leadingBlanks,
                            daysInMonth = daysInMonth,
                            byDate = byDate,
                            selectedDate = selectedDate,
                            todayStr = todayStr,
                            isWideTablet = true,
                            onMonthChange = { monthOffset += it },
                            onDateClick = { selectedDate = it },
                            modifier = Modifier
                                .weight(0.58f)
                                .fillMaxHeight()
                        )
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .fillMaxHeight()
                                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                        )
                        DayDetailPanel(
                            selectedDate = selectedDate,
                            items = selectedItems,
                            onVideoClick = onVideoClick,
                            modifier = Modifier
                                .weight(0.42f)
                                .fillMaxHeight()
                        )
                    }
                } else {
                    // 手机/平板竖屏：上方月历 + 下方当日详情
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(paddingValues)
                    ) {
                        CalendarPanel(
                            year = year,
                            month = month,
                            leadingBlanks = leadingBlanks,
                            daysInMonth = daysInMonth,
                            byDate = byDate,
                            selectedDate = selectedDate,
                            todayStr = todayStr,
                            isWideTablet = false,
                            onMonthChange = { monthOffset += it },
                            onDateClick = { selectedDate = it },
                            modifier = Modifier.fillMaxWidth()
                        )
                        DayDetailPanel(
                            selectedDate = selectedDate,
                            items = selectedItems,
                            onVideoClick = onVideoClick,
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CalendarPanel(
    year: Int,
    month: Int,
    leadingBlanks: Int,
    daysInMonth: Int,
    byDate: Map<String, List<SeriesCalendarItem>>,
    selectedDate: String?,
    todayStr: String,
    isWideTablet: Boolean,
    onMonthChange: (Int) -> Unit,
    onDateClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val weekdays = stringArrayResource(R.array.calendar_weekdays)
    val monthKey = "%04d-%02d".format(year, month + 1)
    val hasUpdatesInMonth = byDate.keys.any { it.startsWith(monthKey) }

    Column(modifier = modifier) {
        // 月份切换
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            IconButton(onClick = { onMonthChange(-1) }) {
                Icon(Icons.Default.ChevronLeft, contentDescription = null)
            }
            Text(
                text = stringResource(R.string.calendar_month_format, year, month + 1),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            IconButton(onClick = { onMonthChange(1) }) {
                Icon(Icons.Default.ChevronRight, contentDescription = null)
            }
        }

        // 星期表头
        Row(modifier = Modifier.fillMaxWidth()) {
            weekdays.forEach { day ->
                Text(
                    text = day,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // 月历网格
        val totalCells = leadingBlanks + daysInMonth
        val rows = (totalCells + 6) / 7
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 2.dp)
                .verticalScroll(rememberScrollState())
        ) {
            for (row in 0 until rows) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    for (col in 0 until 7) {
                        val cellIndex = row * 7 + col
                        val day = cellIndex - leadingBlanks + 1
                        if (day in 1..daysInMonth) {
                            val dateStr = "%04d-%02d-%02d".format(year, month + 1, day)
                            DayCell(
                                day = day,
                                isToday = dateStr == todayStr,
                                hasUpdates = byDate.containsKey(dateStr),
                                isSelected = dateStr == selectedDate,
                                isWideTablet = isWideTablet,
                                onClick = { onDateClick(dateStr) },
                                modifier = Modifier.weight(1f)
                            )
                        } else {
                            Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        if (!hasUpdatesInMonth) {
            Text(
                text = stringResource(R.string.no_updates_month),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = Dimens.spacingMd)
            )
        }
    }
}

@Composable
private fun DayCell(
    day: Int,
    isToday: Boolean,
    hasUpdates: Boolean,
    isSelected: Boolean,
    isWideTablet: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val textColor = when {
        isSelected || isToday || hasUpdates -> Primary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Box(
        modifier = modifier
            // 固定高度格子：宽屏稍大，其他紧凑，避免随列宽暴涨导致溢出
            .height(if (isWideTablet) 72.dp else 56.dp)
            .padding(3.dp)
            .clip(RoundedCornerShape(Dimens.radiusMd))
            .background(
                when {
                    isSelected -> Primary.copy(alpha = 0.2f)
                    hasUpdates -> Primary.copy(alpha = 0.1f)
                    else -> Color.Transparent
                }
            )
            .border(
                width = 1.5.dp,
                color = if (isSelected) Primary else Color.Transparent,
                shape = RoundedCornerShape(Dimens.radiusMd)
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "$day",
                style = MaterialTheme.typography.labelMedium,
                color = textColor,
                fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal
            )
            Spacer(modifier = Modifier.height(3.dp))
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            isSelected -> Primary
                            hasUpdates -> Primary.copy(alpha = 0.6f)
                            else -> Color.Transparent
                        }
                    )
            )
        }
    }
}

@Composable
private fun DayDetailPanel(
    selectedDate: String?,
    items: List<SeriesCalendarItem>,
    onVideoClick: (Long, String) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        // 日期标题
        val titleText = selectedDate?.let { date ->
            val parts = date.split("-")
            if (parts.size == 3) {
                stringResource(
                    R.string.calendar_date_title,
                    parts[0].toIntOrNull() ?: 0,
                    parts[1].toIntOrNull() ?: 0,
                    parts[2].toIntOrNull() ?: 0
                )
            } else {
                date
            }
        }
        Text(
            text = titleText ?: stringResource(R.string.upcoming_calendar),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.padding(
                start = Dimens.spacingLg,
                top = Dimens.spacingMd,
                end = Dimens.spacingLg,
                bottom = Dimens.spacingSm
            )
        )

        when {
            selectedDate == null -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.select_date_hint),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            items.isEmpty() -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.no_updates_today),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentPadding = PaddingValues(
                        start = Dimens.spacingLg,
                        end = Dimens.spacingLg,
                        bottom = Dimens.spacingLg
                    ),
                    verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    items(items, key = { it.seriesId }) { item ->
                        EpisodeItemCard(
                            item = item,
                            onClick = { onVideoClick(item.seriesId, "series") }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EpisodeItemCard(
    item: SeriesCalendarItem,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 封面（竖版）
            Box(
                modifier = Modifier
                    .width(48.dp)
                    .height(64.dp)
                    .clip(RoundedCornerShape(Dimens.radiusSm))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                if (item.coverUrl != null) {
                    AsyncImage(
                        model = item.coverUrl,
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop,
                        alignment = Alignment.TopCenter
                    )
                }
            }
            Spacer(modifier = Modifier.width(Dimens.spacingMd))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(Dimens.spacingXxs))
                item.nextEpisodeNumber?.let { ep ->
                    Text(
                        text = ep,
                        style = MaterialTheme.typography.labelMedium,
                        color = Primary
                    )
                }
            }
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
            )
        }
    }
}
