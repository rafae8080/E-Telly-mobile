import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void navigateTo(String route) {
    final routeMap = {
      'alerts': '/alerts',
      'reports': '/alerts',
      'community': '/home',
      'resources': '/home',
      'home': '/home',
    };

    final namedRoute = routeMap[route] ?? '/home';
    navigatorKey.currentState?.pushNamed(namedRoute);
  }
}
