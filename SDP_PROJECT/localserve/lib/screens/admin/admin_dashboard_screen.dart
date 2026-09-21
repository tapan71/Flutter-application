import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/service_request.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../service_details_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dbService = context.watch<DatabaseService>();
    final admin = authService.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LocalServe Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              admin?.name ?? 'Administrator',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
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
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Requests & Stats'),
            Tab(icon: Icon(Icons.people_outline), text: 'User Management'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Requests & Analytics
          StreamBuilder<List<ServiceRequest>>(
            stream: dbService.streamAllRequests(),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? dbService.allRequests;

              final total = requests.length;
              final pending = requests.where((r) => r.status == 'pending').length;
              final active = requests.where((r) => r.status == 'assigned' || r.status == 'in_progress').length;
              final completed = requests.where((r) => r.status == 'completed').length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI Metric Cards
                  Row(
                    children: [
                      _buildMetricCard(context, 'Total', total.toString(), Colors.indigo),
                      const SizedBox(width: 8),
                      _buildMetricCard(context, 'Pending', pending.toString(), Colors.orange),
                      const SizedBox(width: 8),
                      _buildMetricCard(context, 'Active', active.toString(), Colors.blue),
                      const SizedBox(width: 8),
                      _buildMetricCard(context, 'Done', completed.toString(), Colors.green),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Service Requests',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$total Total',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (requests.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No service requests on the platform yet.'),
                      ),
                    )
                  else
                    ...requests.map((req) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(req.status).withValues(alpha: 0.15),
                            child: Icon(
                              _getStatusIcon(req.status),
                              color: _getStatusColor(req.status),
                            ),
                          ),
                          title: Text(
                            req.service,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Customer: ${req.name} • Worker: ${req.workerName ?? "Unassigned"}\nStatus: ${req.status.toUpperCase()}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) async {
                              if (action == 'view') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ServiceDetailsScreen(request: req),
                                  ),
                                );
                              } else if (action == 'complete') {
                                await dbService.updateStatus(
                                  requestId: req.id,
                                  newStatus: 'completed',
                                );
                              } else if (action == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Request?'),
                                    content: Text('Delete ${req.service} permanently?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await dbService.deleteRequest(req.id);
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('View Details'),
                              ),
                              if (req.status != 'completed')
                                const PopupMenuItem(
                                  value: 'complete',
                                  child: Text('Mark Completed'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete (Admin)'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),

          // TAB 2: User Management
          StreamBuilder<List<AppUser>>(
            stream: dbService.streamAllUsers(),
            builder: (context, snapshot) {
              final users = snapshot.data ?? dbService.allUsers;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          user.isAdmin
                              ? Icons.admin_panel_settings
                              : (user.isWorker ? Icons.handyman : Icons.person),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: user.isAdmin
                                  ? Colors.purple.shade100
                                  : (user.isWorker
                                      ? Colors.amber.shade100
                                      : Colors.blue.shade100),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.role.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: user.isAdmin
                                    ? Colors.purple.shade900
                                    : (user.isWorker
                                        ? Colors.amber.shade900
                                        : Colors.blue.shade900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${user.email} • ${user.mobile}'),
                          if (user.isWorker)
                            Text(
                              'Specialization: ${user.workerSkill ?? "General"} • '
                              'Approval: ${user.isApproved ? "Approved" : "Pending"}',
                              style: const TextStyle(color: Colors.teal),
                            ),
                        ],
                      ),
                      trailing: user.isWorker
                          ? Switch(
                              value: user.isApproved,
                              onChanged: (val) async {
                                await dbService.toggleWorkerApproval(
                                  user.uid,
                                  user.isApproved,
                                );
                              },
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      BuildContext context, String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'assigned':
      case 'in_progress':
        return Icons.hourglass_top;
      case 'cancelled':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.access_time;
    }
  }
}
