namespace BuildWise.Api.Services;

public interface IEmailService
{
    /// <summary>
    /// Sends a plain-text notification email. Never throws — a failed or
    /// unconfigured send is logged and swallowed so it can never block a
    /// procurement action (spec §11: handle timeouts/failures gracefully).
    /// </summary>
    /// <returns>
    /// True when the message was accepted by an SMTP server, false when it was
    /// only logged (no SMTP host configured, empty recipient) or the send failed.
    /// Callers that must tell the user the truth (e.g. admin user provisioning)
    /// should surface this value instead of unconditionally claiming success.
    /// </returns>
    Task<bool> SendAsync(string toEmail, string subject, string body, CancellationToken cancellationToken = default);
}
