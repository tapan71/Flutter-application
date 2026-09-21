import 'package:flutter/material.dart';

import '../models/service_request.dart';

class ServiceDetailsScreen extends StatelessWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.request,
  });

  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
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

          const SizedBox(height: 24),

          // BACK BUTTON
          SizedBox(
            width: double.infinity,

            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },

              icon: const Icon(
                Icons.arrow_back,
              ),

              label: const Text(
                'Back to Home',
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