class Ok<T, E> {
  final T? value;
  Ok(this.value);
}

Ok<void, E> ok<E extends Object>() => Ok<void, E>(null);
