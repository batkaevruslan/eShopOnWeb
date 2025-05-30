using MediatR;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.Web.Features.OrderDeliveryPreparation;

public class PrepareOrderForDelivery : IRequest
{
    public required Order Order { get; init; }
}
