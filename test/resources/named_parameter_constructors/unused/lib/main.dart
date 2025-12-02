import 'client.dart';

class ApiClient {
  final String baseUrl;
  final Duration? timeout;

  ApiClient({required this.baseUrl, this.timeout});

  String describe() => baseUrl;
}

void main() {
  ApiClient(baseUrl: 'https://example.com');
  // Nothing else is referenced.
}
