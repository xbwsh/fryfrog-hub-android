package com.fryfrog.hub

import android.app.Application
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.util.PrefsManager

class FryfrogHubApplication : Application() {

    companion object {
        lateinit var instance: FryfrogHubApplication
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Initialize API client with saved credentials
        val prefs = PrefsManager(this)
        if (prefs.isLoggedIn) {
            ApiClient.init(this)
        }
    }
}
