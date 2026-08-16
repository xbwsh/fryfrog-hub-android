package com.fryfrog.hub.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.window.Dialog
import com.fryfrog.hub.R
import com.fryfrog.hub.ui.theme.Dimens
import com.fryfrog.hub.ui.theme.Primary

/**
 * 统一弹窗外壳（风格与退出登录确认弹窗一致）：
 * Dialog + 圆角 Card + 可选图标头像 + 居中标题 + 内容区 + 底部按钮行（取消 + 确认）。
 * 简单确认类传 [message]；复杂内容类（表单/网格/列表）用 [content] 自定义。
 * [confirmText] 为 null 时只显示取消按钮；[content] 内的操作按钮不受影响。
 */
@Composable
fun FryfrogDialog(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconTint: Color = MaterialTheme.colorScheme.error,
    iconBackground: Color = MaterialTheme.colorScheme.errorContainer,
    title: String? = null,
    message: String? = null,
    content: (@Composable ColumnScope.() -> Unit)? = null,
    confirmText: String? = null,
    confirmColor: Color = Primary,
    confirmEnabled: Boolean = true,
    onConfirm: (() -> Unit)? = null,
    dismissText: String = stringResource(R.string.cancel),
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismissRequest) {
        Card(
            modifier = modifier
                .fillMaxWidth()
                .padding(Dimens.spacingLg),
            shape = RoundedCornerShape(Dimens.radiusXl),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            )
        ) {
            Column(
                modifier = Modifier.padding(Dimens.spacingXl),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (icon != null) {
                    Box(
                        modifier = Modifier
                            .size(Dimens.dialogAvatarSize)
                            .clip(CircleShape)
                            .background(iconBackground),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = iconTint,
                            modifier = Modifier.size(Dimens.dialogIconSize)
                        )
                    }

                    Spacer(Modifier.height(Dimens.spacingLg))
                }

                title?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                        textAlign = TextAlign.Center
                    )

                    Spacer(Modifier.height(Dimens.spacingSm))
                }

                message?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )

                    Spacer(Modifier.height(Dimens.spacingXl))
                }

                content?.invoke(this)

                Spacer(Modifier.height(Dimens.spacingXl))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(Dimens.spacingMd)
                ) {
                    TextButton(
                        onClick = onDismiss,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.onSurface
                        )
                    ) {
                        Text(dismissText)
                    }

                    if (confirmText != null) {
                        Button(
                            onClick = { onConfirm?.invoke() },
                            enabled = confirmEnabled,
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(Dimens.radiusMd),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = confirmColor
                            )
                        ) {
                            Text(confirmText)
                        }
                    }
                }
            }
        }
    }
}
