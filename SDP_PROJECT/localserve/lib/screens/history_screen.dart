import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import 'service_details_screen.dart';
import 'service_request_screen.dart';
import '../widgets/razorpay_payment_sheet.dart';
import '../widgets/review_dialog.dart';
import '../widgets/job_otp_verification_dialog.dart';

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
  late final List<String> _tabs;

  @override
  void initState() {
    super.initState();
    if (widget.currentUser.isWorker) {
      _tabs = [
        'All Jobs',
        'Active',
        'Completed',
      ];
    } else {
      _tabs = [
        'All',
        'Active Jobs',
        'Completed',
      ];
    }
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
      stream: user.isWorker
          ? dbService.streamWorkerJobs(user.uid)
          : dbService.streamCustomerRequests(
              user.uid,
              customerEmail: user.email,
            ),
      builder: (context, snapshot) {
        // Collect customer requests or worker jobs based on user role
        final rawRoleRequests = snapshot.data ??
            (user.isWorker
                ? dbService.allRequests.where((r) => r.workerId == user.uid).toList()
                : dbService.getCustomerRequests(
                    user.uid,
                    customerEmail: user.email,
                  ));

        // When displaying requests for this user, strictly enforce skill integrity if worker
        final myRequests = user.isWorker
            ? rawRoleRequests.where((r) {
                if (user.workerSkill == null || user.workerSkill!.isEmpty) return true;
                final skill = user.workerSkill!.trim().toLowerCase();
                if (skill == 'general service' || skill == 'all') return true;
                final s = r.service.trim().toLowerCase();
                return s == skill || s == 'general service' || s == 'general';
              }).toList()
            : rawRoleRequests;

        final sourceList = (!user.isWorker && _showAllSystemRequests)
            ? dbService.allRequests
            : myRequests;

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
        final activeCount = sourceList
            .where((r) =>
                !r.completed &&
                r.status.toLowerCase() != 'completed' &&
                r.status.toLowerCase() != 'cancelled' &&
                !r.isCancelled)
            .length;
        final completedCount =
            sourceList.where((r) => r.completed || r.status == 'completed').length;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              user.isWorker ? 'Job History' : 'Service History',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: user.isWorker
                ? null
                : [
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
              tabs: user.isWorker
                  ? [
                      Tab(text: 'All ($totalCount)'),
                      Tab(text: 'Active ($activeCount)'),
                      Tab(text: 'Completed ($completedCount)'),
                    ]
                  : [
                      Tab(text: 'All ($totalCount)'),
                      Tab(text: 'Active Jobs ($activeCount)'),
                      Tab(text: 'Completed ($completedCount)'),
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
                            (!user.isWorker && _showAllSystemRequests)
                                ? 'Showing all requests across accounts'
                                : (user.isWorker
                                    ? 'Showing assigned & completed jobs for ${user.name} (${user.workerSkill ?? "Worker"})'
                                    : 'Showing requests for ${user.email}'),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        if (!user.isWorker)
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
                  children: user.isWorker
                      ? [
                          // TAB 1: ALL JOBS
                          _buildRequestsList(filteredBySearch, theme, dbService),

                          // TAB 2: ACTIVE / IN PROGRESS
                          _buildRequestsList(
                            filteredBySearch
                                .where((r) =>
                                    !r.completed &&
                                    r.status.toLowerCase() != 'completed' &&
                                    r.status.toLowerCase() != 'cancelled' &&
                                    !r.isCancelled)
                                .toList(),
                            theme,
                            dbService,
                          ),

                          // TAB 3: COMPLETED
                          _buildRequestsList(
                            filteredBySearch
                                .where((r) =>
                                    r.completed ||
                                    r.status.toLowerCase() == 'completed')
                                .toList(),
                            theme,
                            dbService,
                          ),
                        ]
                      : [
                          // TAB 1: ALL
                          _buildRequestsList(filteredBySearch, theme, dbService),

                          // TAB 2: ACTIVE JOBS (All customer requests that are in progress / pending / direct / billed)
                          _buildRequestsList(
                            filteredBySearch
                                .where((r) =>
                                    !r.completed &&
                                    r.status.toLowerCase() != 'completed' &&
                                    r.status.toLowerCase() != 'cancelled' &&
                                    !r.isCancelled)
                                .toList(),
                            theme,
                            dbService,
                          ),

                          // TAB 3: COMPLETED (Completed requests with reviews)
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
          floatingActionButton: user.isWorker
              ? null
              : FloatingActionButton.extended(
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
              if (!widget.currentUser.isWorker && !_showAllSystemRequests) ...[
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

                  if (req.isBilled) ...[
                    _buildPaymentDetailsCard(req, theme, dbService),
                  ],

                  if (isCompleted) ...[
                    _buildReviewsSection(req, theme, dbService),
                  ],

                  const SizedBox(height: 12),

                  // Bottom action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isCompleted)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                          ),
                          label: const Text(
                            'Mark Done',
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: () async {
                            if (widget.currentUser.isWorker) {
                              final verified = await JobOtpVerificationDialog.show(
                                context,
                                request: req,
                              );
                              if (verified == true && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Job OTP verified & marked completed!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              await dbService.updateStatus(
                                requestId: req.id,
                                newStatus: 'completed',
                              );
                            }
                          },
                        )
                      else if (!widget.currentUser.isWorker)
                        TextButton.icon(
                          icon: const Icon(
                            Icons.replay,
                            size: 16,
                          ),
                          label: const Text(
                            'Mark Pending',
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: () async {
                            await dbService.updateStatus(
                              requestId: req.id,
                              newStatus: 'pending',
                            );
                          },
                        ),
                      const SizedBox(width: 8),
                      if (isCompleted &&
                          !(widget.currentUser.isWorker
                              ? req.workerReviewed
                              : req.customerReviewed)) ...[
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber),
                          label: Text(
                            widget.currentUser.isWorker
                                ? 'Rate Customer'
                                : 'Write Review',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            ReviewDialog.show(
                              context,
                              request: req,
                              currentUser: widget.currentUser,
                              targetUserId: widget.currentUser.isWorker
                                  ? (req.customerId ?? '')
                                  : (req.workerId ?? ''),
                              targetUserName: widget.currentUser.isWorker
                                  ? req.name
                                  : (req.workerName ?? 'Worker'),
                              isCustomerReviewingWorker:
                                  !widget.currentUser.isWorker,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!widget.currentUser.isWorker && req.canPay) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: req.isPaymentFailed
                                ? Colors.red.shade700
                                : const Color(0xFF0C2340),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          icon: Icon(
                            req.isPaymentFailed ? Icons.replay : Icons.payment,
                            size: 16,
                          ),
                          label: Text(
                            req.isPaymentFailed
                                ? 'Retry Payment (₹${req.totalAmount?.toStringAsFixed(0)})'
                                : 'Pay ₹${req.totalAmount?.toStringAsFixed(0)} (Razorpay)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () =>
                              _triggerRazorpayPayment(context, req, dbService),
                        ),
                        const SizedBox(width: 8),
                      ],
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

  Widget _buildPaymentDetailsCard(
    ServiceRequest req,
    ThemeData theme,
    DatabaseService dbService,
  ) {
    final bool isPaid = req.isPaid;
    final bool isFailed = req.isPaymentFailed;
    final Color statusColor = isPaid
        ? Colors.green.shade800
        : (isFailed ? Colors.red.shade800 : Colors.amber.shade900);
    final Color bgColor = isPaid
        ? Colors.green.shade50.withValues(alpha: 0.7)
        : (isFailed
            ? Colors.red.shade50.withValues(alpha: 0.7)
            : Colors.amber.shade50.withValues(alpha: 0.7));
    final Color borderColor = isPaid
        ? Colors.green.shade300
        : (isFailed ? Colors.red.shade300 : Colors.amber.shade400);

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status Badge & Total Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPaid
                        ? Icons.verified
                        : (isFailed
                            ? Icons.error_outline
                            : Icons.pending_actions),
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPaid
                        ? 'PAID VIA RAZORPAY'
                        : (isFailed
                            ? 'PAYMENT FAILED / RETRY'
                            : 'PAYMENT DUE (WORKER BILLED)'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Text(
                '₹${req.totalAmount?.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),

          const Divider(height: 16),

          // Printed Itemized Breakdown:
          Text(
            'Printed Payment Details & Bill Breakdown:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),

          // 1. Work Charge
          _buildBillRow(
            '• Work / Labor Charge (decided by worker)',
            '₹${req.baseAmount?.toStringAsFixed(0) ?? "0"}',
          ),
          const SizedBox(height: 3),

          // 2. Inspection Fee
          _buildBillRow(
            '• Work Condition Inspection Fee',
            '₹${req.inspectionFee?.toStringAsFixed(0) ?? "100"}',
            tag: 'Fixed ₹100',
          ),
          const SizedBox(height: 3),

          // 3. Distance Fee
          _buildBillRow(
            req.distanceKm != null
                ? '• Distance Charge (${req.distanceKm!.toStringAsFixed(1)} km from worker)'
                : '• Distance Service Charge',
            '₹${req.distanceFee?.toStringAsFixed(0) ?? "250"}',
            tag: req.distanceKm != null && req.distanceKm! > 10.0
                ? '< 20 km (₹500)'
                : '< 10 km (₹250)',
          ),

          // If Paid: Print Transaction Details (Payment ID, Method, Date & Time)
          if (isPaid) ...[
            const Divider(height: 16),
            Text(
              'Razorpay Transaction Receipt:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 6),
            if (req.paymentId != null)
              _buildBillRow(
                '• Razorpay Payment ID',
                req.paymentId!,
                isMonospace: true,
              ),
            _buildBillRow(
              '• Payment Method',
              req.paymentMethod ?? 'Razorpay (UPI / Card / NetBanking)',
            ),
            if (req.paidAt != null)
              _buildBillRow(
                '• Paid Date & Time',
                _formatDateTime(req.paidAt!),
              ),
          ],

          // If Payment Pending or Failed: Print Retry Payment Guidance
          if (!isPaid) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFailed ? Colors.red.shade200 : Colors.amber.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isFailed ? Icons.warning_amber_rounded : Icons.info_outline,
                    size: 16,
                    color: isFailed ? Colors.red.shade700 : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFailed
                          ? 'Previous transaction was unsuccessful. Please tap "Retry Payment" to complete payment.'
                          : 'Bill is generated. Tap "Pay via Razorpay" or "Retry Payment" below.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isFailed
                            ? Colors.red.shade900
                            : Colors.amber.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsSection(
    ServiceRequest req,
    ThemeData theme,
    DatabaseService dbService,
  ) {
    final user = widget.currentUser;
    final hasUserReviewed =
        user.isWorker ? req.workerReviewed : req.customerReviewed;
    final reqReviews =
        dbService.allReviews.where((r) => r.requestId == req.id).toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                'Service Reviews & Feedback',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (!hasUserReviewed)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  icon: const Icon(Icons.star_rounded,
                      size: 15, color: Colors.amber),
                  label: Text(
                    user.isWorker ? 'Rate Customer' : 'Write Review',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    ReviewDialog.show(
                      context,
                      request: req,
                      currentUser: user,
                      targetUserId:
                          user.isWorker ? (req.customerId ?? '') : (req.workerId ?? ''),
                      targetUserName: user.isWorker
                          ? req.name
                          : (req.workerName ?? 'Worker'),
                      isCustomerReviewingWorker: !user.isWorker,
                    );
                  },
                ),
            ],
          ),
          if (reqReviews.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              hasUserReviewed
                  ? 'Your review has been recorded.'
                  : 'No reviews submitted yet for this completed job.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ...reqReviews.map((rev) {
              final isFromCustomer =
                  rev.fromUserRole.toLowerCase() == 'customer';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (starIndex) => Icon(
                              starIndex < rev.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rev.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFromCustomer
                                ? Colors.blue.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFromCustomer
                                ? 'Customer Review'
                                : 'Worker Feedback',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isFromCustomer
                                  ? Colors.blue.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rev.comment,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'By ${rev.fromUserName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value, {
    String? tag,
    bool isMonospace = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.grey.shade400, width: 0.8),
                  ),
                  child: Text(
                    tag,
                    style:
                        const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: isMonospace ? 'monospace' : null,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  Future<void> _triggerRazorpayPayment(
    BuildContext context,
    ServiceRequest req,
    DatabaseService dbService,
  ) async {
    final result = await RazorpayPaymentSheet.show(
      context,
      request: req,
      customer: widget.currentUser,
    );

    if (result != null && context.mounted) {
      await dbService.completePayment(
        requestId: req.id,
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
    } else if (context.mounted && !req.isPaid) {
      await dbService.recordPaymentFailure(
        requestId: req.id,
        reason: 'Payment incomplete or cancelled by customer',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Payment was not completed. Tap "Retry Payment" to try again.',
            ),
            backgroundColor: Colors.deepOrange,
            action: SnackBarAction(
              label: 'Retry Now',
              textColor: Colors.white,
              onPressed: () => _triggerRazorpayPayment(context, req, dbService),
            ),
          ),
        );
      }
    }
  }
}
