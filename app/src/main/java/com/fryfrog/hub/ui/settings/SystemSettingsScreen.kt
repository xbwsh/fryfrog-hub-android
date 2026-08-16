@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.SystemSetting
import com.fryfrog.hub.ui.components.FryfrogDialog
import com.fryfrog.hub.ui.components.FryfrogTextField
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary

@Composable
fun SystemSettingsScreen(
    onBackClick: () -> Unit,
    viewModel: SystemSettingsViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var editTarget by remember { mutableStateOf<SystemSetting?>(null) }

    val snackbarText = uiState.snackbarResId?.let { resId ->
        uiState.snackbarArg?.let { stringResource(resId, it) } ?: stringResource(resId)
    }
    LaunchedEffect(uiState.snackbarResId) {
        snackbarText?.let { snackbarHostState.showSnackbar(it) }
        viewModel.clearSnackbar()
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.system_settings)) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
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
        ) {
            if (uiState.isLoading && uiState.settings.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (uiState.settings.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = stringResource(R.string.no_settings),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().navigationBarsPadding(),
                    contentPadding = PaddingValues(
                        start = Dimens.spacingLg,
                        top = Dimens.spacingLg,
                        end = Dimens.spacingLg,
                        bottom = Dimens.spacingXxl
                    ),
                    verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    items(uiState.settings, key = { it.key ?: "setting-${it.id}" }) { setting ->
                        SettingRow(
                            setting = setting,
                            onClick = { editTarget = setting }
                        )
                    }
                }
            }

            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(Dimens.spacingLg)
            )
        }
    }

    editTarget?.let { setting ->
        SettingEditDialog(
            setting = setting,
            onDismiss = { editTarget = null },
            onSubmit = { value ->
                viewModel.updateSetting(setting.key ?: "", value) {
                    editTarget = null
                }
            }
        )
    }
}

@Composable
private fun SettingRow(
    setting: SystemSetting,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        onClick = onClick
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(Dimens.spacingMd),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = setting.key ?: "",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1
                )
                setting.description?.let { desc ->
                    if (desc.isNotBlank()) {
                        Text(
                            text = desc,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )
                    }
                }
                Text(
                    text = setting.value ?: "",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1
                )
            }
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SettingEditDialog(
    setting: SystemSetting,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit
) {
    var value by remember { mutableStateOf(setting.value ?: "") }

    FryfrogDialog(
        onDismissRequest = onDismiss,
        icon = Icons.Default.Settings,
        iconTint = Primary,
        iconBackground = Primary.copy(alpha = 0.1f),
        title = setting.key ?: "",
        content = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
            ) {
                setting.description?.let { desc ->
                    if (desc.isNotBlank()) {
                        Text(
                            text = desc,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                FryfrogTextField(
                    value = value,
                    onValueChange = { value = it },
                    label = { Text(stringResource(R.string.setting_value)) },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmText = stringResource(R.string.save),
        onConfirm = { onSubmit(value) },
        onDismiss = onDismiss
    )
}
