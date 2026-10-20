// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'dart:async';

import 'package:activation_companion/bloc/key_request/key_request_bloc.dart';
import 'package:activation_companion/client/activation_service_client.dart';
import 'package:activation_companion/models/activation_service_exception.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_services.dart';

const _key = 'K7RX2M9QPLA4TB6WZC3N';
const _error = ActivationServiceException('Could not decode request blob!', statusCode: 500);

ResponseBody _activationKey(RequestOptions _) => untypedResponse('{"offline_activation_key": "$_key"}');

ResponseBody _serviceError(RequestOptions _) =>
    untypedResponse('{"error":-15,"message":"Could not decode request blob!","activation_id":""}', status: 500);

/// Answers the services list, cannot reach the hosts in [down], and answers every other request with [answer].
FakeServices _services(Responder answer, {Set<String>? down}) => FakeServices((request) {
  if (request.uri.toString() == servicesListUrl) return jsonResponse(servicesList);
  if (down?.contains(request.uri.host) ?? false) unreachable(request);
  return answer(request);
});

/// Like [_services], with the first service URL answering [first] and the others an activation key.
FakeServices _servicesWithFirstUrl(Responder first) =>
    _services((request) => request.uri.host == 'maps1.example.com' ? first(request) : _activationKey(request));

Iterable<RequestOptions> _keyRequests(FakeServices services) =>
    services.requests.where((request) => request.uri.toString() != servicesListUrl);

// Waits for the result, so the next request starts from it.
Future<void> _send(KeyRequestBloc bloc, KeyRequestEvent event) async {
  bloc.add(event);
  await bloc.stream.firstWhere((state) => state is KeyRequestSuccess || state is KeyRequestFailure);
}

final _connectionFailure = isA<KeyRequestFailure>().having((state) => state.error.statusCode, 'statusCode', isNull);

class _BrokenClient extends ActivationServiceClient {
  @override
  Future<List<String>> fetchServiceUrls() => throw StateError('bug');
}

void main() {
  late FakeServices services;

  blocTest<KeyRequestBloc, KeyRequestState>(
    'posts an activation request blob and emits the offline activation key',
    setUp: () => services = _services(_activationKey),
    build: () => KeyRequestBloc(services.client),
    act: (bloc) => _send(bloc, const OfflineActivationKeyRequested('QUJD')),
    expect: () => const [KeyRequestInProgress(), KeyRequestSuccess(_key)],
    verify: (_) {
      final sent = _keyRequests(services).single;
      expect(sent.method, 'POST');
      expect(sent.uri.toString(), '$node1/services/tokens/v1/activations');
      expect(sent.data, {'request_blob': 'QUJD'});
    },
  );

  blocTest<KeyRequestBloc, KeyRequestState>(
    'deletes with a deactivation request blob and emits the offline deactivation key',
    setUp: () => services = _services((_) => untypedResponse('{"offline_deactivation_key": "$_key"}')),
    build: () => KeyRequestBloc(services.client),
    act: (bloc) => _send(bloc, const OfflineDeactivationKeyRequested('QUJD')),
    expect: () => const [KeyRequestInProgress(), KeyRequestSuccess(_key)],
    verify: (_) => expect(_keyRequests(services).single.method, 'DELETE'),
  );

  blocTest<KeyRequestBloc, KeyRequestState>(
    'removes the line breaks and spaces of a pasted request blob',
    setUp: () => services = _services(_activationKey),
    build: () => KeyRequestBloc(services.client),
    act: (bloc) => _send(bloc, const OfflineActivationKeyRequested('  QUJD\r\nRUZH \n')),
    verify: (_) => expect(_keyRequests(services).single.data, {'request_blob': 'QUJDRUZH'}),
  );

  blocTest<KeyRequestBloc, KeyRequestState>(
    'emits the failure reported by the activation service',
    setUp: () => services = _services(_serviceError),
    build: () => KeyRequestBloc(services.client),
    act: (bloc) => _send(bloc, const OfflineActivationKeyRequested('QUJD')),
    expect: () => const [KeyRequestInProgress(), KeyRequestFailure(_error)],
  );

  blocTest<KeyRequestBloc, KeyRequestState>(
    'ends the request with a failure on an unexpected error, and reports the error',
    build: () => KeyRequestBloc(_BrokenClient()),
    act: (bloc) => _send(bloc, const OfflineActivationKeyRequested('QUJD')),
    expect: () => const [
      KeyRequestInProgress(),
      KeyRequestFailure(ActivationServiceException('The key could not be requested. Try again.')),
    ],
    errors: () => [isStateError],
  );

  blocTest<KeyRequestBloc, KeyRequestState>(
    'ignores a request made while another one is in progress',
    setUp: () {
      final pending = Completer<ResponseBody>();
      services = _services((request) => pending.future);
      Future<void>.delayed(Duration.zero, () => pending.complete(_activationKey(RequestOptions())));
    },
    build: () => KeyRequestBloc(services.client),
    act: (bloc) async {
      bloc
        ..add(const OfflineActivationKeyRequested('QUJD'))
        ..add(const OfflineActivationKeyRequested('QUJD'));
      await bloc.stream.firstWhere((state) => state is KeyRequestSuccess);
    },
    expect: () => const [KeyRequestInProgress(), KeyRequestSuccess(_key)],
    verify: (_) => expect(_keyRequests(services), hasLength(1)),
  );

  blocTest<KeyRequestBloc, KeyRequestState>(
    'returns to idle when reset after a result',
    setUp: () => services = _services(_activationKey),
    build: () => KeyRequestBloc(services.client),
    seed: () => const KeyRequestSuccess(_key),
    act: (bloc) => bloc.add(const KeyRequestReset()),
    expect: () => const [KeyRequestIdle()],
  );

  group('service URL', () {
    late Set<String> down;

    blocTest<KeyRequestBloc, KeyRequestState>(
      'keeps the first URL that answers and looks the service up only once',
      setUp: () => services = _services(_activationKey),
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      verify: (_) {
        expect(_keyRequests(services).map((request) => request.uri.host), ['maps1.example.com', 'maps1.example.com']);
        expect(services.requests.where((request) => request.uri.toString() == servicesListUrl), hasLength(1));
      },
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'skips an unreachable URL and keeps the next one, even when the first one comes back',
      setUp: () {
        down = {'maps1.example.com'};
        services = _services(_activationKey, down: down);
      },
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        down.clear();
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      expect: () => const [
        KeyRequestInProgress(),
        KeyRequestSuccess(_key),
        KeyRequestInProgress(),
        KeyRequestSuccess(_key),
      ],
      verify: (_) => expect(_keyRequests(services).map((request) => request.uri.host), [
        'maps1.example.com',
        'maps2.example.com',
        'maps2.example.com',
      ]),
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'reports a failure of the kept URL without switching to another one',
      setUp: () {
        down = {};
        services = _services(_activationKey, down: down);
      },
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        down.add('maps1.example.com');
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      expect: () => [
        const KeyRequestInProgress(),
        const KeyRequestSuccess(_key),
        const KeyRequestInProgress(),
        _connectionFailure,
      ],
      verify: (_) =>
          expect(_keyRequests(services).map((request) => request.uri.host), everyElement('maps1.example.com')),
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'skips a URL whose gateway reports the service unavailable, and keeps the next one',
      setUp: () => services = _servicesWithFirstUrl(badGateway),
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      expect: () => const [
        KeyRequestInProgress(),
        KeyRequestSuccess(_key),
        KeyRequestInProgress(),
        KeyRequestSuccess(_key),
      ],
      verify: (_) => expect(_keyRequests(services).map((request) => request.uri.host), [
        'maps1.example.com',
        'maps2.example.com',
        'maps2.example.com',
      ]),
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'keeps a URL that timed out, as it may have processed the request',
      setUp: () => services = _servicesWithFirstUrl(timedOut),
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      expect: () => [
        const KeyRequestInProgress(),
        _connectionFailure,
        const KeyRequestInProgress(),
        _connectionFailure,
      ],
      verify: (_) =>
          expect(_keyRequests(services).map((request) => request.uri.host), ['maps1.example.com', 'maps1.example.com']),
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'keeps a URL that answered with an error',
      setUp: () => services = _services(_serviceError),
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      verify: (_) =>
          expect(_keyRequests(services).map((request) => request.uri.host), ['maps1.example.com', 'maps1.example.com']),
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'reports a connection failure when no URL answers, and looks the service up again on the next request',
      setUp: () {
        down = {'maps1.example.com', 'maps2.example.com'};
        services = _services(_activationKey, down: down);
      },
      build: () => KeyRequestBloc(services.client),
      act: (bloc) async {
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
        down.remove('maps2.example.com');
        await _send(bloc, const OfflineActivationKeyRequested('QUJD'));
      },
      expect: () => [
        const KeyRequestInProgress(),
        _connectionFailure,
        const KeyRequestInProgress(),
        const KeyRequestSuccess(_key),
      ],
      verify: (_) =>
          expect(services.requests.where((request) => request.uri.toString() == servicesListUrl), hasLength(2)),
    );

    blocTest<KeyRequestBloc, KeyRequestState>(
      'reports a services list without the activation service',
      setUp: () => services = FakeServices((_) => jsonResponse('[{"service_id": 1, "URLs": ["$node1"]}]')),
      build: () => KeyRequestBloc(services.client),
      act: (bloc) => _send(bloc, const OfflineActivationKeyRequested('QUJD')),
      expect: () => [const KeyRequestInProgress(), isA<KeyRequestFailure>()],
    );
  });
}
