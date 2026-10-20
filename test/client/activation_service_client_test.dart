// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'dart:io';

import 'package:activation_companion/client/activation_service_client.dart';
import 'package:activation_companion/models/activation_service_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_services.dart';

const _blob = 'cmVxdWVzdC1ibG9i';
const _offlineKey = 'K7RX2M9QPLA4TB6WZC3N';

void main() {
  group('a request certainly not sent', () {
    final options = RequestOptions(path: '$node1/services/tokens/v1/activations');
    final refused = DioException.connectionError(
      requestOptions: options,
      reason: 'Connection refused',
      error: const SocketException('Connection refused'),
    );
    final browserError = DioException.connectionError(requestOptions: options, reason: 'XMLHttpRequest onError');
    final connectTimeout = DioException.connectionTimeout(
      requestOptions: options,
      timeout: const Duration(seconds: 20),
    );
    final receiveTimeout = DioException.receiveTimeout(requestOptions: options, timeout: const Duration(seconds: 20));
    final closedOnceConnected = DioException(requestOptions: options, error: const HttpException('Connection closed'));

    bool notSent(DioException error, {required bool bodySent, required bool isWeb}) =>
        ActivationServiceClient.wasNotSent(error, bodySent: bodySent, isWeb: isWeb);

    test('in the browser: an error before the body was fully uploaded', () {
      expect(notSent(browserError, bodySent: false, isWeb: true), isTrue);
      expect(notSent(connectTimeout, bodySent: false, isWeb: true), isTrue);
    });

    test('in the browser: not an error once the body was uploaded, which may follow processing', () {
      expect(notSent(browserError, bodySent: true, isWeb: true), isFalse);
      expect(notSent(connectTimeout, bodySent: true, isWeb: true), isFalse);
      expect(notSent(receiveTimeout, bodySent: false, isWeb: true), isFalse);
    });

    test('on Android and iOS: a failure to connect, and nothing once connected', () {
      expect(notSent(refused, bodySent: false, isWeb: false), isTrue);
      expect(notSent(connectTimeout, bodySent: false, isWeb: false), isTrue);
      expect(notSent(closedOnceConnected, bodySent: true, isWeb: false), isFalse);
      expect(notSent(receiveTimeout, bodySent: true, isWeb: false), isFalse);
    });
  });

  test('reads the URLs of the activation service from the services list', () async {
    final services = FakeServices((_) => jsonResponse(servicesList));

    expect(await services.client.fetchServiceUrls(), [node1, node2]);
    expect(services.requests.single.uri.toString(), servicesListUrl);
  });

  test('reports a services list without the activation service', () async {
    final services = FakeServices((_) => jsonResponse('[{"service_id": 1, "URLs": ["$node1"]}]'));

    await expectLater(services.client.fetchServiceUrls(), throwsA(isA<ActivationServiceException>()));
  });

  test('reports an unreachable services list as a connection failure', () async {
    final services = FakeServices(unreachable);

    await expectLater(
      services.client.fetchServiceUrls(),
      throwsA(isA<ActivationServiceException>().having((e) => e.statusCode, 'statusCode', isNull)),
    );
  });

  test('activation posts the blob to the activation service and returns the offline activation key', () async {
    final services = FakeServices(
      (_) => untypedResponse('{"response_blob": "cmVzcG9uc2U=", "offline_activation_key": "$_offlineKey"}'),
    );

    final key = await services.client.requestOfflineActivationKey(node1, _blob);

    expect(key, _offlineKey);
    final sent = services.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.toString(), '$node1/services/tokens/v1/activations');
    expect(sent.data, {'request_blob': _blob});
  });

  test('deactivation sends DELETE and returns the offline deactivation key', () async {
    final services = FakeServices(
      (_) => untypedResponse('{"response_blob": "cmVzcG9uc2U=", "offline_deactivation_key": "$_offlineKey"}'),
    );

    final key = await services.client.requestOfflineDeactivationKey(node1, _blob);

    expect(key, _offlineKey);
    expect(services.requests.single.method, 'DELETE');
  });

  test('reports the message of a JSON error', () async {
    final services = FakeServices(
      (_) =>
          untypedResponse('{"error":-15,"message":"Could not decode request blob!","activation_id":""}', status: 500),
    );

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(const ActivationServiceException('Could not decode request blob!', statusCode: 500)),
    );
  });

  test('reports a plain text error body as the message', () async {
    final services = FakeServices((_) => untypedResponse("can't get customer id", status: 500));

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(const ActivationServiceException("can't get customer id", statusCode: 500)),
    );
  });

  test('reports an unreachable URL as a connection failure that did not process the request', () async {
    final services = FakeServices(unreachable);

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(
        isA<ActivationServiceException>()
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having((e) => e.isUnprocessed, 'isUnprocessed', isTrue),
      ),
    );
  });

  test('reports a timeout as a failure that may have processed the request', () async {
    final services = FakeServices(timedOut);

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(
        isA<ActivationServiceException>()
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having((e) => e.isUnprocessed, 'isUnprocessed', isFalse),
      ),
    );
  });

  test('reports a connection closed before the answer as a failure that may have processed the request', () async {
    final services = FakeServices(closedBeforeAnswer);

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(isA<ActivationServiceException>().having((e) => e.isUnprocessed, 'isUnprocessed', isFalse)),
    );
  });

  test('reports a gateway error as not processed, without the body of the gateway', () async {
    final services = FakeServices(badGateway);

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(
        const ActivationServiceException(
          'Magic Lane Services are not available right now. Try again later.',
          statusCode: 502,
          isUnprocessed: true,
        ),
      ),
    );
  });

  test('does not show an error page as the message', () async {
    final services = FakeServices(
      (_) => untypedResponse('<html>\n<head><title>403 Forbidden</title></head>\n</html>', status: 403),
    );

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(const ActivationServiceException('Magic Lane Services rejected the request.', statusCode: 403)),
    );
  });

  test('rejects an offline key that is not 20 characters long', () async {
    final services = FakeServices((_) => untypedResponse('{"offline_activation_key": "TOO-SHORT"}'));

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(isA<ActivationServiceException>().having((e) => e.statusCode, 'statusCode', 200)),
    );
  });

  test('rejects a successful response that is not JSON', () async {
    final services = FakeServices((_) => untypedResponse('<html>ok</html>'));

    await expectLater(
      services.client.requestOfflineActivationKey(node1, _blob),
      throwsA(isA<ActivationServiceException>()),
    );
  });
}
