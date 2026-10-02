using BuildWise.Api.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace BuildWise.Api.Data.Configurations;

public class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> builder)
    {
        builder.ToTable("roles");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.Name)
            .HasMaxLength(100)
            .IsRequired();

        builder.HasIndex(r => r.Name).IsUnique();

        builder.HasData(
            // The seven internal roles. SiteOfficer owns delivery receiving and
            // SiteManager owns material-request approval; the former
            // ReceivingOfficer and ProjectManager aliases have been retired and
            // are removed by the ConsolidateLegacyRoles migration.
            new Role { Id = 1, Name = "Administrator" },
            new Role { Id = 2, Name = "SiteEngineer" },
            new Role { Id = 4, Name = "ProcurementOfficer" },
            new Role { Id = 5, Name = "ProcurementManager" },
            new Role { Id = 7, Name = "QualityInspector" },
            new Role { Id = 8, Name = "SiteOfficer" },
            new Role { Id = 9, Name = "SiteManager" }
        );
    }
}
