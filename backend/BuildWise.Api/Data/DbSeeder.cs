using BuildWise.Api.Models.Entities;
using BuildWise.Api.Models.Enums;
using BuildWise.Api.Security;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace BuildWise.Api.Data;

/// <summary>
/// Idempotent development seed data: demo login accounts for every role
/// relevant to Component 2, plus the spec's cement scenario (Â§11) â€” three
/// suppliers and one approved material request â€” so a fresh database is
/// immediately demo-ready (spec Â§6: "suitable seed data").
/// Safe to call on every startup; each block checks for existing rows first.
/// </summary>
public static class DbSeeder
{
    public const string DemoPassword = "Passw0rd!";

    public static async Task SeedAsync(ApplicationDbContext db)
    {
        await SeedUsersAsync(db);
        await SeedProcurementScenarioAsync(db);
    }

    private static async Task SeedUsersAsync(ApplicationDbContext db)
    {
        // Exactly the seven internal roles. The legacy ReceivingOfficer/ProjectManager
        // aliases are not seeded; existing accounts holding them are re-pointed
        // to SiteOfficer/SiteManager by the ConsolidateLegacyRoles migration.
        var requiredRoleNames = new[]
        {
            Roles.Administrator, Roles.SiteEngineer, Roles.SiteOfficer, Roles.SiteManager,
            Roles.ProcurementOfficer, Roles.ProcurementManager, Roles.QualityInspector
        };
        var existingRoleNames = await db.Roles.Select(role => role.Name).ToListAsync();
        foreach (var roleName in requiredRoleNames.Where(name => !existingRoleNames.Contains(name)))
        {
            db.Roles.Add(new Role { Name = roleName });
        }
        await db.SaveChangesAsync();

        var roles = await db.Roles.ToDictionaryAsync(r => r.Name, r => r);
        var hasher = new PasswordHasher<User>();

        (string Name, string Email, string Role)[] demoAccounts =
        [
            ("Ada Administrator", "admin@buildwise.demo", Roles.Administrator),
            ("Sam SiteEngineer", "site.engineer@buildwise.demo", Roles.SiteEngineer),
            ("Nipuni SiteOfficer", "site.officer@buildwise.demo", Roles.SiteOfficer),
            ("Priya Officer", "procurement.officer@buildwise.demo", Roles.ProcurementOfficer),
            ("Mira Manager", "procurement.manager@buildwise.demo", Roles.ProcurementManager),
            ("Nimal Site Manager", "site.manager@buildwise.demo", Roles.SiteManager),
            ("Dinesh Inspector", "quality.inspector@buildwise.demo", Roles.QualityInspector),
        ];

        foreach (var (name, email, roleName) in demoAccounts)
        {
            if (await db.Users.AnyAsync(user => user.Email == email)) continue;

            if (!roles.TryGetValue(roleName, out var roleLink)) continue;

            var user = new User
            {
                FullName = name,
                Email = email,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            user.PasswordHash = hasher.HashPassword(user, DemoPassword);
            user.UserRoles.Add(new UserRole { Role = roleLink });
            db.Users.Add(user);
        }

        await db.SaveChangesAsync();
    }

    private static async Task SeedProcurementScenarioAsync(ApplicationDbContext db)
    {
        if (await db.Suppliers.AnyAsync()) return;

        var supplierA = new Supplier { Name = "Supplier A Building Materials", ContactPerson = "Nimal Perera", Email = "sales@suppliera.demo", Phone = "+94 11 234 5678", Address = "12 Galle Road, Colombo", Status = SupplierStatus.Active, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
        var supplierB = new Supplier { Name = "Supplier B Traders", ContactPerson = "Kamal Silva", Email = "info@supplierb.demo", Phone = "+94 11 345 6789", Address = "45 Kandy Road, Kandy", Status = SupplierStatus.Suspended, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
        var supplierC = new Supplier { Name = "Supplier C Wholesale", ContactPerson = "Anusha Fernando", Email = "quotes@supplierc.demo", Phone = "+94 11 456 7890", Address = "8 Negombo Road, Gampaha", Status = SupplierStatus.Active, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
        db.Suppliers.AddRange(supplierA, supplierB, supplierC);

        var project = new Project { Name = "Riverside Apartments â€” Block C", Location = "Colombo 05", Status = ProjectStatus.Active, StartDate = DateOnly.FromDateTime(DateTime.UtcNow.AddMonths(-2)), MaterialBudgetAmount = 5_000_000m, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
        db.Projects.Add(project);

        var cement = new Material { Name = "Cement (50kg bag)", Unit = "bag", Category = "Structural Materials", IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
        db.Materials.Add(cement);

        await db.SaveChangesAsync();

        var siteEngineer = await db.Users.FirstOrDefaultAsync(u => u.Email == "site.engineer@buildwise.demo");

        var request = new MaterialRequest
        {
            ProjectId = project.Id,
            RequestedByUserId = siteEngineer?.Id ?? 1,
            RequiredDate = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(10)),
            Reason = "Foundation pour for Block C",
            Status = MaterialRequestStatus.Approved,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.MaterialRequests.Add(request);
        await db.SaveChangesAsync();

        db.MaterialRequestItems.Add(new MaterialRequestItem
        {
            MaterialRequestId = request.Id,
            MaterialId = cement.Id,
            RequestedQuantity = 250m,
            Notes = "Standard Portland cement grade 42.5N"
        });

        await db.SaveChangesAsync();
    }
}
