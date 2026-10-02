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

  /// Roles allowed to see purchase order commercial terms. The API redacts
  /// these server-side; the shell mirrors the rule so a receiving or quality
  /// user is never shown a money column.
  static const Set<String> commercial = {
    procurementOfficer,
    procurementManager,
    siteManager,
    administrator,
  };

  /// Roles that have a working surface on the mobile app.
  ///
  /// The mobile app is a **field operations** tool, not a smaller copy of the
  /// React web system. Exactly three roles have field work to do:
  ///
  /// - **Site Engineer** — raises and tracks material requests
  /// - **Site Officer** — receives physical deliveries against a confirmed PO
  /// - **Quality Inspector** — inspects deliveries and raises NCRs
  ///
  /// Everything else is desk or governance work and stays on the web app:
  /// procurement (RFQ by email, recording returned quotations, comparison,
  /// PO creation), management approval, and administration.
  static const Set<String> mobileCapable = {
    siteEngineer,
    siteOfficer,
    qualityInspector,
  };

  /// Roles whose work happens entirely on the web application.
  static const Set<String> webOnly = {
    siteManager,
    procurementOfficer,
    procurementManager,
    administrator,
  };

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

  /// Whether this account must be directed to the web app instead.
  static bool isWebOnly(Iterable<String> roles) =>
      hasAny(normalize(roles), webOnly);
}