package com.fryfrog.hub

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Alignment
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.ui.home.HomeScreen
import com.fryfrog.hub.ui.home.HomeViewModel
import com.fryfrog.hub.ui.home.LibraryOverviewScreen
import com.fryfrog.hub.ui.calendar.UpcomingCalendarScreen
import com.fryfrog.hub.ui.favorites.FavoritesScreen
import com.fryfrog.hub.ui.login.LoginScreen
import com.fryfrog.hub.ui.navigation.FryfrogBottomBar
import com.fryfrog.hub.ui.navigation.Screen
import com.fryfrog.hub.ui.navigation.bottomNavScreens
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.FryfrogHubTheme
import com.fryfrog.hub.ui.player.PlayerScreen
import com.fryfrog.hub.ui.settings.MeScreen
import com.fryfrog.hub.ui.settings.MediaLibrariesScreen
import com.fryfrog.hub.ui.videos.VideoDetailScreen
import com.fryfrog.hub.ui.videos.VideoDetailViewModel
import com.fryfrog.hub.util.PrefsManager
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val VIDEO_DETAIL_ROUTE = "video_detail/{seriesId}?type={type}"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val prefs = PrefsManager(this)

        setContent {
            var themeMode by remember { mutableStateOf(prefs.themeMode) }
            val isDarkTheme = when (themeMode) {
                "dark" -> true
                "light" -> false
                else -> isSystemInDarkTheme()
            }
            var isAdultContentHidden by remember { mutableStateOf(prefs.isAdultContentHidden) }
            var isCarouselEnabled by remember { mutableStateOf(prefs.isCarouselEnabled) }
            var homeViewMode by remember { mutableStateOf(prefs.homeViewMode) }

            FryfrogHubTheme(darkTheme = isDarkTheme) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val navController = rememberNavController()
                    var isLoggedIn by remember { mutableStateOf(prefs.isLoggedIn) }

                    val mainHandler = Handler(Looper.getMainLooper())

                    LaunchedEffect(Unit) {
                        if (prefs.isLoggedIn) {
                            ApiClient.init(this@MainActivity)
                        }
                        ApiClient.onUnauthorized = {
                            mainHandler.post { isLoggedIn = false }
                        }
                    }

                    if (isLoggedIn) {
                        MainContent(
                            navController = navController,
                            onThemeModeChange = { mode ->
                                themeMode = mode
                                prefs.themeMode = mode
                            },
                            isDarkTheme = isDarkTheme,
                            themeMode = themeMode,
                            isAdultContentHidden = isAdultContentHidden,
                            onAdultContentHiddenChange = { hidden ->
                                isAdultContentHidden = hidden
                                prefs.isAdultContentHidden = hidden
                            },
                            isCarouselEnabled = isCarouselEnabled,
                            onCarouselEnabledChange = { enabled ->
                                isCarouselEnabled = enabled
                                prefs.isCarouselEnabled = enabled
                            },
                            homeViewMode = homeViewMode,
                            onViewModeChange = { mode ->
                                homeViewMode = mode
                                prefs.homeViewMode = mode
                            },
                            onLogout = {
                                prefs.clearLogin()
                                isLoggedIn = false
                            }
                        )
                    } else {
                        LoginScreen(
                            onLoginSuccess = {
                                isLoggedIn = true
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MainContent(
    navController: androidx.navigation.NavHostController,
    onThemeModeChange: (String) -> Unit,
    isDarkTheme: Boolean,
    themeMode: String,
    isAdultContentHidden: Boolean,
    onAdultContentHiddenChange: (Boolean) -> Unit,
    isCarouselEnabled: Boolean,
    onCarouselEnabledChange: (Boolean) -> Unit,
    homeViewMode: String,
    onViewModeChange: (String) -> Unit,
    onLogout: () -> Unit = {}
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val showBottomBar = currentRoute in bottomNavRoutes

    val isHomeScreen = currentRoute == Screen.Home.route
    // 顶部有深色渐变遮罩的页面：状态栏图标固定为白色
    val hasDarkTopOverlay = isHomeScreen || currentRoute == VIDEO_DETAIL_ROUTE
    val view = LocalView.current

    // Activity 级别的共享 HomeViewModel
    val homeViewModel: HomeViewModel = viewModel()

    LaunchedEffect(hasDarkTopOverlay, isHomeScreen, isDarkTheme) {
        val window = (view.context as android.app.Activity).window
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.isAppearanceLightStatusBars = !hasDarkTopOverlay && !isDarkTheme
        controller.isAppearanceLightNavigationBars = if (isHomeScreen) false else !isDarkTheme
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0)
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().padding(paddingValues)) {
            NavHost(
                navController = navController,
                startDestination = Screen.Home.route,
                modifier = Modifier.fillMaxSize()
            ) {
            // 首页 - 视频列表
            composable(Screen.Home.route) {
                HomeScreen(
                    viewModel = homeViewModel,
                    isAdultContentHidden = isAdultContentHidden,
                    isCarouselEnabled = isCarouselEnabled,
                    homeViewMode = homeViewMode,
                    onViewModeChange = onViewModeChange,
                    onCalendarClick = {
                        navController.navigate("calendar")
                    },
                    onFavoritesClick = {
                        navController.navigate("favorites")
                    },
                    onVideoClick = { videoId, type ->
                        navController.navigate("video_detail/$videoId?type=$type")
                    },
                    onLibraryClick = { libraryId, libraryName ->
                        val encodedName = android.net.Uri.encode(libraryName)
                        navController.navigate("library_overview/$libraryId?name=$encodedName")
                    }
                )
            }

            // 追更日历
            composable("calendar") {
                UpcomingCalendarScreen(
                    onBackClick = { navController.popBackStack() }
                )
            }

            // 我的收藏
            composable("favorites") {
                FavoritesScreen(
                    onBackClick = { navController.popBackStack() },
                    onVideoClick = { videoId, type ->
                        navController.navigate("video_detail/$videoId?type=$type")
                    }
                )
            }

            // 库总览
            composable(
                route = "library_overview/{libraryId}?name={name}",
                arguments = listOf(
                    navArgument("libraryId") { type = NavType.LongType },
                    navArgument("name") { type = NavType.StringType; defaultValue = "" }
                ),
                enterTransition = {
                    slideInHorizontally(
                        initialOffsetX = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeIn(animationSpec = tween(250))
                },
                exitTransition = {
                    slideOutHorizontally(
                        targetOffsetX = { -it / 3 },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeOut(animationSpec = tween(200))
                },
                popEnterTransition = {
                    slideInHorizontally(
                        initialOffsetX = { -it / 3 },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeIn(animationSpec = tween(250))
                },
                popExitTransition = {
                    slideOutHorizontally(
                        targetOffsetX = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeOut(animationSpec = tween(200))
                }
            ) { backStackEntry ->
                val libraryId = backStackEntry.arguments?.getLong("libraryId")
                val libraryName = backStackEntry.arguments?.getString("name") ?: ""
                val homeUiState by homeViewModel.uiState.collectAsState()
                val libraryItems = homeUiState.libraryGroups.find { it.libraryId == libraryId }
                    ?.let { it.series + it.standaloneVideos }
                    ?: emptyList()
                LibraryOverviewScreen(
                    libraryId = libraryId,
                    libraryName = libraryName,
                    libraryItems = libraryItems,
                    onBackClick = { navController.popBackStack() },
                    onVideoClick = { videoId, type ->
                        navController.navigate("video_detail/$videoId?type=$type")
                    },
                    onRefresh = { homeViewModel.loadHomeData() }
                )
            }

            // 媒体库
            composable(Screen.MediaLibraries.route) {
                MediaLibrariesScreen(
                    onBackClick = null
                )
            }

            // 我的
            composable(Screen.Me.route) {
                key(isDarkTheme) {
                    val scope = rememberCoroutineScope()
                    val snackbarHostState = remember { androidx.compose.material3.SnackbarHostState() }
                    val logoProgressState = remember { mutableStateOf<com.fryfrog.hub.data.model.ScrapeProgress?>(null) }
                    val logoPollJobState = remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
                    val resolutionProgressState = remember { mutableStateOf<com.fryfrog.hub.data.model.ScrapeProgress?>(null) }
                    val resolutionPollJobState = remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
                    val actorsProgressState = remember { mutableStateOf<com.fryfrog.hub.data.model.ScrapeProgress?>(null) }
                    val actorsPollJobState = remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }
                    val seasonCoversProgressState = remember { mutableStateOf<com.fryfrog.hub.data.model.ScrapeProgress?>(null) }
                    val seasonCoversPollJobState = remember { mutableStateOf<kotlinx.coroutines.Job?>(null) }

                    // 通用批量提交 + 进度轮询：submit 返回 (module, 总数)
                    fun submitBatch(
                        submit: suspend () -> Result<Pair<String?, Int>>,
                        defaultModule: String,
                        progressState: androidx.compose.runtime.MutableState<com.fryfrog.hub.data.model.ScrapeProgress?>,
                        pollJobState: androidx.compose.runtime.MutableState<kotlinx.coroutines.Job?>,
                        submittedText: (Int) -> String
                    ) {
                        if (pollJobState.value?.isActive == true) return
                        pollJobState.value = scope.launch {
                            val result = submit()
                            result.fold(
                                onSuccess = { (module, total) ->
                                    snackbarHostState.showSnackbar(submittedText(total))
                                    val resolvedModule = module ?: defaultModule
                                    val api = ApiClient.getApi()
                                    while (true) {
                                        delay(1500)
                                        val p = api.getScrapeProgress(resolvedModule).data ?: continue
                                        progressState.value = p
                                        if (!p.running) {
                                            progressState.value = null
                                            snackbarHostState.showSnackbar("补全完成：成功 ${p.completed}，失败 ${p.failed}，跳过 ${p.skipped}")
                                            break
                                        }
                                    }
                                },
                                onFailure = { e ->
                                    snackbarHostState.showSnackbar("提交失败: ${e.message}")
                                }
                            )
                        }
                    }

                    Box(modifier = Modifier.fillMaxSize()) {
                        MeScreen(
                            isDarkTheme = isDarkTheme,
                            themeMode = themeMode,
                            onThemeModeChange = onThemeModeChange,
                            isAdultContentHidden = isAdultContentHidden,
                            onAdultContentHiddenChange = onAdultContentHiddenChange,
                            isCarouselEnabled = isCarouselEnabled,
                            onCarouselEnabledChange = onCarouselEnabledChange,
                            onLogout = onLogout,
                            onRefreshAllSeasonCovers = {
                                submitBatch(
                                    submit = {
                                        com.fryfrog.hub.data.repository.MediaRepository().refreshAllSeasonCovers()
                                            .map { data ->
                                                (data["module"] as? String) to ((data["totalSeries"] as? Number)?.toInt() ?: 0)
                                            }
                                    },
                                    defaultModule = "season-covers",
                                    progressState = seasonCoversProgressState,
                                    pollJobState = seasonCoversPollJobState,
                                    submittedText = { "已提交 $it 个系列的季海报刷新任务" }
                                )
                            },
                            onRefreshAllMovieActors = {
                                submitBatch(
                                    submit = {
                                        com.fryfrog.hub.data.repository.MediaRepository().refreshAllActors()
                                            .map { it.module to (it.totalVideos ?: 0) }
                                    },
                                    defaultModule = "actors",
                                    progressState = actorsProgressState,
                                    pollJobState = actorsPollJobState,
                                    submittedText = { "已提交 $it 个视频的演员刷新任务" }
                                )
                            },
                            onRefreshAllLogos = {
                                submitBatch(
                                    submit = {
                                        com.fryfrog.hub.data.repository.MediaRepository().refreshAllLogos()
                                            .map { it.module to (it.total ?: it.totalSeries ?: it.totalMovies ?: 0) }
                                    },
                                    defaultModule = "logo:all",
                                    progressState = logoProgressState,
                                    pollJobState = logoPollJobState,
                                    submittedText = { "已提交 $it 个条目的 Logo 补全任务" }
                                )
                            },
                            onRefreshAllResolutions = {
                                submitBatch(
                                    submit = {
                                        com.fryfrog.hub.data.repository.MediaRepository().refreshAllResolutions()
                                            .map { it.module to (it.pendingVideos ?: it.totalVideos ?: 0) }
                                    },
                                    defaultModule = "resolution",
                                    progressState = resolutionProgressState,
                                    pollJobState = resolutionPollJobState,
                                    submittedText = { "已提交 $it 个视频的分辨率补全任务" }
                                )
                            },
                            logoProgress = logoProgressState.value,
                            resolutionProgress = resolutionProgressState.value,
                            actorsProgress = actorsProgressState.value,
                            seasonCoversProgress = seasonCoversProgressState.value
                        )

                        androidx.compose.material3.SnackbarHost(
                            hostState = snackbarHostState,
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .padding(Dimens.spacingLg)
                                .padding(bottom = Dimens.bottomNavReserve)
                        )
                    }
                }
            }

            // 视频详情
            composable(
                route = VIDEO_DETAIL_ROUTE,
                arguments = listOf(
                    navArgument("seriesId") { type = NavType.LongType },
                    navArgument("type") { type = NavType.StringType; defaultValue = "" }
                ),
                enterTransition = {
                    slideInHorizontally(
                        initialOffsetX = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeIn(animationSpec = tween(250))
                },
                exitTransition = {
                    slideOutHorizontally(
                        targetOffsetX = { -it / 3 },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeOut(animationSpec = tween(200))
                },
                popEnterTransition = {
                    slideInHorizontally(
                        initialOffsetX = { -it / 3 },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeIn(animationSpec = tween(250))
                },
                popExitTransition = {
                    slideOutHorizontally(
                        targetOffsetX = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeOut(animationSpec = tween(200))
                }
            ) { backStackEntry ->
                val seriesId = backStackEntry.arguments?.getLong("seriesId") ?: 0L
                val type = backStackEntry.arguments?.getString("type")?.takeIf { it.isNotEmpty() }
                val viewModel: VideoDetailViewModel = viewModel(
                    factory = VideoDetailViewModelFactory(seriesId, type)
                )
                VideoDetailScreen(
                    viewModel = viewModel,
                    onBackClick = {
                        // 返回列表时刷新，获取绑定/刮削后的最新元数据
                        homeViewModel.loadHomeData()
                        navController.popBackStack()
                    },
                    onPlayClick = { videoId, forceRestart ->
                        val encodedTitle = android.net.Uri.encode(viewModel.uiState.value.series?.title ?: "")
                        val route = if (forceRestart) "player/$videoId/$encodedTitle?forceRestart=true" else "player/$videoId/$encodedTitle"
                        navController.navigate(route)
                    }
                )
            }

            // 播放器
            composable(
                route = "player/{videoId}/{title}?forceRestart={forceRestart}",
                arguments = listOf(
                    navArgument("videoId") { type = NavType.LongType },
                    navArgument("title") { type = NavType.StringType },
                    navArgument("forceRestart") { type = NavType.BoolType; defaultValue = false }
                ),
                enterTransition = {
                    slideInVertically(
                        initialOffsetY = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeIn(animationSpec = tween(250))
                },
                exitTransition = {
                    slideOutVertically(
                        targetOffsetY = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeOut(animationSpec = tween(200))
                },
                popEnterTransition = {
                    slideInVertically(
                        initialOffsetY = { -it / 3 },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeIn(animationSpec = tween(250))
                },
                popExitTransition = {
                    slideOutVertically(
                        targetOffsetY = { it },
                        animationSpec = tween(350, easing = FastOutSlowInEasing)
                    ) + fadeOut(animationSpec = tween(200))
                }
            ) { backStackEntry ->
                val videoId = backStackEntry.arguments?.getLong("videoId") ?: 0L
                val title = backStackEntry.arguments?.getString("title") ?: ""
                val forceRestart = backStackEntry.arguments?.getBoolean("forceRestart") ?: false
                val parentEntry = remember {
                    navController.getBackStackEntry("video_detail/{seriesId}?type={type}")
                }
                val detailViewModel: VideoDetailViewModel = viewModel(parentEntry)
                PlayerScreen(
                    videoId = videoId,
                    title = title,
                    onBackClick = { navController.popBackStack() },
                    onProgressSaved = { detailViewModel.refreshProgress() },
                    forceRestart = forceRestart
                )
            }
        }

        // 浮动底部导航栏
        AnimatedVisibility(
            visible = showBottomBar,
            enter = slideInVertically(
                initialOffsetY = { it },
                animationSpec = tween(300)
            ) + fadeIn(animationSpec = tween(300)),
            exit = slideOutVertically(
                targetOffsetY = { it },
                animationSpec = tween(300)
            ) + fadeOut(animationSpec = tween(300)),
            modifier = Modifier
                .align(Alignment.BottomCenter)
        ) {
            FryfrogBottomBar(
                currentRoute = currentRoute,
                onNavigate = { route ->
                    navController.navigate(route) {
                        popUpTo(Screen.Home.route) {
                            saveState = true
                        }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            )
        }
        } // Box
    } // Scaffold
}

private val bottomNavRoutes = listOf(
    Screen.Home.route,
    Screen.MediaLibraries.route,
    Screen.Me.route
)

class VideoDetailViewModelFactory(
    private val seriesId: Long,
    private val type: String? = null
) : androidx.lifecycle.ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        return VideoDetailViewModel(seriesId, type) as T
    }
}
