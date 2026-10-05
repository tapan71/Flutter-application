import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../models/service_request.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../widgets/location_picker_screen.dart';
import '../service_details_screen.dart';
import '../history_screen.dart';
import '../../widgets/notification_badge_button.dart';
import '../../widgets/theme_mode_toggle_button.dart';
import '../../widgets/edit_profile_dialog.dart';
import '../../widgets/user_profile_dialog.dart';
import '../../widgets/submit_bill_dialog.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _filterWithin20Km = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DatabaseService>().checkAndExpireDirectRequests();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double? _getDistanceKm(AppUser worker, ServiceRequest req) {
    if (worker.hasLocation && req.hasLocation) {
      const distance = Distance();
      return distance.as(
        LengthUnit.Kilometer,
        LatLng(worker.latitude!, worker.longitude!),
        LatLng(req.latitude!, req.longitude!),
      );
    }
    return null;
  }

  String? _getDistanceToJob(AppUser worker, ServiceRequest req) {
    final km = _getDistanceKm(worker, req);
    if (km != null) {
      if (km < 1) {
        const distance = Distance();
        final m = distance.as(
          LengthUnit.Meter,
          LatLng(worker.latitude!, worker.longitude!),
          LatLng(req.latitude!, req.longitude!),
        );
        return '${m.toStringAsFixed(0)} m away';
      }
      return '${km.toStringAsFixed(1)} km away';
    }
    return null;
  }

  void _showOutOfRadiusDialog(BuildContext context, double distanceKm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off, size: 48, color: Colors.red),
        title: const Text('Outside 20 km Service Radius'),
        content: Text(
          'This service request is ${distanceKm.toStringAsFixed(1)} km away from your base location.\n\n'
          'To ensure rapid and reliable service, LocalServe requires workers to accept requests within 20 km of their base location.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  bool _matchesWorkerSkill(AppUser worker, ServiceRequest req) {
    final reqService = req.service.trim().toLowerCase();
    // 1. General Service requests can be seen and accepted by ALL workers
    if (reqService == 'general service' || reqService == 'general') return true;

    // 2. Workers specializing in General Service or All can see all requests
    if (worker.workerSkill == null || worker.workerSkill!.isEmpty) return true;
    final skill = worker.workerSkill!.trim().toLowerCase();
    if (skill == 'general service' || skill == 'all') return true;

    // 3. Specific trade matching
    return reqService == skill;
  }

  Widget _buildWorkerKpiBar(AppUser worker, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildKpiItem(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            label: 'Completed',
            value: '${worker.completedJobsCount} Jobs',
          ),
          Container(height: 24, width: 1, color: theme.colorScheme.outlineVariant),
          _buildKpiItem(
            icon: Icons.star_rounded,
            iconColor: Colors.amber.shade700,
            label: 'Rating',
            value: '${worker.rating.toStringAsFixed(1)} ★ (${worker.ratingCount})',
          ),
          Container(height: 24, width: 1, color: theme.colorScheme.outlineVariant),
          _buildKpiItem(
            icon: Icons.verified_user_rounded,
            iconColor: Colors.blue.shade700,
            label: 'Platform Access',
            value: 'Free & Open',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectInvitationsSection(
    BuildContext context,
    ThemeData theme,
    AppUser worker,
    List<ServiceRequest> directInvitations,
  ) {
    if (directInvitations.isEmpty) return const SizedBox.shrink();

    final dbService = context.read<DatabaseService>();

    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2007) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.8 : 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Job Invitations (${directInvitations.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? const Color(0xFFFDE68A) : Colors.amber.shade900,
                        ),
                      ),
                      Text(
                        '1-hour response limit. The customer selected you directly.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFFCD34D) : Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: directInvitations.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (ctx, i) {
                final req = directInvitations[i];
                final now = DateTime.now();
                final diff = req.directRequestExpiresAt?.difference(now);
                final minsRemaining = (diff != null && diff.inMinutes > 0) ? diff.inMinutes : 0;
                final distanceStr = _getDistanceToJob(worker, req);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            req.service,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: minsRemaining <= 15 ? Colors.red.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: minsRemaining <= 15 ? Colors.red.shade400 : Colors.orange.shade400,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_filled,
                                size: 13,
                                color: minsRemaining <= 15 ? Colors.red.shade800 : Colors.orange.shade900,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '⏰ ${minsRemaining}m left',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: minsRemaining <= 15 ? Colors.red.shade800 : Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.black87),
                        const SizedBox(width: 6),
                        Text(
                          'Customer: ${req.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (distanceStr != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• $distanceStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (req.address.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          'Location: ${req.address}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Problem Description:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            req.description,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    if (req.hasImages) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailsScreen(
                                request: req,
                                currentUser: worker,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD8B4FE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_rounded, size: 16, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 6),
                              Text(
                                '📷 ${req.images.length} Issue Photo${req.images.length > 1 ? "s" : ""} Attached • Tap to Inspect',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B21A8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Actions: View Profile & Reviews | Inspect Photos | Accept | Decline
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (req.hasImages)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFFD8B4FE)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFFFAF5FF),
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: Text('Inspect Photos (${req.images.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceDetailsScreen(
                                    request: req,
                                    currentUser: worker,
                                  ),
                                ),
                              );
                            },
                          ),
                        // View Customer Profile & Reviews
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.person_search_outlined, size: 16),
                          label: const Text('Customer Profile & Reviews', style: TextStyle(fontSize: 11)),
                          onPressed: () async {
                            if (req.customerId == null || req.customerId!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Customer profile details not found.')),
                              );
                              return;
                            }
                            final customerUser = await dbService.getUserById(req.customerId!);
                            if (customerUser != null && context.mounted) {
                              UserProfileDialog.show(context, user: customerUser);
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not load customer profile.')),
                              );
                            }
                          },
                        ),
                        // Accept Request
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text(
                            'Accept Job',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            try {
                              await dbService.acceptDirectRequest(
                                requestId: req.id,
                                workerId: worker.uid,
                                workerName: worker.name,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('You accepted the job for ${req.name}!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _tabController.animateTo(1);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                        // Decline
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Decline', style: TextStyle(fontSize: 11)),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Decline Direct Request?'),
                                content: Text(
                                  'Are you sure you want to decline this direct request from ${req.name}?\n\nThe customer will be notified immediately.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                    child: const Text('Decline Request'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await dbService.declineDirectRequest(
                                requestId: req.id,
                                workerId: worker.uid,
                                workerName: worker.name,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request declined. Customer has been notified.'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dbService = context.watch<DatabaseService>();
    final worker = authService.currentUser;
    final theme = Theme.of(context);

    if (worker == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              worker.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Worker • ${worker.workerSkill ?? "General"}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          const ThemeModeToggleButton(compact: true),
          NotificationBadgeButton(user: worker),
          IconButton(
            tooltip: 'Edit Profile & Details',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => EditProfileDialog.show(context, user: worker),
          ),
          IconButton(
            tooltip: 'Service History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(currentUser: worker),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await authService.signOut();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.explore_outlined), text: 'Available Jobs'),
            Tab(icon: Icon(Icons.task_alt), text: 'My Active Jobs'),
          ],
        ),
      ),
      body: Column(
        children: [

          // Worker Performance & Status KPI Bar
          _buildWorkerKpiBar(worker, theme),

          // Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Available Jobs (Pending & Direct Invitations)
                StreamBuilder<List<ServiceRequest>>(
                  stream: dbService.streamWorkerDirectInvitations(worker.uid),
                  builder: (context, directSnapshot) {
                    final directInvitations = directSnapshot.data ?? [];

                    return StreamBuilder<List<ServiceRequest>>(
                      stream: dbService.streamAvailableRequests(skill: worker.workerSkill),
                      builder: (context, snapshot) {
                        final rawPending = snapshot.data ??
                            dbService.allRequests.where((r) => r.status == 'pending').toList();

                        // Strictly filter so only requests matching the worker's skill are shown
                        final allPending = rawPending.where((r) => _matchesWorkerSkill(worker, r)).toList();

                        // Filter by 20 km if toggle is active and worker has location set
                        final requests = (_filterWithin20Km && worker.hasLocation)
                            ? allPending.where((r) {
                                if (!r.hasLocation) return true;
                                final km = _getDistanceKm(worker, r);
                                return km == null || km <= DatabaseService.maxWorkerDistanceKm;
                              }).toList()
                            : allPending;

                        return Column(
                          children: [
                            // Direct Job Invitations Section (1 Hour Limit)
                            _buildDirectInvitationsSection(
                              context,
                              theme,
                              worker,
                              directInvitations,
                            ),

                            // Radius & Specialization Filter Header
                            Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.build_circle, size: 14, color: theme.colorScheme.onPrimaryContainer),
                                        const SizedBox(width: 4),
                                        Text(
                                          worker.workerSkill?.isNotEmpty == true ? worker.workerSkill! : 'All Skills',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.radar, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '20 km',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              FilterChip(
                                selected: _filterWithin20Km,
                                avatar: Icon(
                                  _filterWithin20Km ? Icons.check : Icons.filter_alt_outlined,
                                  size: 14,
                                ),
                                label: Text(
                                  _filterWithin20Km ? 'Within 20 km' : 'All Requests',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onSelected: (val) {
                                  setState(() {
                                    _filterWithin20Km = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Job List
                        Expanded(
                          child: requests.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _filterWithin20Km
                                              ? Icons.location_off_outlined
                                              : Icons.assignment_turned_in_outlined,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _filterWithin20Km
                                              ? 'No ${worker.workerSkill ?? "matching"} requests within 20 km'
                                              : 'No open ${worker.workerSkill ?? "matching"} requests right now',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _filterWithin20Km
                                              ? 'There are no active customer requests for ${worker.workerSkill ?? "your skill"} within 20 km of your base location.'
                                              : 'New customer requests matching your skill (${worker.workerSkill ?? "General"}) will appear here in real-time.',
                                          style: const TextStyle(color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (_filterWithin20Km && allPending.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.public, size: 16),
                                            label: Text('View All Jobs (${allPending.length})'),
                                            onPressed: () {
                                              setState(() {
                                                _filterWithin20Km = false;
                                              });
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  itemCount: requests.length,
                                  itemBuilder: (context, index) {
                                    final req = requests[index];
                                    final distanceStr = _getDistanceToJob(worker, req);
                                    final distanceKm = _getDistanceKm(worker, req);
                                    final bool isOutOfRadius = distanceKm != null &&
                                        distanceKm > DatabaseService.maxWorkerDistanceKm;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Chip(
                                                  avatar: const Icon(Icons.build, size: 16),
                                                  label: Text(req.service),
                                                ),
                                                Row(
                                                  children: [
                                                    if (distanceStr != null) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isOutOfRadius
                                                              ? Colors.red.shade50
                                                              : Colors.green.shade50,
                                                          border: Border.all(
                                                            color: isOutOfRadius
                                                                ? Colors.red.shade300
                                                                : Colors.green.shade300,
                                                          ),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isOutOfRadius
                                                                  ? Icons.location_off
                                                                  : Icons.directions_walk,
                                                              size: 14,
                                                              color: isOutOfRadius
                                                                  ? Colors.red.shade800
                                                                  : Colors.green.shade800,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              isOutOfRadius
                                                                  ? '${distanceKm.toStringAsFixed(1)} km (> 20 km)'
                                                                  : '$distanceStr • In Range',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: isOutOfRadius
                                                                    ? Colors.red.shade900
                                                                    : Colors.green.shade900,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: req.priority.toLowerCase() == 'high'
                                                            ? Colors.red.shade100
                                                            : Colors.blue.shade100,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${req.priority} Priority',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: req.priority.toLowerCase() == 'high'
                                                              ? Colors.red.shade800
                                                              : Colors.blue.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                    if (req.hasImages) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF3E8FF),
                                                          border: Border.all(color: const Color(0xFFD8B4FE)),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.photo_library, size: 12, color: Color(0xFF7C3AED)),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '${req.images.length} photo${req.images.length > 1 ? "s" : ""}',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF7C3AED),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              req.description.isNotEmpty
                                                  ? req.description
                                                  : 'No description provided',
                                              style: const TextStyle(fontSize: 15),
                                            ),
                                            if (req.hasImages) ...[
                                              const SizedBox(height: 8),
                                              InkWell(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ServiceDetailsScreen(request: req),
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFAF5FF),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFE9D5FF)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.camera_alt, size: 14, color: Color(0xFF7C3AED)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '${req.images.length} Issue Photo${req.images.length > 1 ? "s" : ""} Attached • Tap to inspect before accepting',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF6B21A8),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.chevron_right, size: 14, color: Color(0xFF7C3AED)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(req.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                const SizedBox(width: 16),
                                                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    req.address,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 24),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                if (req.hasLocation)
                                                  OutlinedButton.icon(
                                                    icon: const Icon(Icons.map_outlined, size: 16),
                                                    label: const Text('Map'),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => LocationPickerScreen(
                                                            initialLatitude: req.latitude,
                                                            initialLongitude: req.longitude,
                                                            initialAddress: req.address,
                                                            title: '${req.service} Location',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                if (req.hasImages) ...[
                                                  const SizedBox(width: 8),
                                                  OutlinedButton.icon(
                                                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF7C3AED)),
                                                    label: Text(
                                                      'Photos (${req.images.length})',
                                                      style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: Color(0xFFD8B4FE)),
                                                      backgroundColor: const Color(0xFFFAF5FF),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => ServiceDetailsScreen(request: req),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                                const SizedBox(width: 8),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => ServiceDetailsScreen(request: req),
                                                      ),
                                                    );
                                                  },
                                                  child: const Text('View Details'),
                                                ),
                                                const SizedBox(width: 8),

                                                // Accept Job Button / Out-of-radius guard
                                                if (isOutOfRadius)
                                                  FilledButton.tonalIcon(
                                                    icon: const Icon(Icons.block, size: 16),
                                                    label: const Text('Beyond 20 km'),
                                                    style: FilledButton.styleFrom(
                                                      foregroundColor: Colors.red.shade800,
                                                      backgroundColor: Colors.red.shade50,
                                                    ),
                                                    onPressed: () => _showOutOfRadiusDialog(context, distanceKm),
                                                  )
                                                else
                                                  FilledButton.icon(
                                                    icon: const Icon(Icons.check_circle_outline, size: 18),
                                                    label: const Text('Accept Job'),
                                                    onPressed: () async {
                                                      try {
                                                        await dbService.acceptJob(
                                                          requestId: req.id,
                                                          workerId: worker.uid,
                                                          workerName: worker.name,
                                                          worker: worker,
                                                        );
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Accepted job for ${req.service}!'),
                                                              backgroundColor: Colors.green,
                                                            ),
                                                          );
                                                          _tabController.animateTo(1); // switch to active jobs
                                                        }
                                                      } catch (e) {
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                e.toString().replaceAll('Exception:', '').trim(),
                                                              ),
                                                              backgroundColor: Colors.red,
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),

                // TAB 2: My Active Jobs (Assigned to this worker)
                StreamBuilder<List<ServiceRequest>>(
                  stream: dbService.streamWorkerJobs(worker.uid),
                  builder: (context, snapshot) {
                    final rawJobs = snapshot.data ??
                        dbService.allRequests
                            .where((r) => r.workerId == worker.uid)
                            .toList();
                    final jobs = rawJobs.where((r) => _matchesWorkerSkill(worker, r)).toList();

                    if (jobs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.handyman_outlined, size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'No jobs taken yet',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Switch to "Available Jobs" to accept incoming requests.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        final isDone = job.status == 'completed';
                        final distanceStr = _getDistanceToJob(worker, job);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: isDone ? Colors.green.shade100 : Colors.blue.shade100,
                              child: Icon(
                                isDone ? Icons.done_all : Icons.pending,
                                color: isDone ? Colors.green.shade800 : Colors.blue.shade800,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    job.service,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                if (distanceStr != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(
                                      distanceStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Customer: ${job.name} • ${job.mobile}'),
                                Text('Address: ${job.address}'),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (job.hasImages)
                                      InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ServiceDetailsScreen(request: job),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3E8FF),
                                            border: Border.all(color: const Color(0xFFD8B4FE)),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.photo_library, size: 11, color: Color(0xFF7C3AED)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${job.images.length} Photo${job.images.length > 1 ? "s" : ""}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
                                        border: Border.all(
                                          color: isDone ? Colors.green : Colors.amber.shade700,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Status: ${job.status.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDone ? Colors.green.shade900 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                    if (job.isPaid)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          border: Border.all(color: Colors.green.shade600),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.check_circle, size: 12, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              'PAID: ₹${job.totalAmount?.toStringAsFixed(0)} (Razorpay)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (job.isPaymentPending)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          border: Border.all(color: Colors.amber.shade700),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.pending_actions, size: 12, color: Colors.amber.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              'BILL SENT: ₹${job.totalAmount?.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          border: Border.all(color: Colors.blue.shade300),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.receipt_long, size: 12, color: Colors.blue.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              'UNBILLED',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                if (!job.isPaid) ...[
                                  const SizedBox(height: 8),
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    ),
                                    icon: const Icon(Icons.receipt_long, size: 14),
                                    label: Text(
                                      job.isPaymentPending
                                          ? 'Update Bill (₹${job.totalAmount?.toStringAsFixed(0)})'
                                          : 'Decide Bill & Send to Customer',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => SubmitBillDialog.show(
                                      context,
                                      request: job,
                                      worker: worker,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'view' || val == 'photos') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ServiceDetailsScreen(request: job),
                                    ),
                                  );
                                } else if (val == 'map' && job.hasLocation) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LocationPickerScreen(
                                        initialLatitude: job.latitude,
                                        initialLongitude: job.longitude,
                                        initialAddress: job.address,
                                        title: '${job.service} - ${job.name}',
                                      ),
                                    ),
                                  );
                                } else if (val == 'bill') {
                                  SubmitBillDialog.show(
                                    context,
                                    request: job,
                                    worker: worker,
                                  );
                                } else if (val == 'progress') {
                                  await dbService.updateStatus(
                                    requestId: job.id,
                                    newStatus: 'in_progress',
                                  );
                                } else if (val == 'complete') {
                                  await dbService.updateStatus(
                                    requestId: job.id,
                                    newStatus: 'completed',
                                  );
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Text('View Details'),
                                ),
                                if (job.hasImages)
                                  PopupMenuItem(
                                    value: 'photos',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF7C3AED)),
                                        const SizedBox(width: 8),
                                        Text('Issue Photos (${job.images.length})'),
                                      ],
                                    ),
                                  ),
                                if (job.hasLocation)
                                  const PopupMenuItem(
                                    value: 'map',
                                    child: Text('View on Map'),
                                  ),
                                if (!job.isPaid)
                                  PopupMenuItem(
                                    value: 'bill',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.receipt_long, size: 16, color: Colors.deepPurple),
                                        const SizedBox(width: 8),
                                        Text(
                                          job.isPaymentPending
                                              ? 'Update Bill'
                                              : 'Decide Bill & Charge',
                                        ),
                                      ],
                                    ),
                                  ),
                                if (job.status != 'in_progress' && !isDone)
                                  const PopupMenuItem(
                                    value: 'progress',
                                    child: Text('Mark In Progress'),
                                  ),
                                if (!isDone)
                                  const PopupMenuItem(
                                    value: 'complete',
                                    child: Text('Mark Completed'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

