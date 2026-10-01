import 'package:flutter/material.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/razorpay_service.dart';

class RazorpayPaymentSheet extends StatefulWidget {
  final ServiceRequest request;
  final AppUser customer;

  const RazorpayPaymentSheet({
    super.key,
    required this.request,
    required this.customer,
  });

  static Future<RazorpayPaymentSuccess?> show(
    BuildContext context, {
    required ServiceRequest request,
    required AppUser customer,
  }) {
    return showModalBottomSheet<RazorpayPaymentSuccess>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RazorpayPaymentSheet(
        request: request,
        customer: customer,
      ),
    );
  }

  @override
  State<RazorpayPaymentSheet> createState() => _RazorpayPaymentSheetState();
}

class _RazorpayPaymentSheetState extends State<RazorpayPaymentSheet> {
  String _selectedMethod = 'upi';
  bool _isProcessing = false;
  String? _processingStatus;
  bool _simulateFailure = false;
  bool _hasFailed = false;
  String? _failureReason;

  final TextEditingController _upiController =
      TextEditingController(text: 'customer@okaxis');
  final TextEditingController _cardNumberController =
      TextEditingController(text: '4111 2222 3333 4444');
  final TextEditingController _expiryController =
      TextEditingController(text: '12/28');
  final TextEditingController _cvvController =
      TextEditingController(text: '888');

  @override
  void dispose() {
    _upiController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isProcessing = true;
      _hasFailed = false;
      _processingStatus = 'Connecting to Razorpay Secure Gateway...';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _processingStatus = 'Verifying payment credentials...';
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _processingStatus = 'Authorizing transaction...';
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    if (_simulateFailure) {
      setState(() {
        _isProcessing = false;
        _hasFailed = true;
        _failureReason =
            'Bank authorization failed / transaction declined. Please tap Retry Payment to try again or switch method.';
      });
      return;
    }

    final paymentId = RazorpayService.generatePaymentId();
    final orderId = RazorpayService.generateOrderId();

    final result = RazorpayPaymentSuccess(
      paymentId: paymentId,
      orderId: orderId,
      signature: 'sig_${DateTime.now().millisecondsSinceEpoch}',
      amount: widget.request.totalAmount ?? 0.0,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.request.totalAmount ?? 0.0;
    final base = widget.request.baseAmount ?? 0.0;
    final inspection = widget.request.inspectionFee ?? 100.0;
    final distance = widget.request.distanceFee ?? 250.0;
    final distanceKm = widget.request.distanceKm;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Razorpay Header Brand
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0C2340), // Official Razorpay Dark Navy
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C3380),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: Color(0xFF3395FF), // Razorpay Blue
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Razorpay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Tooltip(
                          message: 'Tap to toggle between Normal and Failure simulation',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _simulateFailure = !_simulateFailure;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _simulateFailure
                                    ? Colors.red.shade900
                                    : Colors.amber.shade900.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _simulateFailure ? Colors.white : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _simulateFailure ? 'TEST: FAIL MODE' : 'TEST MODE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _simulateFailure ? Icons.error_outline : Icons.touch_app_outlined,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LocalServe Home Services',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              '${widget.request.service} Service Invoice',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Text(
                              '₹${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Breakdown Accordion
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: theme.colorScheme.primary, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Service Charge Breakdown',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildBreakdownRow(
                      'Work / Labor Charge (Decided by worker)',
                      '₹${base.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 6),
                    _buildBreakdownRow(
                      'Condition Inspection Fee (Showing work condition)',
                      '₹${inspection.toStringAsFixed(0)}',
                      highlightBadge: 'Fixed',
                    ),
                    const SizedBox(height: 6),
                    _buildBreakdownRow(
                      distanceKm != null
                          ? 'Travel / Distance Fee (${distanceKm.toStringAsFixed(1)} km away)'
                          : 'Travel / Distance Fee',
                      '₹${distance.toStringAsFixed(0)}',
                      highlightBadge: distanceKm != null && distanceKm <= 10.0
                          ? '< 10 km'
                          : '< 20 km',
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grand Total',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_hasFailed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade200, width: 2),
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 52,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Payment Unsuccessful',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _failureReason ??
                            'Razorpay could not complete your payment of ₹${total.toStringAsFixed(2)}.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C2340),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF3395FF)),
                          label: const Text(
                            'Retry Payment (Razorpay)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: () {
                            setState(() {
                              _hasFailed = false;
                              _isProcessing = false;
                              _simulateFailure = false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Cancel & Retry Later'),
                      ),
                    ],
                  ),
                ),
              ] else if (_isProcessing) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF0C2340)),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _processingStatus ?? 'Processing Payment...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please do not close this window or hit back',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Payment Method Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // UPI Option
                      _buildMethodTile(
                        id: 'upi',
                        icon: Icons.qr_code_scanner,
                        title: 'UPI (Google Pay, PhonePe, Paytm)',
                        subtitle: 'Instant transfer via any UPI App or VPA ID',
                      ),

                      if (_selectedMethod == 'upi') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                          child: TextFormField(
                            controller: _upiController,
                            decoration: const InputDecoration(
                              labelText: 'UPI ID / VPA',
                              hintText: 'username@bank',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.alternate_email),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],

                      // Card Option
                      _buildMethodTile(
                        id: 'card',
                        icon: Icons.credit_card,
                        title: 'Credit / Debit Card',
                        subtitle: 'Visa, MasterCard, RuPay, Maestro',
                      ),

                      if (_selectedMethod == 'card') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _cardNumberController,
                                decoration: const InputDecoration(
                                  labelText: 'Card Number',
                                  hintText: 'XXXX XXXX XXXX XXXX',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.credit_card),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _expiryController,
                                      decoration: const InputDecoration(
                                        labelText: 'Expiry (MM/YY)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cvvController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'CVV',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Net Banking Option
                      _buildMethodTile(
                        id: 'netbanking',
                        icon: Icons.account_balance,
                        title: 'Net Banking',
                        subtitle: 'SBI, HDFC, ICICI, Axis & 50+ other banks',
                      ),

                      // Wallets Option
                      _buildMethodTile(
                        id: 'wallet',
                        icon: Icons.account_balance_wallet,
                        title: 'Wallets & Cash',
                        subtitle: 'Paytm, PhonePe, Mobikwik, Cash after service',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Pay Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C2340),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _handlePayment,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 16, color: Color(0xFF3395FF)),
                        const SizedBox(width: 8),
                        Text(
                          'Pay ₹${total.toStringAsFixed(2)} with Razorpay',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Footer security reassurance
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      '100% Secure 256-bit SSL Encrypted Payment via Razorpay',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTile({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMethod == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF0C2340) : Colors.grey.shade300,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedMethod = id;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected
                    ? const Color(0xFF0C2340).withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF0C2340) : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: isSelected ? const Color(0xFF0C2340) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {String? highlightBadge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (highlightBadge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    highlightBadge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
