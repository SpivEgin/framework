library angel_framework.http.angel_http_exception;

import 'dart:convert';

/// Basically the same as
/// [feathers-errors](https://github.com/feathersjs/feathers-errors).
class AngelHttpException implements Exception {
  var error;

  /// A list of errors that occurred when this exception was thrown.
  final List<String> errors = [];

  /// The cause of this exception.
  String message;

  /// The [StackTrace] associated with this error.
  StackTrace stackTrace;

  /// An HTTP status code this exception will throw.
  int statusCode;

  AngelHttpException(this.error,
      {this.message: '500 Internal Server Error',
      this.stackTrace,
      this.statusCode: 500,
      List<String> errors: const []}) {
    if (errors != null) {
      this.errors.addAll(errors);
    }
  }

  Map toJson() {
    return {
      'isError': true,
      'statusCode': statusCode,
      'message': message,
      'errors': errors
    };
  }

  Map toMap() => toJson();

  @override
  String toString() {
    return "$statusCode: $message";
  }

  factory AngelHttpException.fromMap(Map data) {
    return new AngelHttpException(null,
        statusCode: data['statusCode'],
        message: data['message'],
        errors: data['errors']);
  }

  factory AngelHttpException.fromJson(String json) =>
      new AngelHttpException.fromMap(JSON.decode(json));

  /// Throws a 400 Bad Request error, including an optional arrray of (validation?)
  /// errors you specify.
  factory AngelHttpException.badRequest(
          {String message: '400 Bad Request', List<String> errors: const []}) =>
      new AngelHttpException(null,
          message: message, errors: errors, statusCode: 400);

  /// Throws a 401 Not Authenticated error.
  factory AngelHttpException.notAuthenticated(
          {String message: '401 Not Authenticated'}) =>
      new AngelHttpException(null, message: message, statusCode: 401);

  /// Throws a 402 Payment Required error.
  factory AngelHttpException.paymentRequired(
          {String message: '402 Payment Required'}) =>
      new AngelHttpException(null, message: message, statusCode: 402);

  /// Throws a 403 Forbidden error.
  factory AngelHttpException.forbidden({String message: '403 Forbidden'}) =>
      new AngelHttpException(null, message: message, statusCode: 403);

  /// Throws a 404 Not Found error.
  factory AngelHttpException.notFound({String message: '404 Not Found'}) =>
      new AngelHttpException(null, message: message, statusCode: 404);

  /// Throws a 405 Method Not Allowed error.
  factory AngelHttpException.methodNotAllowed(
          {String message: '405 Method Not Allowed'}) =>
      new AngelHttpException(null, message: message, statusCode: 405);

  /// Throws a 406 Not Acceptable error.
  factory AngelHttpException.notAcceptable(
          {String message: '406 Not Acceptable'}) =>
      new AngelHttpException(null, message: message, statusCode: 406);

  /// Throws a 408 Timeout error.
  factory AngelHttpException.methodTimeout({String message: '408 Timeout'}) =>
      new AngelHttpException(null, message: message, statusCode: 408);

  /// Throws a 409 Conflict error.
  factory AngelHttpException.conflict({String message: '409 Conflict'}) =>
      new AngelHttpException(null, message: message, statusCode: 409);

  /// Throws a 422 Not Processable error.
  factory AngelHttpException.notProcessable(
          {String message: '422 Not Processable'}) =>
      new AngelHttpException(null, message: message, statusCode: 422);

  /// Throws a 501 Not Implemented error.
  factory AngelHttpException.notImplemented(
          {String message: '501 Not Implemented'}) =>
      new AngelHttpException(null, message: message, statusCode: 501);

  /// Throws a 503 Unavailable error.
  factory AngelHttpException.unavailable({String message: '503 Unavailable'}) =>
      new AngelHttpException(null, message: message, statusCode: 503);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.BadRequest(
          {String message: '400 Bad Request', List<String> errors: const []}) =>
      new AngelHttpException(null,
          message: message, errors: errors, statusCode: 400);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.NotAuthenticated(
          {String message: '401 Not Authenticated'}) =>
      new AngelHttpException(null, message: message, statusCode: 401);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.PaymentRequired(
          {String message: '402 Payment Required'}) =>
      new AngelHttpException(null, message: message, statusCode: 402);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.Forbidden({String message: '403 Forbidden'}) =>
      new AngelHttpException(null, message: message, statusCode: 403);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.NotFound({String message: '404 Not Found'}) =>
      new AngelHttpException(null, message: message, statusCode: 404);

  @deprecated

  /// DEPRECATED: Use lowercase constructor instead.
  factory AngelHttpException.MethodNotAllowed(
          {String message: '405 Method Not Allowed'}) =>
      new AngelHttpException(null, message: message, statusCode: 405);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.NotAcceptable(
          {String message: '406 Not Acceptable'}) =>
      new AngelHttpException(null, message: message, statusCode: 406);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.MethodTimeout({String message: '408 Timeout'}) =>
      new AngelHttpException(null, message: message, statusCode: 408);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.Conflict({String message: '409 Conflict'}) =>
      new AngelHttpException(null, message: message, statusCode: 409);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.NotProcessable(
          {String message: '422 Not Processable'}) =>
      new AngelHttpException(null, message: message, statusCode: 422);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.NotImplemented(
          {String message: '501 Not Implemented'}) =>
      new AngelHttpException(null, message: message, statusCode: 501);

  /// DEPRECATED: Use lowercase constructor instead.
  @deprecated
  factory AngelHttpException.Unavailable({String message: '503 Unavailable'}) =>
      new AngelHttpException(null, message: message, statusCode: 503);
}
