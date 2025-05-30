using System.Configuration;
using System.Text;
using System.Text.Json;
using MediatR;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.Web.Features.OrderDeliveryPreparation;

public class PrepareOrderForDeliveryHandler: IRequestHandler<PrepareOrderForDelivery>
{
    private readonly string _deliveryOrderProcessorUri;

    public PrepareOrderForDeliveryHandler(IConfiguration configuration)
    {
        _deliveryOrderProcessorUri = configuration.GetValue<string>("DeliveryOrderProcessorUri")
                                     ?? throw new ConfigurationErrorsException("DeliveryOrderProcessorUri is not specified in configuration");
    }

    private static readonly HttpClient _httpClient = new();
    public async Task Handle(PrepareOrderForDelivery request, CancellationToken cancellationToken)
    {
        OrderDetails orderDetails = new()
        {
            Items = request.Order.OrderItems.Select(item => new OrderDetails.Item
            {
                Quantity = item.Units,
                Id = item.Id,
                Price = item.UnitPrice,
                Name = item.ItemOrdered.ProductName
            }).ToArray(),
            ShippingAddress = request.Order.ShipToAddress
        };
        StringContent content = ToJson(orderDetails);
        await _httpClient.PostAsync(_deliveryOrderProcessorUri, content, cancellationToken);
    } 
    
    private static StringContent ToJson(object obj)
    {
        return new StringContent(JsonSerializer.Serialize(obj), Encoding.UTF8, "application/json");
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
        public required Item[] Items { get; init; }
        public required Address ShippingAddress { get; init; }
    }
}
