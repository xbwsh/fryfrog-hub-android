package com.fryfrog.hub

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.ui.home.HomeScreen
import com.fryfrog.hub.ui.login.LoginScreen
import com.fryfrog.hub.ui.theme.FryfrogHubTheme
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

                    // Initialize API if already logged in
                    LaunchedEffect(Unit) {
                        if (prefs.isLoggedIn) {
                            ApiClient.init(this@MainActivity)
                        }
                    }

                    NavHost(
                        navController = navController,
                        startDestination = if (isLoggedIn) "home" else "login"
                    ) {
                        composable("login") {
                            LoginScreen(
                                onLoginSuccess = {
                                    isLoggedIn = true
                                    navController.navigate("home") {
                                        popUpTo("login") { inclusive = true }
                                    }
                                }
                            )
                        }

                        composable("home") {
                            HomeScreen(
                                onVideoClick = { videoId ->
                                    // TODO: Navigate to video detail
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
                    }
                }
            }
        }
    }
}
