package com.fryfrog.hub.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.ChromeReaderMode
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Screen(
    val route: String,
    val titleResId: Int,
    val icon: ImageVector
) {
    data object Home : Screen(
        route = "home",
        titleResId = com.fryfrog.hub.R.string.section_home,
        icon = Icons.Default.Home
    )

    data object Videos : Screen(
        route = "videos",
        titleResId = com.fryfrog.hub.R.string.section_videos,
        icon = Icons.Default.VideoLibrary
    )

    data object Music : Screen(
        route = "music",
        titleResId = com.fryfrog.hub.R.string.section_music,
        icon = Icons.Default.LibraryMusic
    )

    data object Comics : Screen(
        route = "comics",
        titleResId = com.fryfrog.hub.R.string.section_comics,
        icon = Icons.Default.Book
    )

    data object Ebooks : Screen(
        route = "ebooks",
        titleResId = com.fryfrog.hub.R.string.section_ebooks,
        icon = Icons.Default.ChromeReaderMode
    )

    data object Settings : Screen(
        route = "settings",
        titleResId = com.fryfrog.hub.R.string.section_settings,
        icon = Icons.Default.Settings
    )
}

val bottomNavScreens = listOf(
    Screen.Home,
    Screen.Videos,
    Screen.Music,
    Screen.Comics,
    Screen.Ebooks,
    Screen.Settings
)
