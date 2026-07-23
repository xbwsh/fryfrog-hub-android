package com.fryfrog.hub

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.ui.components.PlaceholderScreen
import com.fryfrog.hub.ui.comics.ComicDetailScreen
import com.fryfrog.hub.ui.comics.ComicDetailViewModel
import com.fryfrog.hub.ui.comics.ComicsScreen
import com.fryfrog.hub.ui.ebooks.EbookDetailScreen
import com.fryfrog.hub.ui.ebooks.EbookDetailViewModel
import com.fryfrog.hub.ui.ebooks.EbooksScreen
import com.fryfrog.hub.ui.home.HomeScreen
import com.fryfrog.hub.ui.login.LoginScreen
import com.fryfrog.hub.ui.music.MusicScreen
import com.fryfrog.hub.ui.music.MusicViewModel
import com.fryfrog.hub.ui.music.MusicViewModelFactory
import com.fryfrog.hub.ui.navigation.FryfrogBottomBar
import com.fryfrog.hub.ui.navigation.Screen
import com.fryfrog.hub.ui.theme.FryfrogHubTheme
import com.fryfrog.hub.ui.player.PlayerScreen
import com.fryfrog.hub.ui.settings.SettingsScreen
import com.fryfrog.hub.ui.settings.MediaLibrariesScreen
import com.fryfrog.hub.ui.videos.VideoDetailScreen
import com.fryfrog.hub.ui.videos.VideoDetailViewModel
import com.fryfrog.hub.ui.videos.VideosScreen
import com.fryfrog.hub.util.PrefsManager

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val prefs = PrefsManager(this)

        setContent {
            var isDarkTheme by remember { mutableStateOf(prefs.isDarkTheme) }
            var isAdultContentHidden by remember { mutableStateOf(prefs.isAdultContentHidden) }
            var isCarouselEnabled by remember { mutableStateOf(prefs.isCarouselEnabled) }
            var carouselSource by remember { mutableStateOf(prefs.carouselSource) }
            var sectionOrder by remember { mutableStateOf(prefs.homeSectionOrder) }
            var sectionVisible by remember { mutableStateOf(prefs.homeSectionVisible) }

            // 设置状态栏图标颜色
            LaunchedEffect(isDarkTheme) {
                val controller = WindowInsetsControllerCompat(window, window.decorView)
                controller.isAppearanceLightStatusBars = !isDarkTheme
                controller.isAppearanceLightNavigationBars = !isDarkTheme
            }

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
                            carouselSource = carouselSource,
                            onCarouselSourceChange = { source ->
                                carouselSource = source
                                prefs.carouselSource = source
                            },
                            sectionOrder = sectionOrder,
                            onSectionOrderChange = { order ->
                                sectionOrder = order
                                prefs.homeSectionOrder = order
                            },
                            sectionVisible = sectionVisible,
                            onSectionVisibleChange = { sectionId, visible ->
                                sectionVisible = sectionVisible + (sectionId to visible)
                                prefs.homeSectionVisible = sectionVisible
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
    carouselSource: String,
    onCarouselSourceChange: (String) -> Unit,
    sectionOrder: List<String>,
    onSectionOrderChange: (List<String>) -> Unit,
    sectionVisible: Map<String, Boolean>,
    onSectionVisibleChange: (String, Boolean) -> Unit,
    onLogout: () -> Unit = {}
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            if (currentRoute in bottomNavRoutes) {
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
                    },
                    sectionVisible = sectionVisible
                )
            }
        },
        contentWindowInsets = WindowInsets(0, 0, 0, 0)
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(Screen.Home.route) {
                HomeScreen(
                    isAdultContentHidden = isAdultContentHidden,
                    sectionOrder = sectionOrder,
                    sectionVisible = sectionVisible,
                    carouselSource = carouselSource,
                    isCarouselEnabled = isCarouselEnabled,
                    onVideoClick = { videoId, type ->
                        navController.navigate("video_detail/$videoId?type=$type")
                    },
                    onMusicClick = { musicId ->
                        // TODO: Navigate to music player
                    },
                    onComicClick = { comicId ->
                        navController.navigate("comic_detail/$comicId")
                    },
                    onEbookClick = { ebookId ->
                        navController.navigate("ebook_detail/$ebookId")
                    }
                )
            }

            composable(Screen.Videos.route) {
                VideosScreen(
                    isAdultContentHidden = isAdultContentHidden,
                    onVideoClick = { videoId, type ->
                        navController.navigate("video_detail/$videoId?type=$type")
                    }
                )
            }

            composable(Screen.Music.route) {
                val context = LocalContext.current
                val viewModel: MusicViewModel = viewModel(
                    factory = MusicViewModelFactory(context.applicationContext as android.app.Application)
                )
                MusicScreen(viewModel = viewModel)
            }

            composable(Screen.Comics.route) {
                ComicsScreen(
                    onComicClick = { comicId ->
                        navController.navigate("comic_detail/$comicId")
                    }
                )
            }

            composable(
                route = "comic_detail/{seriesId}",
                arguments = listOf(navArgument("seriesId") { type = NavType.LongType })
            ) { backStackEntry ->
                val seriesId = backStackEntry.arguments?.getLong("seriesId") ?: 0L
                val viewModel: ComicDetailViewModel = viewModel(
                    factory = ComicDetailViewModelFactory(seriesId)
                )
                val uiState = viewModel.uiState.collectAsState()
                ComicDetailScreen(
                    series = uiState.value.series,
                    characters = uiState.value.characters,
                    onBackClick = { navController.popBackStack() },
                    onComicClick = { comicId ->
                        // TODO: Navigate to comic reader
                    }
                )
            }

            composable(Screen.Settings.route) {
                key(isDarkTheme) {
                    SettingsScreen(
                        isDarkTheme = isDarkTheme,
                        onThemeChange = onThemeChange,
                        isAdultContentHidden = isAdultContentHidden,
                        onAdultContentHiddenChange = onAdultContentHiddenChange,
                        isCarouselEnabled = isCarouselEnabled,
                        onCarouselEnabledChange = onCarouselEnabledChange,
                        carouselSource = carouselSource,
                        onCarouselSourceChange = onCarouselSourceChange,
                        sectionOrder = sectionOrder,
                        onSectionOrderChange = onSectionOrderChange,
                        sectionVisible = sectionVisible,
                        onSectionVisibleChange = onSectionVisibleChange,
                        onMediaLibrariesClick = {
                            navController.navigate("media_libraries")
                        },
                        onLogout = onLogout
                    )
                }
            }

            composable("media_libraries") {
                MediaLibrariesScreen(
                    onBackClick = { navController.popBackStack() }
                )
            }

            composable(Screen.Ebooks.route) {
                EbooksScreen(
                    onEbookClick = { ebookId ->
                        navController.navigate("ebook_detail/$ebookId")
                    }
                )
            }

            composable(
                route = "ebook_detail/{seriesId}",
                arguments = listOf(navArgument("seriesId") { type = NavType.LongType })
            ) { backStackEntry ->
                val seriesId = backStackEntry.arguments?.getLong("seriesId") ?: 0L
                val viewModel: EbookDetailViewModel = viewModel(
                    factory = EbookDetailViewModelFactory(seriesId)
                )
                val uiState = viewModel.uiState.collectAsState()
                EbookDetailScreen(
                    series = uiState.value.series,
                    characters = uiState.value.characters,
                    onBackClick = { navController.popBackStack() },
                    onEbookClick = { ebookId ->
                        // TODO: Navigate to ebook reader
                    }
                )
            }

            composable(
                route = "video_detail/{seriesId}?type={type}",
                arguments = listOf(
                    navArgument("seriesId") { type = NavType.LongType },
                    navArgument("type") { type = NavType.StringType; defaultValue = "" }
                )
            ) { backStackEntry ->
                val seriesId = backStackEntry.arguments?.getLong("seriesId") ?: 0L
                val type = backStackEntry.arguments?.getString("type")?.takeIf { it.isNotEmpty() }
                val viewModel: VideoDetailViewModel = viewModel(
                    factory = VideoDetailViewModelFactory(seriesId, type)
                )
                VideoDetailScreen(
                    viewModel = viewModel,
                    onBackClick = { navController.popBackStack() },
                    onPlayClick = { videoId ->
                        val encodedTitle = android.net.Uri.encode(viewModel.uiState.value.series?.title ?: "")
                        navController.navigate("player/$videoId/$encodedTitle")
                    }
                )
            }

            composable(
                route = "player/{videoId}/{title}",
                arguments = listOf(
                    navArgument("videoId") { type = NavType.LongType },
                    navArgument("title") { type = NavType.StringType }
                )
            ) { backStackEntry ->
                val videoId = backStackEntry.arguments?.getLong("videoId") ?: 0L
                val title = backStackEntry.arguments?.getString("title") ?: ""
                PlayerScreen(
                    videoId = videoId,
                    title = title,
                    onBackClick = { navController.popBackStack() }
                )
            }
        }
    }
}

private val bottomNavRoutes = listOf(
    Screen.Home.route,
    Screen.Videos.route,
    Screen.Music.route,
    Screen.Comics.route,
    Screen.Ebooks.route,
    Screen.Settings.route
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

class ComicDetailViewModelFactory(
    private val seriesId: Long
) : androidx.lifecycle.ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        return ComicDetailViewModel(seriesId) as T
    }
}

class EbookDetailViewModelFactory(
    private val seriesId: Long
) : androidx.lifecycle.ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        return EbookDetailViewModel(seriesId) as T
    }
}
