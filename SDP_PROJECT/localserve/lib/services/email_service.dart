import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_request.dart';
import '../models/user_model.dart';

/// Professional transactional email dispatch service for LocalServe.
/// Dispatches genuine emails from the system sender: moditapan0@gmail.com
/// Compatible across Flutter Web, Mobile (Android/iOS), and Desktop.
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  /// Format dueDate safely
  static String formatDueDate(DateTime? date) {
    if (date == null) return 'As scheduled / Flexible';
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Official system sender email address
  static const String systemSenderEmail = 'moditapan0@gmail.com';
  static const String systemSenderName = 'LocalServe System';

  /// Key for persisting user-configured Google Apps Script / SMTP relay URL
  static const String prefsWebhookKey = 'localserve_email_webhook_url';

  /// Default Google Apps Script Web App relay endpoint for moditapan0@gmail.com
  /// (Deploy script.google.com with MailApp.sendEmail for 100% free Gmail delivery)
  static const String defaultWebhookUrl =
      'https://script.google.com/macros/s/AKfycbz3v00XydIPjZvABhld9w1TtlnSbiPSR7Vt3a_PfQA0h1631T_mQ4ixJaoLpx_Xy6o/exec';

  String? _customWebhookUrl;

  /// Audit log of sent emails in memory for live inspection & testing
  final List<Map<String, dynamic>> _sentEmailLog = [];
  List<Map<String, dynamic>> get sentEmailLog => List.unmodifiable(_sentEmailLog);

  /// Get the active webhook relay URL
  Future<String> getWebhookUrl() async {
    if (_customWebhookUrl != null && _customWebhookUrl!.trim().isNotEmpty) {
      return _customWebhookUrl!.trim();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefsWebhookKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _customWebhookUrl = saved.trim();
        return _customWebhookUrl!;
      }
    } catch (_) {}
    return defaultWebhookUrl;
  }

  /// Update the active webhook relay URL (e.g. from app settings or test dialog)
  Future<void> setWebhookUrl(String url) async {
    _customWebhookUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsWebhookKey, _customWebhookUrl!);
    } catch (e) {
      debugPrint('[EmailService] Error saving webhook URL: $e');
    }
  }

  /// -------------------------------------------------------------
  /// 1. SEND DIRECT WORKER REQUEST EMAIL
  /// Dispatched when a customer directly requests a specific worker.
  /// -------------------------------------------------------------
  Future<bool> sendDirectRequestEmail({
    required ServiceRequest request,
    required AppUser customer,
    required AppUser targetWorker,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    bool allSuccess = true;

    // 1. Email to Target Worker
    if (targetWorker.email.trim().isNotEmpty) {
      final workerSubject =
          'LocalServe: Direct ${request.service} Request from ${customer.name}';
      final workerPlain = '''
Hello ${targetWorker.name},

You have received a DIRECT service request for "${request.service}" from customer ${customer.name}.

Job Details:
- Service: ${request.service}
- Customer Name: ${customer.name}
- Location: ${request.address}
- Phone: ${customer.mobile.isNotEmpty ? customer.mobile : 'Provided in app'}
- Date/Time: ${formatDueDate(request.dueDate)}
- Job ID: #${request.id}

IMPORTANT - 1-HOUR RESPONSE WINDOW:
Please log in to the LocalServe app within 1 hour to accept or decline this direct request.

LocalServe Partner Network
System Notification sent via $systemSenderEmail
''';

      final workerHtml = _buildDirectRequestEmailHtml(
        recipientName: targetWorker.name,
        service: request.service,
        requestId: request.id,
        otherPartyName: customer.name,
        otherPartyRole: 'Customer',
        address: request.address,
        timeSlot: formatDueDate(request.dueDate),
        phone: customer.mobile,
        isWorker: true,
      );

      final ok = await _dispatchHttpRequest(
        to: targetWorker.email.trim().toLowerCase(),
        subject: workerSubject,
        plainMessage: workerPlain,
        htmlBody: workerHtml,
        role: 'Worker',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
      );
      if (!ok) allSuccess = false;
    }

    // 2. Email confirmation to Customer
    if (customer.email.trim().isNotEmpty) {
      final customerSubject =
          'LocalServe: Direct Request Sent to ${targetWorker.name} (${request.service})';
      final customerPlain = '''
Hello ${customer.name},

Your direct service request for "${request.service}" has been sent to ${targetWorker.name}.

Details:
- Professional: ${targetWorker.name} (${targetWorker.workerSkill ?? request.service})
- Location: ${request.address}
- Job ID: #${request.id}
- Verification OTP: ${request.otp ?? 'Generated upon booking'}

${targetWorker.name} has been notified and has 1 hour to accept your request. We will notify you immediately once they respond!

Thank you for choosing LocalServe!
System Notification sent via $systemSenderEmail
''';

      final customerHtml = _buildDirectRequestEmailHtml(
        recipientName: customer.name,
        service: request.service,
        requestId: request.id,
        otherPartyName: targetWorker.name,
        otherPartyRole: 'Verified Professional',
        address: request.address,
        timeSlot: formatDueDate(request.dueDate),
        phone: targetWorker.mobile,
        otp: request.otp,
        isWorker: false,
      );

      final ok = await _dispatchHttpRequest(
        to: customer.email.trim().toLowerCase(),
        subject: customerSubject,
        plainMessage: customerPlain,
        htmlBody: customerHtml,
        role: 'Customer',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
        otp: request.otp,
      );
      if (!ok) allSuccess = false;
    }

    return allSuccess;
  }

  /// -------------------------------------------------------------
  /// 2. SEND NEARBY JOB ALERT EMAIL TO MATCHING WORKERS
  /// Dispatched for simple/broadcast requests to workers within 20km.
  /// -------------------------------------------------------------
  Future<bool> sendNearbyJobAlertEmail({
    required ServiceRequest request,
    required AppUser worker,
    double? distanceKm,
  }) async {
    final workerEmail = worker.email.trim().toLowerCase();
    if (workerEmail.isEmpty) return false;

    final timestamp = DateTime.now().toIso8601String();
    final distText =
        (distanceKm != null) ? '${distanceKm.toStringAsFixed(1)} km away' : 'Nearby your area';

    final subject = 'LocalServe: New ${request.service} Job Available Nearby! 📍 ($distText)';
    final plainMessage = '''
Hello ${worker.name},

A new service request for "${request.service}" has been posted in your service area ($distText).

Job Overview:
- Service: ${request.service}
- Customer: ${request.name}
- Location: ${request.address}
- Proximity: $distText
- Time Slot: ${formatDueDate(request.dueDate)}
- Job ID: #${request.id}

Open LocalServe now to review the request and apply before other professionals respond!

LocalServe Partner Network
System Notification sent via $systemSenderEmail
''';

    final htmlBody = _buildNearbyAlertEmailHtml(
      workerName: worker.name,
      service: request.service,
      customerName: request.name,
      address: request.address,
      distanceText: distText,
      timeSlot: formatDueDate(request.dueDate),
      requestId: request.id,
    );

    return _dispatchHttpRequest(
      to: workerEmail,
      subject: subject,
      plainMessage: plainMessage,
      htmlBody: htmlBody,
      role: 'Worker',
      serviceType: request.service,
      requestId: request.id,
      timestamp: timestamp,
    );
  }

  /// -------------------------------------------------------------
  /// 3. SEND JOB ACCEPTED / CONFIRMED EMAIL TO BOTH PARTIES
  /// Dispatched when worker accepts direct request or is confirmed by customer.
  /// -------------------------------------------------------------
  Future<bool> sendJobAcceptedEmail({
    required ServiceRequest request,
    required String workerName,
    required String? workerEmail,
    required String customerName,
    required String? customerEmail,
    bool isDirectRequest = false,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    bool allSuccess = true;

    // 1. Email to Customer
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      final subject = 'LocalServe: Job Confirmed! $workerName accepted ${request.service} 🎉';
      final plain = '''
Hello $customerName,

Great news! $workerName has accepted your service request for "${request.service}".

Job Details:
- Assigned Worker: $workerName
- Service: ${request.service}
- Address: ${request.address}
- Scheduled Time: ${formatDueDate(request.dueDate)}
- Job ID: #${request.id}

YOUR COMPLETION OTP: ${request.otp ?? 'Check LocalServe App'}
Please share this 6-digit code with $workerName only AFTER the work is completely done.

LocalServe
System Notification sent via $systemSenderEmail
''';

      final html = _buildJobAcceptedEmailHtml(
        recipientName: customerName,
        otherPartyName: workerName,
        service: request.service,
        requestId: request.id,
        address: request.address,
        timeSlot: formatDueDate(request.dueDate),
        otp: request.otp,
        isCustomer: true,
      );

      final ok = await _dispatchHttpRequest(
        to: customerEmail.trim().toLowerCase(),
        subject: subject,
        plainMessage: plain,
        htmlBody: html,
        role: 'Customer',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
        otp: request.otp,
      );
      if (!ok) allSuccess = false;
    }

    // 2. Email to Worker
    if (workerEmail != null && workerEmail.trim().isNotEmpty) {
      final subject = 'LocalServe: Job Scheduled - ${request.service} with $customerName';
      final plain = '''
Hello $workerName,

Your job for "${request.service}" with customer $customerName is confirmed and scheduled.

Job Details:
- Customer Name: $customerName
- Service: ${request.service}
- Address: ${request.address}
- Scheduled Time: ${formatDueDate(request.dueDate)}
- Job ID: #${request.id}

COMPLETION NOTICE:
Upon finishing the work on-site, ask $customerName for their 6-digit verification OTP and enter it in the app to mark the job complete and receive payment.

LocalServe Partner Network
System Notification sent via $systemSenderEmail
''';

      final html = _buildJobAcceptedEmailHtml(
        recipientName: workerName,
        otherPartyName: customerName,
        service: request.service,
        requestId: request.id,
        address: request.address,
        timeSlot: formatDueDate(request.dueDate),
        otp: null, // Worker does not receive the OTP directly
        isCustomer: false,
      );

      final ok = await _dispatchHttpRequest(
        to: workerEmail.trim().toLowerCase(),
        subject: subject,
        plainMessage: plain,
        htmlBody: html,
        role: 'Worker',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
      );
      if (!ok) allSuccess = false;
    }

    return allSuccess;
  }

  /// -------------------------------------------------------------
  /// 4. SEND PAYMENT RECEIPT & CREDIT EMAIL
  /// Dispatched when customer completes payment via Razorpay.
  /// -------------------------------------------------------------
  Future<bool> sendPaymentReceiptEmail({
    required ServiceRequest request,
    required double amount,
    required String paymentId,
    required String paymentMethod,
    required String? customerEmail,
    required String? workerEmail,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    bool allSuccess = true;

    // 1. Receipt to Customer
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      final subject =
          'LocalServe Payment Receipt: ₹${amount.toStringAsFixed(0)} for ${request.service}';
      final plain = '''
Hello ${request.name},

Thank you for your payment! Here is your official payment receipt for ${request.service}.

Receipt Details:
- Amount Paid: ₹${amount.toStringAsFixed(2)}
- Payment Method: $paymentMethod
- Transaction ID: $paymentId
- Service: ${request.service}
- Professional: ${request.workerName ?? 'LocalServe Partner'}
- Job ID: #${request.id}
- Status: PAID & VERIFIED

LocalServe Customer Support
System Notification sent via $systemSenderEmail
''';

      final html = _buildPaymentReceiptHtml(
        recipientName: request.name,
        service: request.service,
        requestId: request.id,
        amount: amount,
        paymentId: paymentId,
        paymentMethod: paymentMethod,
        otherPartyName: request.workerName ?? 'LocalServe Partner',
        isCustomer: true,
      );

      final ok = await _dispatchHttpRequest(
        to: customerEmail.trim().toLowerCase(),
        subject: subject,
        plainMessage: plain,
        htmlBody: html,
        role: 'Customer',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
      );
      if (!ok) allSuccess = false;
    }

    // 2. Credit Notification to Worker
    if (workerEmail != null && workerEmail.trim().isNotEmpty) {
      final subject =
          'LocalServe: Payment Received - ₹${amount.toStringAsFixed(0)} from ${request.name} 💰';
      final plain = '''
Hello ${request.workerName ?? 'Partner'},

Payment has been successfully received for your service on "${request.service}".

Payment Details:
- Amount Received: ₹${amount.toStringAsFixed(2)}
- Customer: ${request.name}
- Service: ${request.service}
- Transaction ID: $paymentId
- Job ID: #${request.id}
- Payment Status: CREDITED & SETTLED

Thank you for providing outstanding service with LocalServe!
System Notification sent via $systemSenderEmail
''';

      final html = _buildPaymentReceiptHtml(
        recipientName: request.workerName ?? 'Partner',
        service: request.service,
        requestId: request.id,
        amount: amount,
        paymentId: paymentId,
        paymentMethod: paymentMethod,
        otherPartyName: request.name,
        isCustomer: false,
      );

      final ok = await _dispatchHttpRequest(
        to: workerEmail.trim().toLowerCase(),
        subject: subject,
        plainMessage: plain,
        htmlBody: html,
        role: 'Worker',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
      );
      if (!ok) allSuccess = false;
    }

    return allSuccess;
  }

  /// -------------------------------------------------------------
  /// 5. SEND JOB COMPLETED EMAIL TO BOTH PARTIES
  /// Dispatched when worker enters customer's 6-digit OTP and verifies it.
  /// -------------------------------------------------------------
  Future<bool> sendJobCompletedEmail({
    required ServiceRequest request,
    required String? customerEmail,
    required String? workerEmail,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    bool allSuccess = true;

    // 1. Completion Email to Customer
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      final subject = 'LocalServe: Job Completed! ${request.service} (#${request.id}) 🎉';
      final plain = '''
Hello ${request.name},

Your service request for "${request.service}" has been verified with your 6-digit OTP and is now officially COMPLETED!

Summary:
- Service: ${request.service}
- Verified Professional: ${request.workerName ?? 'Partner'}
- Job ID: #${request.id}
- Status: COMPLETED & VERIFIED

Please open the LocalServe app to share your experience and leave a star rating & review for ${request.workerName ?? 'your professional'}.

Thank you for choosing LocalServe!
System Notification sent via $systemSenderEmail
''';

      final html = _buildJobCompletedHtml(
        recipientName: request.name,
        service: request.service,
        requestId: request.id,
        otherPartyName: request.workerName ?? 'Verified Partner',
        isCustomer: true,
      );

      final ok = await _dispatchHttpRequest(
        to: customerEmail.trim().toLowerCase(),
        subject: subject,
        plainMessage: plain,
        htmlBody: html,
        role: 'Customer',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
      );
      if (!ok) allSuccess = false;
    }

    // 2. Completion Email to Worker
    if (workerEmail != null && workerEmail.trim().isNotEmpty) {
      final subject =
          'LocalServe: Job Verified & Completed! ${request.service} (#${request.id})';
      final plain = '''
Hello ${request.workerName ?? 'Partner'},

Congratulations! Customer OTP was successfully verified and job #${request.id} for "${request.service}" is marked COMPLETED.

Summary:
- Service: ${request.service}
- Customer: ${request.name}
- Location: ${request.address}
- Status: COMPLETED & VERIFIED

Please open the LocalServe app to leave a review for customer ${request.name}.

LocalServe Partner Network
System Notification sent via $systemSenderEmail
''';

      final html = _buildJobCompletedHtml(
        recipientName: request.workerName ?? 'Partner',
        service: request.service,
        requestId: request.id,
        otherPartyName: request.name,
        isCustomer: false,
      );

      final ok = await _dispatchHttpRequest(
        to: workerEmail.trim().toLowerCase(),
        subject: subject,
        plainMessage: plain,
        htmlBody: html,
        role: 'Worker',
        serviceType: request.service,
        requestId: request.id,
        timestamp: timestamp,
      );
      if (!ok) allSuccess = false;
    }

    return allSuccess;
  }

  /// -------------------------------------------------------------
  /// 6. SEND SERVICE JOB VERIFICATION OTP EMAIL
  /// Dispatched when a service request is created or reassigned.
  /// -------------------------------------------------------------
  Future<bool> sendJobVerificationOtpEmail({
    required String customerEmail,
    required String customerName,
    required String otp,
    required String serviceName,
    required String requestId,
    String? workerName,
    String? workerEmail,
  }) async {
    final effectiveCustomerEmail = customerEmail.trim().toLowerCase();
    if (effectiveCustomerEmail.isEmpty) {
      debugPrint('[EmailService] Cannot send OTP email: Customer email is empty.');
      return false;
    }

    final timestamp = DateTime.now().toIso8601String();

    // 1. Email to Customer containing the verification OTP
    final customerSubject = 'LocalServe: Your Service Verification OTP is $otp';
    final customerPlain = '''
Hello $customerName,

Your service request for "$serviceName" (ID: $requestId) has been registered.

Your 6-Digit Job Verification OTP: $otp

IMPORTANT:
Please share this OTP with your service worker (${workerName ?? 'assigned professional'}) ONLY after the service has been satisfactorily completed at your location.

Thank you for choosing LocalServe!
System Notification sent via $systemSenderEmail
''';

    final customerHtml = _buildOtpEmailHtml(
      recipientName: customerName,
      otp: otp,
      serviceName: serviceName,
      requestId: requestId,
      workerName: workerName ?? 'Assigned Professional',
      isCustomer: true,
    );

    final customerSuccess = await _dispatchHttpRequest(
      to: effectiveCustomerEmail,
      subject: customerSubject,
      plainMessage: customerPlain,
      htmlBody: customerHtml,
      role: 'Customer',
      serviceType: serviceName,
      requestId: requestId,
      timestamp: timestamp,
      otp: otp,
    );

    // 2. Email to Assigned Worker (if provided) instructing them to collect OTP upon completion
    if (workerEmail != null && workerEmail.trim().isNotEmpty) {
      final effectiveWorkerEmail = workerEmail.trim().toLowerCase();
      final workerSubject =
          'LocalServe: New Job Assigned - $serviceName (OTP Verification Required)';
      final workerPlain = '''
Hello ${workerName ?? 'Partner'},

You have been assigned to a new service job for "$serviceName" (ID: $requestId) for customer $customerName.

Completion Verification Notice:
Upon finishing the work, please ask customer $customerName for their 6-digit verification OTP. You will enter this OTP in the LocalServe app to verify and mark the job as completed.

LocalServe Partner Network
System Notification sent via $systemSenderEmail
''';

      final workerHtml = _buildOtpEmailHtml(
        recipientName: workerName ?? 'Partner',
        otp: null,
        serviceName: serviceName,
        requestId: requestId,
        workerName: workerName ?? 'Partner',
        isCustomer: false,
        customerName: customerName,
      );

      await _dispatchHttpRequest(
        to: effectiveWorkerEmail,
        subject: workerSubject,
        plainMessage: workerPlain,
        htmlBody: workerHtml,
        role: 'Worker',
        serviceType: serviceName,
        requestId: requestId,
        timestamp: timestamp,
        otp: null,
      );
    }

    return customerSuccess;
  }

  /// -------------------------------------------------------------
  /// 7. SEND DUAL-PARTY NOTIFICATION EMAIL (GENERAL FALLBACK)
  /// -------------------------------------------------------------
  Future<bool> sendDualPartyNotificationEmail({
    required String? customerEmail,
    required String? workerEmail,
    required String title,
    required String message,
    String? serviceType,
    String? requestId,
    String? otp,
  }) async {
    final targets = <String>[];
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      targets.add(customerEmail.trim().toLowerCase());
    }
    if (workerEmail != null && workerEmail.trim().isNotEmpty) {
      final w = workerEmail.trim().toLowerCase();
      if (!targets.contains(w)) {
        targets.add(w);
      }
    }

    if (targets.isEmpty) {
      debugPrint('[EmailService] Notice: No recipient email provided for notification "$title"');
      return false;
    }

    final timestamp = DateTime.now().toIso8601String();
    bool allSuccess = true;

    for (final recipient in targets) {
      final isCustomer = (recipient == customerEmail?.trim().toLowerCase());
      final role = isCustomer ? 'Customer' : 'Worker';
      final subject = 'LocalServe: $title';

      final htmlBody = _buildNotificationEmailHtml(
        title: title,
        message: message,
        role: role,
        serviceType: serviceType ?? 'Home Service',
        requestId: requestId ?? 'N/A',
        otp: isCustomer ? otp : null,
      );

      final ok = await _dispatchHttpRequest(
        to: recipient,
        subject: subject,
        plainMessage: message,
        htmlBody: htmlBody,
        role: role,
        serviceType: serviceType ?? 'Home Service',
        requestId: requestId ?? 'N/A',
        timestamp: timestamp,
        otp: isCustomer ? otp : null,
      );

      if (!ok) allSuccess = false;
    }

    return allSuccess;
  }

  /// -------------------------------------------------------------
  /// INTERNAL HTTP DISPATCH WORKER
  /// Uses Google Apps Script Webhook / SMTP API relay
  /// text/plain payload prevents CORS preflight OPTIONS failures on Web!
  /// -------------------------------------------------------------
  Future<bool> _dispatchHttpRequest({
    required String to,
    required String subject,
    required String plainMessage,
    required String htmlBody,
    required String role,
    required String serviceType,
    required String requestId,
    required String timestamp,
    String? otp,
  }) async {
    final payload = {
      'to': to,
      'from': systemSenderEmail,
      'fromName': systemSenderName,
      'subject': subject,
      'title': subject,
      'body': plainMessage,
      'message': plainMessage,
      'htmlBody': htmlBody,
      'role': role,
      'service': serviceType,
      'requestId': requestId,
      'otp': otp ?? '',
      'timestamp': timestamp,
    };

    _sentEmailLog.insert(0, payload);
    if (_sentEmailLog.length > 100) {
      _sentEmailLog.removeLast();
    }

    debugPrint(
      '📧 [EmailService] Dispatching from <$systemSenderEmail> to $role <$to> | Subject: "$subject"',
    );

    final webhookUrl = await getWebhookUrl();

    try {
      // Use text/plain;charset=utf-8 so web browsers treat this as a simple request
      // without failing CORS preflight OPTIONS requests!
      final response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: {
              'Content-Type': 'text/plain;charset=utf-8',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 400) {
        debugPrint(
          '✅ [EmailService] Successfully delivered email to $to via system relay ($systemSenderEmail). Status: ${response.statusCode}',
        );
        return true;
      } else {
        debugPrint(
          '⚠️ [EmailService] Relay responded with status ${response.statusCode}: ${response.body}',
        );
        // Fallback: Attempt GET request with parameters if POST failed
        return await _fallbackGetRequest(webhookUrl, to, subject, plainMessage);
      }
    } catch (e) {
      debugPrint(
        'ℹ️ [EmailService] Relay POST notice for $to ($e). Attempting fallback dispatch...',
      );
      return await _fallbackGetRequest(webhookUrl, to, subject, plainMessage);
    }
  }

  Future<bool> _fallbackGetRequest(
    String webhookUrl,
    String to,
    String subject,
    String plainMessage,
  ) async {
    try {
      final getUri = Uri.parse(webhookUrl).replace(
        queryParameters: {
          'to': to,
          'subject': subject,
          'body': plainMessage,
        },
      );
      final getResp = await http.get(getUri).timeout(const Duration(seconds: 8));
      if (getResp.statusCode >= 200 && getResp.statusCode < 400) {
        debugPrint('✅ [EmailService] Delivered email via GET fallback to $to');
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: DIRECT SERVICE REQUEST
  /// -------------------------------------------------------------
  String _buildDirectRequestEmailHtml({
    required String recipientName,
    required String service,
    required String requestId,
    required String otherPartyName,
    required String otherPartyRole,
    required String address,
    required String timeSlot,
    String? phone,
    String? otp,
    required bool isWorker,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Direct Request</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; margin: 0; color: #ffffff; }
    .subtitle { font-size: 13px; color: #e0f2fe; margin-top: 4px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 32px 28px; }
    .badge { display: inline-block; background: #e0f2fe; color: #0284c7; padding: 6px 12px; border-radius: 20px; font-size: 12px; font-weight: 700; margin-bottom: 16px; }
    .greeting { font-size: 18px; font-weight: 700; margin-bottom: 12px; }
    .timer-alert { background: #fff7ed; border-left: 4px solid #f97316; padding: 14px 18px; border-radius: 8px; font-size: 14px; color: #9a3412; margin: 20px 0; line-height: 1.5; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; background: #f8fafc; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
    .info-label { font-weight: 600; color: #64748b; width: 35%; }
    .info-value { font-weight: 500; color: #0f172a; }
    .otp-box { background: #f0fdf4; border: 2px dashed #16a34a; border-radius: 12px; padding: 16px; text-align: center; margin: 20px 0; }
    .otp-code { font-size: 32px; font-weight: 800; letter-spacing: 6px; color: #15803d; font-family: monospace; }
    .footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 11px; color: #64748b; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="logo">LocalServe</h1>
      <div class="subtitle">Direct Service Gateway</div>
    </div>
    <div class="content">
      <div class="badge">⚡ DIRECT REQUEST</div>
      <div class="greeting">Hello $recipientName,</div>
      ${isWorker ? '<p>You have received a <strong>direct service request</strong> for <strong>$service</strong>. The customer selected you specifically for this work.</p>' : '<p>Your direct request for <strong>$service</strong> was successfully dispatched to <strong>$otherPartyName</strong>.</p>'}

      ${isWorker ? '''
      <div class="timer-alert">
        ⏳ <strong>1-Hour Response Window:</strong> Please review and accept this request in the LocalServe app within 1 hour.
      </div>
      ''' : ''}

      <table class="info-table">
        <tr>
          <td class="info-label">Service</td>
          <td class="info-value"><strong>$service</strong></td>
        </tr>
        <tr>
          <td class="info-label">$otherPartyRole</td>
          <td class="info-value">$otherPartyName</td>
        </tr>
        <tr>
          <td class="info-label">Address</td>
          <td class="info-value">$address</td>
        </tr>
        <tr>
          <td class="info-label">Scheduled Time</td>
          <td class="info-value">$timeSlot</td>
        </tr>
        ${phone != null && phone.isNotEmpty ? '''
        <tr>
          <td class="info-label">Phone</td>
          <td class="info-value">$phone</td>
        </tr>
        ''' : ''}
        <tr>
          <td class="info-label">Job Reference</td>
          <td class="info-value">#$requestId</td>
        </tr>
      </table>

      ${!isWorker && otp != null ? '''
      <div class="otp-box">
        <div style="font-size: 12px; color: #166534; font-weight: 600; text-transform: uppercase;">Your Service Completion OTP</div>
        <div class="otp-code">$otp</div>
        <div style="font-size: 11px; color: #64748b; margin-top: 4px;">Share this code with $otherPartyName only after work is done.</div>
      </div>
      ''' : ''}
    </div>
    <div class="footer">
      Automated System Message sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt;<br>
      © ${DateTime.now().year} LocalServe App • Verified Home Services
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: NEARBY JOB ALERT
  /// -------------------------------------------------------------
  String _buildNearbyAlertEmailHtml({
    required String workerName,
    required String service,
    required String customerName,
    required String address,
    required String distanceText,
    required String timeSlot,
    required String requestId,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Nearby Job Alert</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #059669 0%, #047857 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; margin: 0; color: #ffffff; }
    .subtitle { font-size: 13px; color: #d1fae5; margin-top: 4px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 32px 28px; }
    .badge { display: inline-block; background: #d1fae5; color: #059669; padding: 6px 12px; border-radius: 20px; font-size: 12px; font-weight: 700; margin-bottom: 16px; }
    .greeting { font-size: 18px; font-weight: 700; margin-bottom: 12px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; background: #f8fafc; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
    .info-label { font-weight: 600; color: #64748b; width: 35%; }
    .info-value { font-weight: 500; color: #0f172a; }
    .cta-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 10px; padding: 14px 18px; margin: 20px 0; text-align: center; font-weight: 600; color: #166534; }
    .footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 11px; color: #64748b; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="logo">LocalServe</h1>
      <div class="subtitle">Nearby Opportunities</div>
    </div>
    <div class="content">
      <div class="badge">📍 NEARBY JOB AVAILABLE ($distanceText)</div>
      <div class="greeting">Hello $workerName,</div>
      <p>A customer in your service area has requested <strong>$service</strong> services. Because you are nearby, this opportunity is available to you.</p>

      <table class="info-table">
        <tr>
          <td class="info-label">Service</td>
          <td class="info-value"><strong>$service</strong></td>
        </tr>
        <tr>
          <td class="info-label">Customer</td>
          <td class="info-value">$customerName</td>
        </tr>
        <tr>
          <td class="info-label">Location</td>
          <td class="info-value">$address</td>
        </tr>
        <tr>
          <td class="info-label">Proximity</td>
          <td class="info-value"><strong>$distanceText</strong></td>
        </tr>
        <tr>
          <td class="info-label">Preferred Time</td>
          <td class="info-value">$timeSlot</td>
        </tr>
        <tr>
          <td class="info-label">Job ID</td>
          <td class="info-value">#$requestId</td>
        </tr>
      </table>

      <div class="cta-box">
        🚀 Open LocalServe now to review full details and apply for this job!
      </div>
    </div>
    <div class="footer">
      Automated System Message sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt;<br>
      © ${DateTime.now().year} LocalServe App • Verified Home Services
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: JOB ACCEPTED / SCHEDULED
  /// -------------------------------------------------------------
  String _buildJobAcceptedEmailHtml({
    required String recipientName,
    required String otherPartyName,
    required String service,
    required String requestId,
    required String address,
    required String timeSlot,
    String? otp,
    required bool isCustomer,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Job Confirmed</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #4f46e5 0%, #4338ca 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; margin: 0; color: #ffffff; }
    .subtitle { font-size: 13px; color: #e0e7ff; margin-top: 4px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 32px 28px; }
    .badge { display: inline-block; background: #e0e7ff; color: #4338ca; padding: 6px 12px; border-radius: 20px; font-size: 12px; font-weight: 700; margin-bottom: 16px; }
    .greeting { font-size: 18px; font-weight: 700; margin-bottom: 12px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; background: #f8fafc; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
    .info-label { font-weight: 600; color: #64748b; width: 35%; }
    .info-value { font-weight: 500; color: #0f172a; }
    .otp-box { background: #f0fdf4; border: 2px dashed #16a34a; border-radius: 12px; padding: 18px; text-align: center; margin: 20px 0; }
    .otp-code { font-size: 34px; font-weight: 800; letter-spacing: 6px; color: #15803d; font-family: monospace; }
    .footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 11px; color: #64748b; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="logo">LocalServe</h1>
      <div class="subtitle">Booking Confirmed</div>
    </div>
    <div class="content">
      <div class="badge">🎉 SERVICE CONFIRMED & SCHEDULED</div>
      <div class="greeting">Hello $recipientName,</div>
      ${isCustomer ? '<p>Your service request for <strong>$service</strong> has been accepted by <strong>$otherPartyName</strong>.</p>' : '<p>Your job assignment for <strong>$service</strong> with customer <strong>$otherPartyName</strong> is confirmed.</p>'}

      <table class="info-table">
        <tr>
          <td class="info-label">Service</td>
          <td class="info-value"><strong>$service</strong></td>
        </tr>
        <tr>
          <td class="info-label">${isCustomer ? 'Assigned Worker' : 'Customer'}</td>
          <td class="info-value"><strong>$otherPartyName</strong></td>
        </tr>
        <tr>
          <td class="info-label">Location</td>
          <td class="info-value">$address</td>
        </tr>
        <tr>
          <td class="info-label">Scheduled Time</td>
          <td class="info-value">$timeSlot</td>
        </tr>
        <tr>
          <td class="info-label">Job Reference</td>
          <td class="info-value">#$requestId</td>
        </tr>
      </table>

      ${isCustomer && otp != null ? '''
      <div class="otp-box">
        <div style="font-size: 12px; color: #166534; font-weight: 600; text-transform: uppercase;">Job Verification OTP</div>
        <div class="otp-code">$otp</div>
        <div style="font-size: 11px; color: #64748b; margin-top: 6px;">Share this OTP with $otherPartyName only after work is completed satisfactorily.</div>
      </div>
      ''' : '''
      <div style="background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px 16px; border-radius: 6px; font-size: 13px; color: #92400e; margin: 20px 0;">
        🔑 <strong>OTP Verification:</strong> When you finish the job at the customer site, ask customer $otherPartyName for their 6-digit verification code.
      </div>
      '''}
    </div>
    <div class="footer">
      Automated System Message sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt;<br>
      © ${DateTime.now().year} LocalServe App • Verified Home Services
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: PAYMENT RECEIPT & CREDIT
  /// -------------------------------------------------------------
  String _buildPaymentReceiptHtml({
    required String recipientName,
    required String service,
    required String requestId,
    required double amount,
    required String paymentId,
    required String paymentMethod,
    required String otherPartyName,
    required bool isCustomer,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Payment Confirmation</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #16a34a 0%, #15803d 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; margin: 0; color: #ffffff; }
    .subtitle { font-size: 13px; color: #dcfce7; margin-top: 4px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 32px 28px; }
    .amount-box { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 14px; padding: 20px; text-align: center; margin: 20px 0; }
    .amount-val { font-size: 38px; font-weight: 800; color: #15803d; }
    .amount-label { font-size: 12px; color: #166534; font-weight: 700; text-transform: uppercase; margin-top: 4px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; background: #f8fafc; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
    .info-label { font-weight: 600; color: #64748b; width: 35%; }
    .info-value { font-weight: 500; color: #0f172a; }
    .footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 11px; color: #64748b; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="logo">LocalServe</h1>
      <div class="subtitle">${isCustomer ? 'Official Payment Receipt' : 'Payment Notification'}</div>
    </div>
    <div class="content">
      <div class="amount-box">
        <div class="amount-val">₹${amount.toStringAsFixed(2)}</div>
        <div class="amount-label">${isCustomer ? 'Amount Successfully Paid' : 'Amount Credited & Settled'}</div>
      </div>

      <p>Hello <strong>$recipientName</strong>,</p>
      ${isCustomer ? '<p>Your payment for <strong>$service</strong> was completed successfully via <strong>$paymentMethod</strong>.</p>' : '<p>Payment for service <strong>$service</strong> has been received from customer <strong>$otherPartyName</strong>.</p>'}

      <table class="info-table">
        <tr>
          <td class="info-label">Transaction ID</td>
          <td class="info-value"><code>$paymentId</code></td>
        </tr>
        <tr>
          <td class="info-label">Payment Method</td>
          <td class="info-value">$paymentMethod</td>
        </tr>
        <tr>
          <td class="info-label">Service</td>
          <td class="info-value"><strong>$service</strong></td>
        </tr>
        <tr>
          <td class="info-label">${isCustomer ? 'Worker' : 'Customer'}</td>
          <td class="info-value">$otherPartyName</td>
        </tr>
        <tr>
          <td class="info-label">Job Reference</td>
          <td class="info-value">#$requestId</td>
        </tr>
        <tr>
          <td class="info-label">Status</td>
          <td class="info-value"><span style="color: #16a34a; font-weight: 700;">✓ PAID & VERIFIED</span></td>
        </tr>
      </table>
    </div>
    <div class="footer">
      Automated System Message sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt;<br>
      © ${DateTime.now().year} LocalServe App • Verified Home Services
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: JOB COMPLETED
  /// -------------------------------------------------------------
  String _buildJobCompletedHtml({
    required String recipientName,
    required String service,
    required String requestId,
    required String otherPartyName,
    required bool isCustomer,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Job Completed</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; margin: 0; color: #38bdf8; }
    .subtitle { font-size: 13px; color: #94a3b8; margin-top: 4px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 32px 28px; }
    .verified-badge { display: inline-block; background: #ecfdf5; border: 1px solid #10b981; color: #047857; padding: 6px 14px; border-radius: 20px; font-size: 13px; font-weight: 700; margin-bottom: 16px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; background: #f8fafc; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
    .info-label { font-weight: 600; color: #64748b; width: 35%; }
    .info-value { font-weight: 500; color: #0f172a; }
    .review-box { background: #fefce8; border: 1px solid #fde047; border-radius: 12px; padding: 18px; margin: 24px 0; text-align: center; }
    .footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 11px; color: #64748b; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="logo">LocalServe</h1>
      <div class="subtitle">Job Completion Verified</div>
    </div>
    <div class="content">
      <div class="verified-badge">✓ OTP VERIFIED & COMPLETED</div>
      <div style="font-size: 18px; font-weight: 700; margin-bottom: 12px;">Hello $recipientName,</div>
      ${isCustomer ? '<p>Your service request for <strong>$service</strong> was completed and verified via your 6-digit OTP code.</p>' : '<p>The job for <strong>$service</strong> with customer <strong>$otherPartyName</strong> is successfully closed.</p>'}

      <table class="info-table">
        <tr>
          <td class="info-label">Service</td>
          <td class="info-value"><strong>$service</strong></td>
        </tr>
        <tr>
          <td class="info-label">${isCustomer ? 'Service Partner' : 'Customer'}</td>
          <td class="info-value"><strong>$otherPartyName</strong></td>
        </tr>
        <tr>
          <td class="info-label">Job ID</td>
          <td class="info-value">#$requestId</td>
        </tr>
        <tr>
          <td class="info-label">Status</td>
          <td class="info-value"><span style="color: #16a34a; font-weight: 700;">Completed (OTP Verified)</span></td>
        </tr>
      </table>

      <div class="review-box">
        <div style="font-size: 20px; margin-bottom: 6px;">⭐ ⭐ ⭐ ⭐ ⭐</div>
        <div style="font-weight: 700; color: #854d0e; font-size: 15px;">Rate your experience in LocalServe!</div>
        <div style="font-size: 12px; color: #a16207; margin-top: 4px;">Please open the app to leave a review for $otherPartyName. Your feedback helps our community grow!</div>
      </div>
    </div>
    <div class="footer">
      Automated System Message sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt;<br>
      © ${DateTime.now().year} LocalServe App • Verified Home Services
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: OTP VERIFICATION
  /// -------------------------------------------------------------
  String _buildOtpEmailHtml({
    required String recipientName,
    required String? otp,
    required String serviceName,
    required String requestId,
    required String workerName,
    required bool isCustomer,
    String? customerName,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Verification</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); padding: 28px 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; margin: 0; color: #38bdf8; }
    .subtitle { font-size: 13px; color: #94a3b8; margin-top: 4px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 32px 28px; }
    .greeting { font-size: 18px; font-weight: 600; margin-bottom: 12px; }
    .otp-box { background: #f0fdf4; border: 2px dashed #16a34a; border-radius: 14px; padding: 20px; text-align: center; margin: 24px 0; }
    .otp-code { font-size: 38px; font-weight: 800; letter-spacing: 8px; color: #15803d; font-family: monospace; }
    .otp-caption { font-size: 12px; color: #166534; font-weight: 600; margin-top: 6px; text-transform: uppercase; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px; background: #f8fafc; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; }
    .info-label { font-weight: 600; color: #64748b; width: 35%; }
    .info-value { font-weight: 500; color: #0f172a; }
    .warning { background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px 16px; border-radius: 6px; font-size: 13px; color: #92400e; margin: 20px 0; line-height: 1.5; }
    .footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 11px; color: #64748b; line-height: 1.6; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1 class="logo">LocalServe</h1>
      <div class="subtitle">Home Services Verified Network</div>
    </div>
    <div class="content">
      <div class="greeting">Hello $recipientName,</div>
      ${isCustomer ? '<p>Your service request has been confirmed. Below is your <strong>Service Verification Code (OTP)</strong>:</p>' : '<p>You have been assigned to service request <strong>#$requestId</strong>. Please find the job details below:</p>'}
      
      ${isCustomer && otp != null ? '''
      <div class="otp-box">
        <div class="otp-code">$otp</div>
        <div class="otp-caption">One-Time Job Verification Code</div>
      </div>
      ''' : ''}

      <table class="info-table">
        <tr>
          <td class="info-label">Service Type</td>
          <td class="info-value"><strong>$serviceName</strong></td>
        </tr>
        <tr>
          <td class="info-label">Job ID</td>
          <td class="info-value">#$requestId</td>
        </tr>
        <tr>
          <td class="info-label">${isCustomer ? 'Assigned Worker' : 'Customer Name'}</td>
          <td class="info-value">${isCustomer ? workerName : (customerName ?? 'Customer')}</td>
        </tr>
      </table>

      ${isCustomer ? '''
      <div class="warning">
        🔒 <strong>Confidentiality Notice:</strong> Keep this OTP safe. Only share this 6-digit code with your worker ($workerName) in person after the service has been satisfactorily executed.
      </div>
      ''' : '''
      <div class="warning">
        🔑 <strong>Completion Requirement:</strong> When work is finished at the customer site, request the 6-digit verification OTP from customer ${customerName ?? ''} and enter it in the app to mark the job completed.
      </div>
      '''}
    </div>
    <div class="footer">
      Automated System Message sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt;<br>
      © ${DateTime.now().year} LocalServe App • Instant Home Services
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// HTML TEMPLATE: NOTIFICATION EMAILS
  /// -------------------------------------------------------------
  String _buildNotificationEmailHtml({
    required String title,
    required String message,
    required String role,
    required String serviceType,
    required String requestId,
    String? otp,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>LocalServe Notification</title>
  <style>
    body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 20px; color: #1e293b; }
    .card { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: #0f172a; padding: 24px; text-align: center; color: #ffffff; }
    .logo { font-size: 22px; font-weight: 800; color: #38bdf8; margin: 0; }
    .content { padding: 28px 24px; }
    .title { font-size: 18px; font-weight: 700; color: #0f172a; margin-bottom: 12px; }
    .message-box { background: #f8fafc; border-left: 4px solid #3b82f6; padding: 14px 18px; border-radius: 8px; font-size: 14px; line-height: 1.6; margin: 16px 0; }
    .otp-highlight { background: #ecfdf5; border: 1px solid #10b981; color: #047857; font-weight: 700; font-size: 22px; text-align: center; padding: 12px; border-radius: 8px; margin: 16px 0; letter-spacing: 4px; }
    .footer { background: #f1f5f9; padding: 16px; text-align: center; font-size: 11px; color: #64748b; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="logo">LocalServe</div>
    </div>
    <div class="content">
      <div class="title">$title</div>
      <div class="message-box">$message</div>

      ${otp != null && otp.isNotEmpty ? '''
      <div class="otp-highlight">
        Job OTP: $otp
      </div>
      ''' : ''}

      <p style="font-size: 12px; color: #64748b; margin-top: 20px;">
        Service: <strong>$serviceType</strong> | Job Ref: #$requestId
      </p>
    </div>
    <div class="footer">
      Sent by <strong>$systemSenderName</strong> &lt;$systemSenderEmail&gt; to $role<br>
      © ${DateTime.now().year} LocalServe
    </div>
  </div>
</body>
</html>
''';
  }

  /// -------------------------------------------------------------
  /// READY-TO-PASTE GOOGLE APPS SCRIPT CODE TEMPLATE
  /// Can be copied and pasted into https://script.google.com under moditapan0@gmail.com
  /// Handles both POST (JSON/text) and GET (URL parameters)
  /// -------------------------------------------------------------
  static const String googleAppsScriptCodeTemplate = '''
function doPost(e) {
  try {
    var contents = (e && e.postData) ? e.postData.contents : "";
    var data = contents ? JSON.parse(contents) : {};
    var to = data.to || (e && e.parameter ? e.parameter.to : "");
    var subject = data.subject || "LocalServe Notification";
    var body = data.message || data.body || "";
    var htmlBody = data.htmlBody || body;

    if (!to) {
      return ContentService.createTextOutput(JSON.stringify({
        status: "error",
        message: "Missing 'to' recipient email."
      })).setMimeType(ContentService.MimeType.JSON);
    }

    MailApp.sendEmail({
      to: to,
      subject: subject,
      body: body,
      htmlBody: htmlBody,
      name: "LocalServe System"
    });

    return ContentService.createTextOutput(JSON.stringify({
      status: "success",
      message: "Email dispatched from moditapan0@gmail.com to " + to,
      timestamp: new Date().toISOString()
    })).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({
      status: "error",
      message: err.toString()
    })).setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  if (e && e.parameter && e.parameter.to) {
    try {
      MailApp.sendEmail({
        to: e.parameter.to,
        subject: e.parameter.subject || "LocalServe Notification",
        body: e.parameter.body || e.parameter.message || "",
        htmlBody: e.parameter.htmlBody || e.parameter.body || e.parameter.message || "",
        name: "LocalServe System"
      });
      return ContentService.createTextOutput(JSON.stringify({
        status: "success",
        message: "Email sent via GET to " + e.parameter.to
      })).setMimeType(ContentService.MimeType.JSON);
    } catch(err) {
      return ContentService.createTextOutput(JSON.stringify({
        status: "error",
        message: err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }
  return ContentService.createTextOutput(JSON.stringify({
    status: "online",
    system: "LocalServe Mail Relay",
    sender: "moditapan0@gmail.com"
  })).setMimeType(ContentService.MimeType.JSON);
}
''';
}
