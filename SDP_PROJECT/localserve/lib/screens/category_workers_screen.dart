import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/direct_worker_booking_dialog.dart';
import 'service_request_screen.dart';

class CategoryWorkersScreen extends StatefulWidget {
  final String serviceCategory;
  final String imageUrl;
  final String description;

  const CategoryWorkersScreen({
    super.key,
    required this.serviceCategory,
    required this.imageUrl,
    required this.description,
  });

  @override
  State<CategoryWorkersScreen> createState() => _CategoryWorkersScreenState();
}

class _CategoryWorkersScreenState extends State<CategoryWorkersScreen> {
  bool _filterWithin20Km = true;
  String _workerSearchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = context.watch<AuthService>();
    final dbService = context.watch<DatabaseService>();
    final customer = authService.currentUser;

    final customerLat = customer?.latitude;
    final customerLon = customer?.longitude;

    // Fetch workers for category
    final allCategoryWorkers = dbService.getWorkersForCategory(
      widget.serviceCategory,
      customerLat: customerLat,
      customerLon: customerLon,
      maxDistanceKm: DatabaseService.maxWorkerDistanceKm,
      strictWithinRadius: false,
    );

    // Apply distance filter and search query
    final displayedWorkers = allCategoryWorkers.where((w) {
      if (_workerSearchQuery.trim().isNotEmpty) {
        final q = _workerSearchQuery.toLowerCase();
        final matches = w.name.toLowerCase().contains(q) ||
            (w.address != null && w.address!.toLowerCase().contains(q)) ||
            (w.bio != null && w.bio!.toLowerCase().contains(q));
        if (!matches) return false;
      }

      if (_filterWithin20Km && customerLat != null && customerLon != null) {
        final dist = dbService.calculateDistanceKm(
          lat1: customerLat,
          lon1: customerLon,
          lat2: w.latitude,
          lon2: w.longitude,
        );
        return dist == null || dist <= DatabaseService.maxWorkerDistanceKm;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.serviceCategory} Professionals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Post Public Request to All Workers',
            onPressed: () => _openPublicRequest(context, customer),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPublicRequest(context, customer),
        icon: const Icon(Icons.add),
        label: Text('Post ${widget.serviceCategory} Request'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image Header
            Stack(
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.handyman,
                          size: 64, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.serviceCategory.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Verified Local ${widget.serviceCategory} Workers',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Status & Radius Filter
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.near_me,
                                  size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customer?.address != null &&
                                          customer!.address!.isNotEmpty
                                      ? 'Near: ${customer.address}'
                                      : 'Set your address to calculate proximity',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilterChip(
                          selected: _filterWithin20Km,
                          avatar: Icon(
                            _filterWithin20Km
                                ? Icons.check
                                : Icons.radar_outlined,
                            size: 14,
                          ),
                          label: const Text('Within 20 km',
                              style: TextStyle(fontSize: 11)),
                          onSelected: (val) {
                            setState(() {
                              _filterWithin20Km = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Search Worker Input
                  TextField(
                    decoration: InputDecoration(
                      hintText:
                          'Search ${widget.serviceCategory} workers by name or area...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _workerSearchQuery = val;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Workers Count Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Workers (${displayedWorkers.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Post Public Request',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _openPublicRequest(context, customer),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Direct requests give workers 1 hour to accept. You can also view reviews and past jobs.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),

                  const SizedBox(height: 12),

                  // Workers List
                  if (displayedWorkers.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No ${_filterWithin20Km ? "nearby " : ""}${widget.serviceCategory} workers found',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try toggling "Within 20 km" to view all professionals or post a public request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _openPublicRequest(context, customer),
                            icon: const Icon(Icons.add),
                            label: Text('Post Public ${widget.serviceCategory} Request'),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedWorkers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final worker = displayedWorkers[i];
                        final dist = (customerLat != null && customerLon != null)
                            ? dbService.calculateDistanceKm(
                                lat1: customerLat,
                                lon1: customerLon,
                                lat2: worker.latitude,
                                lon2: worker.longitude,
                              )
                            : null;

                        return _buildWorkerCard(
                          context,
                          theme,
                          worker,
                          customer,
                          dist,
                        );
                      },
                    ),

                  const SizedBox(height: 80), // Padding for FAB
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(
    BuildContext context,
    ThemeData theme,
    AppUser worker,
    AppUser? customer,
    double? distanceKm,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Avatar with verified badge
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: worker.avatarUrl != null &&
                              worker.avatarUrl!.isNotEmpty
                          ? NetworkImage(worker.avatarUrl!)
                          : null,
                      onBackgroundImageError: worker.avatarUrl != null ? (error, stackTrace) {} : null,
                      child: (worker.avatarUrl == null ||
                              worker.avatarUrl!.isEmpty)
                          ? const Icon(Icons.engineering, size: 30)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name, Skill & Ratings
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              worker.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  worker.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                                Text(
                                  ' (${worker.ratingCount})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Trade & Completed Jobs Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              worker.workerSkill ?? widget.serviceCategory,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${worker.completedJobsCount} jobs completed',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),

                      if (distanceKm != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 2),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km away',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (distanceKm <= 5.0)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Text(
                                  'Very Close',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (worker.bio != null && worker.bio!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                worker.bio!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const Divider(height: 20),

            // Contact Info
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  worker.mobile.isNotEmpty ? worker.mobile : 'Available on request',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 14),
                Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    worker.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Actions: View Profile & Reviews | Book This Worker
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.person_search_outlined, size: 16),
                    label: const Text('Profile & Reviews',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      UserProfileDialog.show(context, user: worker);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Book Worker',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      if (customer == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please sign in first.')),
                        );
                        return;
                      }

                      final success = await DirectWorkerBookingDialog.show(
                        context,
                        worker: worker,
                        customer: customer,
                        serviceCategory: widget.serviceCategory,
                        distanceKm: distanceKm,
                      );

                      if (success == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Direct request sent to ${worker.name}! They have 1 hour to respond.',
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        Navigator.pop(context); // Return to home
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPublicRequest(
      BuildContext context, AppUser? customer) async {
    final result = await Navigator.push<ServiceRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestScreen(
          selectedService: widget.serviceCategory,
          currentUser: customer,
        ),
      ),
    );

    if (result != null && context.mounted) {
      final dbService = context.read<DatabaseService>();
      await dbService.addRequest(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Public request for ${result.service} broadcast to nearby workers!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
