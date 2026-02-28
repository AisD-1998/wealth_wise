import 'package:cloud_firestore/cloud_firestore.dart';

enum InvestmentType {
  stock,
  etf,
  bond,
  crypto,
  realEstate,
  mutualFund,
  other,
}

extension InvestmentTypeLabel on InvestmentType {
  String get label {
    switch (this) {
      case InvestmentType.stock:
        return 'Stock';
      case InvestmentType.etf:
        return 'ETF';
      case InvestmentType.bond:
        return 'Bond';
      case InvestmentType.crypto:
        return 'Crypto';
      case InvestmentType.realEstate:
        return 'Real Estate';
      case InvestmentType.mutualFund:
        return 'Mutual Fund';
      case InvestmentType.other:
        return 'Other';
    }
  }
}

class Investment {
  final String? id;
  final String userId;
  final String name;
  final InvestmentType type;
  final double purchasePrice;
  final double currentValue;
  final double quantity;
  final DateTime purchaseDate;
  final String? note;

  const Investment({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.purchasePrice,
    required this.currentValue,
    required this.quantity,
    required this.purchaseDate,
    this.note,
  });

  double get totalCost => purchasePrice * quantity;
  double get totalValue => currentValue * quantity;
  double get gainLoss => totalValue - totalCost;
  double get gainLossPercent =>
      totalCost > 0 ? (gainLoss / totalCost) * 100 : 0;

  factory Investment.fromMap(Map<String, dynamic> map, String id) {
    return Investment(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      type: InvestmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InvestmentType.other,
      ),
      purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
      currentValue: (map['currentValue'] ?? 0.0).toDouble(),
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      purchaseDate: map['purchaseDate'] != null
          ? (map['purchaseDate'] as Timestamp).toDate()
          : DateTime.now(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'type': type.name,
      'purchasePrice': purchasePrice,
      'currentValue': currentValue,
      'quantity': quantity,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'note': note,
    };
  }

  Investment copyWith({
    String? id,
    String? userId,
    String? name,
    InvestmentType? type,
    double? purchasePrice,
    double? currentValue,
    double? quantity,
    DateTime? purchaseDate,
    String? note,
  }) {
    return Investment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentValue: currentValue ?? this.currentValue,
      quantity: quantity ?? this.quantity,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      note: note ?? this.note,
    );
  }
}
