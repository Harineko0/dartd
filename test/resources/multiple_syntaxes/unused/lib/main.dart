import 'additional.dart';

class MultiSyntax {
  MultiSyntax.named();
  factory MultiSyntax.factory() => MultiSyntax.named();
}

void main() {
  // Nothing in this file is referenced.
}
