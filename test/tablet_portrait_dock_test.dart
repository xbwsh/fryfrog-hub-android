import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/app/main_shell.dart';
import 'package:fryfrog_hub/core/adaptive/device_form.dart';
import 'package:fryfrog_hub/core/models/media_models.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/features/books/books_screen.dart';
import 'package:fryfrog_hub/features/home/home_screen.dart';
import 'package:fryfrog_hub/features/music/music_screen.dart';
import 'package:fryfrog_hub/features/profile/profile_screen.dart';
import 'package:fryfrog_hub/widgets/server_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TabletSession extends Session {
  _TabletSession(AppPrefs prefs) : super(ServerConnection(), prefs);

  @override
  final albums = [
    for (var id = 1; id <= 40; id++) MusicAlbum(id: id, title: '专辑 $id'),
  ];

  @override
  final artists = [
    for (var id = 1; id <= 40; id++) MusicArtist(id: id, name: '歌手 $id'),
  ];
}

void main() {
  testWidgets(
    'portrait tablet tabs scroll behind the dock and clear their last row',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1280);
      const insets = FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = insets;
      tester.view.viewPadding = insets;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});

      final prefs = AppPrefs();
      final session = _TabletSession(prefs);
      session.books[BookShelfKind.ebook] = [
        for (var id = 1; id <= 40; id++) BookItem(id: id, title: '电子书 $id'),
      ];
      session.songs.addAll([
        for (var id = 1; id <= 40; id++) MusicSong(id: id, title: '歌曲 $id'),
      ]);
      addTearDown(session.dispose);
      addTearDown(prefs.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScope(
            form: DeviceForm.tabletPortrait,
            child: SessionScope(
              session: session,
              child: Material(child: MainShell(session: session)),
            ),
          ),
        ),
      );
      final dock = find.byKey(const ValueKey('glass_scaffold_bottom_bar'));

      Future<void> select(String label) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }

      Future<void> verifyLastRow(Finder viewport, String label) async {
        expect(tester.getBottomLeft(viewport).dy, 1280);
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: viewport, matching: find.byType(Scrollable)),
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final last = find.text(label);
        expect(last.hitTestable(), findsOneWidget);
        expect(
          tester.getBottomLeft(last).dy,
          lessThan(tester.getTopLeft(dock).dy),
        );
      }

      final home = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.vertical,
        ),
      );
      expect(tester.getBottomLeft(home).dy, 1280);
      expect(
        tester.getTopLeft(dock).dy,
        lessThan(tester.getBottomLeft(home).dy),
      );

      await select('书架');
      await verifyLastRow(
        find.descendant(
          of: find.byType(BooksScreen),
          matching: find.byType(GridView),
        ),
        '电子书 40',
      );

      await select('音乐');
      final music = find.byType(MusicScreen);
      await verifyLastRow(
        find.descendant(of: music, matching: find.byType(ListView)),
        '40. 歌曲 40',
      );
      for (final mode in ['专辑', '歌手']) {
        await select(mode);
        await verifyLastRow(
          find.descendant(of: music, matching: find.byType(GridView)),
          '$mode 40',
        );
      }

      await select('我的');
      await verifyLastRow(
        find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(ListView),
        ),
        '退出登录',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
