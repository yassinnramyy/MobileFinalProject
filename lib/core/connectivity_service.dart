import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // Check if device is currently online
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Stream that listens to connectivity changes in real-time
  // (e.g. wifi turns off while using the app)
  Stream<bool> get connectivityStream {
    return Connectivity().onConnectivityChanged.map(
          (result) => result != ConnectivityResult.none,
    );
  }
}