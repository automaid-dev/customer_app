import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/assign_job_model.dart';
import '../../../core/widgets/photo_remark_capture.dart';
import '../../../core/widgets/dashboard_banner.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../providers/merchant_providers.dart';
import '../scan/merchant_scan_qrcode_screen.dart';
import '../jobs/merchant_order_detail_screen.dart';
import '../history/merchant_activity_history_screen.dart';
import '../notifications/merchant_notifications_screen.dart';
import '../profile/merchant_profile_screen.dart';

class MerchantHomeScreen extends ConsumerWidget {
  const MerchantHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final homeAsync = ref.watch(merchantHomeProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Outlet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MerchantScanQrcodeScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity history',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MerchantActivityHistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MerchantProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showLogoutConfirmDialog(context);
              if (confirmed) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: homeAsync.when(
        data: (state) => Column(
          children: [
            DashboardBanner(
              name: user?.name ?? '',
              mascotAsset: 'assets/images/mascot_merchant.png',
              subtitle: 'Laundry assistant',
              onNotificationTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const MerchantNotificationsScreen())),
            ),
            // On duty sits right after the banner, before any order
            // content, so it's never sandwiched between order cards
            // and their action buttons — that proximity was causing
            // accidental taps between the duty toggle and the next-step
            // button right below it.
            SwitchListTile(
              title: const Text('On duty'),
              subtitle: Text(state.isDuty ? 'You are visible for new jobs' : "You're off duty"),
              value: state.isDuty,
              onChanged: (v) => ref.read(merchantHomeProvider.notifier).toggleDuty(v),
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Active bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            // One list, one source of truth per order — this used to be
            // duplicated across a separate "Active booking" scroller AND
            // a Today/Incoming tabbed list, so the same order could show
            // twice with two different (and sometimes contradictory-
            // looking) labels. Every open job for this merchant, pending
            // or accepted, now lives here exactly once, always showing
            // its true current step.
            Expanded(
              child: _JobList(jobs: state.active, emptyText: 'No active bookings right now.'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load dashboard: $e')),
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.jobs, this.emptyText = 'No jobs here right now.'});
  final List<AssignJob> jobs;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) return Center(child: Text(emptyText));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: jobs.length,
      itemBuilder: (context, i) => _JobCard(job: jobs[i]),
    );
  }
}

class _JobCard extends ConsumerStatefulWidget {
  const _JobCard({required this.job});
  final AssignJob job;

  @override
  ConsumerState<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<_JobCard> {
  bool _isSubmitting = false;

  Future<void> _handleAction() async {
    // Bag receive and wash complete can optionally capture a photo +
    // remark first — same pattern as the rider app's pickup steps.
    PhotoRemarkResult? capture;
    if (widget.job.code == MerchantStatusCode.awaitingBagDelivery) {
      capture = await showPhotoRemarkCapture(context, title: 'Bag received — wash in progress');
      if (capture == null) return; // dismissed without confirming
    } else if (widget.job.code == MerchantStatusCode.washInProgress) {
      capture = await showPhotoRemarkCapture(context, title: 'Wash completed');
      if (capture == null) return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(merchantHomeProvider.notifier);
    try {
      switch (widget.job.code) {
        case MerchantStatusCode.pendingAcceptance:
          await notifier.acceptJob(widget.job.id);
          break;
        case MerchantStatusCode.awaitingBagDelivery:
          await notifier.receiveBag(widget.job.id, photoPath: capture?.photoPath, remark: capture?.remark);
          break;
        case MerchantStatusCode.washInProgress:
          await notifier.completeWash(widget.job.id, photoPath: capture?.photoPath, remark: capture?.remark);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${widget.job.merchantActionLabel} — done.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final booking = job.booking;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MerchantOrderDetailScreen(id: job.id, isComplete: false),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order #${job.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Status code: ${job.code}'),
              if (booking != null) ...[
                if (booking['pickup_date'] != null)
                  Text('Pickup date: ${booking['pickup_date']}'),
                if (booking['pickup_bag_quantity'] != null)
                  Text('Bags: ${booking['pickup_bag_quantity']}'),
              ],
              const SizedBox(height: 8),
              if (job.merchantHasAction)
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleAction,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(job.merchantActionLabel),
                )
              else
                Chip(label: Text(job.merchantActionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
