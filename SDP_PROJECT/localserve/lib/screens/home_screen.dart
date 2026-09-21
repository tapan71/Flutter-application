import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'service_request_screen.dart';
import 'service_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Search text
  String searchQuery = '';

  // Selected filter
  String selectedFilter = 'All';

  // CREATE and EDIT
  Future<void> openServiceRequest({
    String service = 'General Service',
    ServiceRequest? existingRequest,
  }) async {
    final authService = context.read<AuthService>();
    final dbService = context.read<DatabaseService>();
    final user = authService.currentUser;

    final result = await Navigator.push<ServiceRequest>(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestScreen(
          selectedService: service,
          existingRequest: existingRequest,
          currentUser: user,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (existingRequest == null) {
      await dbService.addRequest(result);
    } else {
      await dbService.updateRequest(result);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingRequest == null
                ? 'Service request submitted successfully'
                : 'Service request updated',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // DELETE
  Future<void> deleteRequest(ServiceRequest request) async {
    final dbService = context.read<DatabaseService>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Request?'),
          content: Text(
            'Are you sure you want to cancel the ${request.service} request?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    await dbService.deleteRequest(request.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request deleted'),
        ),
      );
    }
  }

  // TOGGLE STATUS
  Future<void> toggleCompleted(ServiceRequest request) async {
    final dbService = context.read<DatabaseService>();
    final newStatus = request.completed ? 'pending' : 'completed';
    await dbService.updateStatus(
      requestId: request.id,
      newStatus: newStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dbService = context.watch<DatabaseService>();
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return StreamBuilder<List<ServiceRequest>>(
      stream: dbService.streamCustomerRequests(user.uid),
      builder: (context, snapshot) {
        final allCustomerRequests = snapshot.data ??
            dbService.allRequests.where((r) => r.customerId == user.uid).toList();

        final visibleRequests = allCustomerRequests.where((request) {
          final query = searchQuery.toLowerCase();

          final matchesSearch =
              request.service.toLowerCase().contains(query) ||
                  request.name.toLowerCase().contains(query) ||
                  request.email.toLowerCase().contains(query) ||
                  request.description.toLowerCase().contains(query);

          final matchesFilter = selectedFilter == 'All' ||
              (selectedFilter == 'Pending' && !request.completed) ||
              (selectedFilter == 'Completed' && request.completed);

          return matchesSearch && matchesFilter;
        }).toList();

        final completedCount =
            allCustomerRequests.where((request) => request.completed).length;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LocalServe',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          ),

          body: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding =
                  constraints.maxWidth > 600 ? 40.0 : 16.0;

              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                children: [
                  // Heading
                  const Text(
                    'Find Local Home Services',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a service and request a trusted local professional.',
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 20),

                  // SEARCH
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search your requests...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // FILTER
                  DropdownButtonFormField<String>(
                    initialValue: selectedFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter Requests',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(
                          value: 'Completed', child: Text('Completed')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedFilter = value;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // ADD REQUEST
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => openServiceRequest(),
                      icon: const Icon(Icons.add),
                      label: const Text('Request a Service'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // REQUEST TITLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Service Requests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                        ),
                        child: Text(
                          'Completed: $completedCount / ${allCustomerRequests.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // EMPTY STATE
                  if (visibleRequests.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inbox_outlined,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allCustomerRequests.isEmpty
                                  ? 'You have not submitted any service requests yet.'
                                  : 'No matching requests found.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (allCustomerRequests.isEmpty)
                              OutlinedButton.icon(
                                onPressed: () => openServiceRequest(),
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Request'),
                              ),
                          ],
                        ),
                      ),
                    )

                  // REQUEST LIST
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleRequests.length,
                      itemBuilder: (context, index) {
                        final request = visibleRequests[index];
                        final isDone = request.completed;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDone
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              child: Icon(
                                isDone ? Icons.check : Icons.build,
                                color: isDone
                                    ? Colors.green.shade800
                                    : Colors.blue.shade800,
                              ),
                            ),
                            title: Text(
                              request.service,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${request.priority} priority • '
                                  '${request.workerName != null ? "Assigned to: ${request.workerName}" : "Waiting for worker"}',
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Status: ${request.status.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isDone
                                        ? Colors.green.shade800
                                        : (request.status == 'assigned'
                                            ? Colors.blue.shade800
                                            : Colors.orange.shade800),
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'view') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ServiceDetailsScreen(
                                        request: request,
                                      ),
                                    ),
                                  );
                                }
                                if (value == 'edit') {
                                  openServiceRequest(
                                    service: request.service,
                                    existingRequest: request,
                                  );
                                }
                                if (value == 'delete') {
                                  deleteRequest(request);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'view',
                                  child: Text('View Details'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Cancel/Delete'),
                                ),
                              ],
                            ),
                            onTap: () => toggleCompleted(request),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}