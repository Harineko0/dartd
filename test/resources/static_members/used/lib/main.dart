class FeatureFlags {
  static const String apiEndpoint = 'https://example.com';
  static String label() => 'endpoint:' + apiEndpoint;
}

void main() {
  FeatureFlags.label();
}
