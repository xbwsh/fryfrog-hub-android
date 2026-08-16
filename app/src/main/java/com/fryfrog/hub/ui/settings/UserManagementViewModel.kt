package com.fryfrog.hub.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.data.model.UserCreateRequest
import com.fryfrog.hub.data.model.UserDTO
import com.fryfrog.hub.data.model.UserUpdateRequest
import com.fryfrog.hub.data.repository.MediaRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class UserManagementUiState(
    val users: List<UserDTO> = emptyList(),
    val libraries: List<MediaLibrary> = emptyList(),
    val isLoading: Boolean = false,
    val snackbarResId: Int? = null,
    val snackbarArg: String? = null
)

class UserManagementViewModel : ViewModel() {

    private val repository = MediaRepository()

    private val _uiState = MutableStateFlow(UserManagementUiState())
    val uiState: StateFlow<UserManagementUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            val usersResult = repository.getUsers()
            val libsResult = repository.getMediaLibraries()
            _uiState.value = _uiState.value.copy(
                users = usersResult.getOrNull().orEmpty(),
                libraries = libsResult.getOrNull().orEmpty(),
                isLoading = false
            )
            val error = usersResult.exceptionOrNull()?.message
                ?: libsResult.exceptionOrNull()?.message
            if (error != null) {
                _uiState.value = _uiState.value.copy(
                    snackbarResId = R.string.load_failed,
                    snackbarArg = error
                )
            }
        }
    }

    fun createUser(username: String, password: String, nickname: String?, role: String?, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val result = repository.createUser(
                UserCreateRequest(
                    username = username,
                    password = password,
                    nickname = nickname,
                    role = role
                )
            )
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(snackbarResId = R.string.user_created)
                    load()
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarResId = R.string.save_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    fun updateUser(id: Long, nickname: String?, role: String?, enabled: Boolean?, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val result = repository.updateUser(
                id,
                UserUpdateRequest(nickname = nickname, role = role, enabled = enabled)
            )
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(snackbarResId = R.string.user_updated)
                    load()
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarResId = R.string.save_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    fun deleteUser(id: Long, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val result = repository.deleteUser(id)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(snackbarResId = R.string.user_deleted)
                    load()
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarResId = R.string.save_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    fun resetPassword(id: Long, newPassword: String, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val result = repository.resetUserPassword(id, newPassword)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(snackbarResId = R.string.password_reset_done)
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarResId = R.string.save_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    // ===== 媒体库权限 =====

    suspend fun getUserLibraries(id: Long): Set<Long> =
        repository.getUserLibraries(id).getOrNull().orEmpty().toSet()

    fun setUserLibraries(id: Long, libraryIds: Set<Long>, onSuccess: () -> Unit = {}) {
        viewModelScope.launch {
            val result = repository.setUserLibraries(id, libraryIds.toList())
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(snackbarResId = R.string.libraries_assigned)
                    onSuccess()
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        snackbarResId = R.string.save_failed,
                        snackbarArg = e.message
                    )
                }
            )
        }
    }

    fun clearSnackbar() {
        _uiState.value = _uiState.value.copy(snackbarResId = null, snackbarArg = null)
    }
}
