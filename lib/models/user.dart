import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final double balance;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isSubscribed;
  final String? subscriptionType; // 'monthly', 'annual', null
  final DateTime? subscriptionEndDate;

  User({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.balance = 0.0,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    this.isSubscribed = false,
    this.subscriptionType,
    this.subscriptionEndDate,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastLoginAt = lastLoginAt ?? DateTime.now();

  factory User.fromMap(Map<String, dynamic> map, String uid) {
    return User(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      phoneNumber: map['phoneNumber'],
      balance: (map['balance'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastLoginAt: map['lastLoginAt'] != null
          ? (map['lastLoginAt'] as Timestamp).toDate()
          : DateTime.now(),
      isSubscribed: map['isSubscribed'] ?? false,
      subscriptionType: map['subscriptionType'],
      subscriptionEndDate: map['subscriptionEndDate'] != null
          ? (map['subscriptionEndDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isSubscribed': isSubscribed,
      'subscriptionType': subscriptionType,
      'subscriptionEndDate': subscriptionEndDate != null
          ? Timestamp.fromDate(subscriptionEndDate!)
          : null,
    };
  }

  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
    double? balance,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isSubscribed,
    String? subscriptionType,
    DateTime? subscriptionEndDate,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
    );
  }
}
