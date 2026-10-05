# Configure BuildWise email

Without `Smtp:Host`, BuildWise logs notifications and returns `emailSent: false`; no message reaches a mailbox. The RFQ page keeps the recipient and message available for retry when sending fails.

Configure the backend's existing .NET user-secrets store locally, or use deployment environment variables. Do not commit email credentials to appsettings.json.

Required settings are `Smtp:Host`, `Smtp:Port`, `Smtp:EnableSsl`, `Smtp:Username`, `Smtp:Password`, and `Smtp:FromAddress`. Environment variable equivalents use double underscores, for example `Smtp__Host` and `Smtp__Password`. Set the sender to an address your provider permits. The current SMTP client uses STARTTLS; use your provider's STARTTLS endpoint, rather than an implicit TLS endpoint.

Restart the API after configuring credentials. Retry the existing RFQ's Send Email action; a response with `emailSent: true` means the SMTP server accepted the message. Check the recipient's inbox and spam folder separately to confirm delivery. Check backend logs for configuration, authentication, or connection failures if the response is false.
