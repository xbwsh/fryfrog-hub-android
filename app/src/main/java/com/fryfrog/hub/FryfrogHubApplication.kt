package com.fryfrog.hub

import android.app.Application
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.service.MemoryWatchdogReceiver
import com.fryfrog.hub.util.PrefsManager

class FryfrogHubApplication : Application() {

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

    override fun onTerminate() {
        super.onTerminate()
        memoryWatchdog.destroy()
    }
}
