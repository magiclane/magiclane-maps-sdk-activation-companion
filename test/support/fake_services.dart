// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:activation_companion/client/activation_service_client.dart';
import 'package:dio/dio.dart';

const servicesListUrl = 'https://m71os.services.magicearthsdk.com/services_list_json';
const node1 = 'https://maps1.example.com';
const node2 = 'https://maps2.example.com';

// Mirrors the real list: several services, each with its node URLs.
const servicesList =
    '[{"service_id": 1, "URLs": ["$node1", "$node2"]}, '
    '{"service_id": 3, "URLs": ["$node1", "$node2"]}, '
    '{"service_id": 4, "URLs": ["$node1"]}]';

typedef Responder = FutureOr<ResponseBody> Function(RequestOptions request);

/// Magic Lane Services replaced at the HTTP level: records every request and answers with [Responder].
class FakeServices implements HttpClientAdapter {
  FakeServices(this._respond);

  final Responder _respond;
  final requests = <RequestOptions>[];

  ActivationServiceClient get client => ActivationServiceClient(httpClientAdapter: this);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

// The activation endpoints answer without a Content-Type header.
ResponseBody untypedResponse(String body, {int status = 200}) => ResponseBody.fromString(body, status);

Never unreachable(RequestOptions request) => throw DioException.connectionError(
  requestOptions: request,
  reason: 'Connection refused',
  error: const SocketException('Connection refused'),
);

// The request was sent, so the service may have processed it.
Never closedBeforeAnswer(RequestOptions request) => throw DioException.connectionError(
  requestOptions: request,
  reason: 'Connection closed before full header was received',
  error: const HttpException('Connection closed before full header was received'),
);

// The request was sent, so the service may have processed it.
Never timedOut(RequestOptions request) =>
    throw DioException.receiveTimeout(timeout: const Duration(seconds: 20), requestOptions: request);

ResponseBody badGateway(RequestOptions _) => untypedResponse('<html>502 Bad Gateway</html>', status: 502);
