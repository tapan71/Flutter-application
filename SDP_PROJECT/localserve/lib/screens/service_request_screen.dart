import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/location_picker_screen.dart';
import '../widgets/map_preview_card.dart';

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

  double? _selectedLatitude;
  double? _selectedLongitude;

  String priority = 'Medium';
  bool reminder = false;
  DateTime? dueDate;
  late String selectedService;
  bool _didPrefillFromUser = false;

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

    _selectedLatitude = request?.latitude ?? user?.latitude;
    _selectedLongitude = request?.longitude ?? user?.longitude;

    priority = request?.priority ?? 'Medium';
    reminder = request?.reminder ?? false;
    dueDate = request?.dueDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrefillFromUser && widget.existingRequest == null) {
      _didPrefillFromUser = true;
      final authUser = widget.currentUser ??
          context.read<AuthService>().currentUser;
      if (authUser != null) {
        if (nameController.text.trim().isEmpty && authUser.name.isNotEmpty) {
          nameController.text = authUser.name;
        }
        if (emailController.text.trim().isEmpty && authUser.email.isNotEmpty) {
          emailController.text = authUser.email;
        }
        if (mobileController.text.trim().isEmpty && authUser.mobile.isNotEmpty) {
          mobileController.text = authUser.mobile;
        }
        if (addressController.text.trim().isEmpty &&
            authUser.address != null &&
            authUser.address!.isNotEmpty) {
          addressController.text = authUser.address!;
        }
        _selectedLatitude ??= authUser.latitude;
        _selectedLongitude ??= authUser.longitude;
      }
    }
  }

  void _resetToAccountProfile() {
    final activeUser = widget.currentUser ??
        context.read<AuthService>().currentUser;
    if (activeUser != null) {
      setState(() {
        nameController.text = activeUser.name;
        emailController.text = activeUser.email;
        mobileController.text = activeUser.mobile;
        addressController.text = activeUser.address ?? '';
        _selectedLatitude = activeUser.latitude;
        _selectedLongitude = activeUser.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset fields to default account profile details.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialAddress: addressController.text,
          title: 'Pick Service Location',
          confirmButtonText: 'Use This Location',
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result.latitude;
        _selectedLongitude = result.longitude;
        addressController.text = result.address;
      });
    }
  }

  // CREATE / UPDATE REQUEST
  void submitRequest() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final oldRequest = widget.existingRequest;
    final activeUser = widget.currentUser ??
        (mounted ? context.read<AuthService>().currentUser : null);

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

      latitude: _selectedLatitude,

      longitude: _selectedLongitude,

      priority: priority,

      reminder: reminder,

      description: descriptionController.text.trim(),

      dueDate: dueDate,

      status: oldRequest?.status ?? 'pending',
      customerId: oldRequest?.customerId ?? activeUser?.uid,
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

              if (!isEditing)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Account Defaults Auto-filled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.restore, size: 14),
                              label: const Text('Reset Defaults', style: TextStyle(fontSize: 11)),
                              onPressed: _resetToAccountProfile,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your name, email, mobile number, and address are pre-filled below. You can change or edit any details before submitting.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // SERVICE TYPE SELECTOR
              DropdownButtonFormField<String>(
                isExpanded: true,
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
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter contact name',
                  prefixIcon: Icon(Icons.person),
                  helperText: 'Default from your account (editable)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // EMAIL
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter contact email for updates',
                  prefixIcon: Icon(Icons.email),
                  helperText: 'Default from your account (editable)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // MOBILE
              TextFormField(
                controller: mobileController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: 'Enter 10 digit mobile number',
                  prefixIcon: Icon(Icons.phone),
                  helperText: 'Default from your account (editable)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
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
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter service address or pick on map',
                  prefixIcon: const Icon(Icons.location_on),
                  helperText: 'Default from your account (editable or pick on map)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map_outlined, color: Colors.blueAccent),
                    tooltip: 'Pick location on OpenStreetMap',
                    onPressed: _pickLocationOnMap,
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // MAP PICKER BUTTON & PREVIEW
              OutlinedButton.icon(
                onPressed: _pickLocationOnMap,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  side: BorderSide(
                    color: _selectedLatitude != null
                        ? Colors.green.shade600
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                icon: Icon(
                  _selectedLatitude != null
                      ? Icons.check_circle_outline
                      : Icons.explore_outlined,
                  color: _selectedLatitude != null
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  _selectedLatitude != null
                      ? 'Location Picked on Map (${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)})'
                      : 'Pick Location on OpenStreetMap',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _selectedLatitude != null
                        ? Colors.green.shade800
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

              if (_selectedLatitude != null && _selectedLongitude != null) ...[
                const SizedBox(height: 10),
                MapPreviewCard(
                  latitude: _selectedLatitude!,
                  longitude: _selectedLongitude!,
                  address: addressController.text,
                  title: 'Service Location on Map',
                  onEditLocation: _pickLocationOnMap,
                ),
              ],

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