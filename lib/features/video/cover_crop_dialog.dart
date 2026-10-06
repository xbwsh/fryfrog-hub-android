import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

/// 裁剪用途：决定默认选中的比例，但不锁定（用户可自由切换）。
enum CoverCropKind {
  /// 竖版封面 2:3
  poster,

  /// 横版背景 16:9
  fanart,

  /// 不预设比例（原图比例）
  free,
}

/// 2:3 —— uCrop 自带的比例预设里没有竖版 2:3（只有 3x2），所以自定义一个。
class _RatioPreset implements CropAspectRatioPresetData {
  const _RatioPreset(this.name, this.x, this.y);

  @override
  final String name;

  final int x;
  final int y;

  @override
  (int, int) get data => (x, y);
}

const _presetPoster = _RatioPreset('2x3', 2, 3);
const _presetFanart = _RatioPreset('16x9', 16, 9);
const _presetFree = _RatioPreset('free', 1, 1);

/// 把一段图片字节落到临时文件，供裁剪器读取（裁剪器只接受本地路径）。
Future<File> writeTempImage(Uint8List bytes, {String prefix = 'cover'}) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.img',
  );
  await file.writeAsBytes(bytes);
  return file;
}

/// 打开裁剪界面（uCrop）。返回裁剪后的文件；用户取消时返回 null。
///
/// 比例预设给三个：2:3 竖版、16:9 横版、不限制——和 TMDB/媒体库的常见需求一致。
/// `lockAspectRatio: false` 让用户能自由切换，`initAspectRatio` 只决定初始选择。
Future<File?> cropCoverImage(
  BuildContext context, {
  required File source,
  required CoverCropKind kind,
}) async {
  final initial = switch (kind) {
    CoverCropKind.poster => _presetPoster,
    CoverCropKind.fanart => _presetFanart,
    CoverCropKind.free => _presetFree,
  };

  final cropped = await ImageCropper().cropImage(
    sourcePath: source.path,
    compressFormat: ImageCompressFormat.jpg,
    compressQuality: 92,
    // 上限跟着后端一致（后端最长边 4096），避免传上去再被缩一次
    maxWidth: 4096,
    maxHeight: 4096,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: '裁剪图片',
        toolbarColor: const Color(0xFF1F1F22),
        toolbarWidgetColor: Colors.white,
        backgroundColor: const Color(0xFF121214),
        activeControlsWidgetColor: const Color(0xFF4C8DFF),
        statusBarLight: false,
        navBarLight: false,
        lockAspectRatio: false,
        hideBottomControls: false,
        initAspectRatio: initial,
        aspectRatioPresets: const [_presetPoster, _presetFanart, _presetFree],
      ),
      IOSUiSettings(
        title: '裁剪图片',
        aspectRatioLockEnabled: false,
        // iOS 只支持一个自定义预设，这里给 2:3（竖版封面用得最多）
        aspectRatioPresets: const [_presetPoster],
      ),
    ],
  );
  if (cropped == null) return null;
  return File(cropped.path);
}

/// 裁剪 + 上传一步到位：给「帧截图」和「本地图片」两条路共用。
///
/// [sourceBytes] 是原图；[onUpload] 负责把裁剪结果传给后端（由调用方注入，
/// 便于复用同一套 level/kind → 落盘位置的约定）。
/// 返回 true 表示已成功上传。
Future<bool> cropAndUploadCover(
  BuildContext context, {
  required Uint8List sourceBytes,
  required CoverCropKind kind,
  required Future<void> Function(File cropped) onUpload,
}) async {
  File? temp;
  File? cropped;
  try {
    temp = await writeTempImage(sourceBytes);
    // 落盘后 context 可能已失效（页面被 pop），裁剪器要拿它弹界面，先挡一下
    if (!context.mounted) return false;
    cropped = await cropCoverImage(context, source: temp, kind: kind);
    if (cropped == null) return false; // 用户取消
    await onUpload(cropped);
    return true;
  } finally {
    // 临时文件用完就删：裁剪结果已经上传，原图没有保留价值
    for (final f in [cropped, temp]) {
      if (f == null) continue;
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {
        // 删不掉不影响功能（系统会清缓存目录）
      }
    }
  }
}
