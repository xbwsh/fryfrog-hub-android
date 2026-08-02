package com.fryfrog.hub.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.VideoLibrary
import androidx.compose.material.icons.filled.Person
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

    data object MediaLibraries : Screen(
        route = "media_libraries",
        titleResId = com.fryfrog.hub.R.string.section_media_libraries,
        icon = Icons.Default.VideoLibrary
    )

    data object Me : Screen(
        route = "me",
        titleResId = com.fryfrog.hub.R.string.section_me,
        icon = Icons.Default.Person
    )
}

val bottomNavScreens = listOf(
    Screen.Home,
    Screen.MediaLibraries,
    Screen.Me
)
