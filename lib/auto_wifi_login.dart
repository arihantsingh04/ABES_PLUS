import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns true if device has internet access
Future<bool> isInternetWorking() async {
  final connectivityResult = await Connectivity().checkConnectivity();

  // First check if device is connected to Wi-Fi
  if (connectivityResult == ConnectivityResult.wifi ||
      connectivityResult == ConnectivityResult.mobile) {
    try {
      final result = await http.get(Uri.parse('https://www.google.com')).timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      return false; // Timeout, no internet
    }
  } else {
    return false; // Not connected to any network
  }
}


http.Client getBypassSslClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      return true;
    };
  return IOClient(ioClient);
}

Future<bool> isAlreadyLoggedInToWifi() async {
  try {
    final client = getBypassSslClient();
    final response = await client.get(Uri.parse('https://192.168.1.254:8090/httpclient.html'));
    if (response.statusCode == 200 &&
        (response.body.contains('LIVE') || response.body.contains('already'))) {
      return true;
    }
  } catch (e) {
    print('❌ Login status check failed: $e');
  }
  return false;
}

Future<bool> requestLocationPermission() async {
  var status = await Permission.location.request();
  return status.isGranted;
}

Future<String?> getWifiSSID() async {
  final info = NetworkInfo();
  try {
    String? wifiName = await info.getWifiName();
    return wifiName?.replaceAll('"', '');
  } catch (e) {
    print('❌ Failed to get WiFi name: $e');
    return null;
  }
}

Future<Map<String, String>?> showCredentialDialog(BuildContext context) {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter Wi-Fi Credentials',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text("Save & Continue"),
                onPressed: () {
                  Navigator.of(context).pop({
                    'username': usernameController.text.trim(),
                    'password': passwordController.text.trim(),
                  });
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> loginToCollegePortal(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  String? username = prefs.getString('wifi_username');
  String? password = prefs.getString('wifi_password');

  if (username == null || password == null) {
    final creds = await showCredentialDialog(context);
    if (creds == null) {
      print("❌ User cancelled login");
      return false;
    }
    username = creds['username'];
    password = creds['password'];
    await prefs.setString('wifi_username', username!);
    await prefs.setString('wifi_password', password!);
  }

  final url = Uri.parse('https://192.168.1.254:8090/httpclient.html');
  try {
    final client = getBypassSslClient();
    final response = await client.post(
      url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'mode': '191',
        'username': username,
        'password': password,
        'a': DateTime.now().millisecondsSinceEpoch.toString(),
        'producttype': '0',
      },
    );

    print("🔁 Response Status: ${response.statusCode}");
    print("🔁 Response Body: ${response.body}");

    if (response.statusCode == 200 &&
        (response.body.contains('LIVE') || response.body.contains('already'))) {
      print("✅ Wi-Fi Login Successful");
      return true;
    } else {
      print("❌ Wi-Fi Login Failed");
      return false;
    }
  } catch (e) {
    print("❌ Exception during login: $e");
    return false;
  }
}

Future<bool> checkAndAutoLoginToCollegeWifi(BuildContext context) async {
  bool granted = await requestLocationPermission();
  if (!granted) {
    print('❌ Location permission denied');
    return false;
  }

  final wifiName = await getWifiSSID();
  print("📶 Connected WiFi: $wifiName");

  if (wifiName != null && wifiName.contains("ABESEC")) {
    print("✅ ABES Wi-Fi detected. Logging in...");
    final loginSuccess = await loginToCollegePortal(context);
    if (loginSuccess) {
      await Future.delayed(Duration(seconds: 2)); // wait a bit
      return await isAlreadyLoggedInToWifi(); // confirm actual login
    }
    return false;
  } else {
    print("❌ Not connected to ABES Wi-Fi.");
    return false;
  }
}

Future<void> logoutWifiCredentials() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('wifi_username');
  await prefs.remove('wifi_password');
  print("👋 Logged out and credentials cleared.");
}