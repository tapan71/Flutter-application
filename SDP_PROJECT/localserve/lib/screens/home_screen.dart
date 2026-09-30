import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'service_request_screen.dart';
import 'history_screen.dart';
import 'category_workers_screen.dart';
import '../widgets/notification_badge_button.dart';
import '../widgets/user_profile_dialog.dart';

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

              // Bottom space so floating action button doesn't obscure cards
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}