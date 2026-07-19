package com.fryfrog.hub.ui.login

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.remote.FryfrogApi
import com.fryfrog.hub.util.PrefsManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

data class LoginUiState(
    val serverUrl: String = "http://192.168.31.127:20058",
    val password: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val isLoggedIn: Boolean = false
)

class LoginViewModel : ViewModel() {

    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun updateServerUrl(url: String) {
        _uiState.value = _uiState.value.copy(serverUrl = url)
    }

    fun updatePassword(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
    }

    fun login(onSuccess: () -> Unit) {
        val state = _uiState.value
        if (state.password.isBlank()) {
            _uiState.value = state.copy(error = "Password is required")
            return
        }

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val baseUrl = state.serverUrl.trimEnd('/')
                val baseUrlWithSlash = "$baseUrl/"

                // Create a temporary API client for login
                val loggingInterceptor = HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.BODY
                }

                val okHttpClient = OkHttpClient.Builder()
                    .addInterceptor(loggingInterceptor)
                    .connectTimeout(30, TimeUnit.SECONDS)
                    .readTimeout(30, TimeUnit.SECONDS)
                    .build()

                val tempRetrofit = Retrofit.Builder()
                    .baseUrl(baseUrlWithSlash)
                    .client(okHttpClient)
                    .addConverterFactory(GsonConverterFactory.create())
                    .build()

                val tempApi = tempRetrofit.create(FryfrogApi::class.java)

                val response = tempApi.login(mapOf("password" to state.password))

                if (response.success) {
                    val token = response.token ?: ""

                    // Save credentials
                    val context = com.fryfrog.hub.FryfrogHubApplication.instance
                    val prefs = PrefsManager(context)
                    prefs.saveLogin(baseUrl, token)

                    // Update API client with token
                    ApiClient.updateServer(baseUrl, token)

                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true
                    )
                    onSuccess()
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = response.message ?: "Login failed"
                    )
                }
            } catch (e: Exception) {
                android.util.Log.e("LoginScreen", "Login failed", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Connection failed: ${e.message}"
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    viewModel: LoginViewModel = androidx.lifecycle.viewmodel.compose.viewModel(),
    onLoginSuccess: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsState()
    var passwordVisible by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Fryfrog Hub") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Welcome",
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.padding(bottom = 32.dp)
            )

            // Server URL
            OutlinedTextField(
                value = uiState.serverUrl,
                onValueChange = { viewModel.updateServerUrl(it) },
                label = { Text("Server Address") },
                placeholder = { Text("http://192.168.31.127:20058") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Password
            OutlinedTextField(
                value = uiState.password,
                onValueChange = { viewModel.updatePassword(it) },
                label = { Text("Password") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                trailingIcon = {
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                            contentDescription = if (passwordVisible) "Hide password" else "Show password"
                        )
                    }
                }
            )

            // Error message
            if (uiState.error != null) {
                Text(
                    text = uiState.error ?: "",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Login button
            Button(
                onClick = { viewModel.login(onLoginSuccess) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !uiState.isLoading && uiState.password.isNotBlank()
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                } else {
                    Text("Login")
                }
            }
        }
    }
}
