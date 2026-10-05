import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'service_request_screen.dart';
import 'service_details_screen.dart';
import 'history_screen.dart';
import 'category_workers_screen.dart';
import '../widgets/notification_badge_button.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/theme_mode_toggle_button.dart';
import '../widgets/app_image_view.dart';
import 'membership_screen.dart';

class ServiceCategoryItem {
  final String title;
  final String imageUrl;
  final String description;
  final IconData icon;
  final Color color;

  const ServiceCategoryItem({
    required this.title,
    required this.imageUrl,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Search text
  String searchQuery = '';

  // Categories with real images
  final List<ServiceCategoryItem> categoryItems = const [
    ServiceCategoryItem(
      title: 'Plumbing',
      imageUrl: 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=600&auto=format&fit=crop',
      description: 'Pipes, leak fixes, drainage & taps',
      icon: Icons.plumbing,
      color: Colors.blue,
    ),
    ServiceCategoryItem(
      title: 'Electrical',
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=600&auto=format&fit=crop',
      description: 'Wiring, MCBs, fixtures & switches',
      icon: Icons.electrical_services,
      color: Colors.amber,
    ),
    ServiceCategoryItem(
      title: 'Carpentry',
      imageUrl: 'https://images.unsplash.com/photo-1538688525198-9b88f6f53126?w=600&auto=format&fit=crop',
      description: 'Furniture repairs, doors & woodwork',
      icon: Icons.carpenter,
      color: Colors.brown,
    ),
    ServiceCategoryItem(
      title: 'Cleaning',
      imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=600&auto=format&fit=crop',
      description: 'Deep home cleaning, kitchen & sanitization',
      icon: Icons.cleaning_services,
      color: Colors.teal,
    ),
    ServiceCategoryItem(
      title: 'Painting',
      imageUrl: 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=600&auto=format&fit=crop',
      description: 'Interior, exterior walls & waterproofing',
      icon: Icons.format_paint,
      color: Colors.deepOrange,
    ),
    ServiceCategoryItem(
      title: 'Appliance Repair',
      imageUrl: 'https://images.unsplash.com/photo-1581092918056-0c4c3acd3789?w=600&auto=format&fit=crop',
      description: 'AC, fridge, washing machines & ovens',
      icon: Icons.home_repair_service,
      color: Colors.indigo,
    ),
    ServiceCategoryItem(
      title: 'General Service',
      imageUrl: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600&auto=format&fit=crop',
      description: 'Handyman, fixture drilling & home fixes',
      icon: Icons.handyman,
      color: Colors.green,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DatabaseService>().checkAndExpireDirectRequests();
      }
    });
  }

  // OPEN SERVICE REQUEST SCREEN
  Future<void> openServiceRequest({
    String? service,
    ServiceRequest? existingRequest,
  }) async {
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();
    final user = authService.currentUser;

    final result = await Navigator.push<ServiceRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestScreen(
          selectedService: service ?? 'Plumbing',
          existingRequest: existingRequest,
          currentUser: user,
        ),
      ),
    );

    if (result != null && mounted) {
      if (existingRequest != null) {
        await dbService.updateRequest(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Service request updated successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await dbService.addRequest(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request for ${result.service} submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  // BUILD CATEGORY IMAGE CARD WITH + SYMBOL
  Widget _buildCategoryCard(BuildContext context, ServiceCategoryItem item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryWorkersScreen(
                    serviceCategory: item.title,
                    imageUrl: item.imageUrl,
                    description: item.description,
                  ),
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Category Photo
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: item.color.withValues(alpha: 0.15),
                    child: Icon(item.icon, size: 48, color: item.color),
                  ),
                ),

                // Multi-Stop High-Contrast Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // Top-left Frosted Glass Category Tag
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-right Quick Request (+) Button with Gradient Glow
                Positioned(
                  top: 9,
                  right: 9,
                  child: Tooltip(
                    message: 'Quick Request for ${item.title} (+)',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => openServiceRequest(service: item.title),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Category Information
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Find Pros',
                                style: TextStyle(
                                  color: Colors.blue.shade200,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: Colors.blue.shade200,
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => openServiceRequest(service: item.title),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, size: 12, color: Colors.amberAccent),
                                  SizedBox(width: 3),
                                  Text(
                                    'Book',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    final query = searchQuery.trim().toLowerCase();
    final filteredCategories = categoryItems.where((item) {
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openServiceRequest(),
        icon: const Icon(Icons.add, size: 24),
        label: const Text('New Request'),
        tooltip: 'Create New Service Request (+)',
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_repair_service_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LocalServe',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Hi, ${user.name}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Theme Switcher (Dark / Light / Auto)
          const ThemeModeToggleButton(compact: true),

          // + symbol for creating new request
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28),
            tooltip: 'New Service Request (+)',
            onPressed: () => openServiceRequest(),
          ),

          // Dedicated History button where customer views their history
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 26),
            tooltip: 'My Request History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(currentUser: user),
                ),
              );
            },
          ),

          // Notification badge
          NotificationBadgeButton(user: user),

          // VIP Symbol & Profile Avatar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Small VIP Symbol near profile pick
                Tooltip(
                  message: user.hasActiveMembership
                      ? 'LocalServe VIP Active 👑'
                      : 'Join LocalServe Plus / VIP',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MembershipScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: user.hasActiveMembership
                            ? const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              )
                            : null,
                        color: user.hasActiveMembership ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: user.hasActiveMembership
                              ? const Color(0xFFFBBF24)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: user.hasActiveMembership
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.hasActiveMembership ? '👑' : '⭐',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'VIP',
                            style: TextStyle(
                              color: user.hasActiveMembership ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Profile Avatar with VIP indicator
                Tooltip(
                  message: 'View & Edit Profile (${user.name})',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      UserProfileDialog.show(
                        context,
                        user: user,
                        showEditProfileButton: true,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: AppImageView.getProvider(user.effectiveAvatarUrl),
                          onBackgroundImageError: (error, stackTrace) {},
                          child: AppImageView.getProvider(user.effectiveAvatarUrl) == null
                              ? Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                )
                              : null,
                        ),
                        if (user.hasActiveMembership)
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 10,
                                color: Colors.white,
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

          // Sign Out
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            tooltip: 'Sign Out',
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SEARCH BAR AT TOP
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search services (e.g. AC Repair, Plumbing)...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 2. LIVE ACTIVE / PENDING SERVICE REQUEST TRACKER (UNDER SEARCH BAR)
              Builder(
                builder: (ctx) {
                  final dbService = ctx.watch<DatabaseService>();
                  final reqs = dbService.allRequests.where((r) =>
                    (r.customerId == user.uid || (r.email.isNotEmpty && r.email.toLowerCase() == user.email.toLowerCase()))
                  ).toList();
                  final activeReqs = reqs.where((r) => !r.completed && !r.isCancelled && r.status != 'cancelled').toList();

                  if (activeReqs.isEmpty) return const SizedBox.shrink();

                  final latestActive = activeReqs.first;
                  String statusLabel = 'Pending Match';
                  Color statusColor = Colors.orange;
                  IconData statusIcon = Icons.hourglass_top_rounded;

                  if (latestActive.isBilled && !latestActive.isPaid) {
                    statusLabel = 'Bill Ready: ₹${(latestActive.totalAmount ?? 0).toStringAsFixed(0)} • Pay Now';
                    statusColor = Colors.green;
                    statusIcon = Icons.payment;
                  } else if (latestActive.isInProgress) {
                    statusLabel = 'Work In Progress';
                    statusColor = Colors.teal;
                    statusIcon = Icons.engineering;
                  } else if (latestActive.isAssigned) {
                    statusLabel = latestActive.workerName != null
                        ? 'Assigned: ${latestActive.workerName}'
                        : 'Worker Assigned';
                    statusColor = Colors.blue;
                    statusIcon = Icons.assignment_turned_in;
                  } else if (latestActive.isDirectRequest) {
                    statusLabel = 'Direct Request Sent';
                    statusColor = Colors.deepPurple;
                    statusIcon = Icons.person_search;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailsScreen(
                                request: latestActive,
                                currentUser: user,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(statusIcon, color: statusColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'ACTIVE BOOKING',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            latestActive.service,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: statusColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // 3. MODERN HERO PROMO BANNER (URBAN COMPANY / TASKRABBIT STYLE)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: Colors.amber, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'INSTANT DISPATCH • 20 KM RADIUS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Expert Home Services,\nDelivered at Your Doorstep',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1E3A8A),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add_task_rounded, size: 16),
                            label: const Text(
                              'Request Service Now',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () => openServiceRequest(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        size: 42,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. TRUST & BENEFIT HIGHLIGHT PILLS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTrustBadge(
                      icon: Icons.verified_user_rounded,
                      label: 'Verified Specialists',
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    _buildTrustBadge(
                      icon: Icons.timer_rounded,
                      label: '1-Hour Direct Match',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildTrustBadge(
                      icon: Icons.price_check_rounded,
                      label: 'Transparent Billing',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    _buildTrustBadge(
                      icon: Icons.star_rounded,
                      label: '4.8★ Top Rated',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Explore Services',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredCategories.length} categories',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Responsive Image Grid of Categories
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 800
                      ? 4
                      : (constraints.maxWidth > 540 ? 3 : 2);
                  final childAspectRatio =
                      constraints.maxWidth > 540 ? 1.05 : 0.98;

                  if (filteredCategories.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: Text(
                          'No services found matching "$searchQuery"',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final item = filteredCategories[index];
                      return _buildCategoryCard(context, item);
                    },
                  );
                },
              ),

              const SizedBox(height: 22),

              // Featured Verified Pro Specialists
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Featured Specialists ⭐',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Verified professionals available for 1-hour direct booking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Builder(
                builder: (ctx) {
                  final dbService = ctx.watch<DatabaseService>();
                  final pros = dbService.allUsers
                      .where((u) => u.isWorker)
                      .take(4)
                      .toList();

                  if (pros.isEmpty) return const SizedBox.shrink();

                  return SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pros.length,
                      separatorBuilder: (c, i) => const SizedBox(width: 12),
                      itemBuilder: (c, i) {
                        final pro = pros[i];
                        return Container(
                          width: 230,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => UserProfileDialog.show(ctx, user: pro),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                                      backgroundImage: AppImageView.getProvider(pro.effectiveAvatarUrl),
                                      child: AppImageView.getProvider(pro.effectiveAvatarUrl) == null ? const Icon(Icons.engineering, size: 20) : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF3B82F6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 8,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pro.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Theme.of(ctx).colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        pro.workerSkill ?? 'General',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(ctx).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text(
                                            pro.rating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Theme.of(ctx).colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '(${pro.completedJobsCount} jobs)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5),
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
                        );
                      },
                    ),
                  );
                },
              ),

              // Bottom space so floating action button doesn't obscure cards
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}