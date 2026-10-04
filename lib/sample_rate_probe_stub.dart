/// Non-web platforms: the native recorder delivers exactly the requested
/// sample rate, so there is nothing to probe.
Future<int?> probeCaptureSampleRate({String? deviceId}) async => null;
