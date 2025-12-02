import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

@riverpod
class ClassProvider extends _$ClassProvider {
  @override
  int build() => 1;
}

void main() {
  final container = ProviderContainer();
  container.read(classProviderProvider);
}
