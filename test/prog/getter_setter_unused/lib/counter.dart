class Counter {
  int _value = 0;

  int get value => _value;

  set value(int next) => _value = next;

  void use() {
    print('Used member');
  }
}
