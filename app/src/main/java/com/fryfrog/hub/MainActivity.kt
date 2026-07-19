package com.fryfrog.hub

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.ui.components.PlaceholderScreen
import com.fryfrog.hub.ui.home.HomeScreen
import com.fryfrog.hub.ui.login.LoginScreen
import com.fryfrog.hub.ui.navigation.FryfrogBottomBar
import com.fryfrog.hub.ui.navigation.Screen
import com.fryfrog.hub.ui.theme.FryfrogHubTheme
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
            FryfrogHubTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val navController = rememberNavController()
                    var isLoggedIn by remember { mutableStateOf(prefs.isLoggedIn) }

                    LaunchedEffect(Unit) {
                        if (prefs.isLoggedIn) {
                            ApiClient.init(this@MainActivity)
                        }
                    }

                    if (isLoggedIn) {
                        MainContent(navController = navController)
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
private fun MainContent(navController: androidx.navigation.NavHostController) {
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
                    }
                )
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(Screen.Home.route) {
                HomeScreen(
                    onVideoClick = { videoId ->
                        android.util.Log.d("Navigation", "Video clicked: $videoId")
                        navController.navigate("video_detail/$videoId")
                    },
                    onMusicClick = { musicId ->
                        // TODO: Navigate to music player
                    },
                    onComicClick = { comicId ->
                        // TODO: Navigate to comic reader
                    },
                    onEbookClick = { ebookId ->
                        // TODO: Navigate to ebook reader
                    }
                )
            }

            composable(Screen.Videos.route) {
                VideosScreen(
                    onVideoClick = { videoId ->
                        android.util.Log.d("Navigation", "Video clicked from list: $videoId")
                        navController.navigate("video_detail/$videoId")
                    }
                )
            }

            composable(Screen.Music.route) {
                PlaceholderScreen(title = stringResource(Screen.Music.titleResId))
            }

            composable(Screen.Comics.route) {
                PlaceholderScreen(title = stringResource(Screen.Comics.titleResId))
            }

            composable(Screen.Settings.route) {
                PlaceholderScreen(title = stringResource(Screen.Settings.titleResId))
            }

            composable(
                route = "video_detail/{seriesId}",
                arguments = listOf(navArgument("seriesId") { type = NavType.LongType })
            ) { backStackEntry ->
                val seriesId = backStackEntry.arguments?.getLong("seriesId") ?: 0L
                val viewModel: VideoDetailViewModel = viewModel(
                    factory = VideoDetailViewModelFactory(seriesId)
                )
                VideoDetailScreen(
                    viewModel = viewModel,
                    onBackClick = { navController.popBackStack() },
                    onPlayClick = { videoId ->
                        // TODO: Navigate to video player
                    }
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
    Screen.Settings.route
)

class VideoDetailViewModelFactory(
    private val seriesId: Long
) : androidx.lifecycle.ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        return VideoDetailViewModel(seriesId) as T
    }
}
