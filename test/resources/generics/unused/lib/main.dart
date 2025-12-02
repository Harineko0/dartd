import 'box.dart';

class Box<T> {
  final T value;

  Box(this.value);

  T unwrap() => value;
}

void main() {
  // Box and SpareBox are unused.
}
