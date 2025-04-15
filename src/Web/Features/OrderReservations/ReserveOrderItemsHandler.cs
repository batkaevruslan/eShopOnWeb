using MediatR;
using System.Configuration;
using System.Text;
using System.Text.Json;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.Web.Features.OrderReservations;

public class ReserveOrderItemsHandler: IRequestHandler<ReserveOrderItems>
{
    private readonly string _orderItemReserverUri;

    public ReserveOrderItemsHandler(IConfiguration configuration)
    {
        _orderItemReserverUri = configuration.GetValue<string>("OrderItemReserverUri")
                                ?? throw new ConfigurationErrorsException("OrderItemReserverUri is not specified in configuration");
    }

    private static readonly HttpClient _httpClient = new();
    public async Task Handle(ReserveOrderItems request, CancellationToken cancellationToken)
    {
        OrderReservation orderReservation = new()
        {
            Items = request.Order.OrderItems.Select(item => new OrderReservation.Item
            {
                Quantity = item.Units,
                Id = item.Id
            }).ToArray()
        };
        StringContent content = ToJson(orderReservation);
        await _httpClient.PostAsync(_orderItemReserverUri, content, cancellationToken);
    }

    private static StringContent ToJson(object obj)
    {
        return new StringContent(JsonSerializer.Serialize(obj), Encoding.UTF8, "application/json");
    }

    public class OrderReservation
    {
        public class Item
        {
            public int Id { get; init; }
            public int Quantity { get; init; }
        }
        public required Item[] Items { get; init; }
    }
}

