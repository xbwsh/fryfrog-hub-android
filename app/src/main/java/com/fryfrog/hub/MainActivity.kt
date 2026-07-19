package com.fryfrog.hub

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.fryfrog.hub.ui.home.HomeScreen
import com.fryfrog.hub.ui.theme.FryfrogHubTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FryfrogHubTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    val navController = rememberNavController()

                    NavHost(
                        navController = navController,
                        startDestination = "home"
                    ) {
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
