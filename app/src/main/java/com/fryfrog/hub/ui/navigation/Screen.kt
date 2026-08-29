package com.fryfrog.hub.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.LibraryMusic
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.VideoLibrary
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Screen(
    val route: String,
    val titleResId: Int,
    val icon: ImageVector,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    data object Home : Screen(
        route = "home",
        titleResId = com.fryfrog.hub.R.string.section_home,
        icon = Icons.Filled.Home,
        selectedIcon = Icons.Filled.Home,
        unselectedIcon = Icons.Outlined.Home
    )

    data object Music : Screen(
        route = "music",
        titleResId = com.fryfrog.hub.R.string.section_music,
        icon = Icons.Filled.LibraryMusic,
        selectedIcon = Icons.Filled.LibraryMusic,
        unselectedIcon = Icons.Outlined.LibraryMusic
    )

    data object MediaLibraries : Screen(
        route = "media_libraries",
        titleResId = com.fryfrog.hub.R.string.section_media_libraries,
        icon = Icons.Filled.VideoLibrary,
        selectedIcon = Icons.Filled.VideoLibrary,
        unselectedIcon = Icons.Outlined.VideoLibrary
    )

    data object Me : Screen(
        route = "me",
        titleResId = com.fryfrog.hub.R.string.section_me,
        icon = Icons.Filled.Person,
        selectedIcon = Icons.Filled.Person,
        unselectedIcon = Icons.Outlined.Person
    )
}

val bottomNavScreens = listOf(
    Screen.Home,
    Screen.Music,
    Screen.MediaLibraries,
    Screen.Me
)
