// SPDX-FileCopyrightText: 2026 Magic Lane International B.V. <info@magiclane.com>
// SPDX-License-Identifier: Apache-2.0
//
// Contact Magic Lane at <info@magiclane.com> for SDK licensing options.

import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:activation_companion/models/activation_service_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

/// The REST contract of the Magic Lane activation service, as documented in the SDK guide
/// "Activating the SDK". No authentication is needed: the request blob identifies the application
/// and the device. Every failure is reported as an [ActivationServiceException].
class ActivationServiceClient {
  ActivationServiceClient({HttpClientAdapter? httpClientAdapter})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: _timeout,
          receiveTimeout: _timeout,
          // Every answer is returned as text, whatever its status and Content-Type, and decoded below.
          // Dio then throws only when there is no answer at all.
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      ) {
    if (httpClientAdapter != null) _dio.httpClientAdapter = httpClientAdapter;
  }

  static const _timeout = Duration(seconds: 20);

  // Answered by the gateway in front of the service, which did not pass the request on.
  static const _gatewayErrors = {502, 503, 504};

  final Dio _dio;

  /// The base URLs of the activation service, from the `service_id` 3 entry of the services list:
  ///   GET https://m71os.services.magicearthsdk.com/services_list_json
  ///   200 [..., {"service_id": 3, "URLs": ["https://...", "https://..."]}, ...]
  Future<List<String>> fetchServiceUrls() async {
    final response = await _send('https://m71os.services.magicearthsdk.com/services_list_json', method: 'GET');
    if (response.statusCode != 200) {
      throw ActivationServiceException(
        'Magic Lane Services are not available right now. Try again later.',
        statusCode: response.statusCode,
      );
    }

    final Object? services;
    try {
      services = jsonDecode(response.data ?? '');
    } on FormatException {
      throw ActivationServiceException(
        'Magic Lane Services sent an unexpected answer. Try again later.',
        statusCode: response.statusCode,
      );
    }

    if (services is List) {
      for (final service in services) {
        if (service case {'service_id': 3, 'URLs': final List urls}) return urls.whereType<String>().toList();
      }
    }
    throw ActivationServiceException(
      'Magic Lane Services are not available right now. Try again later.',
      statusCode: response.statusCode,
    );
  }

  /// Exchanges an activation request blob for the 20 character key that completes the offline activation:
  ///   POST {serviceUrl}/services/tokens/v1/activations  {"request_blob": "..."}
  ///   200  {"response_blob": "...", "offline_activation_key": "..."}
  Future<String> requestOfflineActivationKey(String serviceUrl, String requestBlob) =>
      _requestOfflineKey(serviceUrl, requestBlob, method: 'POST', keyField: 'offline_activation_key');

  /// Exchanges a deactivation request blob for the 20 character key that completes the offline deactivation:
  ///   DELETE {serviceUrl}/services/tokens/v1/activations  {"request_blob": "..."}
  ///   200    {"response_blob": "...", "offline_deactivation_key": "..."}
  Future<String> requestOfflineDeactivationKey(String serviceUrl, String requestBlob) =>
      _requestOfflineKey(serviceUrl, requestBlob, method: 'DELETE', keyField: 'offline_deactivation_key');

  // Both answer an error as {"error": -15, "message": "Could not decode request blob!", "activation_id": ""}.
  Future<String> _requestOfflineKey(
    String serviceUrl,
    String requestBlob, {
    required String method,
    required String keyField,
  }) async {
    final response = await _send(
      '$serviceUrl/services/tokens/v1/activations',
      method: method,
      data: {'request_blob': requestBlob},
    );
    if (response.statusCode != 200) throw _rejection(response);

    final Object? json;
    try {
      json = jsonDecode(response.data ?? '');
    } on FormatException {
      throw ActivationServiceException(
        'Magic Lane Services sent an unexpected answer. Try again later.',
        statusCode: response.statusCode,
      );
    }

    final key = json is Map ? json[keyField] : null;
    if (key is! String || key.length != 20) {
      throw ActivationServiceException(
        'Magic Lane Services sent an unexpected answer. Try again later.',
        statusCode: response.statusCode,
      );
    }
    return key;
  }

  // The answer of the service itself, whatever its status. A gateway error is reported here, as its body
  // comes from the gateway and not from the service.
  Future<Response<String>> _send(String url, {required String method, Object? data}) async {
    // Set once the whole request body has gone out. In the browser, Dio reports this from the upload events.
    var bodySent = false;
    final Response<String> response;
    try {
      response = await _dio.request<String>(
        url,
        data: data,
        options: Options(method: method),
        onSendProgress: data == null
            ? null
            : (sent, total) {
                if (total <= 0 || sent >= total) bodySent = true;
              },
      );
    } on DioException catch (error) {
      throw ActivationServiceException(
        'Could not reach Magic Lane Services. Check the internet connection.',
        isUnprocessed: wasNotSent(error, bodySent: bodySent),
      );
    }

    if (_gatewayErrors.contains(response.statusCode)) {
      throw ActivationServiceException(
        'Magic Lane Services are not available right now. Try again later.',
        statusCode: response.statusCode,
        isUnprocessed: true,
      );
    }
    return response;
  }

  // True when the request certainly did not reach the service.
  // On Android and iOS, Dio reports a failure to connect as a connect timeout, or as a connection error with a
  // SocketException; a failure once connected comes as another type.
  // In the browser every network error looks the same, even after the request was sent, and a connect timeout only
  // means that no answer started within it. There the request is unsent only while its body has not fully gone out:
  // the browser reports the upload of the body, so a server that cannot be reached is still skipped.
  @visibleForTesting
  static bool wasNotSent(DioException error, {required bool bodySent, bool isWeb = kIsWeb}) => isWeb
      ? !bodySent &&
            (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout)
      : error.type == DioExceptionType.connectionTimeout ||
            (error.type == DioExceptionType.connectionError && error.error is SocketException);

  // The service explains a rejection as {"message": "..."} or as one short line of plain text. Any other body, such
  // as the HTML page of a proxy, is not shown.
  static ActivationServiceException _rejection(Response<String> response) {
    final body = response.data?.trim() ?? '';
    String? explanation;
    try {
      explanation = switch (jsonDecode(body)) {
        {'message': final String message} when message.isNotEmpty => message,
        _ => null,
      };
    } on FormatException {
      final isShortLine = body.isNotEmpty && body.length <= 200 && !body.contains('\n');
      explanation = isShortLine && !body.startsWith('<') ? body : null;
    }
    return ActivationServiceException(
      explanation ?? 'Magic Lane Services rejected the request.',
      statusCode: response.statusCode,
    );
  }
}
