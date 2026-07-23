package com.fryfrog.hub.ui.login

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.R
import com.fryfrog.hub.data.remote.ApiClient
import com.fryfrog.hub.data.remote.FryfrogApi
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary
import com.fryfrog.hub.util.PrefsManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.net.URI
import java.util.concurrent.TimeUnit

data class LoginUiState(
    val serverUrl: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorResId: Int? = null,
    val errorMessage: String? = null,
    val isLoggedIn: Boolean = false,
    val savedServers: List<PrefsManager.SavedServer> = emptyList(),
    val selectedServerUrl: String? = null
)

class LoginViewModel : ViewModel() {

    private val _uiState: MutableStateFlow<LoginUiState>

    init {
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        val prefs = PrefsManager(context)
        val servers = prefs.getSavedServers()
        val lastUrl = prefs.serverUrl
        _uiState = MutableStateFlow(
            LoginUiState(
                serverUrl = lastUrl,
                savedServers = servers,
                selectedServerUrl = servers.firstOrNull { it.url == lastUrl }?.url
            )
        )
    }

    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun updateServerUrl(url: String) {
        _uiState.value = _uiState.value.copy(
            serverUrl = url,
            selectedServerUrl = null
        )
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        PrefsManager(context).serverUrl = url
    }

    fun updatePassword(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
    }

    fun selectServer(server: PrefsManager.SavedServer) {
        _uiState.value = _uiState.value.copy(
            serverUrl = server.url,
            selectedServerUrl = server.url
        )
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        PrefsManager(context).serverUrl = server.url
    }

    fun removeServer(server: PrefsManager.SavedServer) {
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        val prefs = PrefsManager(context)
        prefs.removeServer(server.url)
        val servers = prefs.getSavedServers()
        val state = _uiState.value
        _uiState.value = state.copy(
            savedServers = servers,
            selectedServerUrl = if (state.selectedServerUrl == server.url) null else state.selectedServerUrl
        )
    }

    fun addNewServer() {
        _uiState.value = _uiState.value.copy(
            serverUrl = "",
            selectedServerUrl = null,
            password = ""
        )
    }

    fun login(onSuccess: () -> Unit) {
        val state = _uiState.value
        if (state.password.isBlank()) {
            _uiState.value = state.copy(errorResId = R.string.password_required)
            return
        }

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, errorResId = null, errorMessage = null)

            try {
                val baseUrl = state.serverUrl.trimEnd('/')
                val baseUrlWithSlash = "$baseUrl/"

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

                    val context = com.fryfrog.hub.FryfrogHubApplication.instance
                    val prefs = PrefsManager(context)
                    prefs.saveLogin(baseUrl, token)

                    val serverName = extractHostName(baseUrl)
                    prefs.saveServer(serverName, baseUrl, token)

                    ApiClient.updateServer(baseUrl, token)

                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isLoggedIn = true,
                        savedServers = prefs.getSavedServers(),
                        selectedServerUrl = baseUrl
                    )
                    onSuccess()
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = response.message
                    )
                }
            } catch (e: Exception) {
                android.util.Log.e("LoginScreen", "Login failed", e)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = e.message
                )
            }
        }
    }

    private fun extractHostName(url: String): String {
        return try {
            val uri = URI(url)
            uri.host ?: url
        } catch (e: Exception) {
            url
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

    val errorText = when {
        uiState.errorResId != null -> stringResource(uiState.errorResId!!)
        uiState.errorMessage != null -> stringResource(R.string.connection_failed, uiState.errorMessage ?: "")
        else -> null
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name)) },
                modifier = Modifier.statusBarsPadding(),
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .imePadding()
                .padding(Dimens.spacingXl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = stringResource(R.string.welcome),
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.padding(bottom = Dimens.spacingXxl)
            )

            // Saved servers chips
            if (uiState.savedServers.isNotEmpty()) {
                LazyRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    items(uiState.savedServers, key = { it.url }) { server ->
                        val isSelected = uiState.selectedServerUrl == server.url
                        InputChip(
                            selected = isSelected,
                            onClick = { viewModel.selectServer(server) },
                            label = { Text(server.name, maxLines = 1) },
                            trailingIcon = {
                                IconButton(
                                    onClick = { viewModel.removeServer(server) },
                                    modifier = Modifier.size(Dimens.chipIconSize)
                                ) {
                                    Icon(
                                        Icons.Default.Close,
                                        contentDescription = stringResource(R.string.delete),
                                        modifier = Modifier.size(Dimens.chipCloseIconSize)
                                    )
                                }
                            },
                            colors = InputChipDefaults.inputChipColors(
                                selectedContainerColor = Primary.copy(alpha = 0.15f),
                                selectedLabelColor = Primary,
                                selectedLeadingIconColor = Primary,
                                selectedTrailingIconColor = Primary
                            )
                        )
                    }
                    item {
                        InputChip(
                            selected = false,
                            onClick = { viewModel.addNewServer() },
                            label = { Text(stringResource(R.string.add)) },
                            leadingIcon = {
                                Icon(
                                    Icons.Default.Add,
                                    contentDescription = stringResource(R.string.add),
                                    modifier = Modifier.size(Dimens.chipIconSize)
                                )
                            }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(Dimens.spacingLg))
            }

            OutlinedTextField(
                value = uiState.serverUrl,
                onValueChange = { viewModel.updateServerUrl(it) },
                label = { Text(stringResource(R.string.server_address)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
            )

            Spacer(modifier = Modifier.height(Dimens.spacingLg))

            OutlinedTextField(
                value = uiState.password,
                onValueChange = { viewModel.updatePassword(it) },
                label = { Text(stringResource(R.string.password)) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                trailingIcon = {
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                            contentDescription = stringResource(if (passwordVisible) R.string.hide_password else R.string.show_password)
                        )
                    }
                }
            )

            if (errorText != null) {
                Text(
                    text = errorText,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(top = Dimens.spacingSm)
                )
            }

            Spacer(modifier = Modifier.height(Dimens.spacingXl))

            Button(
                onClick = { viewModel.login(onLoginSuccess) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !uiState.isLoading && uiState.password.isNotBlank() && uiState.serverUrl.isNotBlank()
            ) {
                if (uiState.isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(Dimens.iconSize),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                } else {
                    Text(stringResource(R.string.login))
                }
            }
        }
    }
}
