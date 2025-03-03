using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Core.Diagnostics;
using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace eShopWeb.OrderItemsReserver;

public class ReserveItemFunction(
    ILogger<ReserveItemFunction> logger,
    BlobServiceClient blobServiceClient,
    IOptions<AzureStorageConfig> azureStorageConfig)
{
    private readonly ILogger<ReserveItemFunction> _logger = logger;
    private readonly BlobServiceClient _blobServiceClient = blobServiceClient;
    private readonly IOptions<AzureStorageConfig> _azureStorageConfig = azureStorageConfig;

    [Function("ReserveItemFunction")]
    public async Task Run(
        [ServiceBusTrigger("order-reservation", Connection = "CloudXServiceBusConnectionString")]
        ServiceBusReceivedMessage message,
        ServiceBusMessageActions messageActions)
    {
        _logger.LogInformation("Message ID: {id}", message.MessageId);
        _logger.LogInformation("Message Body: {body}", message.Body);
        _logger.LogInformation("Message Content-Type: {contentType}", message.ContentType);

        BlobContainerClient containerClient = await GetBlobContainerClient();

        BlobClient blobClient = containerClient.GetBlobClient($"{DateTime.UtcNow:yyyy-MM-dd-hh-mm-ss-fff}.json");

        await blobClient.UploadAsync(message.Body);
        // Complete the message
        await messageActions.CompleteMessageAsync(message);
    }

    private async Task<BlobContainerClient> GetBlobContainerClient()
    {
        BlobContainerClient containerClient = _blobServiceClient.GetBlobContainerClient(_azureStorageConfig.Value.FileContainerName);
        await containerClient.CreateIfNotExistsAsync();
        return containerClient;
    }
}
