import 'dart:async';

class Result<T, E extends Object> {
  const Result();
}

class FutureResult<T, E extends Object> {
  final Result<T, E> result;
  const FutureResult(this.result);
}

extension ResultToFutureExtension<T, E extends Object> on Result<T, E> {
  FutureResult<T, E> toAsync() => FutureResult<T, E>(this);
}
