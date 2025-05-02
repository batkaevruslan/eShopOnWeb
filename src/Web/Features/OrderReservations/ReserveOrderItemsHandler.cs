using MediatR;
using Azure.Messaging.ServiceBus;

namespace Microsoft.eShopWeb.Web.Features.OrderReservations;

public class ReserveOrderItemsHandler(ServiceBusClient serviceBusClient): IRequestHandler<ReserveOrderItems>
{
    private const string OrderReservationQueueName = "order-reservation";
    private readonly ServiceBusClient _serviceBusClient = serviceBusClient;

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
        ServiceBusSender sender = _serviceBusClient.CreateSender(OrderReservationQueueName);
        await sender.SendMessageAsync(
            new ServiceBusMessage(BinaryData.FromObjectAsJson(orderReservation)),
            cancellationToken);
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

