import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/location_picker_screen.dart';
import '../widgets/app_image_view.dart';
import '../services/geocoding_service.dart';

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
  List<String> _attachedImages = [];
  bool _isDetectingGps = false;

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

    _attachedImages = List<String>.from(request?.images ?? []);

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

  Future<void> _detectDirectLiveLocation() async {
    setState(() {
      _isDetectingGps = true;
    });

    try {
      final result = await GeocodingService().detectCurrentLocation();
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _selectedLatitude = result.latitude;
          _selectedLongitude = result.longitude;
          addressController.text = result.shortAddress.isNotEmpty
              ? result.shortAddress
              : result.displayName;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gps_fixed, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.isLiveGps
                        ? '📍 Live GPS detected: ${addressController.text}'
                        : '📍 Location detected: ${addressController.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect live location. Please check device GPS or pick on map.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error detecting direct live location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingGps = false;
        });
      }
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

      images: _attachedImages,

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
            _attachedImages.isNotEmpty ||
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

  IconData _getServiceIcon(String service) {
    switch (service) {
      case 'Plumbing':
        return Icons.plumbing_rounded;
      case 'Painting':
        return Icons.format_paint_rounded;
      case 'Electrical':
        return Icons.electrical_services_rounded;
      case 'Carpentry':
        return Icons.carpenter_rounded;
      case 'Cleaning':
        return Icons.cleaning_services_rounded;
      case 'Appliance Repair':
        return Icons.home_repair_service_rounded;
      default:
        return Icons.build_circle_rounded;
    }
  }

  String get formattedDueDate {
    if (dueDate == null) {
      return 'Select Due Date';
    }
    final now = DateTime.now();
    final isToday = dueDate!.year == now.year && dueDate!.month == now.month && dueDate!.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = dueDate!.year == tomorrow.year && dueDate!.month == tomorrow.month && dueDate!.day == tomorrow.day;

    if (isToday) return 'Today (${dueDate!.day}/${dueDate!.month}/${dueDate!.year})';
    if (isTomorrow) return 'Tomorrow (${dueDate!.day}/${dueDate!.month}/${dueDate!.year})';
    return '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}';
  }

  void _showZoomImageDialog(String imageUrl, int index) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
              title: Text(
                'Photo ${index + 1} of ${_attachedImages.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                  onPressed: () {
                    setState(() {
                      _attachedImages.removeAt(index);
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 340,
                width: double.infinity,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: AppImageView(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhotoFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      setState(() {
        _attachedImages.add(base64String);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Photo captured and attached!'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera access error: $e. You can also upload from phone storage.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickPhotoFromStorage() async {
    try {
      final picker = ImagePicker();
      List<XFile> files = [];
      try {
        files = await picker.pickMultiImage(
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 75,
        );
      } catch (_) {
        final single = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 75,
        );
        if (single != null) files = [single];
      }

      if (files.isEmpty) return;

      int addedCount = 0;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _attachedImages.add(base64String);
        addedCount++;
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('$addedCount photo${addedCount > 1 ? "s" : ""} uploaded from phone storage!'),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage access error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Attach Issue Photo',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Take a photo with your camera or select an existing photo from your phone storage.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              // Only two options: Click photo (camera) & Phone storage
              Row(
                children: [
                  // 1. Camera Button (Click Photo)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _capturePhotoFromCamera();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                        ),
                        child: const Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF16A34A),
                              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Take Photo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF14532D)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Click with camera',
                              style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 2. Phone Storage / Gallery Button
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _pickPhotoFromStorage();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD8B4FE), width: 1.5),
                        ),
                        child: const Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF7C3AED),
                              child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Phone Storage',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF581C87)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Upload from gallery',
                              style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityChip(String level, Color color, Color bg) {
    final isSelected = priority == level;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            priority = level;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? bg : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_circle_rounded, size: 14, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                level,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRequest != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await confirmDiscard();
        if (!context.mounted) return;
        if (shouldDiscard) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // 1. SERVICE CATEGORY MODULE (Starts directly at the top)
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Icon(
                            _getServiceIcon(selectedService),
                            size: 24,
                            color: const Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SERVICE CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedService,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Active Trade',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: serviceCategories.contains(selectedService)
                          ? selectedService
                          : 'Plumbing',
                      decoration: InputDecoration(
                        labelText: 'Service Type',
                        hintText: 'Select required service',
                        prefixIcon: const Icon(Icons.handyman_outlined, color: Color(0xFF1E40AF)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                      items: serviceCategories.map((service) {
                        return DropdownMenuItem<String>(
                          value: service,
                          child: Row(
                            children: [
                              Icon(_getServiceIcon(service), size: 20, color: const Color(0xFF2563EB)),
                              const SizedBox(width: 12),
                              Text(
                                service,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
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
                  ],
                ),
              ),

              // 2. CONTACT & LOCATION MODULE
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.person_pin_circle_rounded,
                      title: 'Contact & Service Location',
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                    ),
                    const SizedBox(height: 18),

                    // NAME
                    TextFormField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter contact name',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // EMAIL
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter contact email for updates',
                        prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
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

                    const SizedBox(height: 14),

                    // MOBILE NUMBER
                    TextFormField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10 digit mobile number',
                        prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
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

                    const SizedBox(height: 14),

                    // ADDRESS (with right-hand map symbol)
                    TextFormField(
                      controller: addressController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter service address or pick on map',
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF64748B)),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1-Tap Live GPS Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _isDetectingGps ? null : _detectDirectLiveLocation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _isDetectingGps
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFF16A34A),
                                                ),
                                              )
                                            : const Icon(Icons.my_location, size: 16, color: Color(0xFF16A34A)),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'GPS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Map Picker Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: _pickLocationOnMap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.map_rounded, size: 16, color: Color(0xFF2563EB)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Map',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Address is required';
                        }
                        return null;
                      },
                    ),

                    if (_selectedLatitude != null && _selectedLongitude != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'GPS pinned: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _pickLocationOnMap,
                              child: const Text(
                                'Adjust',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 3. SCHEDULE & PREFERENCES MODULE
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'Schedule & Priority',
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                    ),
                    const SizedBox(height: 18),

                    // DUE DATE TILE
                    InkWell(
                      onTap: selectDueDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Preferred Service Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDueDate,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: dueDate == null
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: const Text(
                                'Select',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PRIORITY SELECTOR
                    const Text(
                      'Request Priority',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityChip('Low', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
                        const SizedBox(width: 10),
                        _buildPriorityChip('Medium', const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                        const SizedBox(width: 10),
                        _buildPriorityChip('High', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFFF1F5F9), height: 20),

                    // REMINDER TOGGLE
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: reminder ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            reminder ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                            size: 20,
                            color: reminder ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Booking Reminder',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Get in-app status notifications & prompt updates',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: reminder,
                          activeThumbColor: const Color(0xFF2563EB),
                          onChanged: (value) {
                            setState(() {
                              reminder = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. REQUIREMENTS MODULE
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      icon: Icons.notes_rounded,
                      title: 'Additional Requirements',
                      iconColor: const Color(0xFF0D9488),
                      iconBg: const Color(0xFFCCFBF1),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Describe issue details, preferred timing, or special notes...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. ISSUE PHOTOS MODULE (OPTIONAL)
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(
                          icon: Icons.camera_alt_rounded,
                          title: 'Issue Photos',
                          iconColor: const Color(0xFF7C3AED),
                          iconBg: const Color(0xFFF3E8FF),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Attach photos of the issue so the specialist can review the damage, evaluate required parts, and prepare before arriving.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_attachedImages.isEmpty) ...[
                      Row(
                        children: [
                          // 1. Click Photo with Camera
                          Expanded(
                            child: InkWell(
                              onTap: _capturePhotoFromCamera,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                                ),
                                child: const Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Color(0xFF16A34A),
                                      child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Take Photo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF14532D),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Click with camera',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Phone Storage
                          Expanded(
                            child: InkWell(
                              onTap: _pickPhotoFromStorage,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFD8B4FE), width: 1.5),
                                ),
                                child: const Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Color(0xFF7C3AED),
                                      child: Icon(Icons.photo_library_rounded, color: Colors.white, size: 22),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Phone Storage',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF581C87),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Upload from gallery',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF7E22CE)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 105,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachedImages.length + 1,
                              separatorBuilder: (context, _) => const SizedBox(width: 10),
                              itemBuilder: (context, idx) {
                                if (idx == _attachedImages.length) {
                                  return InkWell(
                                    onTap: _showAddPhotoSheet,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 90,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFD8B4FE)),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF7C3AED)),
                                          SizedBox(height: 4),
                                          Text(
                                            '+ Add More',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF7C3AED),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final imgUrl = _attachedImages[idx];
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showZoomImageDialog(imgUrl, idx),
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(13),
                                          child: AppImageView(
                                            imageUrl: imgUrl,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _attachedImages.removeAt(idx);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black87,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in_rounded, size: 10, color: Colors.white),
                                            SizedBox(width: 2),
                                            Text(
                                              'View',
                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_attachedImages.length} photo${_attachedImages.length > 1 ? "s" : ""} attached • Worker can inspect',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF15803D),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _capturePhotoFromCamera,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.camera_alt_rounded, size: 12, color: Color(0xFF16A34A)),
                                          SizedBox(width: 3),
                                          Text('Camera', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _pickPhotoFromStorage,
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFE9D5FF)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.photo_library_rounded, size: 12, color: Color(0xFF7C3AED)),
                                          SizedBox(width: 3),
                                          Text('Storage', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // 6. PRIMARY ACTION BUTTON
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: submitRequest,
                  icon: Icon(isEditing ? Icons.save_rounded : Icons.bolt_rounded, color: Colors.white),
                  label: Text(
                    isEditing ? 'Save Changes' : 'Broadcast Service Request',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // CANCEL BUTTON
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    final shouldDiscard = await confirmDiscard();
                    if (!context.mounted) return;
                    if (shouldDiscard) {
                      Navigator.pop(context);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: const Text(
                    'Cancel & Go Back',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}