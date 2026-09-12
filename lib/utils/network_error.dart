import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class NetworkUnavailableException implements Exception {
  const NetworkUnavailableException();

  @override
  String toString() => 'NetworkUnavailableException';
}

bool isNetworkUnavailable(Object error) {
  if (error is NetworkUnavailableException ||
      error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return true;
  }

  // Supabase's retryable transport exception name has changed between SDK
  // versions. Checking its runtime name keeps this helper compatible without
  // coupling the entire app to one package revision.
  final type = error.runtimeType.toString().toLowerCase();
  final message = error.toString().toLowerCase();
  return type.contains('retryablefetch') ||
      type.contains('socket') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('failed to fetch') ||
      message.contains('network request failed') ||
      message.contains('temporary failure in name resolution') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('connection closed') ||
      message.contains('connection reset') ||
      message.contains('connection timed out');
}

Never _throwNetworkUnavailable() =>
    throw const NetworkUnavailableException();

T rethrowAsNetworkUnavailable<T>(Object error) {
  if (isNetworkUnavailable(error)) _throwNetworkUnavailable();
  throw error;
}
