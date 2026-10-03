import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class SubmitBillDialog extends StatefulWidget {
  final ServiceRequest request;
  final AppUser worker;

  const SubmitBillDialog({
    super.key,
    required this.request,
    required this.worker,
  });

  static Future<ServiceRequest?> show(
    BuildContext context, {
    required ServiceRequest request,
    required AppUser worker,
  }) {
    return showDialog<ServiceRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SubmitBillDialog(
        request: request,
        worker: worker,
      ),
    );
  }

  @override
  State<SubmitBillDialog> createState() => _SubmitBillDialogState();
}

class _SubmitBillDialogState extends State<SubmitBillDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseAmountController;
  bool _isSubmitting = false;

  double get _baseAmount {
    return double.tryParse(_baseAmountController.text.trim()) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _baseAmountController = TextEditingController(
      text: widget.request.baseAmount != null
          ? widget.request.baseAmount!.toStringAsFixed(0)
          : '350',
    );
  }

  @override
  void dispose() {
    _baseAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dbService = context.watch<DatabaseService>();
    final theme = Theme.of(context);

    // Compute distance between worker and customer
    final double? distanceKm = dbService.calculateDistanceKm(
      lat1: widget.worker.latitude,
      lon1: widget.worker.longitude,
      lat2: widget.request.latitude,
      lon2: widget.request.longitude,
    );

    final double distanceFee = DatabaseService.calculateDistanceFee(distanceKm);

    // Check if customer is a LocalServe Plus/Gold member (waived inspection fee)
    final customer = widget.request.customerId != null
        ? dbService.getAllUsers().where((u) => u.uid == widget.request.customerId).firstOrNull
        : null;
    final bool isCustomerMember = customer?.isCustomerMember ?? false;
    final double inspectionFee = isCustomerMember ? 0.0 : DatabaseService.inspectionFee;
    final double totalAmount = _baseAmount + inspectionFee + distanceFee;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generate Service Bill',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'For ${widget.request.service} (${widget.request.name})',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice about on-site evaluation
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, color: Colors.amber.shade900, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inspect the condition of work on-site, enter the work/parts charge, and submit the invoice to the customer.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (isCustomerMember) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Color(0xFF1E88E5), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'LocalServe Member (${customer?.membershipTier ?? "Plus"}): ₹100 Inspection Fee is Waived (₹0)!',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0D47A1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Base Work Charge Input
              TextFormField(
                controller: _baseAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Base Work & Labor Charge (₹)',
                  hintText: 'e.g. 500',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  helperText: 'Decided by you based on actual condition and parts',
                ),
                onChanged: (_) {
                  setState(() {});
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter work charge';
                  }
                  final amount = double.tryParse(val.trim());
                  if (amount == null || amount < 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Bill Breakdown Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Summary Breakdown',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Divider(height: 16),
                    _buildRow(
                      '1. Work / Service Charge:',
                      '₹${_baseAmount.toStringAsFixed(0)}',
                      isBold: false,
                    ),
                    const SizedBox(height: 8),
                    _buildRow(
                      '2. Condition Inspection Fee:',
                      isCustomerMember ? '₹0 (Free)' : '₹100',
                      subtext: isCustomerMember
                          ? 'Waived for LocalServe Plus/Gold member'
                          : 'Service charge for showing/assessing work condition',
                      badge: isCustomerMember ? 'MEMBER PERK' : 'Fixed ₹100',
                      badgeColor: isCustomerMember ? Colors.blue.shade100 : null,
                      badgeTextColor: isCustomerMember ? Colors.blue.shade900 : null,
                    ),
                    const SizedBox(height: 8),
                    _buildRow(
                      '3. Distance Travel Charge:',
                      '₹${distanceFee.toStringAsFixed(0)}',
                      subtext: distanceKm != null
                          ? 'Customer is ${distanceKm.toStringAsFixed(1)} km from your base location'
                          : 'Standard travel fee under 10 km',
                      badge: distanceKm != null && distanceKm <= 10.0
                          ? 'Under 10 km (₹250)'
                          : 'Under 20 km (₹500)',
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable (Razorpay):',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_isSubmitting ? 'Sending...' : 'Submit Bill & Notify Customer'),
          onPressed: _isSubmitting
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;

                  setState(() {
                    _isSubmitting = true;
                  });

                  try {
                    final updated = await dbService.submitBill(
                      requestId: widget.request.id,
                      baseAmount: _baseAmount,
                      worker: widget.worker,
                      customerLat: widget.request.latitude,
                      customerLng: widget.request.longitude,
                    );

                    if (context.mounted) {
                      Navigator.pop(context, updated);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Bill of ₹${totalAmount.toStringAsFixed(0)} submitted! Customer notified to pay via Razorpay.',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      setState(() {
                        _isSubmitting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error submitting bill: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
        ),
      ],
    );
  }

  Widget _buildRow(
    String label,
    String amount, {
    bool isBold = false,
    String? subtext,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (subtext != null || badge != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              if (subtext != null)
                Expanded(
                  child: Text(
                    subtext,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor ?? Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor ?? Colors.blue.shade800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
