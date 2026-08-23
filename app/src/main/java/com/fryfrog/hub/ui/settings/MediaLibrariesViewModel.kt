package com.fryfrog.hub.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.data.model.PipelineProgress
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

private const val SCAN_POLLING_INTERVAL_MS = 1500L
private const val SCAN_POLLING_TIMEOUT_MS = 10 * 60 * 1000L

data class DirectoryItem(
    val name: String,
    val path: String,
    val isDirectory: Boolean
)

data class MediaLibrariesUiState(
    val libraries: List<MediaLibrary> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val noticeResId: Int? = null,
    val noticeArg: String? = null,
    val scanningLibraryIds: Set<Long> = emptySet(),
    val pipelineProgress: Map<Long, PipelineProgress> = emptyMap(),
    val createSuccess: Boolean = false,
    val isSorting: Boolean = false,
    val sortingLibraries: List<MediaLibrary> = emptyList(),
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

    // ===== 手动排序 =====

    fun startSorting() {
        _uiState.value = _uiState.value.copy(
            isSorting = true,
            sortingLibraries = _uiState.value.libraries
        )
    }

    fun moveLibrary(index: Int, direction: Int) {
        val current = _uiState.value.sortingLibraries.toMutableList()
        val target = index + direction
        if (target < 0 || target >= current.size) return
        val tmp = current[index]
        current[index] = current[target]
        current[target] = tmp
        _uiState.value = _uiState.value.copy(sortingLibraries = current)
    }

    fun stopSorting() {
        val ordered = _uiState.value.sortingLibraries
        if (ordered.isEmpty()) {
            _uiState.value = _uiState.value.copy(isSorting = false)
            return
        }
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSorting = false, isLoading = true)
            try {
                val api = ApiClient.getApi()
                ordered.forEachIndexed { index, library ->
                    if (library.sortOrder != index) {
                        api.updateMediaLibrary(library.id, library.copy(sortOrder = index))
                    }
                }
                loadLibraries()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    isLoading = false
                )
            }
        }
    }

    fun scanLibrary(library: MediaLibrary) {
        viewModelScope.launch {
            val newIds = _uiState.value.scanningLibraryIds + library.id
            _uiState.value = _uiState.value.copy(scanningLibraryIds = newIds)
            try {
                val api = ApiClient.getApi()
                val response = if (library.type == "MUSIC") {
                    // MUSIC 库走音乐扫描接口
                    api.scanMusicLibraries(library.id)
                } else {
                    api.scanMediaLibrary(library.id)
                }
                if (response.success) {
                    startScanProgressPolling()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to scan library",
                        scanningLibraryIds = newIds - library.id
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    scanningLibraryIds = newIds - library.id
                )
            }
        }
    }

    /** 启用/禁用资源库（PUT /media-libraries/{id}/toggle），乐观更新 */
    fun toggleLibrary(library: MediaLibrary) {
        val newEnabled = !library.enabled
        // 乐观更新列表
        _uiState.value = _uiState.value.copy(
            libraries = _uiState.value.libraries.map {
                if (it.id == library.id) it.copy(enabled = newEnabled) else it
            }
        )
        viewModelScope.launch {
            try {
                val api = ApiClient.getApi()
                val response = api.toggleMediaLibrary(library.id)
                if (!response.success) {
                    // 回滚
                    _uiState.value = _uiState.value.copy(
                        libraries = _uiState.value.libraries.map {
                            if (it.id == library.id) it.copy(enabled = library.enabled) else it
                        },
                        error = response.message ?: "Failed to toggle library"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    libraries = _uiState.value.libraries.map {
                        if (it.id == library.id) it.copy(enabled = library.enabled) else it
                    },
                    error = e.message ?: "Unknown error"
                )
            }
        }
    }

    private var pipelineProgressJob: Job? = null

    /**
     * 扫描进度轮询：
     * - VIDEO 库走 pipeline-progress（聚合 scan/scrape/actors/assets 阶段）
     * - MUSIC 库走 media-libraries/scan/progress（音乐无刮削流水线）
     */
    private fun startScanProgressPolling() {
        pipelineProgressJob?.cancel()
        val startedAt = System.currentTimeMillis()
        val typeById = _uiState.value.libraries.associate { it.id to it.type }
        pipelineProgressJob = viewModelScope.launch {
            while (true) {
                val scanningIds = _uiState.value.scanningLibraryIds
                if (scanningIds.isEmpty()) break

                // 兜底：轮询超过 10 分钟强制停止，避免死循环
                if (System.currentTimeMillis() - startedAt > SCAN_POLLING_TIMEOUT_MS) {
                    _uiState.value = _uiState.value.copy(
                        scanningLibraryIds = emptySet(),
                        pipelineProgress = emptyMap()
                    )
                    break
                }

                try {
                    val api = ApiClient.getApi()
                    val updated = mutableMapOf<Long, PipelineProgress>()
                    val finished = mutableSetOf<Long>()
                    for (id in scanningIds) {
                        if (typeById[id] == "MUSIC") {
                            // MUSIC 库：走 scan/progress 查询
                            val progress = api.getScanProgress(id).data?.firstOrNull()
                            if (progress != null) {
                                updated[id] = PipelineProgress(
                                    libraryId = id,
                                    stage = progress.stage,
                                    running = progress.running,
                                    percent = progress.percent,
                                    currentItem = progress.currentItem,
                                    scrapingEnabled = false,
                                    scanPercent = progress.percent,
                                    scrapePercent = 0.0
                                )
                                if (!progress.running || progress.percent >= 100.0) {
                                    finished.add(id)
                                }
                            } else {
                                // 无进度数据视为已结束
                                finished.add(id)
                            }
                        } else {
                            val response = api.getPipelineProgress(id)
                            if (response.success && response.data != null) {
                                val progress = response.data
                                updated[id] = progress
                                // 结束条件：running=false 且 stage=done，或 percent 已达 100
                                if ((!progress.running && progress.stage == "done") || progress.percent >= 100.0) {
                                    finished.add(id)
                                }
                            }
                        }
                    }
                    _uiState.value = _uiState.value.copy(
                        pipelineProgress = updated - finished,
                        scanningLibraryIds = scanningIds - finished
                    )
                } catch (e: Exception) {
                    // 网络波动时继续下一轮轮询
                }
                delay(SCAN_POLLING_INTERVAL_MS)
            }
        }
    }

    fun scanAllLibraries() {
        viewModelScope.launch {
            val allIds = _uiState.value.libraries.map { it.id }.toSet()
            _uiState.value = _uiState.value.copy(scanningLibraryIds = allIds)
            try {
                val api = ApiClient.getApi()
                val response = api.scanAllMediaLibraries()
                if (response.success) {
                    startScanProgressPolling()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to scan libraries"
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error"
                )
            } finally {
                _uiState.value = _uiState.value.copy(scanningLibraryIds = emptySet())
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

    fun clearNotice() {
        _uiState.value = _uiState.value.copy(noticeResId = null, noticeArg = null)
    }

    // 按库重新刮削（取代已删除的 supplement 接口）
    fun rescrapeLibrary(library: MediaLibrary) {
        viewModelScope.launch {
            val result = com.fryfrog.hub.data.repository.MediaRepository().rescrapeLibrary(library.id)
            result.fold(
                onSuccess = {
                    _uiState.value = _uiState.value.copy(
                        noticeResId = com.fryfrog.hub.R.string.rescrape_submitted
                    )
                },
                onFailure = { e ->
                    _uiState.value = _uiState.value.copy(
                        error = e.message ?: "Failed to submit rescrape"
                    )
                }
            )
        }
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

    fun updateLibrary(
        library: MediaLibrary,
        name: String,
        path: String,
        type: String,
        subType: String?,
        description: String?,
        enableScraping: Boolean,
        isAdult: Boolean,
        enabled: Boolean
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val api = ApiClient.getApi()
                val updated = library.copy(
                    name = name,
                    path = path,
                    type = type,
                    subType = subType,
                    enabled = enabled,
                    enableScraping = enableScraping,
                    isAdult = isAdult,
                    description = description
                )
                val response = api.updateMediaLibrary(library.id, updated)
                if (response.success) {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                    loadLibraries()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to update library",
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

    fun createLibrary(
        name: String,
        path: String,
        type: String,
        subType: String? = null,
        description: String? = null,
        enableScraping: Boolean = true,
        isAdult: Boolean = false
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
                    enableScraping = enableScraping,
                    isAdult = isAdult,
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