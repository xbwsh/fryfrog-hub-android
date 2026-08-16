@file:OptIn(ExperimentalMaterial3Api::class)

package com.fryfrog.hub.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.fryfrog.hub.R
import com.fryfrog.hub.data.model.MediaLibrary
import com.fryfrog.hub.data.model.UserDTO
import com.fryfrog.hub.ui.components.FryfrogDialog
import com.fryfrog.hub.ui.components.FryfrogTextField
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary
import com.fryfrog.hub.ui.theme.Warning

@Composable
fun UserManagementScreen(
    onBackClick: () -> Unit,
    viewModel: UserManagementViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    var showCreateDialog by remember { mutableStateOf(false) }
    var editTarget by remember { mutableStateOf<UserDTO?>(null) }
    var resetTarget by remember { mutableStateOf<UserDTO?>(null) }
    var librariesTarget by remember { mutableStateOf<UserDTO?>(null) }
    var deleteTarget by remember { mutableStateOf<UserDTO?>(null) }

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
                title = { Text(stringResource(R.string.user_management)) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Default.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
                actions = {
                    IconButton(onClick = { showCreateDialog = true }) {
                        Icon(Icons.Default.Add, contentDescription = stringResource(R.string.add_user))
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
            if (uiState.isLoading && uiState.users.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (uiState.users.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = stringResource(R.string.no_users),
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
                        bottom = Dimens.bottomNavReserve
                    ),
                    verticalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    items(uiState.users, key = { it.id }) { user ->
                        UserCard(
                            user = user,
                            onEdit = { editTarget = user },
                            onResetPassword = { resetTarget = user },
                            onAssignLibraries = { librariesTarget = user },
                            onDelete = { deleteTarget = user }
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

    if (showCreateDialog) {
        UserEditDialog(
            title = stringResource(R.string.add_user),
            isCreate = true,
            isSaving = uiState.isLoading,
            onDismiss = { showCreateDialog = false },
            onSubmit = { username, password, nickname, role, _ ->
                viewModel.createUser(username, password, nickname.ifBlank { null }, role) {
                    showCreateDialog = false
                }
            }
        )
    }

    editTarget?.let { user ->
        UserEditDialog(
            title = stringResource(R.string.edit_user),
            isCreate = false,
            initialNickname = user.nickname ?: user.username,
            initialRole = user.role ?: "USER",
            initialEnabled = user.enabled != false,
            isSaving = uiState.isLoading,
            onDismiss = { editTarget = null },
            onSubmit = { _, _, nickname, role, enabled ->
                viewModel.updateUser(user.id, nickname.ifBlank { null }, role, enabled) {
                    editTarget = null
                }
            }
        )
    }

    resetTarget?.let { user ->
        ResetPasswordDialog(
            username = user.username,
            isSaving = uiState.isLoading,
            onDismiss = { resetTarget = null },
            onSubmit = { newPassword ->
                viewModel.resetPassword(user.id, newPassword) {
                    resetTarget = null
                }
            }
        )
    }

    librariesTarget?.let { user ->
        AssignLibrariesDialog(
            user = user,
            libraries = uiState.libraries,
            viewModel = viewModel,
            onDismiss = { librariesTarget = null }
        )
    }

    deleteTarget?.let { user ->
        FryfrogDialog(
            onDismissRequest = { deleteTarget = null },
            icon = Icons.Default.Delete,
            iconTint = MaterialTheme.colorScheme.error,
            iconBackground = MaterialTheme.colorScheme.errorContainer,
            title = stringResource(R.string.delete),
            message = stringResource(R.string.delete_user_confirm, user.username),
            confirmText = stringResource(R.string.delete),
            confirmColor = MaterialTheme.colorScheme.error,
            onConfirm = {
                viewModel.deleteUser(user.id) {
                    deleteTarget = null
                }
            },
            onDismiss = { deleteTarget = null }
        )
    }
}

@Composable
private fun UserCard(
    user: UserDTO,
    onEdit: () -> Unit,
    onResetPassword: () -> Unit,
    onAssignLibraries: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(Dimens.radiusMd),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(Dimens.spacingMd)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(Dimens.avatarSize)
                        .clip(CircleShape)
                        .background(if (user.isAdmin) Warning.copy(alpha = 0.15f) else Primary.copy(alpha = 0.1f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (user.isAdmin) Icons.Default.AdminPanelSettings else Icons.Default.Person,
                        contentDescription = null,
                        tint = if (user.isAdmin) Warning else Primary,
                        modifier = Modifier.size(Dimens.avatarIconSize)
                    )
                }

                Spacer(Modifier.width(Dimens.spacingMd))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = user.displayName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1
                    )
                    Text(
                        text = "@${user.username}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Surface(
                    color = if (user.isAdmin) Warning.copy(alpha = 0.15f) else Primary.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(Dimens.radiusXs)
                ) {
                    Text(
                        text = stringResource(if (user.isAdmin) R.string.role_admin else R.string.role_user),
                        modifier = Modifier.padding(horizontal = Dimens.spacingSm, vertical = Dimens.spacingXxs),
                        style = MaterialTheme.typography.labelSmall,
                        color = if (user.isAdmin) Warning else Primary
                    )
                }
            }

            Spacer(Modifier.height(Dimens.spacingSm))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = onAssignLibraries) {
                    Icon(Icons.Default.Folder, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(Dimens.spacingXs))
                    Text(stringResource(R.string.assign_libraries))
                }
                TextButton(onClick = onResetPassword) {
                    Icon(Icons.Default.Key, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(Dimens.spacingXs))
                    Text(stringResource(R.string.reset_password))
                }
                IconButton(onClick = onEdit) {
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = stringResource(R.string.edit),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                IconButton(onClick = onDelete) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = stringResource(R.string.delete),
                        tint = MaterialTheme.colorScheme.error
                    )
                }
            }
        }
    }
}

@Composable
private fun UserEditDialog(
    title: String,
    isCreate: Boolean,
    initialNickname: String = "",
    initialRole: String = "USER",
    initialEnabled: Boolean = true,
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (username: String, password: String, nickname: String, role: String, enabled: Boolean) -> Unit
) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var nickname by remember { mutableStateOf(initialNickname) }
    var role by remember { mutableStateOf(initialRole) }
    var enabled by remember { mutableStateOf(initialEnabled) }

    FryfrogDialog(
        onDismissRequest = onDismiss,
        title = title,
        content = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
            ) {
                if (isCreate) {
                    FryfrogTextField(
                        value = username,
                        onValueChange = { username = it },
                        label = { Text(stringResource(R.string.username)) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    FryfrogTextField(
                        value = password,
                        onValueChange = { password = it },
                        label = { Text(stringResource(R.string.password)) },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                FryfrogTextField(
                    value = nickname,
                    onValueChange = { nickname = it },
                    label = { Text(stringResource(R.string.nickname)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingSm)
                ) {
                    listOf("USER" to stringResource(R.string.role_user), "ADMIN" to stringResource(R.string.role_admin)).forEach { (value, label) ->
                        val selected = role == value
                        Surface(
                            onClick = { role = value },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(Dimens.radiusMd),
                            color = if (selected) Primary.copy(alpha = 0.15f) else Color.Transparent
                        ) {
                            Text(
                                text = label,
                                modifier = Modifier.padding(vertical = Dimens.spacingSm),
                                style = MaterialTheme.typography.labelMedium,
                                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                                color = if (selected) Primary else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                if (!isCreate) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = stringResource(R.string.user_enabled),
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f)
                        )
                        Checkbox(
                            checked = enabled,
                            onCheckedChange = { enabled = it }
                        )
                    }
                }
            }
        },
        confirmText = stringResource(R.string.save),
        confirmEnabled = !isSaving && (!isCreate || (username.isNotBlank() && password.isNotBlank())),
        onConfirm = { onSubmit(username.trim(), password, nickname.trim(), role, enabled) },
        onDismiss = onDismiss
    )
}

@Composable
private fun ResetPasswordDialog(
    username: String,
    isSaving: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (newPassword: String) -> Unit
) {
    var newPassword by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    val mismatchText = stringResource(R.string.password_mismatch)

    FryfrogDialog(
        onDismissRequest = onDismiss,
        title = stringResource(R.string.reset_password),
        content = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
            ) {
                Text(
                    text = "@$username",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                FryfrogTextField(
                    value = newPassword,
                    onValueChange = { newPassword = it; error = null },
                    label = { Text(stringResource(R.string.new_password)) },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
                FryfrogTextField(
                    value = confirm,
                    onValueChange = { confirm = it; error = null },
                    label = { Text(stringResource(R.string.confirm_new_password)) },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
                error?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
        },
        confirmText = stringResource(R.string.confirm),
        confirmEnabled = !isSaving && newPassword.isNotBlank(),
        onConfirm = {
            if (newPassword != confirm) {
                error = mismatchText
            } else {
                onSubmit(newPassword)
            }
        },
        onDismiss = onDismiss
    )
}

@Composable
private fun AssignLibrariesDialog(
    user: UserDTO,
    libraries: List<MediaLibrary>,
    viewModel: UserManagementViewModel,
    onDismiss: () -> Unit
) {
    var selected by remember { mutableStateOf<Set<Long>>(emptySet()) }
    var isLoading by remember { mutableStateOf(true) }
    val isSaving = false

    LaunchedEffect(user.id) {
        isLoading = true
        selected = viewModel.getUserLibraries(user.id)
        isLoading = false
    }

    FryfrogDialog(
        onDismissRequest = onDismiss,
        title = stringResource(R.string.assign_libraries),
        content = {
            if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(Dimens.listMaxHeight),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (libraries.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(Dimens.listMaxHeight),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = stringResource(R.string.no_libraries),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                Column(
                    modifier = Modifier.fillMaxWidth().heightIn(max = Dimens.listMaxHeight),
                    verticalArrangement = Arrangement.spacedBy(Dimens.spacingXs)
                ) {
                    libraries.forEach { library ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    selected = if (library.id in selected) selected - library.id
                                    else selected + library.id
                                }
                                .padding(vertical = Dimens.spacingSm),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Checkbox(
                                checked = library.id in selected,
                                onCheckedChange = { checked ->
                                    selected = if (checked) selected + library.id else selected - library.id
                                }
                            )
                            Text(
                                text = library.name,
                                style = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }
        },
        confirmText = stringResource(R.string.save),
        confirmEnabled = !isLoading && !isSaving,
        onConfirm = {
            viewModel.setUserLibraries(user.id, selected) {
                onDismiss()
            }
        },
        onDismiss = onDismiss
    )
}
