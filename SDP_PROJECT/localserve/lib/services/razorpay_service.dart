class RazorpayPaymentSuccess {
  final String paymentId;
  final String? orderId;
  final String? signature;
  final double amount;

  const RazorpayPaymentSuccess({
    required this.paymentId,
    this.orderId,
    this.signature,
    required this.amount,
  });
}

class RazorpayPaymentFailure {
  final int code;
  final String message;

  const RazorpayPaymentFailure({
    required this.code,
    required this.message,
  });
}

/// Service managing Razorpay configuration and transaction metadata
class RazorpayService {
  // Test Key ID (standard Razorpay test key format)
  static const String defaultTestKeyId = 'rzp_test_LocalServePay2026';

  /// Generates a realistic mock/test Razorpay Payment ID
  static String generatePaymentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (timestamp % 100000).toString().padLeft(5, '0');
    return 'pay_${timestamp}_$randomSuffix';
  }

  /// Generates an order ID
  static String generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'order_$timestamp';
  }
}
