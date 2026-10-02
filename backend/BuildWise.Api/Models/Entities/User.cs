using BuildWise.Api.Models.Common;

namespace BuildWise.Api.Models.Entities;

/// <summary>
/// Shared application user (Core/shared per the team ERD). Owned collectively —
/// any component may read it, only auth endpoints write it.
/// <para>
/// Every user is internal BuildWise staff. There is intentionally no supplier
/// binding: a supplier is an external stakeholder contacted by email, so it has
/// no BuildWise account, no JWT and no portal. The <see cref="Supplier"/> entity
/// itself is retained and is referenced by RFQs, quotations, purchase orders and
/// deliveries.
/// </para>
/// </summary>
public class User : BaseEntity
{
    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string PasswordHash { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;

    public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
}
