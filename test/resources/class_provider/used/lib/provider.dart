import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'state.dart';

part 'provider.g.dart';

@Riverpod(keepAlive: true)
class ClassProvider extends _$ClassProvider {
  @override
  State build() {
    return State('example');
  }
}
