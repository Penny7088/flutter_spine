/// Repository 模板：abstract + Http 实现 + provider。VM 只 import abstract。
const repoAbstractTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';

/// {{Title}} Repository abstract.
///
/// VM 永远只 depend 这个；测试 override `{{name}}RepositoryProvider`
/// 注入 fake 即可。
abstract class {{Name}}Repository {
  /// 拉一条记录。失败应抛 [AppException]（业务子类）。
  Future<{{Name}}Entity> fetch({required String id});

  /// 列表（演示分页/筛选签名）。
  Future<List<{{Name}}Entity>> list({int page = 1, int size = 20});
}

class {{Name}}Entity {
  const {{Name}}Entity({required this.id, required this.name});

  final String id;
  final String name;

  factory {{Name}}Entity.fromJson(Map<String, dynamic> json) => {{Name}}Entity(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
''';

const repoImplTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';

import '{{name_snake}}_repository.dart';

class Http{{Name}}Repository implements {{Name}}Repository {
  Http{{Name}}Repository(this._http);

  final HttpClient _http;

  @override
  Future<{{Name}}Entity> fetch({required String id}) {
    return _http.get<{{Name}}Entity>(
      '/{{name-kebab}}/$id',
      decoder: (raw) => {{Name}}Entity.fromJson(raw as Map<String, dynamic>),
    );
  }

  @override
  Future<List<{{Name}}Entity>> list({int page = 1, int size = 20}) {
    return _http.get<List<{{Name}}Entity>>(
      '/{{name-kebab}}',
      query: {'page': page, 'size': size},
      decoder: (raw) => (raw as List)
          .map((e) => {{Name}}Entity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
''';

const repoProviderTemplate = r'''
import 'package:flutter_spine/flutter_spine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '{{name_snake}}_repository.dart';
import '{{name_snake}}_repository_impl.dart';

final {{name}}RepositoryProvider = Provider<{{Name}}Repository>((ref) {
  return Http{{Name}}Repository(ref.watch(httpClientProvider));
});
''';
