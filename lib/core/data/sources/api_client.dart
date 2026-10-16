import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Failure raised by [ApiClient] for any transport, status or parse problem.
///
/// The data layer converts every network fault into this single type so callers
/// can degrade to cache/seed content without pattern-matching on Dio internals.
class ApiException implements Exception {
  /// Creates an exception describing [message].
  ApiException(this.message, {this.statusCode, this.uri});

  /// Human-readable cause. Never contains credentials.
  final String message;

  /// HTTP status when the server answered; `null` for timeouts and I/O errors.
  final int? statusCode;

  /// Requested resource, kept for diagnostics.
  final Uri? uri;

  @override
  String toString() => statusCode == null
      ? 'ApiException: $message'
      : 'ApiException($statusCode): $message';
}

/// A decoded response plus the metadata callers need for pagination.
///
/// Paginated endpoints in this ecosystem report totals through headers
/// (`X-Total-Count`) rather than the body, so the header map is part of the
/// contract instead of an implementation detail.
@immutable
class ApiResponse {
  /// Wraps a decoded response body.
  const ApiResponse({
    required this.data,
    this.statusCode,
    this.headers = const <String, String>{},
  });

  /// Decoded JSON (map/list) or raw text, depending on the requested type.
  final dynamic data;

  /// HTTP status, `null` when the transport never produced a response.
  final int? statusCode;

  /// Response headers with lower-cased names.
  final Map<String, String> headers;

  /// Parses a numeric header such as `X-Total-Count`; `null` when absent.
  int? intHeader(String name) {
    final String? raw = headers[name.toLowerCase()];
    return raw == null ? null : int.tryParse(raw.trim());
  }
}

/// Thin JSON/text HTTP client with per-request timeouts and pluggable auth.
///
/// A [Dio] instance is injectable so tests can drive the client with a mock
/// adapter (no mocking package required) and so the app can add interceptors.
///
/// Authentication is split by risk:
/// * [defaultHeaders] are sent to **every** host, so they must never carry a
///   credential — only protocol headers such as `accept`.
/// * [authTokenProvider] supplies a session token that is attached **only** to
///   hosts listed in `authTokenHosts` (constructor argument); with no allow-list
///   the token is never sent. This is what keeps a Clerk JWT away from the
///   third-party publishers this same client fetches feeds from.
/// * Endpoint-specific keys (the SLNews scraper API key) belong in the calling
///   source's own per-request headers.
class ApiClient {
  /// Creates a client, optionally wrapping an existing [dio] instance.
  ApiClient({
    Dio? dio,
    this.timeout = const Duration(seconds: 8),
    this.authTokenProvider,
    Set<String> authTokenHosts = const <String>{},
    Map<String, String> defaultHeaders = const <String, String>{},
  }) : _dio = dio ?? Dio(),
       _authTokenHosts = <String>{
         for (final String host in authTokenHosts) host.toLowerCase(),
       },
       _defaultHeaders = Map<String, String>.unmodifiable(defaultHeaders) {
    _dio.options = _dio.options.copyWith(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
      responseType: ResponseType.json,
      headers: <String, dynamic>{
        'accept': 'application/json, application/rss+xml, application/atom+xml, text/xml, */*',
        ..._dio.options.headers,
      },
    );
  }

  /// Default per-request budget; the data layer treats this as "give up and use
  /// what we already have" rather than as a hard failure.
  final Duration timeout;

  /// Supplies the current session token, or `null` when signed out.
  ///
  /// Called per request so a refreshed session is picked up without rebuilding
  /// the client; a throwing provider degrades to "no token" rather than failing
  /// the request. The token is only attached to hosts in [authTokenHosts].
  final Future<String?> Function()? authTokenProvider;

  /// Hosts allowed to receive the session token.
  ///
  /// Empty by default: a token is never sent anywhere unless a host is listed,
  /// which is what keeps a Clerk JWT from leaking to the third-party publishers
  /// whose feeds this same client fetches.
  final Set<String> _authTokenHosts;

  final Dio _dio;
  final Map<String, String> _defaultHeaders;

  /// Applies a per-source request budget to this client.
  ///
  /// Sources that know better than the shared default (the SLNews scraper API
  /// runs on a cold-starting free tier) tighten or widen the budget here.
  void setTimeout(Duration timeout) {
    _dio.options = _dio.options.copyWith(
      connectTimeout: timeout,
      receiveTimeout: timeout,
      sendTimeout: timeout,
    );
  }

  /// Performs a GET and returns the body with its status and headers.
  Future<ApiResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    ResponseType responseType = ResponseType.json,
  }) async {
    final Response<dynamic> response = await _send(
      () async => _dio.get<dynamic>(
        url,
        queryParameters: query,
        options: await _options(
          url: url,
          headers: headers,
          responseType: responseType,
        ),
      ),
    );
    return ApiResponse(
      data: responseType == ResponseType.json ? _payload(response) : _text(response),
      statusCode: response.statusCode,
      headers: _responseHeaders(response),
    );
  }

  /// Decoded JSON from a GET request.
  Future<dynamic> getJson(String url, {Map<String, dynamic>? query}) async {
    final ApiResponse response = await get(url, query: query);
    return response.data;
  }

  /// Raw body from a GET request, used for XML feeds.
  Future<String> getText(String url, {Map<String, dynamic>? query}) async {
    final ApiResponse response = await get(
      url,
      query: query,
      responseType: ResponseType.plain,
    );
    return response.data?.toString() ?? '';
  }

  /// Decoded JSON from a POST request.
  Future<dynamic> postJson(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final Response<dynamic> response = await _send(
      () async => _dio.post<dynamic>(
        url,
        data: body,
        options: (await _options(url: url, headers: headers)).copyWith(
          contentType: Headers.jsonContentType,
        ),
      ),
    );
    return _payload(response);
  }

  Future<Options> _options({
    required String url,
    Map<String, String>? headers,
    ResponseType responseType = ResponseType.json,
  }) async {
    final Map<String, String> merged = <String, String>{
      ..._defaultHeaders,
      ...?headers,
    };
    if (_allowsSessionToken(url)) {
      final String? token = await _resolveToken();
      if (token != null && token.isNotEmpty) {
        merged['authorization'] = 'Bearer $token';
      }
    }
    // A blank value is how a source drops a header the shared client set (the
    // SLNews scraper's open /api/health probe must not carry its bearer token),
    // so blank entries are removed rather than sent as empty headers.
    merged.removeWhere((String _, String value) => value.trim().isEmpty);
    return Options(
      responseType: responseType,
      headers: merged.isEmpty ? null : merged,
    );
  }

  /// True when [url]'s host is explicitly allowed to receive the session token.
  bool _allowsSessionToken(String url) {
    if (_authTokenHosts.isEmpty) return false;
    final String? host = Uri.tryParse(url)?.host.toLowerCase();
    return host != null && host.isNotEmpty && _authTokenHosts.contains(host);
  }

  Future<String?> _resolveToken() async {
    final Future<String?> Function()? provider = authTokenProvider;
    if (provider == null) return null;
    try {
      return await provider();
    } catch (error) {
      debugPrint('ApiClient: session token unavailable ($error)');
      return null;
    }
  }

  Future<Response<dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      debugPrint(
        'ApiClient: ${error.requestOptions.uri} failed (${error.type.name}): ${error.message}',
      );
      throw _toApiException(error);
    } on FormatException catch (error) {
      throw ApiException('Malformed response: ${error.message}');
    } catch (error) {
      throw ApiException('Unexpected request failure: $error');
    }
  }

  Object? _payload(Response<dynamic> response) {
    final Object? data = response.data;
    // `ResponseType.json` leaves the body as a String when the server did not
    // advertise JSON; decode it here so callers always get maps and lists.
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } on FormatException {
        throw ApiException(
          'Expected JSON but the response was not parseable',
          statusCode: response.statusCode,
          uri: response.requestOptions.uri,
        );
      }
    }
    return data;
  }

  String _text(Response<dynamic> response) {
    final Object? data = response.data;
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data, allowMalformed: true);
    if (data == null) return '';
    return data.toString();
  }

  Map<String, String> _responseHeaders(Response<dynamic> response) {
    return <String, String>{
      for (final MapEntry<String, List<String>> entry in response.headers.map.entries)
        entry.key.toLowerCase(): entry.value.join(', '),
    };
  }

  ApiException _toApiException(DioException error) {
    final Uri uri = error.requestOptions.uri;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(
          'Timed out after ${timeout.inMilliseconds}ms',
          uri: uri,
        );
      case DioExceptionType.badResponse:
        final int status = error.response?.statusCode ?? 0;
        final String reason = error.response?.statusMessage?.trim() ?? '';
        return ApiException(
          'HTTP $status${reason.isEmpty ? '' : ' $reason'}',
          statusCode: status,
          uri: uri,
        );
      case DioExceptionType.badCertificate:
        return ApiException('TLS certificate rejected', uri: uri);
      case DioExceptionType.connectionError:
        return ApiException('Could not reach the server', uri: uri);
      case DioExceptionType.cancel:
        return ApiException('Request cancelled', uri: uri);
      case DioExceptionType.unknown:
        return ApiException(
          error.message?.trim().isNotEmpty ?? false
              ? error.message!.trim()
              : 'Unknown network failure',
          uri: uri,
        );
    }
  }
}
