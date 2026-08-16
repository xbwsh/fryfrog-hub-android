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
        private const val KEY_THEME_MODE = "theme_mode"
        private const val KEY_ADULT_CONTENT_HIDDEN = "adult_content_hidden"
        private const val KEY_CAROUSEL_ENABLED = "carousel_enabled"
        private const val KEY_HOME_VIEW_MODE = "home_view_mode"
        private const val KEY_LIBRARY_VIEW_MODE = "library_view_mode"
        private const val KEY_SAVED_SERVERS = "saved_servers"
        private const val KEY_USERNAME = "last_username"

        private const val DEFAULT_SERVER_URL = ""
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

    // 主题模式：system=跟随系统 / light=浅色 / dark=深色（默认深色）
    var themeMode: String
        get() = prefs.getString(KEY_THEME_MODE, "dark") ?: "dark"
        set(value) = prefs.edit().putString(KEY_THEME_MODE, value).apply()

    var isAdultContentHidden: Boolean
        get() = prefs.getBoolean(KEY_ADULT_CONTENT_HIDDEN, true)
        set(value) = prefs.edit().putBoolean(KEY_ADULT_CONTENT_HIDDEN, value).apply()

    var isCarouselEnabled: Boolean
        get() = prefs.getBoolean(KEY_CAROUSEL_ENABLED, true)
        set(value) = prefs.edit().putBoolean(KEY_CAROUSEL_ENABLED, value).apply()

    var homeViewMode: String
        get() = prefs.getString(KEY_HOME_VIEW_MODE, "grouped") ?: "grouped"
        set(value) = prefs.edit().putString(KEY_HOME_VIEW_MODE, value).apply()

    // 上次登录的用户名（下次回填用）
    var username: String
        get() = prefs.getString(KEY_USERNAME, "") ?: ""
        set(value) = prefs.edit().putString(KEY_USERNAME, value).apply()

    // 每个媒体库单独记忆展示形式
    fun getLibraryViewMode(libraryId: Long): String =
        prefs.getString("${KEY_LIBRARY_VIEW_MODE}_$libraryId", "portrait") ?: "portrait"

    fun setLibraryViewMode(libraryId: Long, mode: String) {
        prefs.edit().putString("${KEY_LIBRARY_VIEW_MODE}_$libraryId", mode).apply()
    }

    data class SavedServer(
        val name: String,
        val url: String,
        val token: String,
        val username: String = ""
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

    fun saveServer(name: String, url: String, token: String, username: String = "") {
        val servers = getSavedServers().toMutableList()
        val existingIndex = servers.indexOfFirst { it.url == url }
        if (existingIndex >= 0) {
            servers[existingIndex] = SavedServer(name, url, token, username)
        } else {
            servers.add(SavedServer(name, url, token, username))
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
