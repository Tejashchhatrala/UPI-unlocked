import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'storage_service.dart';
import '../models/catalog_models.dart';

class SyncService {
  final StorageService _storageService = StorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Future<bool> isConnected() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> syncCatalog() async {
    if (!await isConnected()) {
      throw Exception('No internet connection');
    }

    try {
      // Get local catalog
      final localCatalog = await _storageService.getCatalog(_userId);
      
      // Get server catalog
      final serverDoc = await _firestore
          .collection('vendors')
          .doc(_userId)
          .collection('catalog')
          .doc('data')
          .get();

      if (!serverDoc.exists && localCatalog != null) {
        // Upload local catalog to server
        await _uploadCatalog(localCatalog);
      } else if (serverDoc.exists) {
        // Compare timestamps and sync accordingly
        final serverData = serverDoc.data()!;
        final serverTimestamp = serverData['lastUpdated'] as Timestamp;
        
        if (localCatalog != null) {
          // TODO: Implement proper conflict resolution
          // For now, server wins
          await _downloadCatalog(serverDoc);
        } else {
          await _downloadCatalog(serverDoc);
        }
      }
    } catch (e) {
      print('Sync error: $e');
      throw Exception('Failed to sync catalog');
    }
  }

  Future<void> _uploadCatalog(List<Category> catalog) async {
    await _firestore
        .collection('vendors')
        .doc(_userId)
        .collection('catalog')
        .doc('data')
        .set({
      'categories': catalog.map((c) => c.toMap()).toList(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _downloadCatalog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final categories = (data['categories'] as List)
        .map((c) => Category.fromMap(c))
        .toList();
    
    await _storageService.saveCatalog(_userId, categories);
  }
}