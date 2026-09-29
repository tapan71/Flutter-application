import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/map_preview_card.dart';

class ServiceDetailsScreen extends StatelessWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.request,
  });

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final dbService = context.watch<DatabaseService>();
    final currentUser = authService.currentUser;

    // Find worker coordinates for distance / map pairing
    double? workerLat;
    double? workerLng;
    String? workerName;

    if (currentUser?.isWorker == true && currentUser?.hasLocation == true) {
      workerLat = currentUser!.latitude;
      workerLng = currentUser.longitude;
      workerName = currentUser.name;
    } else if (request.workerId != null) {
      final assignedWorker = dbService.allUsers.where((u) => u.uid == request.workerId).firstOrNull;
      if (assignedWorker?.hasLocation == true) {
        workerLat = assignedWorker!.latitude;
        workerLng = assignedWorker.longitude;
        workerName = assignedWorker.name;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service Details',
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),

        children: [
          // STATUS CARD
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                children: [
                  Icon(
                    request.completed
                        ? Icons.check_circle
                        : Icons.pending_actions,

                    size: 60,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    request.completed
                        ? 'Completed'
                        : 'Pending',

                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    request.service,

                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // MAP PREVIEW (OpenStreetMap)
          if (request.hasLocation) ...[
            MapPreviewCard(
              latitude: request.latitude!,
              longitude: request.longitude!,
              address: request.address,
              title: 'Customer Location on OpenStreetMap',
              workerLatitude: workerLat,
              workerLongitude: workerLng,
              workerName: workerName,
              isInteractive: true,
            ),
            const SizedBox(height: 16),
          ],

          // CUSTOMER DETAILS
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Customer Details',

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  detailRow(
                    'Name',
                    request.name,
                  ),

                  detailRow(
                    'Email',
                    request.email,
                  ),

                  detailRow(
                    'Mobile',
                    request.mobile,
                  ),

                  detailRow(
                    'Address',
                    request.address,
                  ),
                  if (request.hasLocation)
                    detailRow(
                      'Coordinates',
                      '${request.latitude!.toStringAsFixed(4)}, ${request.longitude!.toStringAsFixed(4)}',
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // REQUEST DETAILS
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Request Details',

                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  detailRow(
                    'Service',
                    request.service,
                  ),

                  detailRow(
                    'Priority',
                    request.priority,
                  ),

                  detailRow(
                    'Reminder',
                    request.reminder
                        ? 'Enabled'
                        : 'Disabled',
                  ),

                  detailRow(
                    'Status',
                    request.status.toUpperCase(),
                  ),

                  detailRow(
                    'Assigned Worker',
                    request.workerName ?? 'Not yet assigned',
                  ),

                  detailRow(
                    'Due Date',
                    request.dueDate == null
                        ? 'Not selected'
                        : '${request.dueDate!.day}/'
                        '${request.dueDate!.month}/'
                        '${request.dueDate!.year}',
                  ),

                  detailRow(
                    'Description',
                    request.description.isEmpty
                        ? 'No description provided'
                        : request.description,
                  ),
                ],
              ),
            ),
          ),

          // WORKER 20 KM SERVICE RADIUS BANNER
          if (currentUser?.isWorker == true && request.status == 'pending') ...[
            Builder(
              builder: (ctx) {
                final double? distanceKm = (currentUser!.hasLocation && request.hasLocation)
                    ? dbService.calculateDistanceKm(
                        lat1: currentUser.latitude,
                        lon1: currentUser.longitude,
                        lat2: request.latitude,
                        lon2: request.longitude,
                      )
                    : null;

                final bool isBeyondRadius = distanceKm != null &&
                    distanceKm > DatabaseService.maxWorkerDistanceKm;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isBeyondRadius ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBeyondRadius ? Colors.red.shade300 : Colors.green.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isBeyondRadius ? Icons.location_off : Icons.verified,
                            color: isBeyondRadius ? Colors.red.shade800 : Colors.green.shade800,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              distanceKm != null
                                  ? (isBeyondRadius
                                      ? 'Customer is ${distanceKm.toStringAsFixed(1)} km away (Exceeds 20 km limit). Only nearby workers can accept.'
                                      : 'Customer is ${distanceKm.toStringAsFixed(1)} km away. Within your 20 km service radius!')
                                  : 'Location coordinates not fully specified.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isBeyondRadius ? Colors.red.shade900 : Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: isBeyondRadius
                          ? FilledButton.tonalIcon(
                              onPressed: null,
                              icon: const Icon(Icons.block, size: 18),
                              label: const Text('Beyond 20 km Service Radius'),
                            )
                          : FilledButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Accept This Job'),
                              onPressed: () async {
                                try {
                                  await dbService.acceptJob(
                                    requestId: request.id,
                                    workerId: currentUser.uid,
                                    workerName: currentUser.name,
                                    worker: currentUser,
                                  );
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Accepted job for ${request.service}!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.pop(ctx);
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
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
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],

          // BACK BUTTON
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back,
              ),
              label: const Text(
                'Back',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // REUSABLE DETAIL ROW
  Widget detailRow(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),

      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 100,

            child: Text(
              label,

              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}