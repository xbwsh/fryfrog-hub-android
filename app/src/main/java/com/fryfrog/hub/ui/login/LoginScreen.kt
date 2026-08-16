package com.fryfrog.hub.ui.login

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll

import androidx.compose.foundation.shape.RoundedCornerShape

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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
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
    val protocol: String = "http",
    val serverHost: String = "",
    val serverPort: String = "20058",
    val username: String = "",
    val password: String = "",
    val isLoading: Boolean = false,
    val errorResId: Int? = null,
    val errorMessage: String? = null,
    val isLoggedIn: Boolean = false,
    val savedServers: List<PrefsManager.SavedServer> = emptyList(),
    val selectedServerUrl: String? = null
) {
    val serverUrl: String
        get() = if (serverPort.isNotBlank()) {
            "$protocol://$serverHost:$serverPort"
        } else {
            "$protocol://$serverHost"
        }
}

class LoginViewModel : ViewModel() {

    private val _uiState: MutableStateFlow<LoginUiState>

    init {
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        val prefs = PrefsManager(context)
        val servers = prefs.getSavedServers()
        val lastUrl = prefs.serverUrl

        // 解析上次保存的URL
        val parsed = parseServerUrl(lastUrl)

        _uiState = MutableStateFlow(
            LoginUiState(
                protocol = parsed.protocol,
                serverHost = parsed.host,
                serverPort = parsed.port,
                username = prefs.username,
                savedServers = servers,
                selectedServerUrl = servers.firstOrNull { it.url == lastUrl }?.url
            )
        )
    }

    private data class ParsedUrl(
        val protocol: String,
        val host: String,
        val port: String
    )

    private fun parseServerUrl(url: String): ParsedUrl {
        return try {
            val uri = java.net.URI(url)
            val protocol = uri.scheme ?: "http"
            val host = uri.host ?: ""
            val port = if (uri.port > 0) uri.port.toString() else "20058"
            ParsedUrl(protocol, host, port)
        } catch (e: Exception) {
            ParsedUrl("http", "", "20058")
        }
    }

    val uiState: StateFlow<LoginUiState> = _uiState.asStateFlow()

    fun updateUsername(username: String) {
        _uiState.value = _uiState.value.copy(username = username)
    }

    fun updateProtocol(protocol: String) {
        _uiState.value = _uiState.value.copy(
            protocol = protocol,
            selectedServerUrl = null
        )
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        PrefsManager(context).serverUrl = _uiState.value.serverUrl
    }

    fun updateServerHost(host: String) {
        _uiState.value = _uiState.value.copy(
            serverHost = host,
            selectedServerUrl = null
        )
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        PrefsManager(context).serverUrl = _uiState.value.serverUrl
    }

    fun updateServerPort(port: String) {
        _uiState.value = _uiState.value.copy(
            serverPort = port,
            selectedServerUrl = null
        )
        val context = com.fryfrog.hub.FryfrogHubApplication.instance
        PrefsManager(context).serverUrl = _uiState.value.serverUrl
    }

    fun updatePassword(password: String) {
        _uiState.value = _uiState.value.copy(password = password)
    }

    fun selectServer(server: PrefsManager.SavedServer) {
        val parsed = parseServerUrl(server.url)
        _uiState.value = _uiState.value.copy(
            protocol = parsed.protocol,
            serverHost = parsed.host,
            serverPort = parsed.port,
            username = server.username,
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
            protocol = "http",
            serverHost = "",
            serverPort = "20058",
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
                // 多用户登录：不传 username 时后端按 admin 兼容旧单密码登录
                val body = mutableMapOf<String, String>("password" to state.password)
                if (state.username.isNotBlank()) body["username"] = state.username
                val response = tempApi.login(body)

                if (response.success) {
                    val token = response.effectiveToken ?: ""

                    val context = com.fryfrog.hub.FryfrogHubApplication.instance
                    val prefs = PrefsManager(context)
                    prefs.saveLogin(baseUrl, token)
                    // 保存用户名到本地（下次登录回填）
                    prefs.username = state.username

                    val serverName = extractHostName(baseUrl)
                    prefs.saveServer(serverName, baseUrl, token, state.username)

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
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .imePadding()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(Dimens.spacingXl),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
            Spacer(modifier = Modifier.height(60.dp))

            Text(
                text = stringResource(R.string.welcome),
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.padding(bottom = Dimens.spacingXxl)
            )

            // Saved servers chips（无边框，选中态用背景色区分）
            if (uiState.savedServers.isNotEmpty()) {
                LazyRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    items(uiState.savedServers, key = { it.url }) { server ->
                        val isSelected = uiState.selectedServerUrl == server.url
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(Dimens.radiusFull))
                                .background(
                                    if (isSelected) Primary.copy(alpha = 0.15f)
                                    else MaterialTheme.colorScheme.surfaceVariant
                                )
                                .clickable { viewModel.selectServer(server) }
                                .padding(start = Dimens.spacingMd, end = Dimens.spacingXs, top = Dimens.spacingXs, bottom = Dimens.spacingXs)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = server.name,
                                    color = if (isSelected) Primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                    style = MaterialTheme.typography.labelMedium,
                                    maxLines = 1
                                )
                                IconButton(
                                    onClick = { viewModel.removeServer(server) },
                                    modifier = Modifier.size(Dimens.chipIconSize + 10.dp)
                                ) {
                                    Icon(
                                        Icons.Default.Close,
                                        contentDescription = stringResource(R.string.delete),
                                        tint = if (isSelected) Primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(Dimens.chipCloseIconSize)
                                    )
                                }
                            }
                        }
                    }
                    item {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(Dimens.radiusFull))
                                .background(MaterialTheme.colorScheme.surfaceVariant)
                                .clickable { viewModel.addNewServer() }
                                .padding(horizontal = Dimens.spacingMd, vertical = Dimens.spacingXs)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Default.Add,
                                    contentDescription = stringResource(R.string.add),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.size(Dimens.chipIconSize)
                                )
                                Spacer(Modifier.width(Dimens.spacingXs))
                                Text(
                                    text = stringResource(R.string.add),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(Dimens.spacingLg))

            // 服务器地址卡片
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(Dimens.radiusLg),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            ) {
                Column(
                    modifier = Modifier.padding(Dimens.spacingLg)
                ) {
                    Text(
                        text = "服务器连接",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(bottom = Dimens.spacingMd)
                    )

                    // 协议选择
                    Text(
                        text = "协议",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = Dimens.spacingSm)
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                    ) {
                        listOf("http", "https").forEach { protocol ->
                            val isSelected = uiState.protocol == protocol
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(Dimens.radiusMd))
                                    .background(
                                        if (isSelected) Primary
                                        else MaterialTheme.colorScheme.surfaceVariant
                                    )
                                    .clickable { viewModel.updateProtocol(protocol) }
                                    .padding(vertical = Dimens.spacingSm),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = protocol.uppercase(),
                                    style = MaterialTheme.typography.labelMedium,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary
                                    else MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(Dimens.spacingMd))

                    // 服务器地址（无边框输入框）
                    TextField(
                        value = uiState.serverHost,
                        onValueChange = { viewModel.updateServerHost(it) },
                        label = { Text(stringResource(R.string.server_address)) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                        shape = RoundedCornerShape(Dimens.radiusMd),
                        colors = loginFieldColors()
                    )

                    Spacer(modifier = Modifier.height(Dimens.spacingMd))

                    // 端口（无边框输入框）
                    TextField(
                        value = uiState.serverPort,
                        onValueChange = { viewModel.updateServerPort(it) },
                        label = { Text("端口") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        shape = RoundedCornerShape(Dimens.radiusMd),
                        colors = loginFieldColors()
                    )

                    Spacer(modifier = Modifier.height(Dimens.spacingMd))

                    // 用户名（多用户登录，留空则按 admin 兼容旧单密码模式）
                    TextField(
                        value = uiState.username,
                        onValueChange = { viewModel.updateUsername(it) },
                        label = { Text(stringResource(R.string.username)) },
                        supportingText = { Text(stringResource(R.string.username_hint)) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                        shape = RoundedCornerShape(Dimens.radiusMd),
                        colors = loginFieldColors()
                    )

                    Spacer(modifier = Modifier.height(Dimens.spacingMd))

                    // 密码（无边框输入框）
                    TextField(
                        value = uiState.password,
                        onValueChange = { viewModel.updatePassword(it) },
                        label = { Text(stringResource(R.string.password)) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                        shape = RoundedCornerShape(Dimens.radiusMd),
                        colors = loginFieldColors(),
                        trailingIcon = {
                            IconButton(onClick = { passwordVisible = !passwordVisible }) {
                                Icon(
                                    imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                                    contentDescription = stringResource(if (passwordVisible) R.string.hide_password else R.string.show_password)
                                )
                            }
                        }
                    )
                }
            }

            if (errorText != null) {
                Spacer(modifier = Modifier.height(Dimens.spacingSm))
                Text(
                    text = errorText,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium
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

            Spacer(modifier = Modifier.height(60.dp))
        }
        }
    }
}

// 登录页输入框样式：无边框、浅灰圆角底 + 透明指示线（现代简洁风）
@Composable
private fun loginFieldColors(): TextFieldColors = TextFieldDefaults.colors(
    focusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f),
    disabledContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
    focusedIndicatorColor = Color.Transparent,
    unfocusedIndicatorColor = Color.Transparent,
    disabledIndicatorColor = Color.Transparent,
    focusedLabelColor = Primary,
    cursorColor = Primary
)
