import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/geocoding_service.dart';
import 'app_image_view.dart';
import 'location_picker_screen.dart';

class EditProfileDialog extends StatefulWidget {
  final AppUser user;

  const EditProfileDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, {required AppUser user}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditProfileDialog(user: user),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _bioController;

  double? _latitude;
  double? _longitude;
  String? _workerSkill;
  bool _isDetectingLocation = false;
  bool _isSaving = false;
  String? _avatarBase64;
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _skills = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Cleaning',
    'Painting',
    'Appliance Repair',
    'General Service',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _mobileController = TextEditingController(text: widget.user.mobile);
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _latitude = widget.user.latitude;
    _longitude = widget.user.longitude;
    _workerSkill = widget.user.workerSkill ?? (widget.user.isWorker ? 'Plumbing' : null);
    _avatarBase64 = widget.user.avatarUrl;
  }

  Future<void> _pickAvatarImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (mounted) {
          setState(() {
            _avatarBase64 = base64String;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Update Profile Photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                  ),
                  title: const Text('Take a Photo (Camera)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Capture photo directly with camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAvatarImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 8),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                  ),
                  title: const Text('Phone Storage / Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Choose a picture from device storage'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAvatarImage(ImageSource.gallery);
                  },
                ),
                if (_avatarBase64 != null) ...[
                  const Divider(height: 8),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    ),
                    title: const Text('Reset to Default Avatar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _avatarBase64 = AppUser.defaultAvatarUrl;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final res = await GeocodingService().detectCurrentLocation();
      if (res != null && mounted) {
        setState(() {
          _latitude = res.latitude;
          _longitude = res.longitude;
          _addressController.text = res.shortAddress;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Location detected: ${res.shortAddress}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _addressController.text,
          title: 'Select Address Location',
          confirmButtonText: 'Confirm Location',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _addressController.text = result.address;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();

    try {
      final name = _nameController.text.trim();
      final mobile = _mobileController.text.trim();
      final address = _addressController.text.trim();
      final bio = _bioController.text.trim();

      await authService.updateUserProfile(
        name: name,
        mobile: mobile,
        address: address,
        latitude: _latitude,
        longitude: _longitude,
        workerSkill: widget.user.isWorker ? _workerSkill : null,
        bio: widget.user.isWorker ? bio : null,
        avatarUrl: _avatarBase64 ?? widget.user.avatarUrl,
      );

      await dbService.updateUserProfile(
        uid: widget.user.uid,
        name: name,
        mobile: mobile,
        address: address,
        latitude: _latitude,
        longitude: _longitude,
        workerSkill: widget.user.isWorker ? _workerSkill : null,
        bio: widget.user.isWorker ? bio : null,
        avatarUrl: _avatarBase64 ?? widget.user.avatarUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated! Changes saved permanently.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.edit, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Edit Profile Details', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Avatar with Photo Picker (Storage / Camera)
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _showPhotoSourceBottomSheet,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundColor: theme.colorScheme.primaryContainer,
                                backgroundImage: AppImageView.getProvider(_avatarBase64 ?? widget.user.effectiveAvatarUrl),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showPhotoSourceBottomSheet,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _showPhotoSourceBottomSheet,
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.photo_camera, size: 14),
                        label: const Text('Change Photo (Phone / Camera)', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                const Text(
                  'Update your registered details. Changes are saved permanently.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 14),

                // Mobile
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '10-digit mobile number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Mobile number is required';
                    }
                    final cleaned = val.trim();
                    if (cleaned.length != 10 || int.tryParse(cleaned) == null) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Address
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    hintText: 'House/Flat No., Street, Area, City',
                    border: const OutlineInputBorder(),
                    helperText: _latitude != null && _longitude != null
                        ? '📍 Lat: ${_latitude!.toStringAsFixed(4)}, Lon: ${_longitude!.toStringAsFixed(4)}'
                        : null,
                    helperStyle: const TextStyle(color: Colors.green, fontSize: 11),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter an address' : null,
                ),
                const SizedBox(height: 8),

                // Location action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isDetectingLocation ? null : _detectCurrentLocation,
                        icon: _isDetectingLocation
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location, size: 16),
                        label: const Text('Use GPS', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickOnMap,
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Pick on Map', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),

                if (widget.user.isWorker) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _skills.contains(_workerSkill) ? _workerSkill : 'Plumbing',
                    decoration: const InputDecoration(
                      labelText: 'Primary Trade / Skill',
                      prefixIcon: Icon(Icons.handyman_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _skills
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) => setState(() => _workerSkill = val),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Experience Bio',
                      prefixIcon: Icon(Icons.description_outlined),
                      hintText: 'Years of experience, specializations...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveProfile,
          icon: _isSaving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save),
          label: const Text('Save Profile'),
        ),
      ],
    );
  }
}
