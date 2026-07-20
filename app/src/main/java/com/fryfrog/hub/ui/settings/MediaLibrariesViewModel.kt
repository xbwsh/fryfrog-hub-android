package com.fryfrog.hub.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class DirectoryItem(
    val name: String,
    val path: String,
    val isDirectory: Boolean
)

data class MediaLibrariesUiState(
    val libraries: List<MediaLibrary> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val scanMessage: String? = null,
    val createSuccess: Boolean = false,
    val directories: List<DirectoryItem> = emptyList(),
    val currentPath: String? = null,
    val isLoadingDirectories: Boolean = false
)

class MediaLibrariesViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(MediaLibrariesUiState())
    val uiState: StateFlow<MediaLibrariesUiState> = _uiState.asStateFlow()

    init {
        loadLibraries()
    }

    fun loadLibraries() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val api = ApiClient.getApi()
                val response = api.getMediaLibraries()
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        libraries = response.data ?: emptyList(),
                        isLoading = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to load libraries",
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    isLoading = false
                )
            }
        }
    }

    fun toggleLibrary(library: MediaLibrary) {
        viewModelScope.launch {
            try {
                val api = ApiClient.getApi()
                val response = api.toggleMediaLibrary(library.id)
                if (response.success) {
                    loadLibraries()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to toggle library"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    fun scanLibrary(library: MediaLibrary) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(scanMessage = "Scanning ${library.name}...")
            try {
                val api = ApiClient.getApi()
                val response = api.scanMediaLibrary(library.id)
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        scanMessage = "Scan started for ${library.name}"
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to scan library"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    fun scanAllLibraries() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(scanMessage = "Scanning all libraries...")
            try {
                val api = ApiClient.getApi()
                val response = api.scanAllMediaLibraries()
                if (response.success) {
                    _uiState.value = _uiState.value.copy(
                        scanMessage = "Scan started for all libraries"
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to scan libraries"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    fun deleteLibrary(library: MediaLibrary) {
        viewModelScope.launch {
            try {
                val api = ApiClient.getApi()
                val response = api.deleteMediaLibrary(library.id)
                if (response.success) {
                    loadLibraries()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to delete library"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    fun clearScanMessage() {
        _uiState.value = _uiState.value.copy(scanMessage = null)
    }

    fun clearCreateSuccess() {
        _uiState.value = _uiState.value.copy(createSuccess = false)
    }

    fun browseDirectory(path: String? = null) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoadingDirectories = true)
            try {
                val api = ApiClient.getApi()
                val response = api.browseDirectory(path)
                if (response.success) {
                    val items = response.data?.map { item ->
                        DirectoryItem(
                            name = item["name"] as? String ?: "",
                            path = item["path"] as? String ?: "",
                            isDirectory = item["isDirectory"] as? Boolean ?: true
                        )
                    } ?: emptyList()
                    _uiState.value = _uiState.value.copy(
                        directories = items,
                        currentPath = path,
                        isLoadingDirectories = false
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to browse directory",
                        isLoadingDirectories = false
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    isLoadingDirectories = false
                )
            }
        }
    }

    fun createLibrary(
        name: String,
        path: String,
        type: String,
        subType: String? = null,
        description: String? = null
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val api = ApiClient.getApi()
                val library = MediaLibrary(
                    id = 0,
                    name = name,
                    path = path,
                    type = type,
                    subType = subType,
                    enabled = true,
                    sortOrder = null,
                    description = description,
                    createdAt = null,
                    updatedAt = null
                )
                val response = api.createMediaLibrary(library)
                if (response.success) {
                    _uiState.value = _uiState.value.copy(createSuccess = true)
                    loadLibraries()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to create library",
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    isLoading = false
                )
            }
        }
    }
}