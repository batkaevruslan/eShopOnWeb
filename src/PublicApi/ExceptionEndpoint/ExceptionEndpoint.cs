using System;
using System.Threading;
using System.Threading.Tasks;
using FastEndpoints;
using Microsoft.AspNetCore.Http;

namespace Microsoft.eShopWeb.PublicApi.ExceptionEndpoint;

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
