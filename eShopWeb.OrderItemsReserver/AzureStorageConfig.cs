namespace eShopWeb.OrderItemsReserver;

public class AzureStorageConfig
{
    public const string AzureStorageConfigSectionName = "AzureStorageConfig";

    public required string ServiceUri { get; init; }
    public required string FileContainerName { get; init; }
    public bool UseDevelopmentStorage { get; init; } = false;
}
