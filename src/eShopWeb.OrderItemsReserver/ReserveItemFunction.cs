using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Core.Diagnostics;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Azure;
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

    public class OrderReservation
    {
        public class Item
        {
            public int Id { get; init; }
            public int Quantity { get; init; }
        }

        public required Item[] Items { get; init; }
    }

    [Function("ReserveItemFunction")]
    public async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest request,
        [Microsoft.Azure.Functions.Worker.Http.FromBody] OrderReservation reservation)
    {
        using AzureEventSourceListener listener = 
            AzureEventSourceListener.CreateConsoleLogger();
        _logger.LogInformation("C# HTTP trigger function processed a request.");

        BlobContainerClient containerClient = _blobServiceClient.GetBlobContainerClient(_azureStorageConfig.Value.FileContainerName);
        await containerClient.CreateIfNotExistsAsync();

        BlobClient blobClient = containerClient.GetBlobClient($"{DateTime.UtcNow:yyyy-MM-dd-hh-mm-ss-fff}.json");

        string json = JsonSerializer.Serialize(reservation);
        await blobClient.UploadAsync(BinaryData.FromString(json));

        return new OkObjectResult($"Reserved {reservation.Items.Length} items");
    }
}
