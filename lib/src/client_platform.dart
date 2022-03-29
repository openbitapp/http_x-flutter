import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';

BaseClient getClient(bool trustBadCertificates) {
  var httpClient = HttpClient()
    ..badCertificateCallback =
    ((X509Certificate cert, String host, int port) => trustBadCertificates);

  return IOClient(httpClient);
}