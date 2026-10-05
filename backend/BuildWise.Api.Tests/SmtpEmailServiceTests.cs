using BuildWise.Api.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace BuildWise.Api.Tests;

public class SmtpEmailServiceTests
{
    [Theory]
    [InlineData(null, null, null)]
    [InlineData("localhost", "not-an-address", "587")]
    [InlineData("localhost", "sender@example.test", "-1")]
    [InlineData("localhost", "", "587")]
    public async Task MissingOrInvalidSettingsReturnFalseWithoutBreakingWorkflow(
        string? host, string? sender, string? port)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["Smtp:Host"] = host,
                ["Smtp:FromAddress"] = sender,
                ["Smtp:Port"] = port
            }).Build();
        var service = new SmtpEmailService(configuration, NullLogger<SmtpEmailService>.Instance);
        Assert.False(await service.SendAsync("recipient@example.test", "RFQ", "Test message"));
    }
}
