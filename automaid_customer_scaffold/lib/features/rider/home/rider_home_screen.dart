import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/assign_job_model.dart';
import '../../../core/widgets/photo_remark_capture.dart';
import '../../../core/widgets/dashboard_banner.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../providers/rider_providers.dart';
import '../scan/scan_qrcode_screen.dart';
import '../jobs/rider_order_detail_screen.dart';
import '../history/rider_activity_history_screen.dart';
import '../notifications/rider_notifications_screen.dart';
import '../profile/rider_profile_screen.dart';

class RiderHomeScreen extends ConsumerWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final homeAsync = ref.watch(riderHomeProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Rider'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ScanQrcodeScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity history',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RiderActivityHistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RiderProfileScreen())),
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
              mascotAsset: 'assets/images/mascot_rider.png',
              subtitle: state.isDuty ? 'On duty — visible for new jobs' : 'Off duty',
              onNotificationTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const RiderNotificationsScreen())),
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
              onChanged: (v) => ref.read(riderHomeProvider.notifier).toggleDuty(v),
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
            // looking) labels. Every open job for this rider, pending or
            // accepted, now lives here exactly once, always showing its
            // true current step.
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
    // Every handoff step — including final delivery — now requires a
    // photo before it can be confirmed. (Previous comment here claimed
    // confirmDelivery had its own dedicated multi-photo flow elsewhere;
    // that flow never actually existed in the codebase — this wires it
    // up properly instead, using the same shared capture sheet as
    // every other step.)
    PhotoRemarkResult? capture;
    if (widget.job.code == RiderStatusCode.readyForPickup) {
      capture = await showPhotoRemarkCapture(context, title: 'Item picked up / delivered to outlet');
      if (capture == null) return; // dismissed without confirming
    } else if (widget.job.code == RiderStatusCode.pickupFromWashOutlet) {
      capture = await showPhotoRemarkCapture(context, title: 'Picked up from outlet — delivering to customer');
      if (capture == null) return;
    } else if (widget.job.code == RiderStatusCode.deliveryToCustomer) {
      capture = await showPhotoRemarkCapture(context, title: 'Delivered to customer');
      if (capture == null) return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(riderHomeProvider.notifier);
    try {
      switch (widget.job.code) {
        case RiderStatusCode.pendingAcceptance:
          await notifier.acceptJob(widget.job.id);
          break;
        case RiderStatusCode.readyForPickup:
          await notifier.confirmPickup(widget.job.id, photoPath: capture?.photoPath, remark: capture?.remark);
          break;
        case RiderStatusCode.pickupFromWashOutlet:
          await notifier.confirmPickupFromOutlet(widget.job.id, photoPath: capture?.photoPath, remark: capture?.remark);
          break;
        case RiderStatusCode.deliveryToCustomer:
          await notifier.confirmDelivery(widget.job.id, photoPath: capture!.photoPath, remark: capture.remark);
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${widget.job.actionLabel} — done.')));
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
            builder: (_) => RiderOrderDetailScreen(id: job.id, isComplete: false),
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
              if (job.hasAction)
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleAction,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(job.actionLabel),
                )
              else
                Chip(label: Text(job.actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
