import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'main.g.dart';

@Riverpod(keepAlive: true)
class ClassProvider extends _$ClassProvider {
  @override
  DataClass build() {
    return DataClass('example', 42);
  }
}

class DataClass {
  DataClass(this.name, this.value);

  final String name;
  final int value;
}

void main() {
  final container = ProviderContainer();
  final state = container.read(classProviderProvider.select((DataClass value) => value.name));
  print(state);
}
