import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
// `widgets.dart` re-exports the project's own ErrorWidget, which collides with
// Flutter's built-in ErrorWidget. This screen uses neither, so the clash is
// hidden rather than resolved with a prefix.
import '../../../core/widgets/widgets.dart' hide ErrorWidget;

/// Shown to a Site Manager, Procurement Officer, Procurement Manager or
/// Administrator who signs in on the mobile app.
///
/// This is intentional, not a missing feature. The mobile app is a **field
/// operations** tool for the three roles that do physical work on site — the
/// Site Engineer, Site Officer and Quality Inspector. Management approval,
/// procurement and administration are desk work driven by external email:
/// the officer issues an RFQ by email, suppliers reply by email, and the
/// returned quotations are keyed in and compared before a manager approves.
/// Duplicating that on a phone would create two places where purchase orders
/// can be raised.
///
/// Suppliers never reach this screen — they are not BuildWise users at all.
class WebOnlyNoticeScreen extends StatelessWidget {
  const WebOnlyNoticeScreen({super.key, required this.roleLabel});

  /// Human-readable role name, e.g. "Procurement Officer".
  final String roleLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('BuildWise')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.laptop_mac, size: 34, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$roleLabel works on the web app',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'Your role runs on the BuildWise web application, not on mobile. '
              'Sign in there to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 26),
            const SectionHeader(title: 'What you do on the web'),
            const SizedBox(height: 10),
            const _Step(
              number: '1',
              title: 'Approve and manage',
              detail:
                  'Site Managers review material requests and procurement recommendations. Administrators manage users, audit trail and service health.',
            ),
            const _Step(
              number: '2',
              title: 'Issue the RFQ by email',
              detail:
                  'Procurement selects supplier contact records and BuildWise emails the RFQ. Suppliers are external — they never log in.',
            ),
            const _Step(
              number: '3',
              title: 'Record, compare and approve',
              detail:
                  'Quotations come back by email and are keyed in. The quotation agent ranks them, deterministic validation runs, then the Procurement Manager approves. The purchase order is created only after that approval.',
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.phone_android, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This device is used on site by the Site Engineer '
                      '(material requests), Site Officer (delivery receiving) '
                      'and Quality Inspector (inspections and NCRs).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// One numbered step in the "how the web workflow works" explainer.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.detail});

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}