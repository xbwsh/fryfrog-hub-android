package com.fryfrog.hub.data.remote

import android.content.Context
import com.fryfrog.hub.util.PrefsManager
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

object ApiClient {

    private var retrofit: Retrofit? = null
    private var api: FryfrogApi? = null
    private var currentServerUrl: String? = null

    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BODY
    }

    fun init(context: Context) {
        val prefs = PrefsManager(context)
        createRetrofit(prefs.serverUrl, prefs.authToken)
    }

    fun updateServer(serverUrl: String, token: String?) {
        createRetrofit(serverUrl, token)
    }

    private fun createRetrofit(serverUrl: String, token: String?) {
        if (serverUrl == currentServerUrl && api != null) return

        val authInterceptor = Interceptor { chain ->
            val request = chain.request().newBuilder().apply {
                addHeader("Content-Type", "application/json")
                token?.let {
                    addHeader("Authorization", "Bearer $it")
                }
            }.build()
            chain.proceed(request)
        }

        val okHttpClient = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .addInterceptor(loggingInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .build()

        retrofit = Retrofit.Builder()
            .baseUrl(serverUrl)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()

        api = retrofit!!.create(FryfrogApi::class.java)
        currentServerUrl = serverUrl
    }

    fun getApi(): FryfrogApi {
        if (api == null) {
            throw IllegalStateException("ApiClient not initialized. Call init(context) first.")
        }
        return api!!
    }

    fun getBaseUrl(): String {
        return currentServerUrl ?: throw IllegalStateException("ApiClient not initialized")
    }
}
