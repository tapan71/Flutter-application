import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/service_request.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../service_details_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Available Jobs (Pending)
          StreamBuilder<List<ServiceRequest>>(
            stream: dbService.streamAvailableRequests(),
            builder: (context, snapshot) {
              final requests = snapshot.data ??
                  dbService.allRequests.where((r) => r.status == 'pending').toList();

              if (requests.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'No open requests right now',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'New customer requests will appear here in real-time.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
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
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            req.description.isNotEmpty
                                ? req.description
                                : 'No description provided',
                            style: const TextStyle(fontSize: 15),
                          ),
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
                              FilledButton.icon(
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: const Text('Accept Job'),
                                onPressed: () async {
                                  await dbService.acceptJob(
                                    requestId: req.id,
                                    workerId: worker.uid,
                                    workerName: worker.name,
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
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // TAB 2: My Active Jobs (Assigned to this worker)
          StreamBuilder<List<ServiceRequest>>(
            stream: dbService.streamWorkerJobs(worker.uid),
            builder: (context, snapshot) {
              final jobs = snapshot.data ??
                  dbService.allRequests
                      .where((r) => r.workerId == worker.uid)
                      .toList();

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
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final isDone = job.status == 'completed';

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
                      title: Text(
                        job.service,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Customer: ${job.name} • ${job.mobile}'),
                          Text('Address: ${job.address}'),
                          const SizedBox(height: 6),
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
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'view') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ServiceDetailsScreen(request: job),
                              ),
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
    );
  }
}
