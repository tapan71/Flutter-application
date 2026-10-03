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
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
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

            // Gradient Overlay for Text Readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Top-left Icon Tag
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(item.icon, color: Colors.white, size: 18),
              ),
            ),

            // Top-right "+" symbol for Quick Request
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: 'Quick Request for ${item.title} (+)',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => openServiceRequest(service: item.title),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Category Info & Action Buttons
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
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
                              fontWeight: FontWeight.bold,
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: Colors.white),
                              SizedBox(width: 2),
                              Text(
                                'Request',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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

          // LocalServe Plus Membership Button
          IconButton(
            icon: Icon(
              user.hasActiveMembership ? Icons.stars : Icons.stars_outlined,
              color: user.hasActiveMembership ? Colors.amber.shade700 : null,
              size: 26,
            ),
            tooltip: 'LocalServe Plus Membership',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MembershipScreen(),
                ),
              );
            },
          ),

          // Notification badge
          NotificationBadgeButton(user: user),

          // Top right customer profile button: watch profile & edit profile via button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
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
                child: CircleAvatar(
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
              ),
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
              // Location Chip Bar
              if (user.address != null && user.address!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user.address!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          UserProfileDialog.show(context, user: user, showEditProfileButton: true);
                        },
                        child: const Text('Change', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),

              // Membership Banner
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MembershipScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: user.hasActiveMembership
                          ? [const Color(0xFF1565C0), const Color(0xFF1E88E5)]
                          : [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          user.hasActiveMembership ? Icons.stars : Icons.workspace_premium,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.hasActiveMembership
                                  ? '${user.membershipTier ?? "Plus"} Member Active 👑'
                                  : 'Join LocalServe Plus ✨',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.hasActiveMembership
                                  ? '₹0 Inspection fee active on all your service bookings'
                                  : 'Get ₹0 inspection fees on all bookings & 10-20% discounts',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.hasActiveMembership ? 'Perks' : 'Upgrade',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Live Active Request Tracker (Reactive from DatabaseService)
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

              // SEARCH
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search services...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Explore Services',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${filteredCategories.length} categories',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                              color: pro.isWorkerPro ? Colors.amber.shade400 : Colors.grey.shade300,
                              width: pro.isWorkerPro ? 1.5 : 1,
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
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              pro.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (pro.isWorkerPro) ...[
                                            const SizedBox(width: 3),
                                            const Icon(Icons.stars, size: 11, color: Colors.orange),
                                          ],
                                        ],
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