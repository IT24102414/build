using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BuildWise.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class RemoveSupplierUserAccount : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Delete any legacy supplier login rows before dropping the binding.
            // They are keyed on the role name and on a non-null SupplierId. The
            // suppliers table itself is NEVER touched: it is the business entity
            // still referenced by RFQs, quotations, purchase orders and
            // deliveries, and it is only the *account* that is being removed.
            migrationBuilder.Sql("""
                DELETE FROM user_roles
                WHERE "RoleId" IN (SELECT "Id" FROM roles WHERE "Name" = 'Supplier');

                DELETE FROM users
                WHERE "SupplierId" IS NOT NULL;

                DELETE FROM roles WHERE "Name" = 'Supplier';
                """);

            migrationBuilder.DropForeignKey(
                name: "FK_users_suppliers_SupplierId",
                table: "users");

            migrationBuilder.DropIndex(
                name: "IX_users_SupplierId",
                table: "users");

            migrationBuilder.DropColumn(
                name: "SupplierId",
                table: "users");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "SupplierId",
                table: "users",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_SupplierId",
                table: "users",
                column: "SupplierId");

            migrationBuilder.AddForeignKey(
                name: "FK_users_suppliers_SupplierId",
                table: "users",
                column: "SupplierId",
                principalTable: "suppliers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
