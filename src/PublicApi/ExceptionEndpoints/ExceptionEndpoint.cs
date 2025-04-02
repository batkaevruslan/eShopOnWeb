using FastEndpoints;
using System.Threading.Tasks;
using System.Threading;
using System;
using Microsoft.AspNetCore.Http;

namespace Microsoft.eShopWeb.PublicApi.ExceptionEndpoints;

public class ExceptionEndpoint : EndpointWithoutRequest<string>
{
    public override void Configure()
    {
        Get("api/exceptions");
        AllowAnonymous();
        Description(d => d.Produces<string>());
    }

    public override Task HandleAsync(CancellationToken ct)
    {
        throw new Exception("Test Application Insights exception reporting");
    }
}
