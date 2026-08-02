library;

import 'types.dart';

class YEvent {
  final YType target;
  final Set<String> keysChanged;

  const YEvent({required this.target, required this.keysChanged});
}

typedef YObserver = void Function(YEvent event);
typedef YDeepObserver = void Function(List<YEvent> events);
