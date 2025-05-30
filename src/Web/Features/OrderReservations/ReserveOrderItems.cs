using MediatR;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.Web.Features.OrderReservations;

public class ReserveOrderItems : IRequest
{
    public required Order Order { get; init; }
}
