import 'class.dart';

class VisibleUtility {
  void call() {}
}

void main() {
  VisibleUtility().call();
  VisibleUtilityOnOtherFile().call();
}
