import 'additional.dart';

typedef IntMapper = int Function(int);

int _arrowHelper(int value) => value * 2;

class MultiSyntax {
  MultiSyntax.named();
  factory MultiSyntax.factory() => MultiSyntax.named();

  int get computed => 1;

  set computed(int value) {}
}

extension HiddenDigits on String {
  int get digits => length;
}

void main() {
  // Auxiliary and unseenHelper stay unused.
}
