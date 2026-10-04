using BuildWise.Api.Data;
using BuildWise.Api.DTOs;
using BuildWise.Api.Models.Entities;
using Microsoft.EntityFrameworkCore;

namespace BuildWise.Api.Services;

/// <summary>
/// Turns raw audit rows into business-readable activity entries, resolved from
/// persisted records.
/// <para>
/// This is the single place that knows how an endpoint maps to a business action
/// and to the related entities, so every dashboard uses the same rule instead of
/// each role dashboard parsing endpoints itself.
/// </para>
/// <para>
/// Related entities are resolved in batched queries - one per type for the whole
/// page - so a dashboard does not degrade into one query per activity row. A
/// record that no longer exists leaves its field empty; nothing is invented and
/// nothing throws.
/// </para>
/// </summary>
public class ActivityFormatter
{
    private readonly ApplicationDbContext _db;

    public ActivityFormatter(ApplicationDbContext db) => _db = db;

    /// <summary>Business areas an activity belongs to. Used for role scoping.</summary>
    public static class Domains
    {
        public const string Requests = "Requests";
        public const string Procurement = "Procurement";
        public const string Deliveries = "Deliveries";
        public const string Quality = "Quality";
        public const string Administration = "Administration";
    }

    /// <summary>
    /// Formats audit rows for one role. Rows outside the role's business areas are
    /// dropped here rather than hidden in the client, so an unrelated or sensitive
    /// call never reaches a dashboard with no business showing it. Administrator
    /// sees everything.
    /// </summary>
    public async Task<IReadOnlyList<DashboardActivityDto>> FormatAsync(
        IEnumerable<AuditLog> auditRows, string role)
    {
        var rows = auditRows.ToList();
        if (rows.Count == 0) return Array.Empty<DashboardActivityDto>();

        var scoped = rows.Select(Parse).Where(p => IsRelevantTo(p.Domain, role)).ToList();
        if (scoped.Count == 0) return Array.Empty<DashboardActivityDto>();

        var quotationIds = scoped.Where(p => p.QuotationId is not null).Select(p => p.QuotationId!.Value).Distinct().ToList();
        var supplierIds = scoped.Where(p => p.SupplierId is not null).Select(p => p.SupplierId!.Value).Distinct().ToList();
        var poIds = scoped.Where(p => p.PurchaseOrderId is not null).Select(p => p.PurchaseOrderId!.Value).Distinct().ToList();
        var deliveryIds = scoped.Where(p => p.DeliveryId is not null).Select(p => p.DeliveryId!.Value).Distinct().ToList();
        var ncrIds = scoped.Where(p => p.NcrId is not null).Select(p => p.NcrId!.Value).Distinct().ToList();

        var quotations = quotationIds.Count == 0
            ? new List<Quotation>()
            : await _db.Quotations.Where(q => quotationIds.Contains(q.Id)).ToListAsync();

        var suppliers = supplierIds.Count == 0
            ? new Dictionary<int, string>()
            : await _db.Suppliers.Where(s => supplierIds.Contains(s.Id)).ToDictionaryAsync(s => s.Id, s => s.Name);

        var purchaseOrders = poIds.Count == 0
            ? new Dictionary<int, PurchaseOrder>()
            : await _db.PurchaseOrders.Where(p => poIds.Contains(p.Id)).ToDictionaryAsync(p => p.Id, p => p);

        var deliveries = deliveryIds.Count == 0
            ? new Dictionary<int, Delivery>()
            : await _db.Deliveries.Where(d => deliveryIds.Contains(d.Id)).ToDictionaryAsync(d => d.Id, d => d);

        var ncrNumbers = ncrIds.Count == 0
            ? new Dictionary<int, string>()
            : await _db.NonConformances.Where(n => ncrIds.Contains(n.Id)).ToDictionaryAsync(n => n.Id, n => n.NcrNumber);

        var results = new List<DashboardActivityDto>(scoped.Count);

        foreach (var entry in scoped)
            results.Add(Compose(entry, quotations, suppliers, purchaseOrders, deliveries, ncrNumbers));

        return results;
    }

    /// <summary>
    /// Parses one audit row into a business action plus the ids needed to resolve
    /// related records.
    /// <para>
    /// The audit row stores only "POST /api/material-requests/75/quotations". The
    /// resource, the action and the record ids are recovered from that path here,
    /// once, so no consumer repeats this logic. Unknown shapes degrade to the
    /// resource name rather than throwing.
    /// </para>
    /// </summary>
    private static ParsedActivity Parse(AuditLog audit)
    {
        var (method, path) = SplitCall(audit.Action, audit.HttpMethod, audit.RequestPath);
        var segments = path.Split('/', StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Split(':')[0])
            .ToArray();

        // segments[0] is "api"; segments[1] is the resource collection.
        var resource = segments.Length >= 2 ? Humanise(segments[1]) : Humanise(path);
        var domain = DomainFor(segments);
        var title = TitleFor(method, segments, resource);

        int? FirstIdAfter(params string[] names)
        {
            for (var i = 0; i < segments.Length; i++)
            {
                var matches = names.Any(n => string.Equals(segments[i], n, StringComparison.OrdinalIgnoreCase));
                if (matches && i + 1 < segments.Length && int.TryParse(segments[i + 1], out var id))
                    return id;
            }
            return null;
        }

        var requestId = FirstIdAfter("material-requests", "material-request");
        var quotationId = FirstIdAfter("quotations", "quotation");
        var supplierId = FirstIdAfter("suppliers", "supplier");
        var deliveryId = FirstIdAfter("deliveries", "delivery");
        var ncrId = FirstIdAfter("non-conformances", "non-conformance", "ncr");
        var poId = FirstIdAfter("purchase-orders", "purchase-order");

        // A delivery/PO route carries its own id in the next segment.
        if (poId is null && resource.StartsWith("Purchase order", StringComparison.OrdinalIgnoreCase))
            poId = FirstNumericFrom(2);
        if (requestId is null && resource.StartsWith("Material request", StringComparison.OrdinalIgnoreCase))
            requestId = FirstNumericFrom(2);

        // A quotation entry identifies the offer, not the request, so the request
        // id must not be inferred from the same numeric segment.
        if (quotationId is not null) requestId = null;

        int? FirstNumericFrom(int start)
        {
            for (var i = start; i < segments.Length; i++)
                if (int.TryParse(segments[i], out var id)) return id;
            return null;
        }

        return new ParsedActivity(
            audit.Id, domain, title, resource, audit.StatusCode,
            audit.CreatedAt, audit.Action,
            requestId, quotationId, supplierId, poId, deliveryId, ncrId);
    }

    private static (string Method, string Path) SplitCall(string? action, string? httpMethod, string? requestPath)
    {
        var text = (action ?? string.Empty).Trim();
        var space = text.IndexOf(' ');
        if (space > 0) return (text[..space].ToUpperInvariant(), text[(space + 1)..]);

        // Some rows hold only the path; fall back to the stored columns.
        var path = string.IsNullOrWhiteSpace(text) ? (requestPath ?? string.Empty) : text;
        return ((httpMethod ?? string.Empty).ToUpperInvariant(), path);
    }

    private static string DomainFor(string[] segments)
    {
        bool Has(params string[] names) =>
            segments.Any(s => names.Contains(s, StringComparer.OrdinalIgnoreCase));

        if (Has("suppliers", "rfqs", "rfq", "quotations", "quotation", "purchase-orders", "purchase-order", "procurement-workflow"))
            return Domains.Procurement;
        if (Has("deliveries", "delivery")) return Domains.Deliveries;
        if (Has("quality-inspections", "inspections", "inspection", "non-conformances", "non-conformance", "ncr"))
            return Domains.Quality;
        if (Has("admin", "users", "audit-logs")) return Domains.Administration;
        return Domains.Requests;
    }

    private static string TitleFor(string method, string[] segments, string resource)
    {
        // Checked before the action switch: "agent/analyze-request/51" carries an
        // "analyze-request" action segment, which would otherwise render as the
        // meaningless "Agent analyze request recorded".
        if (segments.Any(s => s.StartsWith("analyze", StringComparison.OrdinalIgnoreCase)))
            return "Request analysis completed";

        var action = ResolveAction(segments);

        if (action is not null)
        {
            return action switch
            {
                "Approval" => $"{resource} approval decided",
                "Submit" => $"{resource} submitted for approval",
                "Revise" => $"{resource} revision requested",
                "Status" => $"{resource} status changed",
                "Transition" => $"{resource} transition recorded",
                "Quotations" or "Quotation" => "Quotation recorded",
                "Discrepancy analysis" => "Delivery discrepancy analysis run",
                "Risk analysis" => "Quality risk analysis run",
                _ => $"{resource} {action.ToLowerInvariant()} recorded"
            };
        }

        return method switch
        {
            "POST" => $"{resource} recorded",
            "PATCH" or "PUT" => $"{resource} updated",
            "DELETE" => $"{resource} removed",
            _ => string.IsNullOrEmpty(method) ? $"{resource} activity" : $"{resource} {method.ToLowerInvariant()}"
        };
    }

    /// <summary>
    /// Finds the action segment in a REST path. The record id can sit on either
    /// side of it:
    /// <code>
    /// /api/material-requests/75/quotations -> resource, id,     action
    /// /api/agent/analyze-request/51       -> resource, action, id
    /// </code>
    /// So the action is whichever neighbour of the id is not itself numeric.
    /// Reading only the trailing segment (or only segment 2) mislabels one of the
    /// two layouts.
    /// </summary>
    private static string? ResolveAction(string[] segments)
    {
        var idIndex = Array.FindIndex(segments, segment => int.TryParse(segment, out _));
        if (idIndex < 0) return null;

        // segments[1] is the resource, so an action may only precede the id when
        // the id is at index 3 or later.
        if (idIndex >= 3 && !int.TryParse(segments[idIndex - 1], out _))
            return Humanise(segments[idIndex - 1]);

        if (idIndex + 1 < segments.Length && !int.TryParse(segments[idIndex + 1], out _))
            return Humanise(segments[idIndex + 1]);

        return null;
    }

    private static string Humanise(string segment) =>
        segment.Replace('-', ' ').Trim() switch
        {
            "" => "Record",
            var s => char.ToUpperInvariant(s[0]) + s[1..]
        };

    private static DashboardActivityDto Compose(
        ParsedActivity entry,
        IReadOnlyCollection<Quotation> quotations,
        IReadOnlyDictionary<int, string> suppliers,
        IReadOnlyDictionary<int, PurchaseOrder> purchaseOrders,
        IReadOnlyDictionary<int, Delivery> deliveries,
        IReadOnlyDictionary<int, string> ncrNumbers)
    {
        var related = new List<string>();
        string reference;

        // The id parsed from the path is authoritative for the reference even when
        // the row has since been deleted - showing "Quotation #999" is truthful,
        // where falling back to the resource name ("Quotations") would be vaguer.
        // Only the optional related details need the row to still exist.
        if (entry.QuotationId is int quotationId)
        {
            reference = $"Quotation #{quotationId}";
            if (quotations.FirstOrDefault(q => q.Id == quotationId) is { } quotation
                && suppliers.TryGetValue(quotation.SupplierId, out var quotationSupplier))
                related.Add($"Supplier: {quotationSupplier}");
        }
        else if (entry.RequestId is int requestId)
        {
            // A collection POST such as /material-requests/75/quotations carries no
            // id of its own - the server assigns it - so the request is named
            // instead. Nothing is invented here.
            reference = $"Material Request #{requestId}";
        }
        else if (entry.SupplierId is int supplierId)
        {
            reference = suppliers.TryGetValue(supplierId, out var supplierName)
                ? $"Supplier: {supplierName}"
                : $"Supplier #{supplierId}";
        }
        else if (entry.PurchaseOrderId is int poId)
        {
            reference = $"Purchase Order PO-{poId}";
            if (purchaseOrders.TryGetValue(poId, out var po) && po.SupplierId is int poSupplierId
                && suppliers.TryGetValue(poSupplierId, out var poSupplier))
                related.Add($"Supplier: {poSupplier}");
        }
        else if (entry.DeliveryId is int deliveryId)
        {
            reference = deliveries.TryGetValue(deliveryId, out var delivery)
                ? $"Delivery #{deliveryId} ({delivery.DeliveryReference})"
                : $"Delivery #{deliveryId}";
        }
        else if (entry.NcrId is int ncrId)
        {
            reference = ncrNumbers.TryGetValue(ncrId, out var ncrNumber)
                ? $"Non-Conformance {ncrNumber}"
                : $"Non-Conformance #{ncrId}";
        }
        else
        {
            // Nothing resolved from a persisted record: name the resource rather
            // than showing a bare endpoint, but never invent a record reference.
            reference = entry.Resource;
        }

        // Only add the request as a related record when it is not already the
        // primary reference - otherwise the row reads "Material Request #50 ::
        // Material Request #50".
        if (entry.RequestId is int rId && reference != $"Material Request #{rId}"
            && !related.Contains($"Material Request #{rId}"))
        {
            related.Insert(0, $"Material Request #{rId}");
        }

        return new DashboardActivityDto(
            entry.Id, entry.Domain, entry.Title, reference, related,
            OutcomeFor(entry.StatusCode), entry.StatusCode, entry.OccurredAt, entry.Endpoint);
    }

    /// <summary>
    /// Business areas each role should see. Administrator is deliberately absent
    /// so it sees everything, including system and user-administration activity.
    /// </summary>
    private static bool IsRelevantTo(string domain, string role) => role switch
    {
        "Administrator" => true,
        "SiteEngineer" => domain is Domains.Requests,
        "SiteManager" => domain is Domains.Requests or Domains.Deliveries or Domains.Quality,
        "ProcurementOfficer" => domain is Domains.Procurement or Domains.Requests,
        "ProcurementManager" => domain is Domains.Procurement or Domains.Requests,
        "SiteOfficer" => domain is Domains.Deliveries,
        "QualityInspector" => domain is Domains.Quality or Domains.Deliveries,
        _ => true
    };

    internal static string OutcomeFor(int statusCode) => statusCode switch
    {
        >= 200 and < 300 => "Completed",
        400 => "Rejected by a validation rule",
        401 => "Rejected - not signed in",
        403 => "Rejected - not permitted for your role",
        404 => "Rejected - record not found",
        409 => "Rejected - conflicting state",
        >= 500 => "Failed - server error",
        _ => "Unknown outcome"
    };

    private sealed record ParsedActivity(
        int Id, string Domain, string Title, string Resource,
        int StatusCode, DateTime OccurredAt, string? Endpoint,
        int? RequestId, int? QuotationId, int? SupplierId, int? PurchaseOrderId,
        int? DeliveryId, int? NcrId);
}
