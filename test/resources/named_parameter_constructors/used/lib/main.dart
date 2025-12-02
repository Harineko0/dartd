import 'client.dart';

class ApiClient {
  final String baseUrl;
  final Duration? timeout;

  ApiClient({required this.baseUrl, this.timeout});

  String describe() => '$baseUrl:${timeout?.inSeconds ?? 0}';
}

void main() {
  ApiClient(baseUrl: 'https://example.com', timeout: Duration(seconds: 1))
      .describe();
  LoggingClient('used');
}
