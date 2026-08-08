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
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.Alignment
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
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
import com.fryfrog.hub.ui.login.LoginScreen
import com.fryfrog.hub.ui.navigation.FryfrogBottomBar
import com.fryfrog.hub.ui.navigation.Screen
import com.fryfrog.hub.ui.navigation.bottomNavScreens
import com.fryfrog.hub.ui.theme.FryfrogHubTheme
import com.fryfrog.hub.ui.player.PlayerScreen
import com.fryfrog.hub.ui.settings.MeScreen
import com.fryfrog.hub.ui.settings.MediaLibrariesScreen
import com.fryfrog.hub.ui.videos.VideoDetailScreen
import com.fryfrog.hub.ui.videos.VideoDetailViewModel
import com.fryfrog.hub.util.PrefsManager

private const val VIDEO_DETAIL_ROUTE = "video_detail/{seriesId}?type={type}"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val prefs = PrefsManager(this)

        setContent {
            var isDarkTheme by remember { mutableStateOf(prefs.isDarkTheme) }
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
                            onThemeChange = { dark ->
                                isDarkTheme = dark
                                prefs.isDarkTheme = dark
                            },
                            isDarkTheme = isDarkTheme,
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
    onThemeChange: (Boolean) -> Unit,
    isDarkTheme: Boolean,
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
    var bottomBarHeight by remember { mutableIntStateOf(0) }

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
                modifier = Modifier.fillMaxSize().padding(
                    bottom = if (showBottomBar) with(LocalDensity.current) { bottomBarHeight.toDp() } else 0.dp
                )
            ) {
            // 首页 - 视频列表
            composable(Screen.Home.route) {
                HomeScreen(
                    viewModel = homeViewModel,
                    isAdultContentHidden = isAdultContentHidden,
                    isCarouselEnabled = isCarouselEnabled,
                    homeViewMode = homeViewMode,
                    onViewModeChange = onViewModeChange,
                    onVideoClick = { videoId, type ->
                        navController.navigate("video_detail/$videoId?type=$type")
                    },
                    onLibraryClick = { libraryId, libraryName ->
                        val encodedName = android.net.Uri.encode(libraryName)
                        navController.navigate("library_overview/$libraryId?name=$encodedName")
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
                    MeScreen(
                        isDarkTheme = isDarkTheme,
                        onThemeChange = onThemeChange,
                        isAdultContentHidden = isAdultContentHidden,
                        onAdultContentHiddenChange = onAdultContentHiddenChange,
                        isCarouselEnabled = isCarouselEnabled,
                        onCarouselEnabledChange = onCarouselEnabledChange,
                        onLogout = onLogout
                    )
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
                    onBackClick = { navController.popBackStack() },
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
                .onGloballyPositioned { coordinates ->
                    bottomBarHeight = coordinates.size.height
                }
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
