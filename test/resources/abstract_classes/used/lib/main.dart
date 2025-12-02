import 'task.dart';

abstract class Presenter {
  String render();
}

class ConsolePresenter implements Presenter {
  @override
  String render() => 'ok';
}

class ConsoleRenderer implements Renderer {
  @override
  String render() => 'renderer';
}

void main() {
  ConsolePresenter().render();
  ConsoleRenderer().render();
}
