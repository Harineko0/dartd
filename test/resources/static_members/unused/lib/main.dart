import 'static_class.dart';

class FeatureFlags {
  static const String unusedName = 'staging';
  static String unusedLabel() => 'unused';
}

class UserClass {
  void unusedMethod() {
    StaticClass.staticMethod();
  }
}

void main() {
  // Static members are never referenced.
}
