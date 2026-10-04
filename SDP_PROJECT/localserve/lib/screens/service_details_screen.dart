import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/map_preview_card.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/review_dialog.dart';
import '../widgets/submit_bill_dialog.dart';
import '../widgets/razorpay_payment_sheet.dart';
import '../widgets/app_image_view.dart';

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
                        if (!isCancelled) ...[
                          const SizedBox(height: 16),
                          _buildProgressStepper(currentReq, theme),
                        ],
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
                                        onBackgroundImageError: worker?.avatarUrl != null ? (error, stackTrace) {} : null,
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

            // SECTION: INVOICE & RAZORPAY PAYMENT
            _buildBillingAndPaymentCard(
              context: context,
              currentReq: currentReq,
              effectiveUser: effectiveUser,
              isCustomerOwner: isCustomerOwner,
              isAssignedWorker: isAssignedWorker,
              isWorkerUser: isWorkerUser,
              dbService: dbService,
              theme: theme,
            ),

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

            // ISSUE PHOTOS & VISUAL INSPECTION CARD
            Card(
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
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.photo_library_rounded,
                                color: Color(0xFF7C3AED),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Issue Photos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (currentReq.hasImages)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD8B4FE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt, size: 14, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Text(
                                  '${currentReq.images.length} photo${currentReq.images.length > 1 ? "s" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isWorkerUser
                          ? 'Visual inspection photos uploaded by customer to help you assess required tools and components before visiting.'
                          : 'Photos attached to this request to assist the specialist with pre-arrival diagnosis.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (currentReq.hasImages) ...[
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: currentReq.images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (ctx, idx) {
                            final imgUrl = currentReq.images[idx];
                            return GestureDetector(
                              onTap: () => _showFullImageViewer(
                                context,
                                currentReq.images,
                                idx,
                                currentReq.service,
                                currentReq.description,
                              ),
                              child: Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      AppImageView(
                                        imageUrl: imgUrl,
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.7),
                                              ],
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '#${idx + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.zoom_in, size: 13, color: Colors.white),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Zoom',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF7C3AED)),
                          SizedBox(width: 4),
                          Text(
                            'Tap any photo to open full-screen pinch & zoom inspection',
                            style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.no_photography_outlined, size: 20, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isWorkerUser
                                    ? 'No photos uploaded by customer. You can inspect the condition on-site.'
                                    : 'No issue photos attached to this request.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

            // WORKER GENERATE / UPDATE BILL ACTION BUTTON
            if (isAssignedWorker &&
                (currentReq.isAssigned || currentReq.isInProgress || currentReq.completed) &&
                !currentReq.isCancelled &&
                currentReq.status != 'cancelled') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0C2340),
                    side: const BorderSide(color: Color(0xFF0C2340), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    currentReq.isBilled
                        ? 'Update Service Bill (Razorpay)'
                        : 'Generate Service Bill (Inspect & Submit)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    SubmitBillDialog.show(
                      context,
                      request: currentReq,
                      worker: effectiveUser!,
                    );
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

  Widget _buildBillingAndPaymentCard({
    required BuildContext context,
    required ServiceRequest currentReq,
    required AppUser? effectiveUser,
    required bool isCustomerOwner,
    required bool isAssignedWorker,
    required bool isWorkerUser,
    required DatabaseService dbService,
    required ThemeData theme,
  }) {
    if (currentReq.isCancelled || currentReq.status == 'cancelled') {
      return const SizedBox.shrink();
    }

    final isPaid = currentReq.isPaid;
    final isBilled = currentReq.isBilled;
    final isPaymentPending = currentReq.isPaymentPending;

    Color cardBorderColor = Colors.grey.shade300;
    Color cardBgColor = Colors.white;

    if (isPaid) {
      cardBorderColor = Colors.green.shade400;
      cardBgColor = Colors.green.shade50.withValues(alpha: 0.35);
    } else if (isPaymentPending) {
      cardBorderColor = const Color(0xFF0C2340);
      cardBgColor = Colors.blue.shade50.withValues(alpha: 0.25);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: isPaymentPending ? 1.5 : 1),
      ),
      color: cardBgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? Colors.green.shade100
                            : (isPaymentPending
                                ? const Color(0xFF0C2340).withValues(alpha: 0.1)
                                : Colors.grey.shade200),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaid ? Icons.verified : Icons.receipt_long_rounded,
                        color: isPaid ? Colors.green.shade800 : const Color(0xFF0C2340),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment & Invoice',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Secured by Razorpay Gateway',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.shade100
                        : (isPaymentPending ? Colors.amber.shade100 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPaid
                          ? Colors.green.shade400
                          : (isPaymentPending ? Colors.amber.shade400 : Colors.grey.shade400),
                    ),
                  ),
                  child: Text(
                    isPaid
                        ? 'PAID VIA RAZORPAY'
                        : (isPaymentPending ? 'PAYMENT PENDING' : 'NOT BILLED YET'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isPaid
                          ? Colors.green.shade900
                          : (isPaymentPending ? Colors.amber.shade900 : Colors.grey.shade700),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // If NOT billed yet:
            if (!isBilled) ...[
              if (isAssignedWorker) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.engineering_outlined, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Inspect the condition of work on-site, enter the work/parts charge, and submit the invoice to the customer.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.add_card, size: 18),
                    label: const Text('Generate Service Bill (Inspect & Submit)'),
                    onPressed: () {
                      SubmitBillDialog.show(
                        context,
                        request: currentReq,
                        worker: effectiveUser!,
                      );
                    },
                  ),
                ),
              ] else if (isCustomerOwner) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your worker (${currentReq.workerName ?? "Worker"}) will inspect the condition of work and submit your itemized invoice here.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const Text(
                  'No invoice generated yet for this request.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ]

            // If billed (either pending or paid):
            else ...[
              // Breakdown details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInvoiceRow(
                      'Work / Service Charge (Decided by worker):',
                      '₹${currentReq.baseAmount?.toStringAsFixed(0) ?? "0"}',
                    ),
                    const SizedBox(height: 6),
                    _buildInvoiceRow(
                      'Condition Inspection Fee (Showing work condition):',
                      '₹${currentReq.inspectionFee?.toStringAsFixed(0) ?? "100"}',
                      badge: 'Fixed ₹100',
                    ),
                    const SizedBox(height: 6),
                    _buildInvoiceRow(
                      currentReq.distanceKm != null
                          ? 'Distance Travel Fee (${currentReq.distanceKm!.toStringAsFixed(1)} km):'
                          : 'Distance Travel Fee:',
                      '₹${currentReq.distanceFee?.toStringAsFixed(0) ?? "250"}',
                      badge: currentReq.distanceKm != null && currentReq.distanceKm! <= 10.0
                          ? '< 10 km (₹250)'
                          : '< 20 km (₹500)',
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Payable Amount:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹${currentReq.totalAmount?.toStringAsFixed(0) ?? "0"}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.green.shade800 : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // If PAID:
              if (isPaid) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade800, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Paid via Razorpay (${currentReq.paymentMethod ?? "Online"})',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Razorpay Payment ID: ${currentReq.paymentId ?? "pay_confirmed"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (currentReq.paidAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Paid on: ${currentReq.paidAt!.day}/${currentReq.paidAt!.month}/${currentReq.paidAt!.year} at ${currentReq.paidAt!.hour}:${currentReq.paidAt!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                        ),
                      ],
                    ],
                  ),
                ),
              ]

              // If PENDING OR FAILED (canPay):
              else if (currentReq.canPay) ...[
                if (isCustomerOwner) ...[
                  if (currentReq.isPaymentFailed) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Previous transaction was not completed. Tap "Retry Payment" to complete securely with Razorpay.',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C2340), // Official Razorpay Dark Navy
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(
                        currentReq.isPaymentFailed ? Icons.replay : Icons.lock,
                        size: 18,
                        color: const Color(0xFF3395FF),
                      ),
                      label: Text(
                        currentReq.isPaymentFailed
                            ? 'Retry Payment (₹${currentReq.totalAmount?.toStringAsFixed(0) ?? "0"}) with Razorpay'
                            : 'Pay ₹${currentReq.totalAmount?.toStringAsFixed(0) ?? "0"} via Razorpay',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final result = await RazorpayPaymentSheet.show(
                          context,
                          request: currentReq,
                          customer: effectiveUser!,
                        );

                        if (result != null && context.mounted) {
                          await dbService.completePayment(
                            requestId: currentReq.id,
                            paymentId: result.paymentId,
                            amount: result.amount,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Payment of ₹${result.amount.toStringAsFixed(0)} completed successfully via Razorpay (ID: ${result.paymentId})!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else if (context.mounted && !currentReq.isPaid) {
                          await dbService.recordPaymentFailure(
                            requestId: currentReq.id,
                            reason: 'Payment incomplete or cancelled by customer',
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Payment was not completed. You can tap "Retry Payment" whenever you are ready.',
                                ),
                                backgroundColor: Colors.deepOrange,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Supports UPI (GPay, PhonePe, Paytm), Debit/Credit Cards & NetBanking',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ] else if (isAssignedWorker) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Update Bill'),
                          onPressed: () {
                            SubmitBillDialog.show(
                              context,
                              request: currentReq,
                              worker: effectiveUser!,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Text(
                            'Customer notified to pay via Razorpay',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String amount, {String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          amount,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProgressStepper(ServiceRequest req, ThemeData theme) {
    // Determine active steps
    final bool step1Active = true; // Requested
    final bool step2Active = req.isAssigned || req.isInProgress || req.completed; // Assigned
    final bool step3Active = req.isInProgress || req.completed; // In Progress
    final bool step4Active = req.completed; // Completed

    return Row(
      children: [
        _buildStepItem(
          label: 'Booked',
          isActive: step1Active,
          icon: Icons.bookmark_added_rounded,
          theme: theme,
        ),
        _buildStepLine(isActive: step2Active, theme: theme),
        _buildStepItem(
          label: 'Assigned',
          isActive: step2Active,
          icon: Icons.person_pin_circle_rounded,
          theme: theme,
        ),
        _buildStepLine(isActive: step3Active, theme: theme),
        _buildStepItem(
          label: 'Working',
          isActive: step3Active,
          icon: Icons.handyman_rounded,
          theme: theme,
        ),
        _buildStepLine(isActive: step4Active, theme: theme),
        _buildStepItem(
          label: 'Done',
          isActive: step4Active,
          icon: Icons.verified_rounded,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String label,
    required bool isActive,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? theme.colorScheme.primary : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine({required bool isActive, required ThemeData theme}) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isActive ? theme.colorScheme.primary : Colors.grey.shade300,
    );
  }

  void _showFullImageViewer(
    BuildContext context,
    List<String> images,
    int initialIndex,
    String service,
    String description,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        int currentIndex = initialIndex;
        final pageController = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Issue Inspection (${currentIndex + 1} of ${images.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Image View with PageView
                      SizedBox(
                        height: 380,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PageView.builder(
                              controller: pageController,
                              itemCount: images.length,
                              onPageChanged: (page) {
                                setDialogState(() {
                                  currentIndex = page;
                                });
                              },
                              itemBuilder: (pCtx, pageIndex) {
                                return InteractiveViewer(
                                  minScale: 0.8,
                                  maxScale: 4.0,
                                  child: AppImageView(
                                    imageUrl: images[pageIndex],
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.broken_image, color: Colors.white54, size: 48),
                                          SizedBox(height: 8),
                                          Text(
                                            'Failed to load full photo',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Prev button
                            if (currentIndex > 0)
                              Positioned(
                                left: 8,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                  ),
                                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                                  onPressed: () {
                                    pageController.previousPage(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),

                            // Next button
                            if (currentIndex < images.length - 1)
                              Positioned(
                                right: 8,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                  ),
                                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                                  onPressed: () {
                                    pageController.nextPage(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Bottom Info Caption
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        color: const Color(0xFF1E293B),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    service,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pinch or double-tap to zoom in',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}