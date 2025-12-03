import 'package:riverpod/riverpod.dart';

import 'provider.dart';

void main() {
  final container = ProviderContainer();
  final state =
      container.read(classProviderProvider.select((value) => value.name));
  print(state);
}
