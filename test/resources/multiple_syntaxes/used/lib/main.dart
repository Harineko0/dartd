import 'additional.dart';

typedef IntMapper = int Function(int);

int _arrowHelper(int value) => value * 2;

class MultiSyntax {
  MultiSyntax.named();
  factory MultiSyntax.factory() => MultiSyntax.named();

  int get computed => _arrowHelper(1);

  set computed(int value) {}
}

extension HiddenDigits on String {
  int get digits => length;
}

void main() {
  IntMapper mapper = _arrowHelper;
  final value = mapper(3);
  final ms = MultiSyntax.factory();
  ms.computed = value;
  ms.computed;
  '123'.digits;
  Auxiliary.named();
  unseenHelper();
}
