import 'package:flutter/foundation.dart';

/// 一个 multipart 文件 / 二进制片段。**不引用 Dio 类型**——业务通过它描述
/// 上传 payload，[DioHttpClient.upload] 内部转成 Dio 的 `MultipartFile`。
///
/// 三种来源：
///
/// 1. **本地文件路径**（移动端）：
///    ```dart
///    MultipartFilePart.fromPath(
///      field: 'avatar',
///      filePath: '/storage/photos/me.jpg',
///      contentType: 'image/jpeg',
///    )
///    ```
///
/// 2. **内存字节**（图片裁剪 / Web）：
///    ```dart
///    MultipartFilePart.fromBytes(
///      field: 'logo',
///      bytes: pngBytes,
///      filename: 'logo.png',
///      contentType: 'image/png',
///    )
///    ```
///
/// 3. **可读流**（大文件分片 / 不想一次性 load 进内存）：
///    ```dart
///    MultipartFilePart.fromStream(
///      field: 'video',
///      stream: file.openRead(),
///      length: file.lengthSync(),
///      filename: 'clip.mp4',
///      contentType: 'video/mp4',
///    )
///    ```
@immutable
class MultipartFilePart {
  /// 路径来源。`filename` 不传时用 path 末段。
  const MultipartFilePart.fromPath({
    required this.field,
    required String filePath,
    this.filename,
    this.contentType,
  })  : _path = filePath,
        _bytes = null,
        _stream = null,
        _length = null;

  /// 内存字节来源。`filename` 必填——服务端通常需要它判断扩展名。
  const MultipartFilePart.fromBytes({
    required this.field,
    required List<int> bytes,
    required this.filename,
    this.contentType,
  })  : _path = null,
        _bytes = bytes,
        _stream = null,
        _length = null;

  /// 流式来源。`length` 必填（HTTP multipart 协议要求 Content-Length）。
  const MultipartFilePart.fromStream({
    required this.field,
    required Stream<List<int>> stream,
    required int length,
    required this.filename,
    this.contentType,
  })  : _path = null,
        _bytes = null,
        _stream = stream,
        _length = length;

  /// form 字段名（与服务端约定，例如 `'file'` / `'image'` / `'attachments'`）。
  final String field;

  /// 上传到服务端时显示的文件名。`null` 时由实现侧根据来源推断。
  final String? filename;

  /// MIME content-type，例如 `'image/png'`、`'application/pdf'`。`null` 时由
  /// 实现侧（通常是 Dio）根据扩展名猜，猜不出落到 `application/octet-stream`。
  final String? contentType;

  // ── 三选一来源（运行时由 [DioHttpClient.upload] 检查）────────────────────────
  final String? _path;
  final List<int>? _bytes;
  final Stream<List<int>>? _stream;
  final int? _length;

  /// 实现侧用——返回当前片段的来源类型 + 内容。
  ///
  /// **不应**被业务代码直接调用；只是 Dio 转换层的接入点，对外暴露给
  /// `dart doc` 是因为没法 `@internal`（mixin/visible_for_overriding 限制）。
  MultipartSource get source {
    final path = _path;
    if (path != null) return MultipartSourcePath(path);
    final bytes = _bytes;
    if (bytes != null) return MultipartSourceBytes(bytes);
    final stream = _stream;
    final length = _length;
    if (stream != null && length != null) {
      return MultipartSourceStream(stream, length);
    }
    throw StateError(
      'MultipartFilePart with no source — should be unreachable, '
      'check your constructor call.',
    );
  }
}

/// [MultipartFilePart.source] 的标签 union。Dio 转换层 switch 处理。
sealed class MultipartSource {
  const MultipartSource();
}

class MultipartSourcePath extends MultipartSource {
  const MultipartSourcePath(this.path);
  final String path;
}

class MultipartSourceBytes extends MultipartSource {
  const MultipartSourceBytes(this.bytes);
  final List<int> bytes;
}

class MultipartSourceStream extends MultipartSource {
  const MultipartSourceStream(this.stream, this.length);
  final Stream<List<int>> stream;
  final int length;
}
