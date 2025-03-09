import 'package:flutter/material.dart';
import 'steps/upi_setup_step.dart';
import 'steps/basic_info_step.dart';
import 'steps/catalog_setup_step.dart';

class VendorSetupWizard extends StatefulWidget {
  const VendorSetupWizard({super.key});

  @override
  State<VendorSetupWizard> createState() => _VendorSetupWizardState();
}

class _VendorSetupWizardState extends State<VendorSetupWizard> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  
  // Store data as we progress through steps
  final Map<String, dynamic> _vendorData = {
    'upiId': '',
    'businessName': '',
    'address': '',
    'storeType': '',
    'categories': [],
  };

  final List<String> _completedSteps = [];

  List<Step> get _steps => [
    Step(
      title: const Text('UPI Setup'),
      content: UPISetupStep(
        onSave: (upiId) {
          setState(() {
            _vendorData['upiId'] = upiId;
            if (!_completedSteps.contains('upi')) {
              _completedSteps.add('upi');
            }
          });
        },
        initialValue: _vendorData['upiId'],
      ),
      isActive: _currentStep >= 0,
      state: _getStepState(0),
    ),
    Step(
      title: const Text('Business Info'),
      content: BasicInfoStep(
        onSave: (basicInfo) {
          setState(() {
            _vendorData.addAll(basicInfo);
            if (!_completedSteps.contains('basic')) {
              _completedSteps.add('basic');
            }
          });
        },
        initialData: _vendorData,
      ),
      isActive: _currentStep >= 1,
      state: _getStepState(1),
    ),
    Step(
      title: const Text('Catalog'),
      content: CatalogSetupStep(
        onSave: (categories) {
          setState(() {
            _vendorData['categories'] = categories;
            if (!_completedSteps.contains('catalog')) {
              _completedSteps.add('catalog');
            }
          });
        },
        onSkip: () {
          _handleComplete();
        },
      ),
      isActive: _currentStep >= 2,
      state: _getStepState(2),
    ),
  ];

  StepState _getStepState(int step) {
    if (_currentStep == step) {
      return StepState.editing;
    }
    if (_completedSteps.contains(_stepKeyForIndex(step))) {
      return StepState.complete;
    }
    return StepState.indexed;
  }

  String _stepKeyForIndex(int index) {
    switch (index) {
      case 0:
        return 'upi';
      case 1:
        return 'basic';
      case 2:
        return 'catalog';
      default:
        return '';
    }
  }

  Future<void> _handleComplete() async {
    // Save vendor data to Firebase
    try {
      setState(() => _isLoading = true);
      await _saveVendorData();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/vendor/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Your Store'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentStep -= 1;
                  });
                },
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < _steps.length - 1) {
              setState(() {
                _currentStep += 1;
              });
            } else {
              _handleComplete();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep -= 1;
              });
            }
          },
          onStepTapped: (step) {
            setState(() {
              _currentStep = step;
            });
          },
          steps: _steps,
          controlsBuilder: (context, controls) {
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                children: [
                  if (_currentStep < _steps.length - 1)
                    ElevatedButton(
                      onPressed: _isLoading ? null : controls.onStepContinue,
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : controls.onStepContinue,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Complete Setup'),
                    ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _isLoading ? null : controls.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

final StorageService _storageService = StorageService();

Future<void> _saveVendorData() async {
  try {
    // Save to Firebase
    final vendorRef = FirebaseFirestore.instance
        .collection('vendors')
        .doc(FirebaseAuth.instance.currentUser!.uid);

    await vendorRef.set({
      'upiId': _vendorData['upiId'],
      'businessName': _vendorData['businessName'],
      'address': _vendorData['address'],
      'storeType': _vendorData['storeType'],
      'latitude': _vendorData['latitude'],
      'longitude': _vendorData['longitude'],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Save categories
    final categories = _vendorData['categories'] as List<Category>;
    await _storageService.saveCatalog(
      FirebaseAuth.instance.currentUser!.uid,
      categories,
    );

    // Save images locally
    for (var category in categories) {
      for (var product in category.products) {
        if (product.localImagePath != null) {
          await _storageService.saveImage(product.localImagePath!);
        }
      }
    }

  } catch (e) {
    rethrow;
  }
}