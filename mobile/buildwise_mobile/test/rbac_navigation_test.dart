import 'package:buildwise_mobile/core/auth/buildwise_roles.dart';
import 'package:flutter_test/flutter_test.dart';

/// Role model tests for the Flutter shell.
///
/// Two properties matter for the SE3090 workflow and are asserted here:
///
/// 1. BuildWise has exactly seven internal roles, and the procurement desk is
///    web-only — so a Procurement Officer signing in on the phone is directed
///    to the web app rather than shown a partial procurement UI.
/// 2. **A supplier is not a BuildWise user.** There is no `Supplier` role, no
///    `isSupplier` capability and no supplier screen. Suppliers are external
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
        expect(BuildWiseRoles.canUseMobileApp([role]), isFalse, reason: role);
        expect(BuildWiseRoles.isWebOnly([role]), isTrue, reason: role);
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

  group('The mobile app is a field-operations app for exactly three roles', () {
    test('only Site Engineer, Site Officer and Quality Inspector are mobile', () {
      expect(
        BuildWiseRoles.mobileCapable,
        {'SiteEngineer', 'SiteOfficer', 'QualityInspector'},
      );
    });

    test('Site Manager and Administrator are web-only', () {
      // Approval and governance are desk work; there is no field task for
      // either role on a site device.
      for (final role in ['SiteManager', 'Administrator']) {
        expect(BuildWiseRoles.canUseMobileApp([role]), isFalse, reason: role);
        expect(BuildWiseRoles.isWebOnly([role]), isTrue, reason: role);
      }
    });

    test('no supplier role exists in either set', () {
      expect(BuildWiseRoles.mobileCapable.contains('Supplier'), isFalse);
      expect(BuildWiseRoles.webOnly.contains('Supplier'), isFalse);
    });
  });

  group('Site Manager — approves on the web, not on mobile', () {
    test('is internal and commercial, but not a field role', () {
      const roles = ['SiteManager'];
      expect(BuildWiseRoles.isInternalStaff(roles), isTrue);
      expect(BuildWiseRoles.canSeeCommercialTerms(roles), isTrue);
      expect(BuildWiseRoles.isSite(roles), isFalse);
      // Reviewing and approving a material request is a web task.
      expect(BuildWiseRoles.canUseMobileApp(roles), isFalse);
      expect(BuildWiseRoles.isWebOnly(roles), isTrue);
    });
  });

  group('Administrator — full internal access, web only', () {
    test('is internal and commercial but has no mobile surface', () {
      const roles = ['Administrator'];
      expect(BuildWiseRoles.isInternalStaff(roles), isTrue);
      expect(BuildWiseRoles.canSeeCommercialTerms(roles), isTrue);
      // User management, audit trail and health monitoring are not field work.
      expect(BuildWiseRoles.canUseMobileApp(roles), isFalse);
      expect(BuildWiseRoles.isWebOnly(roles), isTrue);
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