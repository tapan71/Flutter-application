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
                        color: user.hasActiveMembership ? null : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: user.hasActiveMembership
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFCBD5E1),
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
                              color: user.hasActiveMembership ? Colors.white : const Color(0xFF334155),
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
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          onBackgroundImageError:
                              user.avatarUrl != null ? (error, stackTrace) {} : null,
                          child: user.avatarUrl == null
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search services (e.g. AC Repair, Plumbing)...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
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

              const SizedBox(height: 20),

              // Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.category_rounded, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Text(
                        'Explore Services',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredCategories.length} categories',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
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

              const SizedBox(height: 20),

              // Featured Verified Pro Specialists
              const Text(
                'Featured Verified Specialists ⭐',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Top-rated professionals available for 1-hour direct booking',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pros.length,
                      separatorBuilder: (c, i) => const SizedBox(width: 12),
                      itemBuilder: (c, i) {
                        final pro = pros[i];
                        return Container(
                          width: 210,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => UserProfileDialog.show(ctx, user: pro),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: pro.avatarUrl != null ? NetworkImage(pro.avatarUrl!) : null,
                                  child: pro.avatarUrl == null ? const Icon(Icons.engineering, size: 18) : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pro.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        pro.workerSkill ?? 'General',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, size: 11, color: Colors.amber),
                                          const SizedBox(width: 2),
                                          Text(
                                            pro.rating.toStringAsFixed(1),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
}