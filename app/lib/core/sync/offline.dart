import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

/// Whether [error] just means the device cannot reach Google right now (airplane mode, no signal, DNS or
/// connection failure, a timeout) as opposed to something that is actually wrong.
///
/// `package:http` wraps the underlying `SocketException` in a `ClientException`, so look inside its message too.
bool isOfflineError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    (error is http.ClientException && error.message.contains('SocketException'));
