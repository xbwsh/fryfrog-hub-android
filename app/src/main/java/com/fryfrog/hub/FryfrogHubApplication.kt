package com.fryfrog.hub

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.service.MemoryWatchdogReceiver
import com.fryfrog.hub.util.PrefsManager
import okhttp3.OkHttpClient
import okhttp3.Request

class FryfrogHubApplication : Application(), ImageLoaderFactory {

    companion object {
        lateinit var instance: FryfrogHubApplication
            private set
    }

    private val memoryWatchdog = MemoryWatchdogReceiver()

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Initialize API client with saved credentials
        val prefs = PrefsManager(this)
        if (prefs.isLoggedIn) {
            ApiClient.init(this)
        }

        // 初始化小米澎湃OS公平运行内存机制适配
        memoryWatchdog.initialize(this)
    }

    override fun newImageLoader(): ImageLoader {
        val prefs = PrefsManager(this)
        val token = prefs.authToken

        val okHttpClient = OkHttpClient.Builder()
            .addInterceptor { chain ->
                val request = chain.request().newBuilder().apply {
                    token?.let {
                        addHeader("Authorization", "Bearer $it")
                    }
                }.build()
                chain.proceed(request)
            }
            .build()

        return ImageLoader.Builder(this)
            .okHttpClient(okHttpClient)
            .build()
    }

    override fun onTerminate() {
        super.onTerminate()
        memoryWatchdog.destroy()
    }
}
