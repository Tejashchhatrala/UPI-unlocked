import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../scanner/qr_scanner_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome Customer!'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const QRScannerScreen(),
            ),
          );
        },
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }
}