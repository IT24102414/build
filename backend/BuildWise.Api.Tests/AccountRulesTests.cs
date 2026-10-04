using BuildWise.Api.Security;
using Xunit;

namespace BuildWise.Api.Tests;

/// <summary>
/// The administrator console and self-service registration must apply the same
/// account rules. They previously disagreed on password length (6 vs 8), so the
/// weaker rule won for console-created accounts.
/// </summary>
public class AccountRulesTests
{
    [Theory]
    [InlineData("admin@buildwise.demo")]
    [InlineData("first.last@sub.buildwise.lk")]
    [InlineData("user+tag@example.co.uk")]
    public void Valid_emails_are_accepted(string email)
    {
        Assert.True(AccountRules.IsValidEmail(email));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    [InlineData("no-at-sign")]
    [InlineData("@buildwise.demo")]
    [InlineData("user@")]
    [InlineData("user@nodot")]
    [InlineData("user name@buildwise.demo")]
    [InlineData("Display Name <user@buildwise.demo>")]
    public void Invalid_emails_are_rejected(string? email)
    {
        Assert.False(AccountRules.IsValidEmail(email));
    }

    [Theory]
    [InlineData("Passw0rd!")]      // the seeded demo password stays valid
    [InlineData("abcd1234")]
    [InlineData("longenoughpassword1")]
    public void Valid_passwords_are_accepted(string password)
    {
        Assert.True(AccountRules.IsValidPassword(password));
    }

    [Theory]
    [InlineData("Pass123")]        // 7 characters - the old console minimum
    [InlineData("abcdefgh")]       // no digit
    [InlineData("12345678")]       // no letter
    [InlineData("")]
    [InlineData(null)]
    public void Invalid_passwords_are_rejected(string? password)
    {
        Assert.False(AccountRules.IsValidPassword(password));
    }

    [Fact]
    public void Console_and_registration_share_one_password_policy()
    {
        // "Abc123" is exactly the 6 characters the administrator console used to
        // accept. It must now be rejected so the two paths cannot drift apart.
        Assert.False(AccountRules.IsValidPassword("Abc123"));
        Assert.True(AccountRules.IsValidPassword("Abc12345"));
    }
}