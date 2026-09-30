import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_screen.dart';
import '../features/bookmarks/bookmarks_screen.dart';
import '../features/picker/picker_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';

/// `/` is the mushaf picker; the reader, bookmarks, settings and about pages
/// sit above it, so Back from the reader always returns to the picker.
GoRouter buildRouter(String initialLocation) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PickerScreen(),
      routes: [
        GoRoute(
          path: 'read/:mushaf',
          builder: (context, state) => ReaderScreen(
            key: ValueKey(state.uri.toString()),
            mushafId: state.pathParameters['mushaf']!,
            initialPage: int.tryParse(state.uri.queryParameters['page'] ?? ''),
          ),
        ),
        GoRoute(path: 'bookmarks', builder: (context, state) => const BookmarksScreen()),
        GoRoute(path: 'settings', builder: (context, state) => const SettingsScreen()),
        GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
      ],
    ),
  ],
);

String readerLocation(String mushafId, int page) => '/read/$mushafId?page=$page';
