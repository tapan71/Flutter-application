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
      if (_addressController.text.isEmpty) {
        _detectAndSetLocation(showFeedback: false);
      }
    });
  }

  Future<void> _detectAndSetLocation({bool showFeedback = true}) async {
    setState(() {
      _isDetectingLocation = true;
      _errorMessage = null;
    });

    try {
      final result = await GeocodingService().detectCurrentLocation();
      if (!mounted) return;

      if (result != null) {
        final addressStr = result.shortAddress.isNotEmpty
            ? result.shortAddress
            : result.displayName;
        setState(() {
          _selectedLatitude = result.latitude;
          _selectedLongitude = result.longitude;
          _addressController.text = addressStr;
        });

        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Location detected: $addressStr'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (showFeedback) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Create an Account'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Ambient Decorative Glow
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      // Elevated Form Container Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFDBEAFE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_add_alt_1_rounded, size: 14, color: Color(0xFF2563EB)),
                                      SizedBox(width: 4),
                                      Text(
                                        'GET STARTED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Create LocalServe Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Select your role and start booking or offering verified services',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 22),

                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Color(0xFFDC2626), size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFB91C1C),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],

                              // Role Selection Segmented Control
                              const Text(
                                'I want to register as:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<UserRole>(
                                style: ButtonStyle(
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: UserRole.customer,
                                    label: Text('Customer', style: TextStyle(fontWeight: FontWeight.w600)),
                                    icon: Icon(Icons.person_rounded),
                                  ),
                                  ButtonSegment(
                                    value: UserRole.worker,
                                    label: Text('Service Pro', style: TextStyle(fontWeight: FontWeight.w600)),
                                    icon: Icon(Icons.engineering_rounded),
                                  ),
                                ],
                                selected: {_selectedRole},
                                onSelectionChanged: (Set<UserRole> newSelection) {
                                  setState(() {
                                    _selectedRole = newSelection.first;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),

                              // Worker Skill Dropdown
                              if (_selectedRole == UserRole.worker) ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _workerSkill,
                                  decoration: const InputDecoration(
                                    labelText: 'Primary Skill / Trade',
                                    prefixIcon: Icon(Icons.build_circle_rounded),
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
                                const SizedBox(height: 18),
                              ],

                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'John Doe',
                                  prefixIcon: Icon(Icons.badge_rounded),
                                ),
                                validator: (val) => (val == null || val.trim().isEmpty)
                                    ? 'Please enter your full name'
                                    : null,
                              ),
                              const SizedBox(height: 18),

                              // Email Address
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'name@example.com',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
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
                              const SizedBox(height: 18),

                              // Phone Number
                              TextFormField(
                                controller: _mobileController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Mobile Number',
                                  hintText: '10-digit number',
                                  prefixIcon: Icon(Icons.phone_rounded),
                                ),
                                validator: (val) => (val == null || val.trim().length < 10)
                                    ? 'Please enter a valid 10-digit mobile number'
                                    : null,
                              ),
                              const SizedBox(height: 18),

                              // Address Header & Location Helper Actions
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  const Text(
                                    'Base Address & Map Location:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  if (_selectedLatitude != null && _selectedLongitude != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                                          SizedBox(width: 4),
                                          Text(
                                            'GPS Coordinates Saved',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

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
                                        : const Icon(Icons.my_location_rounded, size: 15),
                                    label: Text(
                                      _isDetectingLocation ? 'Detecting...' : 'Detect Location',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickOnMap,
                                    icon: const Icon(Icons.map_rounded, size: 15),
                                    label: const Text('Pick on Map', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Address Text Field
                              TextFormField(
                                controller: _addressController,
                                keyboardType: TextInputType.streetAddress,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Address',
                                  hintText: 'Enter street address, landmark & city',
                                  prefixIcon: const Icon(Icons.location_on_rounded),
                                  suffixIcon: _addressController.text.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Clear address',
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _addressController.clear();
                                              _selectedLatitude = null;
                                              _selectedLongitude = null;
                                            });
                                          },
                                        )
                                      : null,
                                  helperText: _selectedLatitude != null
                                      ? '📍 OpenStreetMap: ${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}'
                                      : 'Tip: Use "Detect Location" or "Pick on Map" to save coordinates',
                                  helperStyle: TextStyle(
                                    fontSize: 11,
                                    color: _selectedLatitude != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    fontWeight: _selectedLatitude != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                validator: (val) => (val == null || val.trim().isEmpty)
                                    ? 'Please enter your address or pick on map'
                                    : null,
                              ),
                              const SizedBox(height: 18),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Minimum 6 characters',
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
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

                              // Submit Button with Gradient
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: authService.isLoading ? null : _handleSignUp,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Center(
                                        child: authService.isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Create Account',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(Icons.arrow_forward_rounded,
                                                      color: Colors.white, size: 20),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
