import 'package:flutter/material.dart';

import '../models/service_request.dart';
import '../models/user_model.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({
    super.key,
    required this.selectedService,
    this.existingRequest,
    this.currentUser,
  });

  final String selectedService;
  final ServiceRequest? existingRequest;
  final AppUser? currentUser;

  @override
  State<ServiceRequestScreen> createState() =>
      _ServiceRequestScreenState();
}

class _ServiceRequestScreenState
    extends State<ServiceRequestScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController mobileController;
  late final TextEditingController addressController;
  late final TextEditingController descriptionController;

  String priority = 'Medium';
  bool reminder = false;
  DateTime? dueDate;
  late String selectedService;

  final List<String> serviceCategories = const [
    'Plumbing',
    'Painting',
    'Electrical',
    'Carpentry',
    'Cleaning',
    'Appliance Repair',
    'General Service',
  ];

  @override
  void initState() {
    super.initState();

    final request = widget.existingRequest;
    final user = widget.currentUser;

    selectedService = request?.service ??
        (serviceCategories.contains(widget.selectedService)
            ? widget.selectedService
            : 'Plumbing');

    nameController = TextEditingController(
      text: request?.name ?? user?.name ?? '',
    );

    emailController = TextEditingController(
      text: request?.email ?? user?.email ?? '',
    );

    mobileController = TextEditingController(
      text: request?.mobile ?? user?.mobile ?? '',
    );

    addressController = TextEditingController(
      text: request?.address ?? user?.address ?? '',
    );

    descriptionController = TextEditingController(
      text: request?.description ?? '',
    );

    priority = request?.priority ?? 'Medium';
    reminder = request?.reminder ?? false;
    dueDate = request?.dueDate;
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    addressController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  // CREATE / UPDATE REQUEST
  void submitRequest() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final oldRequest = widget.existingRequest;

    final request = ServiceRequest(
      id: oldRequest?.id ??
          DateTime.now()
              .microsecondsSinceEpoch
              .toString(),

      service: selectedService,

      name: nameController.text.trim(),

      email: emailController.text.trim(),

      mobile: mobileController.text.trim(),

      address: addressController.text.trim(),

      priority: priority,

      reminder: reminder,

      description: descriptionController.text.trim(),

      dueDate: dueDate,

      status: oldRequest?.status ?? 'pending',
      customerId: oldRequest?.customerId ?? widget.currentUser?.uid,
      workerId: oldRequest?.workerId,
      workerName: oldRequest?.workerName,
    );

    Navigator.pop(context, request);
  }

  // CONFIRM DISCARD
  Future<bool> confirmDiscard() async {
    final hasData =
        nameController.text.trim().isNotEmpty ||
            emailController.text.trim().isNotEmpty ||
            mobileController.text.trim().isNotEmpty ||
            addressController.text.trim().isNotEmpty ||
            descriptionController.text.trim().isNotEmpty ||
            dueDate != null;

    if (!hasData) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Discard Request?',
          ),
          content: const Text(
            'Are you sure you want to discard this request?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Discard',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // DATE PICKER
  Future<void> selectDueDate() async {
    final today = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,

      initialDate: dueDate ?? today,

      firstDate: today,

      lastDate: today.add(
        const Duration(days: 365),
      ),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        dueDate = selectedDate;
      });
    }
  }

  String get formattedDueDate {
    if (dueDate == null) {
      return 'Select Due Date';
    }

    return '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing =
        widget.existingRequest != null;

    return PopScope(
      canPop: false,

      onPopInvokedWithResult:
          (didPop, result) async {
        if (didPop) {
          return;
        }

        final shouldDiscard = await confirmDiscard();
        if (!context.mounted) return;
        if (shouldDiscard) {
          Navigator.pop(context);
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditing
                ? 'Edit $selectedService Request'
                : '$selectedService Request',
          ),
        ),

        body: Form(
          key: formKey,

          child: ListView(
            padding: const EdgeInsets.all(16),

            children: [
              // TITLE
              Text(
                isEditing
                    ? 'Edit $selectedService Request'
                    : 'Request $selectedService Service',

                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isEditing
                    ? 'Update your service request details.'
                    : 'Enter your details to request a local professional.',
              ),

              const SizedBox(height: 16),

              if (widget.currentUser != null && !isEditing)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Phone number and address auto-filled from your registered account.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // SERVICE TYPE SELECTOR
              DropdownButtonFormField<String>(
                initialValue: serviceCategories.contains(selectedService) ? selectedService : 'Plumbing',
                decoration: const InputDecoration(
                  labelText: 'Service Type',
                  hintText: 'Select required service (Plumbing, Painting, etc.)',
                  prefixIcon: Icon(Icons.handyman_outlined),
                  border: OutlineInputBorder(),
                ),
                items: serviceCategories.map((service) {
                  IconData icon;
                  switch (service) {
                    case 'Plumbing':
                      icon = Icons.plumbing;
                      break;
                    case 'Painting':
                      icon = Icons.format_paint;
                      break;
                    case 'Electrical':
                      icon = Icons.electrical_services;
                      break;
                    case 'Carpentry':
                      icon = Icons.carpenter;
                      break;
                    case 'Cleaning':
                      icon = Icons.cleaning_services;
                      break;
                    case 'Appliance Repair':
                      icon = Icons.home_repair_service;
                      break;
                    default:
                      icon = Icons.build_circle_outlined;
                  }
                  return DropdownMenuItem<String>(
                    value: service,
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(service, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedService = val;
                    });
                  }
                },
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Please select a service type' : null,
              ),

              const SizedBox(height: 16),

              // NAME
              TextFormField(
                controller: nameController,

                textInputAction:
                TextInputAction.next,

                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Name is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // EMAIL
              TextFormField(
                controller: emailController,

                keyboardType:
                TextInputType.emailAddress,

                textInputAction:
                TextInputAction.next,

                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Email is required';
                  }

                  if (!value.contains('@') ||
                      !value.contains('.')) {
                    return 'Enter a valid email';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // MOBILE
              TextFormField(
                controller: mobileController,

                keyboardType:
                TextInputType.phone,

                textInputAction:
                TextInputAction.next,

                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter 10 digit mobile number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Mobile number is required';
                  }

                  final mobile = value.trim();

                  if (mobile.length != 10) {
                    return 'Enter 10 digit mobile number';
                  }

                  if (int.tryParse(mobile) == null) {
                    return 'Enter numbers only';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ADDRESS
              TextFormField(
                controller: addressController,

                textInputAction:
                TextInputAction.next,

                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter your address',
                  prefixIcon:
                  Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Address is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // PRIORITY
              DropdownButtonFormField<String>(
                initialValue: priority,

                decoration: const InputDecoration(
                  labelText: 'Priority',
                  prefixIcon:
                  Icon(Icons.priority_high),
                  border: OutlineInputBorder(),
                ),

                items: const [
                  DropdownMenuItem(
                    value: 'Low',
                    child: Text('Low'),
                  ),
                  DropdownMenuItem(
                    value: 'Medium',
                    child: Text('Medium'),
                  ),
                  DropdownMenuItem(
                    value: 'High',
                    child: Text('High'),
                  ),
                ],

                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      priority = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 8),

              // REMINDER
              SwitchListTile(
                contentPadding: EdgeInsets.zero,

                title: const Text(
                  'Enable Reminder',
                ),

                subtitle: const Text(
                  'Receive a reminder about this request',
                ),

                value: reminder,

                onChanged: (value) {
                  setState(() {
                    reminder = value;
                  });
                },
              ),

              const SizedBox(height: 8),

              // DUE DATE
              Card(
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),

                  leading: const Icon(
                    Icons.calendar_month,
                  ),

                  title: Text(
                    formattedDueDate,
                  ),

                  subtitle: const Text(
                    'Choose the date for this service request',
                  ),

                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),

                  onTap: selectDueDate,
                ),
              ),

              const SizedBox(height: 16),

              // DESCRIPTION
              TextFormField(
                controller:
                descriptionController,

                maxLines: 4,

                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText:
                  'Describe your service requirement',
                  prefixIcon:
                  Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 24),

              // SUBMIT / UPDATE
              SizedBox(
                width: double.infinity,

                child: FilledButton.icon(
                  onPressed: submitRequest,

                  icon: Icon(
                    isEditing
                        ? Icons.save
                        : Icons.send,
                  ),

                  label: Text(
                    isEditing
                        ? 'Update Request'
                        : 'Submit Request',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // CANCEL
              SizedBox(
                width: double.infinity,

                child: OutlinedButton(
                  onPressed: () async {
                    final shouldDiscard = await confirmDiscard();
                    if (!context.mounted) return;
                    if (shouldDiscard) {
                      Navigator.pop(context);
                    }
                  },

                  child: const Text(
                    'Cancel',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}