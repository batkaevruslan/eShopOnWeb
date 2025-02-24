using System.Configuration;
using System.Net;
using System.Text.Json.Serialization;
using Azure.Identity;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace eShopWeb.DeliveryOrderProcessor
{
    public class PrepareOrderForDeliveryFunction
    {
        private const string DatabaseName = "DeliveryDb";
        private const string OrderTablePartitionKeyPath = "/shippingAddress/country";
        private const string OrderTableName = "Orders";
        private readonly ILogger<PrepareOrderForDeliveryFunction> _logger;
        private readonly string _cosmosDbAccountEndpoint;

        public PrepareOrderForDeliveryFunction(ILogger<PrepareOrderForDeliveryFunction> logger,
            IConfiguration configuration)
        {
            _logger = logger;
            _cosmosDbAccountEndpoint = configuration.GetValue<string>("CosmosDbAccountEndpoint")
                             ?? throw new ConfigurationErrorsException("CosmosDbAccountEndpoint is not provided");
        }

        [Function("PrepareOrderForDelivery")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequest req,
            [Microsoft.Azure.Functions.Worker.Http.FromBody] OrderDetails orderDetails)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            
            CosmosClient client = new CosmosClient(_cosmosDbAccountEndpoint,
                new DefaultAzureCredential(),
                new CosmosClientOptions
                {
                    SerializerOptions = new CosmosSerializationOptions
                    {
                        PropertyNamingPolicy = CosmosPropertyNamingPolicy.CamelCase
                    }
                });
            Database database = client.GetDatabase(DatabaseName);

            await database.CreateContainerIfNotExistsAsync(OrderTableName, OrderTablePartitionKeyPath);
            Container orderTable = database.GetContainer(OrderTableName);

            await orderTable.CreateItemAsync(orderDetails, new PartitionKey(orderDetails.ShippingAddress.Country));

            return new OkObjectResult("Welcome to Azure Functions!");
        }

        public class OrderDetails
        {
            public class Item
            {
                public int Id { get; init; }
                public int Quantity { get; init; }
                public decimal Price { get; set; }
                public required string Name { get; init; }
            }
            public Guid Id { get; init; } = Guid.NewGuid();
            public required Item[] Items { get; init; }
            public required Address ShippingAddress { get; init; }
        }
    }
}
