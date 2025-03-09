import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class UPISetupStep extends StatefulWidget {
  final Function(String) onSave;
  final String? initialValue;

  const UPISetupStep({
    super.key,
    required this.onSave,
    this.initialValue,
  });

  @override
  State<UPISetupStep> createState() => _UPISetupStepState();
}

class _UPISetupStepState extends State<UPISetupStep> {
  final _upiController = TextEditingController();
  bool _isScanning = false;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    _upiController.text = widget.initialValue ?? '';
  }

  @override
  void dispose() {
    _upiController.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _isScanning = true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
      }
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        _handleScannedCode(scanData.code!);
      }
    });
  }

  void _handleScannedCode(String code) {
    // Basic UPI ID validation
    if (code.contains('upi://')) {
      final upiId = _extractUPIId(code);
      if (upiId != null) {
        setState(() {
          _upiController.text = upiId;
          _isScanning = false;
        });
        widget.onSave(upiId);
      }
    }
  }

  String? _extractUPIId(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme == 'upi') {
        // Extract pa (payment address) parameter
        return uri.queryParameters['pa'];
      }
    } catch (e) {
      print('Error parsing UPI QR: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Column(
        children: [
          Expanded(
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() => _isScanning = false);
              },
              child: const Text('Cancel Scanning'),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _upiController,
            decoration: const InputDecoration(
              labelText: 'UPI ID',
              hintText: 'Enter your UPI ID',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your UPI ID';
              }
              // Basic UPI ID format validation
              if (!value.contains('@')) {
                return 'Please enter a valid UPI ID';
              }
              return null;
            },
            onChanged: (value) {
              widget.onSave(value);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _startScanning,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Code'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan your UPI QR code or manually enter your UPI ID',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}