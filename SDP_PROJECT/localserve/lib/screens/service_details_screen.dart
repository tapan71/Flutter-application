import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/map_preview_card.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/review_dialog.dart';

class ServiceDetailsScreen extends StatelessWidget {
  final ServiceRequest request;
  final AppUser? currentUser;

  const ServiceDetailsScreen({
    super.key,
    required this.request,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final dbService = context.watch<DatabaseService>();
    final authService = context.watch<AuthService>();
    final effectiveUser = currentUser ?? authService.currentUser;
    final theme = Theme.of(context);

    // Reactively get latest request from DatabaseService
    final currentReq = dbService.allRequests
        .where((r) => r.id == request.id)
        .firstOrNull ?? request;

    final workerLat = effectiveUser?.isWorker == true ? effectiveUser?.latitude : null;
    final workerLng = effectiveUser?.isWorker == true ? effectiveUser?.longitude : null;
    final workerName = effectiveUser?.isWorker == true ? effectiveUser?.name : null;

    final bool isCustomerOwner = effectiveUser != null &&
        (currentReq.customerId == effectiveUser.uid ||
            (currentReq.email.isNotEmpty &&
                currentReq.email.toLowerCase() == effectiveUser.email.toLowerCase()));

    final bool isWorkerUser = effectiveUser?.isWorker == true;
    final bool isAssignedWorker = isWorkerUser && currentReq.workerId == effectiveUser?.uid;
    final bool hasApplied = isWorkerUser && currentReq.applicantWorkerIds.contains(effectiveUser?.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS BANNER
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Builder(
                  builder: (_) {
                    final isCancelled = currentReq.isCancelled || currentReq.status == 'cancelled';
                    IconData icon = Icons.pending_actions;
                    Color iconColor = Colors.orange;
                    String statusText = 'Pending Acceptance';

                    if (isCancelled) {
                      icon = Icons.cancel;
                      iconColor = Colors.red;
                      statusText = 'Cancelled by Customer';
                    } else if (currentReq.completed) {
                      icon = Icons.check_circle;
                      iconColor = Colors.green;
                      statusText = 'Completed';
                    } else if (currentReq.isAssigned) {
                      icon = Icons.assignment_turned_in;
                      iconColor = theme.colorScheme.primary;
                      statusText = 'Assigned & Confirmed';
                    } else if (currentReq.isInProgress) {
                      icon = Icons.engineering;
                      iconColor = Colors.teal;
                      statusText = 'In Progress';
                    }

                    return Column(
                      children: [
                        Icon(
                          icon,
                          size: 56,
                          color: iconColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isCancelled ? Colors.red.shade800 : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentReq.service,
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            if (currentReq.isCancelled || currentReq.status == 'cancelled') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'This request has been cancelled by the customer. No further work can be performed.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // OPENSTREETMAP PREVIEW
            if (currentReq.hasLocation) ...[
              MapPreviewCard(
                latitude: currentReq.latitude!,
                longitude: currentReq.longitude!,
                address: currentReq.address,
                title: 'Customer Location on OpenStreetMap',
                workerLatitude: workerLat,
                workerLongitude: workerLng,
                workerName: workerName,
                isInteractive: true,
              ),
              const SizedBox(height: 16),
            ],

            // SECTION: APPLICANT WORKERS (CUSTOMER VIEW)
            if (isCustomerOwner && currentReq.isPending) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.group_outlined, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Interested Workers (${currentReq.applicantWorkerIds.length})',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (currentReq.applicantWorkerIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Awaiting Confirmation',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentReq.applicantWorkerIds.isEmpty
                          ? 'No workers have accepted yet. Verified specialists within 20 km will appear here as soon as they accept.'
                          : 'Review the worker details, photo, and previous customer reviews below. Confirming one worker will automatically reject others.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 12),

                      if (currentReq.applicantWorkerIds.isNotEmpty)
                        Column(
                          children: currentReq.applicantWorkerIds.map((workerId) {
                            final worker = dbService.allUsers
                                .where((u) => u.uid == workerId)
                                .firstOrNull;

                            final distanceKm = (worker?.hasLocation == true && currentReq.hasLocation)
                                ? dbService.calculateDistanceKm(
                                    lat1: worker!.latitude,
                                    lon1: worker.longitude,
                                    lat2: currentReq.latitude,
                                    lon2: currentReq.longitude,
                                  )
                                : null;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: theme.colorScheme.primaryContainer,
                                        backgroundImage: worker?.avatarUrl != null
                                            ? NetworkImage(worker!.avatarUrl!)
                                            : null,
                                        child: worker?.avatarUrl == null
                                            ? Text(
                                                worker != null && worker.name.isNotEmpty
                                                    ? worker.name[0].toUpperCase()
                                                    : 'W',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              worker?.name ?? 'Specialist Worker',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              '🔧 ${worker?.workerSkill ?? "General"} Specialist',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${worker?.rating.toStringAsFixed(1) ?? "4.8"} (${worker?.ratingCount ?? 0} reviews)',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                if (distanceKm != null) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '• ${distanceKm.toStringAsFixed(1)} km away',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.green.shade800,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      // View Profile & Reviews Button
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                          icon: const Icon(Icons.badge_outlined, size: 16),
                                          label: const Text('View Profile', style: TextStyle(fontSize: 12)),
                                          onPressed: () {
                                            if (worker != null) {
                                              UserProfileDialog.show(
                                                context,
                                                user: worker,
                                                showActionButtons: true,
                                                onConfirmWorker: () async {
                                                  await dbService.confirmWorker(
                                                    requestId: currentReq.id,
                                                    workerId: worker.uid,
                                                    workerName: worker.name,
                                                    customerId: currentUser?.uid ?? currentReq.customerId ?? '',
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Confirmed ${worker.name} for this job!'),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                },
                                                onDeclineWorker: () async {
                                                  await dbService.declineWorker(
                                                    requestId: currentReq.id,
                                                    workerId: worker.uid,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Declined ${worker.name}. Checking next applicants.'),
                                                      ),
                                                    );
                                                  }
                                                },
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Decline Button
                                      IconButton.outlined(
                                        tooltip: 'Decline Worker',
                                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                        onPressed: () async {
                                          await dbService.declineWorker(
                                            requestId: currentReq.id,
                                            workerId: workerId,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Declined ${worker?.name ?? "worker"}. Next applicant displayed.'),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      // Confirm Button
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('Confirm', style: TextStyle(fontSize: 12)),
                                          onPressed: () async {
                                            await dbService.confirmWorker(
                                              requestId: currentReq.id,
                                              workerId: workerId,
                                              workerName: worker?.name ?? 'Worker',
                                              customerId: currentUser?.uid ?? currentReq.customerId ?? '',
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Confirmed ${worker?.name ?? "worker"} for this job!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // SECTION: CONFIRMED ASSIGNED WORKER (WHEN ASSIGNED OR COMPLETED)
            if (currentReq.workerId != null && currentReq.workerId!.isNotEmpty) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Confirmed Worker',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock, size: 12, color: Colors.green.shade800),
                                const SizedBox(width: 4),
                                Text(
                                  'Confirmed & Locked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: const Icon(Icons.person, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentReq.workerName ?? 'Worker',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${currentReq.service} Specialist',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.badge_outlined, size: 16),
                            label: const Text('Profile'),
                            onPressed: () async {
                              final workerUser = await dbService.getUserById(currentReq.workerId!);
                              if (workerUser != null && context.mounted) {
                                UserProfileDialog.show(context, user: workerUser);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // SECTION: MUTUAL REVIEWS (AFTER COMPLETION)
            if (currentReq.completed) ...[
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.amber.shade50.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.rate_review, color: Colors.amber),
                          const SizedBox(width: 8),
                          const Text(
                            'Job Reviews & Ratings',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Customer Review Action
                      if (isCustomerOwner) ...[
                        if (!currentReq.customerReviewed) ...[
                          Text(
                            'Please leave a review for your worker, ${currentReq.workerName ?? "Worker"}:',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
                            icon: const Icon(Icons.star, size: 16),
                            label: Text('Rate & Review ${currentReq.workerName ?? "Worker"}'),
                            onPressed: () {
                              ReviewDialog.show(
                                context,
                                request: currentReq,
                                currentUser: effectiveUser,
                                targetUserId: currentReq.workerId ?? '',
                                targetUserName: currentReq.workerName ?? 'Worker',
                                isCustomerReviewingWorker: true,
                              );
                            },
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You have reviewed this worker. Thank you for your feedback!',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],

                      // Worker Review Action
                      if (isAssignedWorker) ...[
                        if (!currentReq.workerReviewed) ...[
                          Text(
                            'Please rate and review customer ${currentReq.name} for this service:',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
                            icon: const Icon(Icons.star, size: 16),
                            label: Text('Rate Customer ${currentReq.name}'),
                            onPressed: () {
                              ReviewDialog.show(
                                context,
                                request: currentReq,
                                currentUser: effectiveUser!,
                                targetUserId: currentReq.customerId ?? '',
                                targetUserName: currentReq.name,
                                isCustomerReviewingWorker: false,
                              );
                            },
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You have reviewed this customer. Thank you for your feedback!',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // CUSTOMER DETAILS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    detailRow('Name', currentReq.name),
                    detailRow('Email', currentReq.email),
                    detailRow('Mobile', currentReq.mobile),
                    detailRow('Address', currentReq.address),
                    if (currentReq.hasLocation)
                      detailRow(
                        'Coordinates',
                        '${currentReq.latitude!.toStringAsFixed(4)}, ${currentReq.longitude!.toStringAsFixed(4)}',
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // REQUEST DETAILS CARD
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    detailRow('Service', currentReq.service),
                    detailRow('Priority', currentReq.priority),
                    detailRow('Reminder', currentReq.reminder ? 'Enabled' : 'Disabled'),
                    detailRow('Status', currentReq.status.toUpperCase()),
                    detailRow('Assigned Worker', currentReq.workerName ?? 'Not yet confirmed'),
                    detailRow(
                      'Due Date',
                      currentReq.dueDate == null
                          ? 'Not selected'
                          : '${currentReq.dueDate!.day}/${currentReq.dueDate!.month}/${currentReq.dueDate!.year}',
                    ),
                    detailRow(
                      'Description',
                      currentReq.description.isEmpty
                          ? 'No description provided'
                          : currentReq.description,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // WORKER ACTIONS & ACCEPTANCE BANNER
            if (isWorkerUser && currentReq.isPending) ...[
              Builder(
                builder: (ctx) {
                  final double? distanceKm = (effectiveUser!.hasLocation && currentReq.hasLocation)
                      ? dbService.calculateDistanceKm(
                          lat1: effectiveUser.latitude,
                          lon1: effectiveUser.longitude,
                          lat2: currentReq.latitude,
                          lon2: currentReq.longitude,
                        )
                      : null;

                  final bool isBeyondRadius = distanceKm != null &&
                      distanceKm > DatabaseService.maxWorkerDistanceKm;

                  final reqService = currentReq.service.trim().toLowerCase();
                  final bool isGeneralRequest =
                      reqService == 'general service' || reqService == 'general';

                  final bool skillMatches = isGeneralRequest ||
                      effectiveUser.workerSkill == null ||
                      effectiveUser.workerSkill!.trim().isEmpty ||
                      effectiveUser.workerSkill!.trim().toLowerCase() == 'general service' ||
                      effectiveUser.workerSkill!.trim().toLowerCase() == 'all' ||
                      effectiveUser.workerSkill!.trim().toLowerCase() == reqService;

                  return Column(
                    children: [
                      if (!skillMatches)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.build_circle_outlined, color: Colors.orange.shade900),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Requires ${currentReq.service} specialist (Your skill: ${currentUser!.workerSkill ?? "General"}). Only ${currentReq.service} workers can accept this request.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

                      // If worker has already applied
                      if (hasApplied) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hourglass_top, color: Colors.blue.shade800),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Application Submitted! Customer has been notified and is reviewing your profile and reviews to confirm.',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: !skillMatches
                              ? FilledButton.tonalIcon(
                                  onPressed: null,
                                  icon: const Icon(Icons.handyman_outlined, size: 18),
                                  label: Text('Requires ${currentReq.service} Specialist'),
                                )
                              : isBeyondRadius
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
                                            requestId: currentReq.id,
                                            workerId: effectiveUser.uid,
                                            workerName: effectiveUser.name,
                                            worker: effectiveUser,
                                          );
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Accepted ${currentReq.service} request! Customer notified to review your profile.',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
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
                      ],
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ],

            // CUSTOMER CANCEL REQUEST BUTTON
            if (isCustomerOwner &&
                !currentReq.completed &&
                currentReq.status != 'completed' &&
                !currentReq.isCancelled &&
                currentReq.status != 'cancelled') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Service Request'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        icon: const Icon(Icons.cancel_outlined, size: 44, color: Colors.red),
                        title: const Text('Cancel Service Request?'),
                        content: Text(
                          'Are you sure you want to cancel your ${currentReq.service} request?\n\n'
                          '${currentReq.workerName != null ? "Assigned worker (${currentReq.workerName}) will be notified." : "Any applied workers will be notified."}',
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

                    if (confirm == true && context.mounted) {
                      await dbService.cancelRequest(requestId: currentReq.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Service request cancelled.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // PROGRESSION BUTTONS (START WORK / COMPLETE JOB)
            if (isAssignedWorker && currentReq.isAssigned && !currentReq.isCancelled && currentReq.status != 'cancelled') ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Work (Mark In Progress)'),
                  onPressed: () async {
                    await dbService.updateStatus(requestId: currentReq.id, newStatus: 'in_progress');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Job status updated to In Progress!')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            if ((isAssignedWorker || isCustomerOwner) && currentReq.isInProgress && !currentReq.isCancelled && currentReq.status != 'cancelled') ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark Job Completed'),
                  onPressed: () async {
                    await dbService.updateStatus(requestId: currentReq.id, newStatus: 'completed');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Job completed! You can now leave a mutual review.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // BACK BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
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