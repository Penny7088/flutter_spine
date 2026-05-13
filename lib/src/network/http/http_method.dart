/// HTTP 方法枚举。所有 [HttpClient] 调用统一通过它指定方法。
enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE'),
  head('HEAD');

  const HttpMethod(this.name);
  final String name;
}
