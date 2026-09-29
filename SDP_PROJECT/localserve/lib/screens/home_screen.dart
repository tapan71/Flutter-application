import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'service_request_screen.dart';
import 'service_details_screen.dart';
import 'history_screen.dart';
import '../widgets/location_picker_screen.dart';
import '../widgets/notification_badge_button.dart';
import '../widgets/edit_profile_dialog.dart';

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

  // Services list
  final List<String> services = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Cleaning',
    'Painting',
    'Appliance Repair',
  ];

  // Helper icon for services
  IconData _getServiceIcon(String service) {
    switch (service.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'carpentry':
        return Icons.carpenter;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'painting':
        return Icons.format_paint;
      case 'appliance repair':
        return Icons.home_repair_service;
      default:
        return Icons.handyman;
    }
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

  // CANCEL REQUEST WITH CONFIRMATION
  Future<void> handleCancelRequest(ServiceRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.cancel_outlined, size: 44, color: Colors.red),
        title: const Text('Cancel Service Request?'),
        content: Text(
          'Are you sure you want to cancel your ${request.service} request?\n\n'
          '${request.workerName != null ? "Assigned worker (${request.workerName}) will be notified immediately." : "Any applied workers will be notified."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Request'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final dbService = context.read<DatabaseService>();
      await dbService.cancelRequest(requestId: request.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // DELETE REQUEST (PERMANENT)
  Future<void> deleteRequest(ServiceRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Request?'),
          content: const Text(
            'Are you sure you want to permanently remove this request from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    final dbService = context.read<DatabaseService>();
    await dbService.deleteRequest(request.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request deleted'),
        ),
      );
    }
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
              (selectedFilter == 'Pending' && request.status == 'pending') ||
              (selectedFilter == 'Assigned' &&
                  (request.status == 'assigned' || request.status == 'in_progress')) ||
              (selectedFilter == 'Completed' &&
                  (request.status == 'completed' || request.completed)) ||
              (selectedFilter == 'Cancelled' && request.status == 'cancelled');

          return matchesSearch && matchesFilter;
        }).toList();

        final completedCount = allCustomerRequests
            .where((request) => request.completed || request.status == 'completed')
            .length;

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
              NotificationBadgeButton(user: user),
              IconButton(
                icon: const Icon(Icons.logout),
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
                      hintText: 'Search services, details, or requests...',
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

                  // BANNER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Find Local Home Services',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Verified local electricians, plumbers, carpenters & more.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SECTION: POPULAR SERVICES
                  const Text(
                    'Select a Service',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.edit, size: 14),
                                label: const Text('Edit Profile', style: TextStyle(fontSize: 12)),
                                onPressed: () => EditProfileDialog.show(context, user: user),
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

                  // SERVICE CHIPS / BUTTONS
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.map((service) {
                      return ActionChip(
                        avatar: Icon(_getServiceIcon(service), size: 18),
                        label: Text(service),
                        onPressed: () => openServiceRequest(service: service),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // FILTER DROPDOWN
                  DropdownButtonFormField<String>(
                    initialValue: selectedFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter Requests',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Requests')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending (Waiting for Worker)')),
                      DropdownMenuItem(value: 'Assigned', child: Text('Assigned / In Progress')),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
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
                                  : 'No matching requests found for "$selectedFilter".',
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
                        final isDone = request.completed || request.status == 'completed';
                        final isCancelled = request.status == 'cancelled';

                        Color badgeColor = Colors.orange;
                        String statusLabel = 'PENDING';
                        if (isCancelled) {
                          badgeColor = Colors.red;
                          statusLabel = 'CANCELLED';
                        } else if (isDone) {
                          badgeColor = Colors.green;
                          statusLabel = 'COMPLETED';
                        } else if (request.status == 'in_progress') {
                          badgeColor = Colors.teal;
                          statusLabel = 'IN PROGRESS';
                        } else if (request.status == 'assigned') {
                          badgeColor = Colors.blue;
                          statusLabel = 'ASSIGNED';
                        } else if (request.applicantWorkerIds.isNotEmpty) {
                          badgeColor = Colors.purple;
                          statusLabel = 'APPLICANT READY';
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: badgeColor.withValues(alpha: 0.15),
                              child: Icon(
                                _getServiceIcon(request.service),
                                color: badgeColor,
                              ),
                            ),
                            title: Text(
                              request.service,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${request.priority} priority • '
                                  '${request.workerName != null ? "Worker: ${request.workerName}" : "Waiting for worker"}',
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: badgeColor,
                                    ),
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
                                        currentUser: user,
                                      ),
                                    ),
                                  );
                                }
                                if (value == 'cancel') {
                                  handleCancelRequest(request);
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
                                if (!isDone && !isCancelled)
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Text('Cancel Request', style: TextStyle(color: Colors.red)),
                                  ),
                                if (request.hasLocation)
                                  const PopupMenuItem(
                                    value: 'map',
                                    child: Text('View on Map'),
                                  ),
                                if (!isDone && !isCancelled)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete Permanently'),
                                ),
                              ],
                            ),
                            onTap: () {
                              // Tapping always opens the full details screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ServiceDetailsScreen(
                                    request: request,
                                    currentUser: user,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
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