import 'dart:io';
import 'package:dio/dio.dart';

/// Converts raw exceptions (DioException, SocketException, etc.) into
/// friendly, user-facing messages that do NOT expose backend URLs,
/// stack traces, or internal error details.
String friendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please check your internet connection and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your internet connection.';
      case DioExceptionType.badCertificate:
        return 'Secure connection failed. Please try again later.';
      case DioExceptionType.cancel:
        return 'Request was cancelled. Please try again.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        // Try to get the backend's user-friendly message if it's a map
        if (data is Map) {
          final msg = data['message'] ?? data['error'] ?? data['msg'];
          if (msg != null && msg is String && msg.isNotEmpty) {
            return msg;
          }
        }
        // Map common HTTP status codes to user messages
        return switch (statusCode) {
          400 => 'Invalid request. Please check your input and try again.',
          401 => 'Your session has expired. Please log in again.',
          403 => 'You do not have permission to perform this action.',
          404 => 'The requested resource was not found.',
          408 => 'Request timed out. Please try again.',
          409 => 'A conflict occurred. Please refresh and try again.',
          422 => 'Invalid data submitted. Please check your input.',
          429 => 'Too many requests. Please wait a moment and try again.',
          500 => 'The server encountered an error. Please try again later.',
          502 => 'Service temporarily unavailable. Please try again later.',
          503 => 'Service is currently unavailable. Please try again later.',
          504 => 'Server took too long to respond. Please try again.',
          _ => fallback,
        };
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return 'No internet connection. Please check your network and try again.';
        }
        return fallback;
    }
  }

  if (error is SocketException) {
    return 'No internet connection. Please check your network and try again.';
  }

  // For strings and other exception types, inspect the string representation
  final raw = error is Exception 
      ? error.toString().replaceFirst('Exception: ', '') 
      : error.toString();

  // If the message looks like a URL or contains raw technical details, don't show it
  if (raw.contains('http') ||
      raw.contains('://') ||
      raw.contains('SocketException') ||
      raw.contains('DioException') ||
      raw.contains('HandshakeException') ||
      raw.contains('FormatException') ||
      raw.contains('TypeError') ||
      raw.contains('NullThrownError') ||
      raw.contains('NoSuchMethodError') ||
      raw.contains('DatabaseException') ||
      raw.contains('OS Error') ||
      raw.contains('sql') ||
      raw.contains('database') ||
      raw.contains('query') ||
      raw.contains('select') ||
      raw.contains('insert') ||
      raw.contains('update') ||
      raw.contains('delete') ||
      raw.contains('stack trace') ||
      raw.contains('Stacktrace') ||
      raw.contains('Internal Server Error')) {
    return fallback;
  }

  // If it's reasonably short and human-readable, use it
  if (raw.length < 200 && !raw.contains('\n') && raw.trim().isNotEmpty) {
    return raw.trim();
  }

  return fallback;
}

/// Whether an error is caused by network connectivity issues.
bool isNetworkError(Object error) {
  if (error is DioException) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown &&
            error.error is SocketException);
  }
  return error is SocketException;
}
