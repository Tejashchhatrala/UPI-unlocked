import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Stream<QuerySnapshot> getVendorOrders() {
    final vendorId = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addOrderNote(String orderId, String note) async {
    await _firestore.collection('orders').doc(orderId).update({
      'notes': FieldValue.arrayUnion([{
        'text': note,
        'timestamp': FieldValue.serverTimestamp(),
        'by': FirebaseAuth.instance.currentUser!.uid,
      }]),
    });
  }

  Stream<DocumentSnapshot> getOrderDetails(String orderId) {
    return _firestore.collection('orders').doc(orderId).snapshots();
  }
}