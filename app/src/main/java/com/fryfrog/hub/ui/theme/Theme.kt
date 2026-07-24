package com.fryfrog.hub.ui.theme

import android.os.Build
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration

// 暗色主题 - 暗夜黑
private val DarkColorScheme = darkColorScheme(
    primary = Primary,
    onPrimary = White,
    primaryContainer = Primary,
    onPrimaryContainer = White,

    secondary = Success,
    onSecondary = White,

    tertiary = Info,
    onTertiary = White,

    background = SoftBlack,
    onBackground = White,
    surface = SoftBlack,
    onSurface = White,
    surfaceVariant = Color(0xFF252525),
    onSurfaceVariant = TextSecondary,

    error = Danger,
    onError = White,

    outline = BorderDark
)

// 亮色主题 - 流光白
private val LightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = White,
    primaryContainer = Color(0xFFD9ECFF),
    onPrimaryContainer = TextPrimary,

    secondary = Success,
    onSecondary = White,

    tertiary = Info,
    onTertiary = White,

    background = PageBackground,
    onBackground = TextPrimary,
    surface = BaseBackground,
    onSurface = TextPrimary,
    surfaceVariant = FillLight,
    onSurfaceVariant = TextRegular,

    error = Danger,
    onError = White,

    outline = BorderBase
)

@Composable
fun FryfrogHubTheme(
    darkTheme: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val configuration = LocalConfiguration.current
    val isTablet = configuration.screenWidthDp >= 600
    val dimens = if (isTablet) TabletDimens else PhoneDimens

    CompositionLocalProvider(LocalDimens provides dimens) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = getTypography(),
            content = content
        )
    }
}
