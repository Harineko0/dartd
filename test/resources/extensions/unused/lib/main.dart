import 'ext.dart';

extension NumberFormatting on int {
  String asCurrency() => '\$${this}';
}

void main() {
  // No extension methods are exercised.
}
