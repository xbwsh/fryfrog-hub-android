package com.fryfrog.hub.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.data.model.PipelineProgress
import com.fryfrog.hub.data.model.ScrapeProgress
import com.fryfrog.hub.data.remote.ApiClient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

private const val SCAN_POLLING_INTERVAL_MS = 1500L
private const val SCAN_POLLING_TIMEOUT_MS = 10 * 60 * 1000L
private const val MODULE_POLLING_INTERVAL_MS = 1500L
private const val MODULE_POLLING_TIMEOUT_MS = 30 * 60 * 1000L
private const val ADULT_ALL_KEY = -1L

data class DirectoryItem(
    val name: String,
    val path: String,
    val isDirectory: Boolean
)

data class MediaLibrariesUiState(
    val libraries: List<MediaLibrary> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val scanningLibraryIds: Set<Long> = emptySet(),
    val pipelineProgress: Map<Long, PipelineProgress> = emptyMap(),
    val supplementingLibraryIds: Set<Long> = emptySet(),
    val adultScrapingLibraryIds: Set<Long> = emptySet(),
    val supplementProgress: Map<Long, ScrapeProgress> = emptyMap(),
    val adultProgress: Map<Long, ScrapeProgress> = emptyMap(),
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
                val response = api.scanMediaLibrary(library.id)
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

    private var pipelineProgressJob: Job? = null

    private fun startScanProgressPolling() {
        pipelineProgressJob?.cancel()
        val startedAt = System.currentTimeMillis()
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

    fun scrapeAdultOnly(libraryId: Long? = null) {
        // 不传 libraryId 时后端处理所有库，进度模块为 adult:all，用 -1 作 key
        val key = libraryId ?: ADULT_ALL_KEY
        val newIds = _uiState.value.adultScrapingLibraryIds + key
        _uiState.value = _uiState.value.copy(adultScrapingLibraryIds = newIds)
        viewModelScope.launch {
            try {
                val api = ApiClient.getApi()
                val response = api.scrapeAdultOnly(libraryId)
                if (response.success) {
                    startModulePolling()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to scrape adult",
                        adultScrapingLibraryIds = newIds - key
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    adultScrapingLibraryIds = newIds - key
                )
            }
        }
    }

    fun scrapeSupplement(libraryId: Long, force: Boolean = false) {
        val newIds = _uiState.value.supplementingLibraryIds + libraryId
        _uiState.value = _uiState.value.copy(supplementingLibraryIds = newIds)
        viewModelScope.launch {
            try {
                val api = ApiClient.getApi()
                val response = api.scrapeSupplement(libraryId, force)
                if (response.success) {
                    startModulePolling()
                } else {
                    _uiState.value = _uiState.value.copy(
                        error = response.message ?: "Failed to supplement scrape",
                        supplementingLibraryIds = newIds - libraryId
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    error = e.message ?: "Unknown error",
                    supplementingLibraryIds = newIds - libraryId
                )
            }
        }
    }

    // ===== 补充/成人刮削进度轮询 =====

    private var modulePollingJob: Job? = null

    private fun startModulePolling() {
        modulePollingJob?.cancel()
        val startedAt = System.currentTimeMillis()
        modulePollingJob = viewModelScope.launch {
            while (true) {
                val s = _uiState.value
                val supplementIds = s.supplementingLibraryIds
                val adultIds = s.adultScrapingLibraryIds
                if (supplementIds.isEmpty() && adultIds.isEmpty()) break

                if (System.currentTimeMillis() - startedAt > MODULE_POLLING_TIMEOUT_MS) {
                    _uiState.value = _uiState.value.copy(
                        supplementingLibraryIds = emptySet(),
                        adultScrapingLibraryIds = emptySet(),
                        supplementProgress = emptyMap(),
                        adultProgress = emptyMap()
                    )
                    break
                }

                try {
                    val api = ApiClient.getApi()
                    val supUpdated = mutableMapOf<Long, ScrapeProgress>()
                    val supDone = mutableSetOf<Long>()
                    for (id in supplementIds) {
                        val p = api.getScrapeProgress("supplement:$id").data
                        if (p != null) {
                            supUpdated[id] = p
                            if (!p.running) supDone.add(id)
                        }
                    }
                    val adultUpdated = mutableMapOf<Long, ScrapeProgress>()
                    val adultDone = mutableSetOf<Long>()
                    for (id in adultIds) {
                        val module = if (id == ADULT_ALL_KEY) "adult:all" else "adult:$id"
                        val p = api.getScrapeProgress(module).data
                        if (p != null) {
                            adultUpdated[id] = p
                            if (!p.running) adultDone.add(id)
                        }
                    }
                    _uiState.value = _uiState.value.copy(
                        supplementingLibraryIds = supplementIds - supDone,
                        adultScrapingLibraryIds = adultIds - adultDone,
                        supplementProgress = supUpdated - supDone,
                        adultProgress = adultUpdated - adultDone
                    )
                } catch (e: Exception) {
                    // 网络波动时继续下一轮轮询
                }
                delay(MODULE_POLLING_INTERVAL_MS)
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