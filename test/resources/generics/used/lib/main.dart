import 'box.dart';

class Result<T> {
  final T data;

  Result(this.data);
}

void main() {
  final result = Result<int>(1);
  result.data.toString();

  final spare = SpareResult<String>('ok');
  spare.data.toString();
}
