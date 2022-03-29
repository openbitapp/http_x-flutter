import 'dart:convert';
import 'dart:typed_data';
import 'package:bitapp_http_x/src/client_platform.dart'
    if (dart.library.html) 'package:bitapp_http_x/src/client_web.dart';
import 'package:http/http.dart';

/// Sends an HTTP HEAD request with the given headers to the given URL.
///
/// This automatically initializes a new [Client] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [Client] for all of those requests.
///
/// For more fine-grained control over the request, use [Request] instead.
Future<Response> custom_head(Uri url, {Map<String, String>? headers, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) => client.head(url, headers: headers));

/// Sends an HTTP GET request with the given headers to the given URL.
///
/// This automatically initializes a new [Client] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [Client] for all of those requests.
///
/// For more fine-grained control over the request, use [Request] instead.
Future<Response> custom_get(Uri url, {Map<String, String>? headers, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) => client.get(url, headers: headers));

/// Sends an HTTP POST request with the given headers and body to the given URL.
///
/// [body] sets the body of the request. It can be a [String], a [List<int>] or
/// a [Map<String, String>]. If it's a String, it's encoded using [encoding] and
/// used as the body of the request. The content-type of the request will
/// default to "text/plain".
///
/// If [body] is a List, it's used as a list of bytes for the body of the
/// request.
///
/// If [body] is a Map, it's encoded as form fields using [encoding]. The
/// content-type of the request will be set to
/// `"application/x-www-form-urlencoded"`; this cannot be overridden.
///
/// [encoding] defaults to [utf8].
///
/// For more fine-grained control over the request, use [Request] or
/// [StreamedRequest] instead.
Future<Response> custom_post(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) =>
        client.post(url, headers: headers, body: body, encoding: encoding));

/// Sends an HTTP PUT request with the given headers and body to the given URL.
///
/// [body] sets the body of the request. It can be a [String], a [List<int>] or
/// a [Map<String, String>]. If it's a String, it's encoded using [encoding] and
/// used as the body of the request. The content-type of the request will
/// default to "text/plain".
///
/// If [body] is a List, it's used as a list of bytes for the body of the
/// request.
///
/// If [body] is a Map, it's encoded as form fields using [encoding]. The
/// content-type of the request will be set to
/// `"application/x-www-form-urlencoded"`; this cannot be overridden.
///
/// [encoding] defaults to [utf8].
///
/// For more fine-grained control over the request, use [Request] or
/// [StreamedRequest] instead.
Future<Response> custom_put(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) =>
        client.put(url, headers: headers, body: body, encoding: encoding));

/// Sends an HTTP PATCH request with the given headers and body to the given
/// URL.
///
/// [body] sets the body of the request. It can be a [String], a [List<int>] or
/// a [Map<String, String>]. If it's a String, it's encoded using [encoding] and
/// used as the body of the request. The content-type of the request will
/// default to "text/plain".
///
/// If [body] is a List, it's used as a list of bytes for the body of the
/// request.
///
/// If [body] is a Map, it's encoded as form fields using [encoding]. The
/// content-type of the request will be set to
/// `"application/x-www-form-urlencoded"`; this cannot be overridden.
///
/// [encoding] defaults to [utf8].
///
/// For more fine-grained control over the request, use [Request] or
/// [StreamedRequest] instead.
Future<Response> custom_patch(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) =>
        client.patch(url, headers: headers, body: body, encoding: encoding));

/// Sends an HTTP DELETE request with the given headers to the given URL.
///
/// This automatically initializes a new [Client] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [Client] for all of those requests.
///
/// For more fine-grained control over the request, use [Request] instead.
Future<Response> custom_delete(Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) =>
        client.delete(url, headers: headers, body: body, encoding: encoding));

/// Sends an HTTP GET request with the given headers to the given URL and
/// returns a Future that completes to the body of the response as a [String].
///
/// The Future will emit a [ClientException] if the response doesn't have a
/// success status code.
///
/// This automatically initializes a new [Client] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [Client] for all of those requests.
///
/// For more fine-grained control over the request and response, use [Request]
/// instead.
Future<String> custom_read(Uri url, {Map<String, String>? headers, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) => client.read(url, headers: headers));

/// Sends an HTTP GET request with the given headers to the given URL and
/// returns a Future that completes to the body of the response as a list of
/// bytes.
///
/// The Future will emit a [ClientException] if the response doesn't have a
/// success status code.
///
/// This automatically initializes a new [Client] and closes that client once
/// the request is complete. If you're planning on making multiple requests to
/// the same server, you should use a single [Client] for all of those requests.
///
/// For more fine-grained control over the request and response, use [Request]
/// instead.
Future<Uint8List> custom_readBytes(Uri url, {Map<String, String>? headers, bool trustBadCertificates = false}) =>
    _withClient(trustBadCertificates, (client) => client.readBytes(url, headers: headers));

Future<T> _withClient<T>(bool trustBadCertificates, Future<T> Function(Client) fn) async {
  var client = getClient(trustBadCertificates);

  try {
    return await fn(client);
  } finally {
    client.close();
  }
}