import 'package:flutter/foundation.dart';

@immutable
class MyPageState {
  const MyPageState({
    this.counter = 0,
  });

  final int counter;

  MyPageState copyWith({int? counter}) =>
      MyPageState(counter: counter ?? this.counter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyPageState && other.counter == counter;

  @override
  int get hashCode => counter.hashCode;
}
