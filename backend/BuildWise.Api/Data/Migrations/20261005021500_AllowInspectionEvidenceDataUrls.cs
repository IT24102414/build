using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace BuildWise.Api.Data.Migrations;

public partial class AllowInspectionEvidenceDataUrls : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AlterColumn<string>(
            name: "FileUrl", table: "inspection_evidences", type: "text", nullable: false,
            oldClrType: typeof(string), oldType: "character varying(2000)", oldMaxLength: 2000);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AlterColumn<string>(
            name: "FileUrl", table: "inspection_evidences", type: "character varying(2000)", maxLength: 2000, nullable: false,
            oldClrType: typeof(string), oldType: "text");
    }
}
