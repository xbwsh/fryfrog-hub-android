package com.fryfrog.hub.ui.settings

import android.content.Intent
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.R
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.File

data class LogFileInfo(
    val name: String,
    val sizeKb: Long,
    val modifiedAt: String?
)

data class LogsUiState(
    val logs: List<LogFileInfo> = emptyList(),
    val isLoading: Boolean = false,
    val isDownloading: String? = null, // 正在下载的文件名
    val snackbarResId: Int? = null,
    val snackbarArg: String? = null
)

class LogsViewModel : ViewModel() {

    private val repository = MediaRepository()
    private val context = com.fryfrog.hub.FryfrogHubApplication.instance

    private val _uiState = MutableStateFlow(LogsUiState())
    val uiState: StateFlow<LogsUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val result = repository.listLogs()
            val logs = result.getOrNull().orEmpty().mapNotNull { item ->
                val name = (item["fileName"] as? String)
                    ?: (item["name"] as? String)
                    ?: return@mapNotNull null
                val sizeBytes = (item["size"] as? Number)?.toLong()
                    ?: (item["sizeBytes"] as? Number)?.toLong()
                    ?: 0L
                val modifiedAt = (item["modifiedAt"] as? String)
                    ?: (item["lastModified"] as? String)
                LogFileInfo(
                    name = name,
                    sizeKb = sizeBytes / 1024,
                    modifiedAt = modifiedAt
                )
            }
            _uiState.value = _uiState.value.copy(
                logs = logs,
                isLoading = false
            )
            result.exceptionOrNull()?.let { e ->
                _uiState.value = _uiState.value.copy(
                    snackbarResId = R.string.load_failed,
                    snackbarArg = e.message
                )
            }
        }
    }

    fun shareLog(fileName: String) {
        if (_uiState.value.isDownloading != null) return
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isDownloading = fileName)
            val file = File(context.cacheDir, "logs/$fileName")
            file.parentFile?.mkdirs()
            val result = repository.downloadLog(fileName, file.outputStream())
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(isDownloading = null)
                    launchShareIntent(file, fileName)
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        isDownloading = null,
                        snackbarResId = R.string.log_download_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    private fun launchShareIntent(file: File, fileName: String) {
        try {
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, fileName)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(intent, fileName))
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                snackbarResId = R.string.log_share_failed,
                snackbarArg = e.message
            )
        }
    }

    fun clearSnackbar() {
        _uiState.value = _uiState.value.copy(snackbarResId = null, snackbarArg = null)
    }
}
