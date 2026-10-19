import 'package:http/http.dart' as http;

/// An HTTP client that adds `Authorization: Bearer <token>` to every request.
///
/// The token comes from [tokenProvider], which the platform SDK answers cheaply when it has a valid one. A
/// token is reused for [maxAge] (Google access tokens live about an hour) and dropped as soon as a request is
/// answered with 401, so the next request gets a fresh one.
class BearerClient extends http.BaseClient {
  BearerClient(
    this.tokenProvider, {
    http.Client? inner,
    this.maxAge = const Duration(minutes: 30),
    DateTime Function()? clock,
  }) : _inner = inner ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final Future<String> Function() tokenProvider;
  final Duration maxAge;
  final http.Client _inner;
  final DateTime Function() _clock;

  String? _token;
  DateTime? _fetchedAt;

  Future<String> _currentToken() async {
    final at = _fetchedAt;
    if (_token == null || at == null || _clock().difference(at) >= maxAge) {
      _token = await tokenProvider();
      _fetchedAt = _clock();
    }
    return _token!;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer ${await _currentToken()}';
    final response = await _inner.send(request);
    if (response.statusCode == 401) _token = null;
    return response;
  }

  @override
  void close() => _inner.close();
}
