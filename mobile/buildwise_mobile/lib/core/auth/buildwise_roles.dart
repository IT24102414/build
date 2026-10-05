/// Role vocabulary and screen gating for the Flutter shell.
///
/// BuildWise has exactly **seven internal roles**:
///
/// ```text
/// SiteEngineer → SiteManager → ProcurementOfficer → ProcurementManager
///              → SiteOfficer → QualityInspector → Administrator
/// ```
///
/// There is deliberately **no `Supplier` role**. A supplier is an external
/// party contacted by email; it has no BuildWise login, no JWT, no mobile app
/// and no API access. The only supplier data BuildWise holds is a *contact
/// record* (name + email) that the Procurement Officer uses to send an RFQ and
/// later a purchase order.
///
/// Mirrors backend `BuildWise.Api/Security/Roles.cs` and the React
/// `auth/accessControl.js` table. All three must agree: the API enforces
/// access, these tables decide what to *show*, and a mismatch means a user
/// either sees a screen that 403s or is missing one they are entitled to.
class BuildWiseRoles {
  const BuildWiseRoles._();

  // --- The seven internal roles -------------------------------------------

  static const String siteEngineer = 'SiteEngineer';
  static const String siteManager = 'SiteManager';
  static const String procurementOfficer = 'ProcurementOfficer';
  static const String procurementManager = 'ProcurementManager';
  static const String siteOfficer = 'SiteOfficer';
  static const String qualityInspector = 'QualityInspector';
  static const String administrator = 'Administrator';

  /// Every role a person can actually sign in with.
  static const Set<String> internalStaff = {
    siteEngineer,
    siteManager,
    procurementOfficer,
    procurementManager,
    siteOfficer,
    qualityInspector,
    administrator,
  };

  /// Role names retired by the backend `ConsolidateLegacyRoles` migration,
  /// mapped to their canonical replacement.
  ///
  /// The backend migration re-points every affected account, so this map is only
  /// a short-lived safety net for a JWT minted before that migration ran. Each
  /// mapping was verified to be a permission superset, so a stale token resolves
  /// to the role that replaced it rather than losing the user's access.
  static const Map<String, String> legacyAliases = {
    'ReceivingOfficer': siteOfficer, // receiving-facing alias → Site Officer
    'ProjectManager': siteManager, // approval-facing alias → Site Manager
  };

  // --- Capability groups ---------------------------------------------------

  /// Roles that raise, revise and track material requests on site.
  static const Set<String> siteOperations = {siteEngineer, siteOfficer};

  /// Roles that may record a delivery against a confirmed purchase order.
  ///
  /// Narrower than [siteOperations] on purpose. The Site Officer physically
  /// receives the goods and signs for them; the Site Engineer opens the same
  /// delivery workspace to follow what happened to the material they requested,
  /// read-only. Keeping the write with one role stops a request being marked
  /// satisfied by the same person who raised it.
  static const Set<String> deliveryReceivers = {siteOfficer};

  /// Roles allowed to see purchase order commercial terms. The API redacts
  /// these server-side; the shell mirrors the rule so a receiving or quality
  /// user is never shown a money column.
  static const Set<String> commercial = {
    procurementOfficer,
    procurementManager,
    siteManager,
    administrator,
  };

  /// Roles that approve someone else's work at a human decision gate.
  ///
  /// Mirrors the backend `MaterialRequestApprovalOnly` policy. The API enforces
  /// it; this set only decides whether the Approve/Reject controls are drawn, so
  /// a non-approver never taps a button that would 403.
  static const Set<String> approvers = {
    siteManager,
    procurementManager,
    administrator,
  };

  /// Roles that run the procurement desk: RFQ, quotation recording, comparison
  /// and purchase order creation.
  ///
  /// Mirrors the backend `ProcurementStaffAndAdmin` / `SupplierAdministrationOnly`
  /// policies. Note this is *not* the same as [approvers]: a Site Manager
  /// approves a material request but does not raise RFQs.
  static const Set<String> procurementDesk = {
    procurementOfficer,
    procurementManager,
    administrator,
  };

  /// Every role that has a working surface on the mobile app.
  ///
  /// All seven internal roles are mobile-capable. Each one sees only the tabs
  /// its own capabilities allow, driven by the sets above:
  ///
  /// | Role              | Mobile tabs                                               |
  /// |-------------------|-----------------------------------------------------------|
  /// | Site Engineer     | Home, Requests, Inspections, Status, Agents                |
  /// | Site Officer      | Home, Deliveries, Inspections, Status, Agents             |
  /// | Quality Inspector | Home, Inspections, Agents                                  |
  /// | Site Manager      | Home, Inspections, Approvals, Agents                      |
  /// | Procurement Officer | Home, Inspections, Suppliers, RFQs, Quotations, Record, Orders, Agents |
  /// | Procurement Manager | Home, Inspections, Approvals, Suppliers, RFQs, Quotations, Record, Orders, Agents |
  /// | Administrator     | Home, Inspections, Suppliers, RFQs, Quotations, Record, Orders, Admin, Agents |
  ///
  /// **Quality Inspections and Non-Conformance Reports are readable by every
  /// internal role**, exactly as the web sidebar exposes them. Completing an
  /// inspection stays with the Quality Inspector / Administrator, and moving
  /// an NCR to Resolved or Closed stays with the Procurement Manager / Site
  /// Manager / Administrator, so the shell only draws those controls for roles
  /// the API would accept.
  ///
  /// The field roles keep their purpose-built screens. The desk roles get the
  /// same screens the React app uses, pointed at the identical API endpoints, so
  /// the two clients cannot drift apart in behaviour — only in presentation.
  ///
  /// There is still **no `Supplier` role**: a supplier is an external party
  /// contacted by email, so it is absent here and gains no access.
  static const Set<String> mobileCapable = internalStaff;

  /// Roles whose work is governance rather than field or desk execution.
  ///
  /// Retained because the shell still needs a label for these roles, and
  /// because [isWebOnly] must stay false for a real internal role — the mobile
  /// app is not a second-rate client, it is the same system in a pocket.
  static const Set<String> governance = {administrator};

  /// Backend capability groups used by both navigation and action controls.
  static const Set<String> requestReaders = {
    siteEngineer,
    siteOfficer,
    procurementOfficer,
    procurementManager,
    siteManager,
    administrator,
  };
  static const Set<String> supplierEditors = {
    procurementOfficer,
    administrator,
  };
  static const Set<String> procurementWriters = {
    procurementOfficer,
    procurementManager,
    administrator,
  };
  static const Set<String> qualityWriters = {qualityInspector, administrator};

  // --- Queries -------------------------------------------------------------

  static bool hasAny(Iterable<String> roles, Set<String> allowed) =>
      allowed.any(roles.contains);

  /// Folds legacy role names into their canonical equivalent and drops
  /// anything unrecognised (including any stray `Supplier` claim). Call this
  /// once on the JWT role list before any capability check, so alias accounts
  /// are treated as their canonical role.
  static Set<String> normalize(Iterable<String> roles) {
    final resolved = <String>{};
    for (final role in roles) {
      resolved.add(legacyAliases[role] ?? role);
    }
    return resolved.where(internalStaff.contains).toSet();
  }

  static bool isSite(Iterable<String> roles) =>
      hasAny(normalize(roles), siteOperations);

  static bool isInternalStaff(Iterable<String> roles) =>
      hasAny(normalize(roles), internalStaff);

  static bool canSeeCommercialTerms(Iterable<String> roles) =>
      hasAny(normalize(roles), commercial);

  /// Whether this account has anything to do on the mobile app at all.
  static bool canUseMobileApp(Iterable<String> roles) =>
      hasAny(normalize(roles), mobileCapable);

  /// Whether this account can approve at a human decision gate.
  static bool canApprove(Iterable<String> roles) =>
      hasAny(normalize(roles), approvers);

  /// Whether this account runs the procurement desk.
  static bool canRunProcurement(Iterable<String> roles) =>
      hasAny(normalize(roles), procurementDesk);

  /// Whether this account administers users, audit and health.
  static bool canAdminister(Iterable<String> roles) =>
      hasAny(normalize(roles), governance);

  /// Roles that still belong on the web app.
  ///
  /// Now empty: all seven internal roles work on mobile. It is kept so callers
  /// that branch on it keep compiling, and so the one case that genuinely
  /// belongs on neither client — a non-internal claim such as a stray
  /// `Supplier` — is still expressible.
  static Set<String> get webOnly => internalStaff.difference(mobileCapable);

  /// Whether this account must be directed to the web app instead.
  static bool isWebOnly(Iterable<String> roles) =>
      hasAny(normalize(roles), webOnly);
}
