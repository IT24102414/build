using BuildWise.Api.Data;
using BuildWise.Api.Models.Entities;
using BuildWise.Api.Models.Enums;
using BuildWise.Api.Services;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace BuildWise.Api.Tests;

/// <summary>
/// The dashboard is a management control centre, so each KPI has to mean
/// something the viewer can act on. Two defects motivated these tests: a
/// SiteManager was shown the agent-workflow approval count (procurement work they
/// are not part of) instead of the material requests they actually approve, and
/// the role had no task list at all because BuildTasks had no SiteManager branch.
/// </summary>
public class DashboardServiceTests
{
    [Fact]
    public async Task SiteManager_sees_requests_awaiting_approval_not_agent_workflows()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.PendingApproval, workflowAwaitingApproval: true);

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "SiteManager" });

        var metric = dashboard.Metrics.Single(m => m.Key == "proposalsAwaitingApproval");
        Assert.Equal(1, metric.Value);
        // The label must say what the number is, not imply a procurement queue.
        Assert.Contains("your approval", metric.Label, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ProcurementManager_still_sees_the_agent_workflow_approval_queue()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.PendingApproval, workflowAwaitingApproval: true);

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "ProcurementManager" });

        var metric = dashboard.Metrics.Single(m => m.Key == "proposalsAwaitingApproval");
        Assert.Equal(1, metric.Value); // the agent workflow, not the request
        Assert.Equal("Proposals awaiting approval", metric.Label);
    }

    [Fact]
    public async Task SiteManager_is_offered_tasks_including_approval_review()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.PendingApproval, workflowAwaitingApproval: false);

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "SiteManager" });

        Assert.NotEmpty(dashboard.Tasks);
        var reviewTask = dashboard.Tasks.Single(t => t.Key == "review-requests");
        Assert.Equal("/material-requests", reviewTask.Route);
        Assert.Equal("High", reviewTask.Priority);
        Assert.Contains("1 request(s)", reviewTask.Description);
    }

    [Fact]
    public async Task Confirmed_purchase_order_count_uses_only_confirmed_orders()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "Administrator" });

        // Seeded one Confirmed and one Created order.
        Assert.Equal(1, dashboard.Metrics.Single(m => m.Key == "confirmedPurchaseOrders").Value);
    }
    [Fact]
    public async Task Suspended_supplier_alert_counts_only_suspended_suppliers()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        db.Suppliers.AddRange(
            NewSupplier("Active Build Mart", SupplierStatus.Active),
            NewSupplier("Blocked Traders", SupplierStatus.Suspended),
            NewSupplier("Another Active", SupplierStatus.Active));
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "SiteManager" });

        var alert = dashboard.Alerts.Single(a => a.Title == "Suspended suppliers");
        Assert.Contains("1 supplier(s)", alert.Detail);
        Assert.Equal("/suppliers", alert.Route);
    }

    [Theory]
    [InlineData(200, "Completed")]
    [InlineData(201, "Completed")]
    [InlineData(400, "Rejected by a validation rule")]
    [InlineData(403, "Rejected - not permitted for your role")]
    [InlineData(404, "Rejected - record not found")]
    [InlineData(500, "Failed - server error")]
    public async Task Activity_reports_the_recorded_outcome_and_never_calls_a_rejection_a_success(int statusCode, string expected)
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        db.AuditLogs.Add(new AuditLog
        {
            UserId = userId,
            Action = "POST /api/material-requests/50/approval",
            RequestPath = "/api/material-requests/50/approval",
            StatusCode = statusCode,
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "SiteManager" });

        var entry = Assert.Single(dashboard.Activity);
        Assert.Equal(expected, entry.Outcome);
        Assert.Equal(statusCode, entry.StatusCode);
        // The raw call is still available for the expandable details row...
        Assert.Equal("POST /api/material-requests/50/approval", entry.Endpoint);
        // ...and the readable line names the action and the record.
        Assert.Contains("approval decided", entry.Title);
        Assert.Contains("#50", entry.Reference);
    }

    [Theory]
    // The action sits AFTER the id in a nested action route...
    [InlineData("POST /api/material-requests/50/approval", "Material requests approval decided")]
    // ...and BEFORE the id in an agent route. Both layouts must resolve, otherwise
    // one of them is mislabelled as a plain submission.
    [InlineData("POST /api/agent/analyze-request/51", "Request analysis completed")]
    [InlineData("POST /api/material-requests", "Material requests recorded")]
    [InlineData("PATCH /api/purchase-orders/42/status", "Purchase orders status changed")]
    public async Task Activity_names_the_action_regardless_of_where_the_id_sits(string action, string expectedTitle)
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        db.AuditLogs.Add(new AuditLog
        {
            UserId = userId,
            Action = action,
            RequestPath = action[(action.IndexOf(' ') + 1)..],
            StatusCode = 200,
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync();

        // Administrator is used here because this test asserts the TITLE mapping
        // only. Role scoping is asserted separately in Role_scoping_hides_...
        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "Administrator" });

        Assert.Equal(expectedTitle, Assert.Single(dashboard.Activity).Title);
    }

    [Fact]
    public async Task Three_quotation_events_stay_three_distinguishable_entries()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        var request = await db.MaterialRequests.FirstAsync();

        // A quotation POST names the request, not the quotation: the server assigns
        // the quotation id, so the audit row cannot know it. Three such calls must
        // stay three entries rather than being merged into one summary row.
        for (var i = 0; i < 3; i++)
        {
            db.AuditLogs.Add(new AuditLog
            {
                UserId = userId,
                Action = $"POST /api/material-requests/{request.Id}/quotations",
                RequestPath = $"/api/material-requests/{request.Id}/quotations",
                StatusCode = 201,
                CreatedAt = DateTime.UtcNow.AddMinutes(-i)
            });
        }
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "ProcurementOfficer" });

        Assert.Equal(3, dashboard.Activity.Count);
        Assert.All(dashboard.Activity, entry =>
        {
            Assert.Equal("Quotation recorded", entry.Title);
            Assert.Equal($"Material Request #{request.Id}", entry.Reference);
            // The raw call is still available as secondary detail.
            Assert.EndsWith("/quotations", entry.Endpoint);
        });
        // Distinct rows, not one deduplicated entry.
        Assert.Equal(3, dashboard.Activity.Select(e => e.Id).Distinct().Count());
    }

    [Theory]
    // A SiteOfficer sees receiving activity but not procurement decisions...
    [InlineData("SiteOfficer", "POST /api/deliveries", true)]
    [InlineData("SiteOfficer", "POST /api/material-requests/50/approval", false)]
    // ...a SiteEngineer sees their own request work but not quality records...
    [InlineData("SiteEngineer", "POST /api/material-requests", true)]
    [InlineData("SiteEngineer", "POST /api/quality-inspections", false)]
    // ...a QualityInspector sees quality and receiving, not procurement...
    [InlineData("QualityInspector", "POST /api/quality-inspections", true)]
    [InlineData("QualityInspector", "POST /api/purchase-orders/42/status", false)]
    // ...and the Administrator sees every business area.
    [InlineData("Administrator", "POST /api/purchase-orders/42/status", true)]
    [InlineData("Administrator", "POST /api/quality-inspections", true)]
    public async Task Role_scoping_hides_activity_from_roles_with_no_business_in_it(string role, string action, bool shouldShow)
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        db.AuditLogs.Add(new AuditLog
        {
            UserId = userId,
            Action = action,
            RequestPath = action[(action.IndexOf(' ') + 1)..],
            StatusCode = 200,
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { role });

        Assert.Equal(shouldShow, dashboard.Activity.Count == 1);
    }

    [Fact]
    public async Task Activity_never_throws_when_the_related_record_no_longer_exists()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        // Quotation #999 does not exist. The entry must still render.
        db.AuditLogs.Add(new AuditLog
        {
            UserId = userId,
            Action = "POST /api/quotations/999",
            RequestPath = "/api/quotations/999",
            StatusCode = 201,
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "ProcurementOfficer" });

        var entry = Assert.Single(dashboard.Activity);
        Assert.Equal("Quotation #999", entry.Reference);
        Assert.Empty(entry.RelatedRecords);
    }

    private static Quotation NewQuotation(int requestId, int supplierId) => new()
    {
        MaterialRequestId = requestId,
        SupplierId = supplierId,
        QuotationDate = DateOnly.FromDateTime(DateTime.UtcNow),
        ValidUntil = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(30)),
        Status = QuotationStatus.Submitted,
        TotalAmount = 1000m,
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    private static NonConformance NewNcr(string number, NonConformanceStatus status) => new()
    {
        NcrNumber = number,
        Status = status,
        Severity = NonConformanceSeverity.Medium,
        IssueDescription = "Test defect",
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    private static Supplier NewSupplier(string name, SupplierStatus status) => new()
    {
        Name = name,
        Status = status,
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    private static async Task<int> SeedAsync(
        ApplicationDbContext db,
        MaterialRequestStatus materialRequestStatus,
        bool workflowAwaitingApproval)
    {
        var project = new Project
        {
            Name = "Dashboard Project",
            Status = ProjectStatus.Active,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.Projects.Add(project);
        await db.SaveChangesAsync();

        db.MaterialRequests.Add(new MaterialRequest
        {
            ProjectId = project.Id,
            RequestedByUserId = 2,
            RequiredDate = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(10)),
            Reason = "Dashboard scenario",
            Status = materialRequestStatus,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });

        db.PurchaseOrders.AddRange(
            NewPurchaseOrder(project.Id, PurchaseOrderStatus.Confirmed, 1000m),
            NewPurchaseOrder(project.Id, PurchaseOrderStatus.Created, 2000m));

        if (workflowAwaitingApproval)
        {
            db.AgentWorkflows.Add(new AgentWorkflow
            {
                InitiatedByUserId = 1,
                Objective = "Rank suppliers",
                Status = WorkflowStatus.AwaitingApproval,
                ApprovalStatus = AgentApprovalStatus.Pending,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
        }

        await db.SaveChangesAsync();
        return 1;
    }

    private static PurchaseOrder NewPurchaseOrder(int projectId, PurchaseOrderStatus status, decimal total) => new()
    {
        ProjectId = projectId,
        OrderDate = DateOnly.FromDateTime(DateTime.UtcNow),
        ExpectedDeliveryDate = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(5)),
        Status = status,
        TotalAmount = total,
        CreatedAt = DateTime.UtcNow,
        UpdatedAt = DateTime.UtcNow
    };

    [Fact]
    public async Task Active_ncr_count_excludes_resolved_and_closed()
    {
        var db = TestDbFactory.CreateInMemory();
        var userId = await SeedAsync(db, MaterialRequestStatus.Approved, workflowAwaitingApproval: false);

        db.NonConformances.AddRange(
            NewNcr("NCR-000001", NonConformanceStatus.Open),
            NewNcr("NCR-000002", NonConformanceStatus.Resolved),
            NewNcr("NCR-000003", NonConformanceStatus.Closed));
        await db.SaveChangesAsync();

        var dashboard = await new DashboardService(db, new ActivityFormatter(db)).GetAsync(userId, new[] { "QualityInspector" });

        Assert.Equal(1, dashboard.Metrics.Single(m => m.Key == "activeNcrs").Value);
    }
}
