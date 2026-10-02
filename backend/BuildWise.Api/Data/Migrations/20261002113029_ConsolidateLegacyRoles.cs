using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace BuildWise.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ConsolidateLegacyRoles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Re-point existing accounts at their canonical replacement BEFORE
            // the legacy rows are deleted, otherwise user_roles would be orphaned
            // and the foreign key to roles would reject the delete.
            //
            // Both mappings were verified against the authorization policies to be
            // permission supersets, so no user loses access:
            //   ReceivingOfficer (internal + delivery only)  ⊂ SiteOfficer
            //   ProjectManager  (internal only)               ⊂ SiteManager
            //
            // De-duplicated because a user may already hold the target role
            // (for example an account holding both SiteOfficer and ReceivingOfficer).
            migrationBuilder.Sql("""
                INSERT INTO user_roles ("UserId", "RoleId")
                SELECT ur."UserId", target."Id"
                FROM user_roles ur
                JOIN roles legacy ON legacy."Id" = ur."RoleId" AND legacy."Name" = 'ReceivingOfficer'
                JOIN roles target ON target."Name" = 'SiteOfficer'
                WHERE NOT EXISTS (
                    SELECT 1 FROM user_roles existing
                    WHERE existing."UserId" = ur."UserId" AND existing."RoleId" = target."Id"
                );

                INSERT INTO user_roles ("UserId", "RoleId")
                SELECT ur."UserId", target."Id"
                FROM user_roles ur
                JOIN roles legacy ON legacy."Id" = ur."RoleId" AND legacy."Name" = 'ProjectManager'
                JOIN roles target ON target."Name" = 'SiteManager'
                WHERE NOT EXISTS (
                    SELECT 1 FROM user_roles existing
                    WHERE existing."UserId" = ur."UserId" AND existing."RoleId" = target."Id"
                );

                DELETE FROM user_roles
                WHERE "RoleId" IN (SELECT "Id" FROM roles WHERE "Name" IN ('ReceivingOfficer', 'ProjectManager'));

                -- The demo account that carried ReceivingOfficer is redundant now
                -- that SiteOfficer is seeded; drop it rather than leave a second
                -- site-officer login. Its supplier/quotation data is untouched
                -- because this user only ever recorded deliveries.
                DELETE FROM users WHERE "Email" = 'receiving.officer@buildwise.demo';
                """);

            migrationBuilder.DeleteData(
                table: "roles",
                keyColumn: "Id",
                keyValue: 3);

            migrationBuilder.DeleteData(
                table: "roles",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "roles",
                keyColumn: "Id",
                keyValue: 10);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "roles",
                columns: new[] { "Id", "Name" },
                values: new object[,]
                {
                    { 3, "ProjectManager" },
                    { 6, "ReceivingOfficer" },
                    { 10, "Supplier" }
                });
        }
    }
}
