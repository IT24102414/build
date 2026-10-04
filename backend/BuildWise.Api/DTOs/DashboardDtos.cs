namespace BuildWise.Api.DTOs;

public record DashboardMetricDto(
    string Key,
    string Label,
    decimal Value,
    string? Suffix = null
);

public record DashboardTaskDto(
    string Key,
    string Title,
    string Description,
    string Route,
    string Priority
);

/// <summary>
/// One business-readable activity entry, derived from an audit row.
/// <para>
/// The audit table records the raw call. These fields carry the business meaning
/// so a dashboard never has to parse an endpoint itself. Everything is resolved
/// from persisted records; nothing here is invented, and a missing related
/// record simply leaves the optional field null.
/// </para>
/// </summary>
/// <param name="Domain">Requests | Procurement | Deliveries | Quality | Administration.
/// Used for role scoping.</param>
/// <param name="Title">Business action, e.g. "Quotation recorded".</param>
/// <param name="Reference">The primary record, e.g. "Quotation #12".</param>
/// <param name="RelatedRecords">Other resolved entities, e.g. "Material Request #75", "Supplier A".</param>
/// <param name="Outcome">Derived from the recorded HTTP status.</param>
/// <param name="StatusCode">The recorded HTTP status code.</param>
/// <param name="OccurredAtUtc">The stored timestamp, unmodified.</param>
/// <param name="Endpoint">The raw call, shown as secondary detail.</param>
public record DashboardActivityDto(
    int Id,
    string Domain,
    string Title,
    string Reference,
    IReadOnlyList<string> RelatedRecords,
    string Outcome,
    int StatusCode,
    DateTime OccurredAtUtc,
    string? Endpoint
);

public record DashboardAlertDto(
    string Severity,
    string Title,
    string Detail,
    string Route
);

public record DashboardResponseDto(
    string PrimaryRole,
    IReadOnlyList<string> Roles,
    IReadOnlyList<DashboardMetricDto> Metrics,
    IReadOnlyList<DashboardTaskDto> Tasks,
    IReadOnlyList<DashboardActivityDto> Activity,
    IReadOnlyList<DashboardAlertDto> Alerts,
    DateTime GeneratedAtUtc
);
