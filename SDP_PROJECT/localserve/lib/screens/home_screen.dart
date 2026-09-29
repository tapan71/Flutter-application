import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'service_request_screen.dart';
import 'service_details_screen.dart';
import 'history_screen.dart';
import '../widgets/location_picker_screen.dart';

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
      stream: dbService.streamCustomerRequests(user.uid, customerEmail: user.email),
      builder: (context, snapshot) {
        final allCustomerRequests = snapshot.data ??
            dbService.getCustomerRequests(user.uid, customerEmail: user.email);

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
                tooltip: 'Service History',
                icon: const Icon(Icons.history_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(currentUser: user),
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

                  const SizedBox(height: 16),

                  // Customer Profile Banner showing registered phone & address
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Text(
                                  'Customer Account',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 16, color: Colors.blue),
                              const SizedBox(width: 6),
                              Text(
                                user.mobile.isNotEmpty ? user.mobile : 'No phone registered',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  user.address != null && user.address!.isNotEmpty
                                      ? user.address!
                                      : 'No saved address (Tap to set on map)',
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.edit_location_alt, size: 16),
                                label: Text(user.hasLocation ? 'Edit Map' : 'Set on Map'),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final result = await Navigator.push<LocationPickerResult>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LocationPickerScreen(
                                        initialLatitude: user.latitude,
                                        initialLongitude: user.longitude,
                                        initialAddress: user.address,
                                        title: 'Set Default Home Location',
                                        confirmButtonText: 'Save Home Location',
                                      ),
                                    ),
                                  );

                                  if (result != null && mounted) {
                                    await authService.updateCurrentUserLocation(
                                      latitude: result.latitude,
                                      longitude: result.longitude,
                                      address: result.address,
                                    );
                                    await dbService.updateUserLocation(
                                      uid: user.uid,
                                      latitude: result.latitude,
                                      longitude: result.longitude,
                                      address: result.address,
                                    );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Home location saved: ${result.address}'),
                                          backgroundColor: Colors.green,
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
                  ),

                  const SizedBox(height: 16),

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

                  // ACTION BUTTONS: REQUEST & HISTORY
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => openServiceRequest(),
                          icon: const Icon(Icons.add),
                          label: const Text('Request Service'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HistoryScreen(currentUser: user),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('View History'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
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
                                if (value == 'map' && request.hasLocation) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LocationPickerScreen(
                                        initialLatitude: request.latitude,
                                        initialLongitude: request.longitude,
                                        initialAddress: request.address,
                                        title: '${request.service} Location',
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
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'view',
                                  child: Text('View Details'),
                                ),
                                if (request.hasLocation)
                                  const PopupMenuItem(
                                    value: 'map',
                                    child: Text('View on Map'),
                                  ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
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