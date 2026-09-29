import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../services/database_service.dart';

class ReviewDialog extends StatefulWidget {
  final ServiceRequest request;
  final AppUser currentUser;
  final String targetUserId;
  final String targetUserName;
  final bool isCustomerReviewingWorker;

  const ReviewDialog({
    super.key,
    required this.request,
    required this.currentUser,
    required this.targetUserId,
    required this.targetUserName,
    required this.isCustomerReviewingWorker,
  });

  static Future<void> show(
    BuildContext context, {
    required ServiceRequest request,
    required AppUser currentUser,
    required String targetUserId,
    required String targetUserName,
    required bool isCustomerReviewingWorker,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ReviewDialog(
        request: request,
        currentUser: currentUser,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        isCustomerReviewingWorker: isCustomerReviewingWorker,
      ),
    );
  }

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _selectedStars = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a brief feedback comment.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbService = context.read<DatabaseService>();
      final review = Review(
        id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
        requestId: widget.request.id,
        service: widget.request.service,
        fromUserId: widget.currentUser.uid,
        fromUserName: widget.currentUser.name,
        fromUserRole: widget.isCustomerReviewingWorker ? 'customer' : 'worker',
        toUserId: widget.targetUserId,
        toUserName: widget.targetUserName,
        rating: _selectedStars.toDouble(),
        comment: comment,
        createdAt: DateTime.now(),
      );

      await dbService.submitReview(review);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you! Review submitted for ${widget.targetUserName}.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCustomerReviewingWorker
        ? 'Rate & Review Worker'
        : 'Rate & Review Customer';

    final subtitle = widget.isCustomerReviewingWorker
        ? 'How was ${widget.targetUserName}\'s ${widget.request.service} work?'
        : 'How was your experience with customer ${widget.targetUserName}?';

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Star Rating Picker
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return IconButton(
                    iconSize: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      starVal <= _selectedStars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedStars = starVal;
                      });
                    },
                  );
                }),
              ),
            ),
            Center(
              child: Text(
                '$_selectedStars of 5 Stars',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Comment input
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Your Feedback / Comment',
                hintText: widget.isCustomerReviewingWorker
                    ? 'e.g. Arrived on time, professional, and solved the issue quickly!'
                    : 'e.g. Great communication, clear instructions, smooth experience!',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitReview,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Review'),
        ),
      ],
    );
  }
}
