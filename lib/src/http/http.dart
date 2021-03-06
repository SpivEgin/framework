/// Various libraries useful for creating highly-extensible servers.
library angel_framework.http;

import 'dart:async';
import 'dart:io';
import 'server.dart' show ServerGenerator;
export 'package:angel_route/angel_route.dart';
export 'package:body_parser/body_parser.dart' show FileUploadInfo;
export 'angel_base.dart';
export 'angel_http_exception.dart';
export 'anonymous_service.dart';
export 'base_middleware.dart';
export 'base_plugin.dart';
export 'controller.dart';
export 'fatal_error.dart';
export 'hooked_service.dart';
export 'map_service.dart';
export 'metadata.dart';
export 'memory_service.dart';
export 'request_context.dart';
export 'response_context.dart';
export 'routable.dart';
export 'server.dart';
export 'service.dart';
export 'typed_service.dart';

/// Boots a shared server instance. Use this if launching multiple isolates
Future<HttpServer> startShared(InternetAddress address, int port) => HttpServer
    .bind(address ?? InternetAddress.LOOPBACK_IP_V4, port ?? 0, shared: true);

/// Boots a secure shared server instance. Use this if launching multiple isolates
ServerGenerator startSharedSecure(SecurityContext securityContext) {
  return (InternetAddress address, int port) => HttpServer.bindSecure(
      address ?? InternetAddress.LOOPBACK_IP_V4, port ?? 0, securityContext,
      shared: true);
}
