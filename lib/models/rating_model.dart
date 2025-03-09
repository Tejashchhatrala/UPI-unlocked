class Rating {
  final String id;
  final String orderId;
  final String customerId;
  final String vendorId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final List<String>? images;
  final VendorResponse? vendorResponse;

  Rating({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.vendorId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.images,
    this.vendorResponse,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'vendorId': vendorId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'images': images,
      'vendorResponse': vendorResponse?.toMap(),
    };
  }

  factory Rating.fromMap(String id, Map<String, dynamic> map) {
    return Rating(
      id: id,
      orderId: map['orderId'] ?? '',
      customerId: map['customerId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'],
      createdAt: DateTime.parse(map['createdAt']),
      images: List<String>.from(map['images'] ?? []),
      vendorResponse: map['vendorResponse'] != null
          ? VendorResponse.fromMap(map['vendorResponse'])
          : null,
    );
  }
}

class VendorResponse {
  final String response;
  final DateTime createdAt;

  VendorResponse({
    required this.response,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'response': response,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory VendorResponse.fromMap(Map<String, dynamic> map) {
    return VendorResponse(
      response: map['response'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}