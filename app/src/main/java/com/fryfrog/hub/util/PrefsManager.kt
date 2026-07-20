package com.fryfrog.hub.util

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

class PrefsManager(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("fryfrog_hub_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    companion object {
        private const val KEY_SERVER_URL = "server_url"
        private const val KEY_AUTH_TOKEN = "auth_token"
        private const val KEY_IS_LOGGED_IN = "is_logged_in"
        private const val KEY_DARK_THEME = "dark_theme"
        private const val KEY_SAVED_SERVERS = "saved_servers"

        private const val DEFAULT_SERVER_URL = "http://192.168.31.127:20058"
    }

    var serverUrl: String
        get() = prefs.getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
        set(value) = prefs.edit().putString(KEY_SERVER_URL, value).apply()

    var authToken: String?
        get() = prefs.getString(KEY_AUTH_TOKEN, null)
        set(value) = prefs.edit().putString(KEY_AUTH_TOKEN, value).apply()

    var isLoggedIn: Boolean
        get() = prefs.getBoolean(KEY_IS_LOGGED_IN, false)
        set(value) = prefs.edit().putBoolean(KEY_IS_LOGGED_IN, value).apply()

    var isDarkTheme: Boolean
        get() = prefs.getBoolean(KEY_DARK_THEME, true)
        set(value) = prefs.edit().putBoolean(KEY_DARK_THEME, value).apply()

    data class SavedServer(
        val name: String,
        val url: String,
        val token: String
    )

    fun getSavedServers(): List<SavedServer> {
        val json = prefs.getString(KEY_SAVED_SERVERS, null) ?: return emptyList()
        return try {
            val type = object : TypeToken<List<SavedServer>>() {}.type
            gson.fromJson(json, type)
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveServer(name: String, url: String, token: String) {
        val servers = getSavedServers().toMutableList()
        // Update if same URL exists, otherwise add
        val existingIndex = servers.indexOfFirst { it.url == url }
        if (existingIndex >= 0) {
            servers[existingIndex] = SavedServer(name, url, token)
        } else {
            servers.add(SavedServer(name, url, token))
        }
        prefs.edit().putString(KEY_SAVED_SERVERS, gson.toJson(servers)).apply()
    }

    fun removeServer(url: String) {
        val servers = getSavedServers().filter { it.url != url }
        prefs.edit().putString(KEY_SAVED_SERVERS, gson.toJson(servers)).apply()
    }

    fun switchToServer(server: SavedServer) {
        serverUrl = server.url
        authToken = server.token
        isLoggedIn = true
    }

    fun saveLogin(serverUrl: String, token: String) {
        this.serverUrl = serverUrl
        this.authToken = token
        this.isLoggedIn = true
    }

    fun clearLogin() {
        authToken = null
        isLoggedIn = false
    }
}
