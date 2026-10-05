import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/app_image_view.dart';

class DirectWorkerBookingDialog extends StatefulWidget {
  final AppUser worker;
  final AppUser customer;
  final String serviceCategory;
  final double? distanceKm;

  const DirectWorkerBookingDialog({
    super.key,
    required this.worker,
    required this.customer,
    required this.serviceCategory,
    this.distanceKm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required AppUser worker,
    required AppUser customer,
    required String serviceCategory,
    double? distanceKm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DirectWorkerBookingDialog(
        worker: worker,
        customer: customer,
        serviceCategory: serviceCategory,
        distanceKm: distanceKm,
      ),
    );
  }

  @override
  State<DirectWorkerBookingDialog> createState() =>
      _DirectWorkerBookingDialogState();
}

class _DirectWorkerBookingDialogState extends State<DirectWorkerBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  final _descriptionController = TextEditingController();

  String _priority = 'Medium';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _emailController = TextEditingController(text: widget.customer.email);
    _mobileController = TextEditingController(text: widget.customer.mobile);
    _addressController =
        TextEditingController(text: widget.customer.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dbService = context.read<DatabaseService>();
      final newReq = ServiceRequest(
        id: 'req_${DateTime.now().millisecondsSinceEpoch}',
        service: widget.serviceCategory,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        address: _addressController.text.trim(),
        latitude: widget.customer.latitude,
        longitude: widget.customer.longitude,
        priority: _priority,
        reminder: true,
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        customerId: widget.customer.uid,
        createdAt: DateTime.now(),
      );

      await dbService.createDirectRequest(
        request: newReq,
        targetWorker: widget.worker,
        customer: widget.customer,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direct Service Request',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Book a specific verified worker',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selected Worker Header Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: AppImageView.getProvider(widget.worker.effectiveAvatarUrl),
                        onBackgroundImageError: (error, stackTrace) {},
                        child: AppImageView.getProvider(widget.worker.effectiveAvatarUrl) == null
                            ? const Icon(Icons.engineering, size: 28)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.worker.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.worker.workerSkill ??
                                        widget.serviceCategory,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.worker.rating.toStringAsFixed(1)} (${widget.worker.ratingCount})',
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (widget.distanceKm != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.near_me,
                                      size: 13, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.distanceKm!.toStringAsFixed(1)} km from your location',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.account_circle_outlined, size: 16),
                        label: const Text('Profile', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          UserProfileDialog.show(context, user: widget.worker);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 1-Hour Expiration Alert
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 20, color: Colors.blue.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1-Hour Response Rule: ${widget.worker.name} will have 1 hour to accept or decline. If no response in 1 hour, your request will automatically cancel and notify you.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Job Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Work Description *',
                    hintText:
                        'Explain the problem in detail (e.g. Kitchen tap leaking, bathroom pipe burst)...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please describe the service required';
                    }
                    if (val.trim().length < 8) {
                      return 'Please provide a little more detail (at least 8 characters)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Priority & Preferred Date Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Low', child: Text('Low')),
                          DropdownMenuItem(
                              value: 'Medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'High', child: Text('High')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _priority = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectDueDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Preferred Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Contact & Address Confirmation
                const Text(
                  'Your Contact & Service Address (Auto-filled from Profile)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Name required'
                      : null,
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone_outlined),
                          isDense: true,
                        ),
                        validator: (val) =>
                            val == null || val.trim().length < 10
                                ? 'Valid phone required'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                          isDense: true,
                        ),
                        validator: (val) => val == null || !val.contains('@')
                            ? 'Valid email required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Service Address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Address required'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _handleSubmit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send),
          label: Text(_isSubmitting ? 'Sending Request...' : 'Send Direct Request (1 Hr)'),
        ),
      ],
    );
  }
}
