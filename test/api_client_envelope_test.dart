import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fryfrog_hub/core/network/api_client.dart';

/// C2+C3 回归：后端 `ApiResponse{success,message,data}` 的失败有两种投递方式，
/// 前者是 HTTP 4xx/5xx，**后者是 HTTP 200 + success=false**（`ApiResponse.error`）。
/// 只看 HTTP 状态码的写接口会把失败当成功——UI 提示"已设置"，实际什么都没写。
///
/// 这里起一个真实的 loopback HttpServer：`package:http` 走 `dart:io`，
/// 换 `HttpOverrides` 伪造反而要实现一大堆接口，起服务更接近线上路径。

typedef _Reply = ({int status, Object? json});

void main() {
  late HttpServer server;
  late ApiClient client;

  /// 每个用例先给 `reply` 赋值，服务端再按它回包。
  _Reply Function(HttpRequest req, String body) reply = (req, body) =>
      throw StateError('reply not set');

  setUpAll(() async {
    // flutter_test 默认装的 HttpOverrides 会把所有请求挡掉，必须先摘掉。
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = ApiClient('http://127.0.0.1:${server.port}', token: 't');
    server.listen((req) async {
      try {
        final body = await utf8.decoder.bind(req).join();
        final r = reply(req, body);
        req.response.statusCode = r.status;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(r.json));
        await req.response.close();
      } catch (_) {
        req.response.statusCode = 500;
        await req.response.close();
      }
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  group('C3 写接口必须认 success=false', () {
    test('setSeriesLogo：200 + success=false 要抛出并透出后端 message', () async {
      reply = (req, body) => (
        status: 200,
        json: {'success': false, 'message': '系列没有 TMDB ID，无法设置 logo'},
      );

      await expectLater(
        client.setSeriesLogo(7, filePath: '/tmp/a.jpg'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '系列没有 TMDB ID，无法设置 logo',
          ),
        ),
      );
    });

    test('deleteWatchProgress（DELETE）：success=false 不能被吞掉', () async {
      reply = (req, body) =>
          (status: 200, json: {'success': false, 'message': '磁盘异常，已拒绝'});

      await expectLater(
        client.deleteWatchProgress(11),
        throwsA(isA<ApiException>()),
      );
    });

    test('saveEbookProgress（PUT）：进度写失败要让上层重试', () async {
      reply = (req, body) =>
          (status: 200, json: {'success': false, 'message': '进度校验失败'});

      await expectLater(
        client.saveEbookProgress(3, positionPercent: 50, chapterIndex: 1),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '进度校验失败'),
        ),
      );
    });

    test('success=true 照常放行（不管有没有 data）', () async {
      reply = (req, body) => (status: 200, json: {'success': true});

      await client.setSeriesLogo(7, filePath: '/tmp/a.jpg');
      await client.deleteWatchProgress(11);
      await client.saveEbookProgress(3, positionPercent: 50, chapterIndex: 1);
    });

    test('HTTP 4xx 的后端 message 仍然透出（FastAPI detail 数组不再炸类型）', () async {
      reply = (req, body) => (
        status: 400,
        json: {
          'detail': [
            {
              'loc': ['body', 'position'],
              'msg': 'field required',
            },
          ],
        },
      );

      await expectLater(
        client.saveEbookProgress(3, positionPercent: 50, chapterIndex: 1),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'field required'),
        ),
      );
    });
  });

  group('C2 uploadCover 必须认 HTTP 状态码', () {
    test('401/403 之类没有 success 键的错误体：状态码与文案都要透出', () async {
      reply = (req, body) =>
          (status: 401, json: {'detail': 'Not authenticated'});

      await expectLater(
        client.uploadCover(
          11,
          bytes: utf8.encode('x'),
          filename: 'a.png',
          level: 'episode',
          kind: 'poster',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Not authenticated'),
        ),
      );
    });

    test('200 + success=false 的业务校验失败照常抛出', () async {
      reply = (req, body) =>
          (status: 200, json: {'success': false, 'message': '图片格式不支持'});

      await expectLater(
        client.uploadCover(
          11,
          bytes: utf8.encode('x'),
          filename: 'a.png',
          level: 'episode',
          kind: 'poster',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '图片格式不支持'),
        ),
      );
    });

    test('真成功时返回后端给的 path', () async {
      reply = (req, body) => (
        status: 200,
        json: {
          'success': true,
          'data': {'path': '/covers/a.jpg'},
        },
      );

      final path = await client.uploadCover(
        11,
        bytes: utf8.encode('x'),
        filename: 'a.png',
        level: 'episode',
        kind: 'poster',
      );
      expect(path, '/covers/a.jpg');
    });
  });

  group('_unwrap 可空返回', () {
    test('信封没有 data 时，可空返回的接口拿到 null 而不是 500', () async {
      // 后端 ApiResponse 带 exclude_none：`ApiResponse.ok(null)` 只回
      // `{"success":true}`，data 键整个消失。
      reply = (req, body) => (status: 200, json: {'success': true});

      await expectLater(
        client.saveWatchProgress(11, position: 10, duration: 100),
        completion(isNull),
      );
    });

    test('非空返回的接口仍会在缺 data 时报错', () async {
      reply = (req, body) => (status: 200, json: {'success': true});

      await expectLater(
        client.me(),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '响应缺少 data'),
        ),
      );
    });
  });
}
