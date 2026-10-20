import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/models/books.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';
import 'package:fryfrog_hub/core/network/server_connection.dart';
import 'package:fryfrog_hub/core/state/app_prefs.dart';
import 'package:fryfrog_hub/core/state/session.dart';
import 'package:fryfrog_hub/features/books/book_detail_screen.dart';

class _ScrapeApi extends ApiClient {
  _ScrapeApi() : super('http://test.invalid');

  String? searchedSource;
  String? searchedQuery;
  String? boundSource;
  String? boundId;

  @override
  Future<List<ScrapeProviderInfo>> fetchScrapeProviders(
    BookShelfKind kind,
  ) async => const [
    ScrapeProviderInfo(source: 'ximalaya', displayName: '喜马拉雅'),
  ];

  @override
  Future<List<ScrapeResult>> searchScrape(
    BookShelfKind kind, {
    required String q,
    String? source,
  }) async {
    searchedSource = source;
    searchedQuery = q;
    return const [
      ScrapeResult(
        source: 'ximalaya',
        sourceId: '123',
        title: '三体',
        author: '作者甲',
        narrator: '演员乙',
      ),
    ];
  }

  @override
  Future<void> bindScrape(
    BookShelfKind kind, {
    required int id,
    required String source,
    required String sourceId,
  }) async {
    boundSource = source;
    boundId = sourceId;
  }
}

void main() {
  testWidgets('动态选择喜马拉雅，以专辑 ID 搜索并绑定原始来源', (tester) async {
    final api = _ScrapeApi();
    final connection = ServerConnection();
    final prefs = AppPrefs();
    final session = Session(connection, prefs)..api = api;
    addTearDown(session.dispose);
    addTearDown(connection.dispose);
    addTearDown(prefs.dispose);
    bool? bound;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  bound = await showDialog<bool>(
                    context: context,
                    builder: (_) => ScrapeDialog(
                      kind: BookShelfKind.audiobook,
                      bookId: 1,
                      session: session,
                    ),
                  );
                },
                child: const Text('刮削'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('刮削'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('喜马拉雅'));
    await tester.pumpAndSettle();
    expect(find.text('关键词 / 专辑链接 / ID'), findsOneWidget);
    expect(find.text('搜索受限时，请粘贴喜马拉雅专辑链接或 ID'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    expect(api.searchedSource, 'ximalaya');
    expect(api.searchedQuery, '123');
    expect(find.textContaining('演播：演员乙'), findsOneWidget);

    await tester.tap(find.text('三体'));
    await tester.pumpAndSettle();
    expect(api.boundSource, 'ximalaya');
    expect(api.boundId, '123');
    expect(bound, isTrue);
  });
}
