import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';

void main() {
  late HttpServer server;
  late ApiClient client;
  Map<String, dynamic>? savedProgress;
  Uri? musicQuery;
  Uri? lyricsQuery;
  String? lyricsAuthorization;
  var lyricsRequests = 0;

  setUpAll(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = ApiClient('http://127.0.0.1:${server.port}', token: 'test-token');
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      Object response;
      if (request.uri.path == '/api/v1/audiobooks/9') {
        response = {
          'success': true,
          'data': {
            'id': 9,
            'title': 'Audio book',
            'playType': 'MULTI',
            'tracks': [
              {
                'id': 90,
                'trackIndex': 4,
                'title': 'Track',
                'durationSeconds': 100,
                'streamUrl':
                    '/api/v1/audiobooks/tracks/90/stream?exp=123&sig=test',
              },
            ],
            'chapters': [
              {
                'chapterIndex': 11,
                'trackIndex': 4,
                'title': 'Chapter',
                'startSeconds': 30,
                'endSeconds': 80,
                'startInTrack': 7,
              },
            ],
            'progress': {
              'trackIndex': 4,
              'positionSeconds': 6,
              'completed': false,
            },
          },
        };
      } else if (request.uri.path == '/api/v1/audiobooks/9/progress') {
        savedProgress = jsonDecode(body) as Map<String, dynamic>;
        response = {'success': true};
      } else if (request.uri.path == '/api/v1/music/songs') {
        musicQuery = request.uri;
        response = {
          'success': true,
          'data': {
            'content': <Object>[],
            'page': 2,
            'size': 200,
            'totalElements': 0,
            'totalPages': 0,
          },
        };
      } else if (request.uri.path == '/api/v1/music/songs/23') {
        response = {
          'success': true,
          'data': {
            'id': 23,
            'title': 'Song with lyrics',
            'streamUrl': '/stream?exp=123&sig=stream',
            'lyricsUrl': '/api/v1/music/songs/23/lyrics?exp=456&sig=lyrics',
          },
        };
      } else if (request.uri.path == '/api/v1/music/songs/24') {
        response = {
          'success': true,
          'data': {'id': 24, 'title': 'Instrumental'},
        };
      } else if (request.uri.path == '/api/v1/music/songs/23/lyrics') {
        lyricsRequests++;
        lyricsQuery = request.uri;
        lyricsAuthorization = request.headers.value('authorization');
        request.response.headers.contentType = ContentType(
          'text',
          'plain',
          charset: 'utf-8',
        );
        request.response.add(utf8.encode('[00:01.20]第一句\n[00:02.40]第二句'));
        await request.response.close();
        return;
      } else {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  test('audiobook detail retains indexes and signed URL query through resolution', () async {
    final detail = await client.fetchAudiobookDetail(9);
    expect(detail.chapterAt(11)?.trackIndex, 4);
    expect(detail.chapterAt(11)?.startInTrack, 7);
    expect(detail.progress?.positionSeconds, 6);
    expect(
      client.resolveUrl(detail.tracks.single.streamUrl),
      'http://127.0.0.1:${server.port}/api/v1/audiobooks/tracks/90/stream?exp=123&sig=test',
    );

    await client.saveAudiobookProgress(9, trackIndex: 4, positionSeconds: 12.5);
    expect(savedProgress, {'trackIndex': 4, 'positionSeconds': 12.5});
  });

  test(
    'music catalog filters are passed through to paginated endpoint',
    () async {
      await client.fetchMusicSongs(page: 2, size: 200, albumId: 7, artistId: 3);
      expect(musicQuery?.queryParameters, {
        'page': '2',
        'size': '200',
        'albumId': '7',
        'artistId': '3',
      });
    },
  );

  test(
    'lyrics use a fresh signed plain-text URL and preserve UTF-8 body',
    () async {
      final lyrics = await client.fetchMusicLyrics(23);

      expect(lyrics, '[00:01.20]第一句\n[00:02.40]第二句');
      expect(lyricsQuery?.queryParameters, {'exp': '456', 'sig': 'lyrics'});
      expect(lyricsAuthorization, 'Bearer test-token');
      expect(lyricsRequests, 1);
    },
  );

  test('songs without lyrics do not request the lyrics endpoint', () async {
    final before = lyricsRequests;
    expect(await client.fetchMusicLyrics(24), isEmpty);
    expect(lyricsRequests, before);
  });
}
