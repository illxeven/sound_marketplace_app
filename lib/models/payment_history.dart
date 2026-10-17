class PaymentHistory {
  final int id;
  final int? buyerId;
  final String? buyerEmail;
  final int? merchandiseId;
  final String? merchandiseTitle;
  final String stripeChargeId;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;

  PaymentHistory({
    required this.id,
    this.buyerId,
    this.buyerEmail,
    this.merchandiseId,
    this.merchandiseTitle,
    required this.stripeChargeId,
    required this.amount,
    this.currency = 'USD',
    this.status = 'COMPLETED',
    this.createdAt,
  });

  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    return PaymentHistory(
      id: json['id'] as int,
      buyerId: json['buyerId'] as int?,
      buyerEmail: json['buyerEmail'] as String?,
      merchandiseId: json['merchandiseId'] as int?,
      merchandiseTitle: json['merchandiseTitle'] as String?,
      stripeChargeId: json['stripeChargeId'] as String? ?? '',
      amount: (json['amount'] != null) ? (json['amount'] as num).toDouble() : 0.0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'COMPLETED',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyerId': buyerId,
      'buyerEmail': buyerEmail,
      'merchandiseId': merchandiseId,
      'merchandiseTitle': merchandiseTitle,
      'stripeChargeId': stripeChargeId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
