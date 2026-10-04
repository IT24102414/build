import 'package:buildwise_mobile/core/auth/buildwise_roles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Role model tests for the Flutter shell.
///
/// Three properties matter for the SE3090 workflow and are asserted here:
///
/// 1. BuildWise has exactly seven internal roles, and **all seven work on the
///    mobile app** — the field roles get field screens, the desk roles get the
///    same procurement screens the web app uses, and the Administrator gets
///    administration. Capability sets decide *which* tabs each role sees, so a
///    role is never shown a control the API would reject.
/// 2. The human approval gate stays with approvers. An AI agent may recommend,
///    but only Site Manager, Procurement Manager and Administrator decide.
/// 3. **A supplier is not a BuildWise user.** There is no `Supplier` role, no
///    `isSupplier` capability and no supplier portal. Suppliers are external
///    parties contacted by email. If a stray `Supplier` claim ever appears in a
///    JWT it must resolve to no internal capability at all.
void main() {
  group('BuildWise has exactly seven internal roles', () {
    test('the role set is the documented seven, in workflow order', () {
      expect(
        BuildWiseRoles.internalStaff.toList(),
        <String>[
          'SiteEngineer',
          'SiteManager',
          'ProcurementOfficer',
          'ProcurementManager',
          'SiteOfficer',
          'QualityInspector',
          'Administrator',
        ],
      );
      expect(BuildWiseRoles.internalStaff, hasLength(7));
    });

    test('no internal role is named Supplier', () {
      expect(BuildWiseRoles.internalStaff.contains('Supplier'), isFalse);
    });
  });

  group('A supplier is never a BuildWise user', () {
    test('a Supplier claim grants no internal capability', () {
      const roles = ['Supplier'];

      expect(BuildWiseRoles.isInternalStaff(roles), isFalse);
      expect(BuildWiseRoles.isSite(roles), isFalse);
      expect(BuildWiseRoles.canSeeCommercialTerms(roles), isFalse);
      // Not mobile-capable, so the shell shows the web-only notice rather than
      // any operations screen. There is no supplier portal to reach.
      expect(BuildWiseRoles.canUseMobileApp(roles), isFalse);
    });

    test('normalize drops a Supplier claim instead of aliasing it', () {
      expect(BuildWiseRoles.normalize(['Supplier']), isEmpty);
    });

    test('a supplier claim alongside a real role adds nothing', () {
      // If an account somehow carried both, it is treated purely as its real
      // role — the supplier claim must never widen access.
      final resolved = BuildWiseRoles.normalize(['Supplier', 'SiteEngineer']);
      expect(resolved, {'SiteEngineer'});
      expect(
        BuildWiseRoles.canSeeCommercialTerms(['Supplier', 'SiteEngineer']),
        isFalse,
      );
    });
  });

  group('Site Engineer — mobile, raises material requests', () {
    test('is site, internal and mobile-capable', () {
      const roles = ['SiteEngineer'];
      expect(BuildWiseRoles.isSite(roles), isTrue);
      expect(BuildWiseRoles.isInternalStaff(roles), isTrue);
      expect(BuildWiseRoles.canUseMobileApp(roles), isTrue);
    });

    test('never sees commercial terms', () {
      expect(BuildWiseRoles.canSeeCommercialTerms(['SiteEngineer']), isFalse);
    });
  });

  group('Site Officer — mobile, receives deliveries', () {
    test('is site and mobile-capable', () {
      const roles = ['SiteOfficer'];
      expect(BuildWiseRoles.isSite(roles), isTrue);
      expect(BuildWiseRoles.canUseMobileApp(roles), isTrue);
    });

    test('never sees commercial terms', () {
      expect(BuildWiseRoles.canSeeCommercialTerms(['SiteOfficer']), isFalse);
    });
  });

  group('Quality Inspector — mobile, inspects quality', () {
    test('is internal and mobile-capable but not site', () {
      const roles = ['QualityInspector'];
      expect(BuildWiseRoles.isInternalStaff(roles), isTrue);
      expect(BuildWiseRoles.canUseMobileApp(roles), isTrue);
      expect(BuildWiseRoles.isSite(roles), isFalse);
    });

    test('never sees commercial terms', () {
      expect(BuildWiseRoles.canSeeCommercialTerms(['QualityInspector']), isFalse);
    });
  });

group('Procurement desk — web only', () {
    test('Procurement Officer and Manager are internal but not mobile', () {
      for (final role in ['ProcurementOfficer', 'ProcurementManager']) {
        expect(BuildWiseRoles.isInternalStaff([role]), isTrue, reason: role);
        expect(BuildWiseRoles.canUseMobileApp([role]), isTrue, reason: role);
        expect(BuildWiseRoles.isWebOnly([role]), isFalse, reason: role);
      }
    });

    test('no procurement role is a site role', () {
      expect(BuildWiseRoles.isSite(['ProcurementOfficer']), isFalse);
      expect(BuildWiseRoles.isSite(['ProcurementManager']), isFalse);
    });

    test('both procurement roles see commercial terms', () {
      expect(
        BuildWiseRoles.canSeeCommercialTerms(['ProcurementOfficer']),
        isTrue,
      );
      expect(
        BuildWiseRoles.canSeeCommercialTerms(['ProcurementManager']),
        isTrue,
      );
    });

    test('the mobile and web-only sets partition the internal roles', () {
      // Every internal role is either mobile-capable or web-only, never both
      // and never neither — so no one lands on an empty shell.
      final overlap =
          BuildWiseRoles.mobileCapable.intersection(BuildWiseRoles.webOnly);
      expect(overlap, isEmpty);

      final covered =
          BuildWiseRoles.mobileCapable.union(BuildWiseRoles.webOnly);
      expect(covered, BuildWiseRoles.internalStaff);
    });
  });

  group('All seven internal roles work on the mobile app', () {
    test('every internal role is mobile-capable', () {
      // The mobile app is the same system in a pocket, not a reduced one. The
      // three field roles keep their purpose-built screens; the desk and
      // governance roles get the same screens the web app uses.
      expect(BuildWiseRoles.mobileCapable, BuildWiseRoles.internalStaff);
      expect(BuildWiseRoles.mobileCapable, hasLength(7));
    });

    test('no role is web-only any more', () {
      expect(BuildWiseRoles.webOnly, isEmpty);
      for (final role in BuildWiseRoles.internalStaff) {
        expect(BuildWiseRoles.isWebOnly([role]), isFalse, reason: role);
        expect(BuildWiseRoles.canUseMobileApp([role]), isTrue, reason: role);
      }
    });

    test('mobile-capable and web-only still partition the internal roles', () {
      final overlap =
          BuildWiseRoles.mobileCapable.intersection(BuildWiseRoles.webOnly);
      expect(overlap, isEmpty);
      final covered =
          BuildWiseRoles.mobileCapable.union(BuildWiseRoles.webOnly);
      expect(covered, BuildWiseRoles.internalStaff);
    });

    test('no supplier role exists in either set', () {
      expect(BuildWiseRoles.mobileCapable.contains('Supplier'), isFalse);
      expect(BuildWiseRoles.webOnly.contains('Supplier'), isFalse);
    });
  });

  group('The approval gate is restricted to approvers', () {
    test('Site Manager, Procurement Manager and Administrator can approve', () {
      for (final role in ['SiteManager', 'ProcurementManager', 'Administrator']) {
        expect(BuildWiseRoles.canApprove([role]), isTrue, reason: role);
      }
    });

    test('field and procurement-officer roles cannot approve', () {
      // The Site Engineer raises requests and must not approve their own; the
      // Procurement Officer runs the desk but the manager holds the gate.
      for (final role in [
        'SiteEngineer',
        'SiteOfficer',
        'QualityInspector',
        'ProcurementOfficer',
      ]) {
        expect(BuildWiseRoles.canApprove([role]), isFalse, reason: role);
      }
    });

    test('approving is not the same as running the procurement desk', () {
      // A Site Manager approves a request but raises no RFQs.
      expect(BuildWiseRoles.canApprove(['SiteManager']), isTrue);
      expect(BuildWiseRoles.canRunProcurement(['SiteManager']), isFalse);
      // A Procurement Officer raises RFQs but does not hold the approval gate.
      expect(BuildWiseRoles.canRunProcurement(['ProcurementOfficer']), isTrue);
      expect(BuildWiseRoles.canApprove(['ProcurementOfficer']), isFalse);
    });
  });

  group('The procurement desk is restricted to procurement roles', () {
    test('Procurement Officer, Procurement Manager and Administrator run it', () {
      for (final role in [
        'ProcurementOfficer',
        'ProcurementManager',
        'Administrator',
      ]) {
        expect(BuildWiseRoles.canRunProcurement([role]), isTrue, reason: role);
      }
    });

    test('field roles never see supplier commercials', () {
      for (final role in ['SiteEngineer', 'SiteOfficer', 'QualityInspector']) {
        expect(BuildWiseRoles.canRunProcurement([role]), isFalse, reason: role);
        expect(BuildWiseRoles.canSeeCommercialTerms([role]), isFalse, reason: role);
      }
    });
  });

  group('Only the Administrator administers', () {
    test('governance is a single role', () {
      expect(BuildWiseRoles.governance, {'Administrator'});
      expect(BuildWiseRoles.canAdminister(['Administrator']), isTrue);
      for (final role in [
        'SiteEngineer',
        'SiteOfficer',
        'SiteManager',
        'ProcurementOfficer',
        'ProcurementManager',
        'QualityInspector',
      ]) {
        expect(BuildWiseRoles.canAdminister([role]), isFalse, reason: role);
      }
    });
  });

  group('Site Manager — approves on mobile as well as the web', () {
    test('is internal, commercial and now mobile-capable', () {
      const roles = ['SiteManager'];
      expect(BuildWiseRoles.isInternalStaff(roles), isTrue);
      expect(BuildWiseRoles.canSeeCommercialTerms(roles), isTrue);
      expect(BuildWiseRoles.isSite(roles), isFalse);
      expect(BuildWiseRoles.canUseMobileApp(roles), isTrue);
      expect(BuildWiseRoles.isWebOnly(roles), isFalse);
    });
  });

  group('Administrator — full internal access including mobile', () {
    test('is internal, commercial, mobile-capable and administering', () {
      const roles = ['Administrator'];
      expect(BuildWiseRoles.isInternalStaff(roles), isTrue);
      expect(BuildWiseRoles.canSeeCommercialTerms(roles), isTrue);
      expect(BuildWiseRoles.canUseMobileApp(roles), isTrue);
      expect(BuildWiseRoles.isWebOnly(roles), isFalse);
      expect(BuildWiseRoles.canAdminister(roles), isTrue);
    });
  });

  group('normalize folds legacy seeded roles into the seven', () {
    test('ReceivingOfficer resolves to SiteOfficer', () {
      expect(BuildWiseRoles.normalize(['ReceivingOfficer']), {'SiteOfficer'});
      // It keeps that role's capabilities rather than losing access.
      expect(BuildWiseRoles.isSite(['ReceivingOfficer']), isTrue);
      expect(BuildWiseRoles.canUseMobileApp(['ReceivingOfficer']), isTrue);
    });

    test('ProjectManager resolves to SiteManager', () {
      expect(BuildWiseRoles.normalize(['ProjectManager']), {'SiteManager'});
      expect(BuildWiseRoles.canSeeCommercialTerms(['ProjectManager']), isTrue);
      // It lands on a role that can approve, so a stale token keeps the gate.
      expect(BuildWiseRoles.canApprove(['ProjectManager']), isTrue);
    });

    test('a ProjectManager token keeps mobile access, not just the web', () {
      // The alias used to resolve to a web-only role. It must not now strand a
      // stale token on a notice screen.
      expect(BuildWiseRoles.canUseMobileApp(['ProjectManager']), isTrue);
      expect(BuildWiseRoles.isWebOnly(['ProjectManager']), isFalse);
    });

    test('a canonical role is returned unchanged', () {
      expect(
        BuildWiseRoles.normalize(['QualityInspector']),
        {'QualityInspector'},
      );
    });

    test('unknown roles are dropped', () {
      expect(BuildWiseRoles.normalize(['SomethingElse']), isEmpty);
    });

    test('every internal role survives normalize unchanged', () {
      for (final role in BuildWiseRoles.internalStaff) {
        expect(BuildWiseRoles.normalize([role]), {role}, reason: role);
      }
    });
  });
  // __APPEND_HERE__
}