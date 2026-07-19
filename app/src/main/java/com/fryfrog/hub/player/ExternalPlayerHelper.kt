package com.fryfrog.hub.player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.Toast
import com.fryfrog.hub.data.remote.ApiClient

object ExternalPlayerHelper {

    private const val MPV_PACKAGE = "is.xyz.mpv"

    fun launchMpv(context: Context, videoId: Long, title: String) {
        val streamUrl = "${ApiClient.getBaseUrl()}/api/v1/video/$videoId/stream"

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(Uri.parse(streamUrl), "video/*")
            setPackage(MPV_PACKAGE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e("ExternalPlayer", "Failed to launch mpv", e)
            Toast.makeText(
                context,
                "mpv-android 未安装，请先安装",
                Toast.LENGTH_LONG
            ).show()
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
