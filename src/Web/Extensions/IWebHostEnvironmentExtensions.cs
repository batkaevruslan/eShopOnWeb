namespace Microsoft.eShopWeb.Web.Extensions;

public static class WebHostEnvironmentExtensions
{
    public static bool IsDocker(this IWebHostEnvironment environment)
        => environment.EnvironmentName == "Docker";
}
