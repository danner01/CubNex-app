import 'dart:async';

import 'package:flutter/widgets.dart';

/// Estado global de primer/segundo plano para no hacer polling de red
/// cuando la app no esta visible.
class AppForeground with WidgetsBindingObserver {
  AppForeground._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AppForeground instance = AppForeground._();

  bool _active = true;
  bool get isActive => _active;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }
}

/// Como [Timer.periodic], pero omite [callback] mientras la app esta en segundo plano.
Timer foregroundPeriodic(Duration interval, void Function(Timer timer) callback) {
  AppForeground.instance;
  return Timer.periodic(interval, (timer) {
    if (AppForeground.instance.isActive) callback(timer);
  });
}
