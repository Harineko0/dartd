import 'package:freezed_annotation/freezed_annotation.dart';

part 'model.freezed.dart';

@freezed
class Todo with _$Todo {
  const factory Todo({required String id, String? note}) = _Todo;
}

void main() {}
