import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pam_ll2_http/data/network/http_json_client.dart';
import 'package:pam_ll2_http/domain/entities/store_failure.dart';

void main() {
  test(
    'preserves API prefix and serializes JSON with correct headers',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:8080/api/profile');
        expect(request.method, 'PUT');
        expect(request.body, '{"name":"Test"}');
        expect(request.headers['content-type'], contains('application/json'));
        return http.Response('{"ok":true}', 200);
      });
      addTearDown(client.close);
      final api = HttpJsonClient(
        client: client,
        baseUrl: 'http://localhost:8080/api',
      );
      expect(await api.request('PUT', 'profile', body: {'name': 'Test'}), {
        'ok': true,
      });
    },
  );
  test('maps non-JSON HTTP errors to a typed failure', () async {
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    addTearDown(client.close);
    final api = HttpJsonClient(client: client, baseUrl: 'http://localhost/api');
    await expectLater(
      api.request('GET', 'catalog'),
      throwsA(
        isA<StoreFailure>().having((f) => f.statusCode, 'statusCode', 503),
      ),
    );
  });
  test('rejects malformed successful JSON', () async {
    final client = MockClient((_) async => http.Response('[]', 200));
    addTearDown(client.close);
    await expectLater(
      HttpJsonClient(
        client: client,
        baseUrl: 'http://localhost/api',
      ).request('GET', 'catalog'),
      throwsA(isA<StoreFailure>()),
    );
  });
  test('accepts 204 with an empty body', () async {
    final client = MockClient((_) async => http.Response('', 204));
    addTearDown(client.close);
    expect(
      await HttpJsonClient(
        client: client,
        baseUrl: 'http://localhost/api',
      ).request('DELETE', 'review'),
      isEmpty,
    );
  });
  test('maps connection errors and timeouts', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      HttpJsonClient(
        client: client,
        baseUrl: 'http://localhost/api',
      ).request('GET', 'catalog'),
      throwsA(isA<StoreFailure>()),
    );
    final pending = Completer<http.Response>();
    final delayed = MockClient((_) => pending.future);
    addTearDown(delayed.close);
    await expectLater(
      HttpJsonClient(
        client: delayed,
        baseUrl: 'http://localhost/api',
        timeout: const Duration(milliseconds: 5),
      ).request('GET', 'catalog'),
      throwsA(isA<StoreFailure>()),
    );
    pending.complete(http.Response('{}', 200));
  });
}
