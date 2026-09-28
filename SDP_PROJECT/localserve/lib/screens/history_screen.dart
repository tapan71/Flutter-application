import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import 'service_details_screen.dart';
import 'service_request_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.currentUser,
  });

  final AppUser currentUser;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAllSystemRequests = false;

  final List<String> _tabs = [
    'All',
    'Pending',
    'Assigned',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  IconData _getServiceIcon(String service) {
    switch (service.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'painting':
        return Icons.format_paint;
      case 'electrical':
        return Icons.electrical_services;
      case 'carpentry':
        return Icons.carpenter;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'appliance repair':
        return Icons.home_repair_service;
      default:
        return Icons.build_circle_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'assigned':
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbService = context.watch<DatabaseService>();
    final theme = Theme.of(context);
    final user = widget.currentUser;

    return StreamBuilder<List<ServiceRequest>>(
      stream: dbService.streamCustomerRequests(
        user.uid,
        customerEmail: user.email,
      ),
      builder: (context, snapshot) {
        // Collect customer requests or all system requests based on toggle
        final customerRequests = snapshot.data ??
            dbService.getCustomerRequests(
              user.uid,
              customerEmail: user.email,
            );

        final sourceList = _showAllSystemRequests
            ? dbService.allRequests
            : customerRequests;

        final query = _searchQuery.trim().toLowerCase();
        final filteredBySearch = sourceList.where((req) {
          if (query.isEmpty) return true;
          return req.service.toLowerCase().contains(query) ||
              req.description.toLowerCase().contains(query) ||
              req.address.toLowerCase().contains(query) ||
              req.priority.toLowerCase().contains(query) ||
              req.status.toLowerCase().contains(query) ||
              (req.workerName?.toLowerCase().contains(query) ?? false);
        }).toList();

        // Calculate summary counters
        final totalCount = sourceList.length;
        final pendingCount =
            sourceList.where((r) => r.status.toLowerCase() == 'pending').length;
        final assignedCount = sourceList
            .where((r) =>
                r.status.toLowerCase() == 'assigned' ||
                r.status.toLowerCase() == 'in_progress')
            .length;
        final completedCount =
            sourceList.where((r) => r.completed || r.status == 'completed').length;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Service History',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: _showAllSystemRequests
                    ? 'Showing All Requests'
                    : 'Showing My Requests',
                icon: Icon(
                  _showAllSystemRequests
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  color: _showAllSystemRequests
                      ? theme.colorScheme.primary
                      : null,
                ),
                onPressed: () {
                  setState(() {
                    _showAllSystemRequests = !_showAllSystemRequests;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(
                        _showAllSystemRequests
                            ? 'Displaying all system requests'
                            : 'Displaying requests for ${user.name}',
                      ),
                    ),
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: false,
              tabs: [
                Tab(text: 'All ($totalCount)'),
                Tab(text: 'Pending ($pendingCount)'),
                Tab(text: 'Assigned ($assignedCount)'),
                Tab(text: 'Done ($completedCount)'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Search & Filter header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search service, address, worker...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _showAllSystemRequests
                                ? 'Showing all requests across accounts'
                                : 'Showing requests for ${user.email}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(() {
                              _showAllSystemRequests = !_showAllSystemRequests;
                            });
                          },
                          child: Text(
                            _showAllSystemRequests
                                ? 'My Account Only'
                                : 'Show All History',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // TabBar Views for each filter state
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: ALL
                    _buildRequestsList(filteredBySearch, theme, dbService),

                    // TAB 2: PENDING
                    _buildRequestsList(
                      filteredBySearch
                          .where((r) => r.status.toLowerCase() == 'pending')
                          .toList(),
                      theme,
                      dbService,
                    ),

                    // TAB 3: ASSIGNED / IN PROGRESS
                    _buildRequestsList(
                      filteredBySearch
                          .where((r) =>
                              r.status.toLowerCase() == 'assigned' ||
                              r.status.toLowerCase() == 'in_progress')
                          .toList(),
                      theme,
                      dbService,
                    ),

                    // TAB 4: COMPLETED
                    _buildRequestsList(
                      filteredBySearch
                          .where((r) =>
                              r.completed ||
                              r.status.toLowerCase() == 'completed')
                          .toList(),
                      theme,
                      dbService,
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push<ServiceRequest>(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceRequestScreen(
                    selectedService: 'General Service',
                    currentUser: user,
                  ),
                ),
              );

              if (result != null) {
                await dbService.addRequest(result);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service request added to history'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('New Request'),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(
    List<ServiceRequest> requests,
    ThemeData theme,
    DatabaseService dbService,
  ) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 64,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No requests found in this section',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try clearing your search query'
                    : 'Any submitted request will appear here with full history.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              if (!_showAllSystemRequests) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllSystemRequests = true;
                    });
                  },
                  icon: const Icon(Icons.all_inbox),
                  label: const Text('View All System Requests'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final statusColor = _getStatusColor(req.status);
        final isCompleted = req.completed || req.status == 'completed';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isCompleted
                  ? Colors.green.shade200
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceDetailsScreen(request: req),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Title + Status Chip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getServiceIcon(req.service),
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.service,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Priority: ${req.priority}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : (req.status == 'assigned'
                                      ? Icons.assignment_ind
                                      : Icons.schedule),
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              req.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (req.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      req.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],

                  const Divider(height: 20),

                  // Contact & Location info
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        req.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.phone_outlined,
                          size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        req.mobile,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  if (req.address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            req.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (req.workerName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.handyman_outlined,
                            size: 15, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Assigned Worker: ${req.workerName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          isCompleted
                              ? Icons.replay
                              : Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(
                          isCompleted ? 'Mark Pending' : 'Mark Done',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () async {
                          final newStatus =
                              isCompleted ? 'pending' : 'completed';
                          await dbService.updateStatus(
                            requestId: req.id,
                            newStatus: newStatus,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServiceDetailsScreen(request: req),
                            ),
                          );
                        },
                        child: const Text(
                          'View Details',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
