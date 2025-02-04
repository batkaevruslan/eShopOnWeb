namespace BlazorShared;

public class BaseUrlConfiguration
{
    public const string ConfigName = "baseUrls";

    public string ApiBase { get; set; }
    public string WebBase { get; set; }
}
