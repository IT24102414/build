namespace BuildWise.Api.Security;

/// <summary>
/// Single source of truth for role and policy names.
/// Every <c>[Authorize]</c> attribute and every policy registration references
/// these constants, so a role rename can never silently drift out of sync with
/// the policies that grant it (Phase 1 RBAC hardening).
/// </summary>
public static class Roles
{
    public const string Administrator = "Administrator";
    public const string SiteEngineer = "SiteEngineer";
    public const string SiteOfficer = "SiteOfficer";
    public const string SiteManager = "SiteManager";
    public const string ProcurementOfficer = "ProcurementOfficer";
    public const string ProcurementManager = "ProcurementManager";
    public const string QualityInspector = "QualityInspector";

    /// <summary>
    /// The seven internal application roles, in workflow order. This is the
    /// complete set of roles a person can sign in with.
    /// <para>
    /// There is deliberately no <c>Supplier</c> role. Suppliers are external
    /// stakeholders, not BuildWise users: they have no account, no JWT and no
    /// portal. Procurement reaches them by email, and the quotations they send
    /// back are recorded by the Procurement Officer. The <see cref="Models.Entities.Supplier"/>
    /// business entity still exists — it is referenced by RFQs, quotations,
    /// purchase orders and deliveries — but it is not a login.
    /// </para>
    /// <para>
    /// The former <c>ReceivingOfficer</c> and <c>ProjectManager</c> roles were
    /// legacy aliases and have been retired. Both were strict subsets of the
    /// role that replaced them — <c>ReceivingOfficer</c> ⊂ <c>SiteOfficer</c>
    /// (receiving) and <c>ProjectManager</c> ⊂ <c>SiteManager</c> (approval) —
    /// so the migration could only widen access, never narrow it unexpectedly.
    /// <see cref="Legacy"/> records the mapping used by the data migration.
    /// </para>
    /// </summary>
    public static readonly string[] All = {
        SiteEngineer,
        SiteManager,
        ProcurementOfficer,
        ProcurementManager,
        SiteOfficer,
        QualityInspector,
        Administrator
    };

    /// <summary>
    /// Retired role names mapped to their canonical replacement.
    /// <para>
    /// Used by the <c>ConsolidateLegacyRoles</c> migration to re-point existing
    /// user accounts. Each mapping was verified to be a permission superset, so
    /// no user loses access: see the summary on <see cref="All"/>.
    /// </para>
    /// </summary>
    public static readonly IReadOnlyDictionary<string, string> Legacy = new Dictionary<string, string>
    {
        ["ReceivingOfficer"] = SiteOfficer,
        ["ProjectManager"] = SiteManager
    };

    // --- Composite role sets -------------------------------------------------
    // SiteOfficer is the receiving-facing alias of SiteEngineer; SiteManager is
    // the approval-facing alias of ProcurementManager.

    public const string SiteOperations = SiteEngineer + "," + SiteOfficer;
    public const string SiteOperationsAndAdmin = SiteOperations + "," + Administrator;
    public const string ProcurementStaff = ProcurementOfficer + "," + ProcurementManager;
    public const string ProcurementStaffAndAdmin = ProcurementStaff + "," + SiteManager + "," + Administrator;
    public const string ProcurementManagers = ProcurementManager + "," + SiteManager;
    public const string ProcurementDecisionMakers = ProcurementManagers + "," + Administrator;

    /// <summary>Roles that create/own RFQs and supplier master data.</summary>
    public const string SupplierAdministration = ProcurementOfficer + "," + Administrator;

    /// <summary>Roles allowed to read quality records. Delivery and site roles are
    /// included because they consume inspection outcomes; the Procurement Officer
    /// is included so the desk that raised the purchase order can track the
    /// quality outcome of its deliveries (mirrors the web sidebar, which exposes
    /// Quality Inspections and Non-Conformance Reports to every internal role).
    /// Pricing is never exposed to any of them (see <c>PurchaseOrderProjection</c>),
    /// and this set grants reads only — writes stay behind
    /// <c>QualityControlOnly</c> / <c>ProcurementDecisionOnly</c>.</summary>
    public const string QualityReaders = SiteOperations + "," + ProcurementStaff
        + "," + ProcurementManagers + "," + QualityInspector + "," + Administrator;

    /// <summary>Roles permitted to act on the delivery / receiving surface.
    /// Procurement Officers are included so they can track PO fulfilment.</summary>
    public const string DeliveryParticipants = SiteOperations
        + "," + QualityInspector + "," + ProcurementOfficer + "," + ProcurementManagers + "," + Administrator;
}

/// <summary>Authorization policy names registered in <c>Program.cs</c>.</summary>
public static class Policies
{
    /// <summary>Site Engineer / Site Officer — may raise and revise material requests.</summary>
    public const string SiteOperationsOnly = "SiteOperationsOnly";

    /// <summary>Procurement desk — may maintain suppliers, RFQs and quotations.</summary>
    public const string ProcurementStaffOnly = "ProcurementStaffOnly";

    /// <summary>Procurement desk — may create and maintain suppliers, RFQs, quotations.</summary>
    public const string SupplierAdministrationOnly = "SupplierAdministrationOnly";

    /// <summary>
    /// Procurement readers and managers. Grants read access to suppliers, RFQs,
    /// quotations, agent workflows and purchase orders. This is the only policy
    /// that can reach commercial data.
    /// </summary>
    public const string ProcurementStaffAndAdmin = "ProcurementStaffAndAdmin";

    /// <summary>
    /// Roles permitted to read quality inspections and non-conformance records.
    /// </summary>
    public const string QualityReaders = "QualityReaders";

    /// <summary>Quality control — may complete inspections and raise NCRs.</summary>
    public const string QualityControlOnly = "QualityControlOnly";

    /// <summary>Approvers — may approve material requests and procurement recommendations.</summary>
    public const string MaterialRequestApprovalOnly = "MaterialRequestApprovalOnly";

    /// <summary>Approvers — may accept or reject a procurement recommendation.</summary>
    public const string ProcurementDecisionOnly = "ProcurementDecisionOnly";

    /// <summary>
    /// Roles that may read material requests. Site roles are additionally
    /// narrowed to their own rows by <c>MaterialRequestsController</c>; this
    /// policy only establishes which functions may read the resource at all.
    /// </summary>
    public const string MaterialRequestReaders = "MaterialRequestReaders";

    /// <summary>Every authenticated internal staff member.</summary>
    public const string InternalStaffOnly = "InternalStaffOnly";

    /// <summary>
    /// Roles permitted to read the delivery / receiving surface: site, receiving,
    /// quality and procurement management.
    /// </summary>
    public const string DeliveryParticipantsOnly = "DeliveryParticipantsOnly";

    /// <summary>
    /// Roles permitted to <em>record</em> a delivery against a confirmed purchase
    /// order. Deliberately narrower than <see cref="DeliveryParticipantsOnly"/>:
    /// the Site Officer is the one physically taking the goods in and signing for
    /// them, so they are the only site role that may write a receiving entry.
    /// The Site Engineer opens the same workspace to follow the material they
    /// requested, but read-only — raising demand and accepting stock are
    /// different responsibilities and one person holding both would let a request
    /// appear satisfied by their own keying.
    /// </summary>
    public const string DeliveryReceiversOnly = "DeliveryReceiversOnly";
}

/// <summary>
/// Helpers for reading the caller's roles out of the validated JWT. Centralised
/// so every controller scopes data the same way.
/// </summary>
public static class CallerScope
{
    public static IReadOnlyList<string> GetRoleNames(this System.Security.Claims.ClaimsPrincipal principal) =>
        principal.FindAll(System.Security.Claims.ClaimTypes.Role)
            .Select(claim => claim.Value)
            .Distinct(StringComparer.Ordinal)
            .ToArray();

    public static bool IsInAnyRole(this System.Security.Claims.ClaimsPrincipal principal, params string[] roles) =>
        principal.GetRoleNames().Any(roles.Contains);
}