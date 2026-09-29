import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/location_picker_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  String _workerSkill = 'Plumbing';
  bool _obscurePassword = true;
  String? _errorMessage;

  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isDetectingLocation = false;
  bool _askedLocationPrompt = false;

  final List<String> _serviceCategories = [
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptForDefaultLocation();
    });
  }

  Future<void> _promptForDefaultLocation() async {
    if (!mounted || _askedLocationPrompt || _addressController.text.isNotEmpty) return;
    _askedLocationPrompt = true;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.my_location, size: 40, color: Colors.blue),
        title: const Text('Use Current Location as Address?'),
        content: const Text(
          'LocalServe can automatically detect your current location and use it as your default address via OpenStreetMap.\n\n'
          'If you accept, your address and map coordinates will be filled automatically. You can also decline and type your address manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text("No, I'll Type Manually"),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogCtx, true),
            icon: const Icon(Icons.check),
            label: const Text('Accept & Use Location'),
          ),
        ],
      ),
    );

    if (accepted == true && mounted) {
      await _detectAndSetLocation();
    }
  }

  Future<void> _detectAndSetLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _errorMessage = null;
    });

    try {
      final result = await GeocodingService().detectCurrentLocation();
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _selectedLatitude = result.latitude;
          _selectedLongitude = result.longitude;
          _addressController.text = result.shortAddress;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Location detected: ${result.shortAddress}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not auto-detect location. Please select on map or type manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error detecting location: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialAddress: _addressController.text,
          title: 'Select Your Base Address',
          confirmButtonText: 'Use This Address',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLatitude = result.latitude;
        _selectedLongitude = result.longitude;
        _addressController.text = result.address;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    // If user typed address manually without picking on map, attempt quick geocode
    if (_selectedLatitude == null && _addressController.text.trim().isNotEmpty) {
      try {
        final geoMatch = await GeocodingService().forwardGeocode(_addressController.text.trim());
        if (geoMatch != null) {
          _selectedLatitude = geoMatch.latitude;
          _selectedLongitude = geoMatch.longitude;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final authService = context.read<AuthService>();
    try {
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
        role: _selectedRole,
        workerSkill: _selectedRole == UserRole.worker ? _workerSkill : null,
      );

      if (mounted) {
        // Show completion confirmation dialog showing registered address & phone number
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Registration Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${_nameController.text.trim()}!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your registered contact & address details:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phone: ${_mobileController.text.trim()}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Address: ${_addressController.text.trim()}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (_selectedLatitude != null && _selectedLongitude != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Map Coordinates: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Continue to LocalServe'),
              ),
            ],
          ),
        );

        if (mounted) {
          Navigator.pop(context); // Pop back to auth wrapper / dashboard
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create an Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join LocalServe',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose your role and register',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    // Role Selection Segmented Control
                    const Text(
                      'Select Account Type:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.customer,
                          label: Text('Customer'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: UserRole.worker,
                          label: Text('Worker'),
                          icon: Icon(Icons.handyman),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (Set<UserRole> newSelection) {
                        setState(() {
                          _selectedRole = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Worker Skill Dropdown
                    if (_selectedRole == UserRole.worker) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _workerSkill,
                        decoration: const InputDecoration(
                          labelText: 'Specialization / Skill',
                          prefixIcon: Icon(Icons.build_circle_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: _serviceCategories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _workerSkill = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Email Address
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!val.contains('@') || !val.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.trim().length < 10)
                          ? 'Please enter a valid 10-digit mobile number'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Address Header & Location Helper Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Address & Location:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (_selectedLatitude != null && _selectedLongitude != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'GPS Set',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Quick Action Buttons: Auto-detect or Pick on Map
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isDetectingLocation ? null : _detectAndSetLocation,
                          icon: _isDetectingLocation
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location, size: 16),
                          label: Text(
                            _isDetectingLocation ? 'Detecting...' : 'Use Current Location',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickOnMap,
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const Text('Pick on Map', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Address Text Field (Fully editable so user can type manually or refine)
                    TextFormField(
                      controller: _addressController,
                      keyboardType: TextInputType.streetAddress,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter complete house/street address or detect location',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: _addressController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear address',
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _addressController.clear();
                                    _selectedLatitude = null;
                                    _selectedLongitude = null;
                                  });
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        helperText: _selectedLatitude != null
                            ? '📍 OpenStreetMap: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}'
                            : 'Type manually or tap "Use Current Location" / "Pick on Map"',
                        helperStyle: TextStyle(
                          fontSize: 11,
                          color: _selectedLatitude != null ? Colors.green.shade800 : Colors.grey.shade600,
                        ),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter your address or pick on map'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password (min 6 characters)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (val) => (val == null || val.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    FilledButton(
                      onPressed: authService.isLoading ? null : _handleSignUp,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: authService.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
