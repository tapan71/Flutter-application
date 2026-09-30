import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../services/database_service.dart';
import 'edit_profile_dialog.dart';

class UserProfileDialog extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onConfirmWorker;
  final VoidCallback? onDeclineWorker;
  final bool showActionButtons;
  final bool showEditProfileButton;

  const UserProfileDialog({
    super.key,
    required this.user,
    this.onConfirmWorker,
    this.onDeclineWorker,
    this.showActionButtons = false,
    this.showEditProfileButton = false,
  });

  static void show(
    BuildContext context, {
    required AppUser user,
    VoidCallback? onConfirmWorker,
    VoidCallback? onDeclineWorker,
    bool showActionButtons = false,
    bool showEditProfileButton = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserProfileDialog(
        user: user,
        onConfirmWorker: onConfirmWorker,
        onDeclineWorker: onDeclineWorker,
        showActionButtons: showActionButtons,
        showEditProfileButton: showEditProfileButton,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = context.watch<DatabaseService>();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Profile Header (Avatar + Name + Rating)
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            onBackgroundImageError: user.avatarUrl != null ? (error, stackTrace) {} : null,
                            child: user.avatarUrl == null
                                ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.isWorker
                                  ? '🔧 ${user.workerSkill ?? "General"} Specialist'
                                  : '👤 Customer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                user.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${user.ratingCount} reviews)',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.task_alt, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                '${user.completedJobsCount} completed jobs',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),

                          // Prominent Edit Profile button for customer/worker viewing own profile
                          if (showEditProfileButton) ...[
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text(
                                'Edit Profile & Address',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                EditProfileDialog.show(context, user: user);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const Divider(height: 32),

                    // Bio / About
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const Text(
                        'About & Experience',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.bio!,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Contact & Location
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Details & Location',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        if (showEditProfileButton)
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Edit', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context);
                              EditProfileDialog.show(context, user: user);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined, color: Colors.indigo),
                      title: Text(user.email.isNotEmpty ? user.email : 'Not provided'),
                      subtitle: const Text('Registered Email', style: TextStyle(fontSize: 11)),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_outlined, color: Colors.green),
                      title: Text(user.mobile.isNotEmpty ? user.mobile : 'Not provided'),
                      subtitle: const Text('Contact number', style: TextStyle(fontSize: 11)),
                    ),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined, color: Colors.red),
                      title: Text(user.address ?? 'Location not specified'),
                      subtitle: user.hasLocation
                          ? Text(
                              'GPS: ${user.latitude!.toStringAsFixed(4)}, ${user.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                    ),

                    const Divider(height: 28),

                    // Customer Reviews Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Client Reviews (${user.ratingCount})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              user.rating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    StreamBuilder<List<Review>>(
                      stream: dbService.streamReviewsForUser(user.uid),
                      builder: (context, snapshot) {
                        final reviews = snapshot.data ?? dbService.getReviewsForUser(user.uid);
                        if (reviews.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Text(
                              'No reviews yet for this profile.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return Column(
                          children: reviews.map((rev) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          rev.fromUserName,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: List.generate(5, (starIdx) {
                                            return Icon(
                                              starIdx < rev.rating.round()
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 14,
                                              color: Colors.amber,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      rev.comment,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${rev.service} • ${rev.createdAt.day}/${rev.createdAt.month}/${rev.createdAt.year}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    // Confirmation Action Buttons (if shown in customer applicant flow)
                    if (showActionButtons) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (onDeclineWorker != null)
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  onDeclineWorker?.call();
                                },
                                child: const Text('Decline'),
                              ),
                            ),
                          if (onDeclineWorker != null) const SizedBox(width: 12),
                          if (onConfirmWorker != null)
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Confirm This Worker'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  onConfirmWorker?.call();
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
