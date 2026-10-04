namespace BuildWise.Api.Security;

/// <summary>
/// Account rules shared by every path that creates or changes an account, so the
/// administrator console and self-service registration cannot drift apart.
/// Previously the console accepted a 6-character password while registration
/// required 8, which meant the weaker rule won for the accounts it created.
/// </summary>
public static class AccountRules
{
    public const int MinimumPasswordLength = 8;

    public const string PasswordRequirementMessage =
        "Password must be at least 8 characters long and contain both a letter and a digit.";

    /// <summary>
    /// Length plus a character-class requirement. Deliberately not a full
    /// composition rule (no symbol/uppercase demands) so the seeded demo password
    /// and existing accounts stay valid.
    /// </summary>
    public static bool IsValidPassword(string? password)
    {
        if (string.IsNullOrWhiteSpace(password) || password.Length < MinimumPasswordLength)
            return false;

        return password.Any(char.IsLetter) && password.Any(char.IsDigit);
    }

    /// <summary>
    /// Shape check for an email address. Uses MailAddress rather than a regex so
    /// the accepted set matches what the SMTP client will actually send to, and
    /// rejects the forms that silently break mail delivery (missing @, missing
    /// domain, embedded spaces).
    /// </summary>
    public static bool IsValidEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return false;

        var trimmed = email.Trim();
        if (trimmed.Length != email.Length && email != email.Trim()) return false;

        try
        {
            var address = new System.Net.Mail.MailAddress(trimmed);

            // MailAddress accepts "Name <a@b.com>"; an account identity must be a
            // bare address, and the host must contain a dot.
            return address.Address == trimmed
                && !trimmed.Contains(' ')
                && trimmed.Contains('@')
                && trimmed.Contains('.');
        }
        catch (FormatException)
        {
            return false;
        }
    }
}