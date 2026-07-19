package com.fryfrog.hub.ui.player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.util.PrefsManager

object ExternalPlayerHelper {

    private const val MPV_PACKAGE = "is.xyz.mpv"

    fun launchMpv(context: Context, videoId: Long, title: String) {
        val streamUrl = "${ApiClient.getBaseUrl()}/api/v1/video/$videoId/stream"

        // Check if mpv-android is installed
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(streamUrl), "video/*")
            setPackage(MPV_PACKAGE)
            putExtra("title", title)
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Toast.makeText(
                context,
                "mpv-android 未安装，请先安装 mpv-android 应用",
                Toast.LENGTH_LONG
            ).show()

            // Open Play Store or GitHub to download mpv-android
            val marketIntent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("https://github.com/mpv-android/mpv-android/releases")
            }
            try {
                context.startActivity(marketIntent)
            } catch (_: Exception) {
                // Ignore if no browser available
            }
        }
    }

    fun isMpvInstalled(context: Context): Boolean {
        return try {
            context.packageManager.getPackageInfo(MPV_PACKAGE, 0)
            true
        } catch (e: Exception) {
            false
        }
    }
}
