import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:riverpod/riverpod.dart';

part 'main.g.dart';

@riverpod
String greeting(GreetingRef ref) => 'hi';

void main() {
  final container = ProviderContainer();
  container.read(greetingProvider);
}
