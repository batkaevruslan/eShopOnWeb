using Azure.Identity;
using eShopWeb.OrderItemsReserver;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.Azure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);

builder.AddAspireServiceDefaults();

builder.ConfigureFunctionsWebApplication();

builder.Services.Configure<AzureStorageConfig>(
    builder.Configuration.GetSection(AzureStorageConfig.AzureStorageConfigSectionName));

builder.Services.AddAzureClients(clientBuilder =>
{
    AzureStorageConfig? config = builder.Configuration
        .GetRequiredSection(AzureStorageConfig.AzureStorageConfigSectionName)
        .Get<AzureStorageConfig>();
    if (config.UseDevelopmentStorage)
    {
        clientBuilder.AddBlobServiceClient("UseDevelopmentStorage=true");
    }
    else
    {
        clientBuilder.AddBlobServiceClient(new Uri(config.ServiceUri));
    }

    clientBuilder.UseCredential(new ChainedTokenCredential(
        new VisualStudioCredential(),
        new ManagedIdentityCredential()));
});

// Application Insights isn't enabled by default. See https://aka.ms/AAt8mw4.
// builder.Services
//     .AddApplicationInsightsTelemetryWorkerService()
//     .ConfigureFunctionsApplicationInsights();

builder.Build().Run();
