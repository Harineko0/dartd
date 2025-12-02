import 'ext.dart';

extension ShoutyString on String {
  String shout() => toUpperCase();
}

void main() {
  'hi'.shout();
  'there'.friendly();
}
