using System.Collections.Generic;

namespace BlazorShared.Models;

public class PagedCatalogItemResponse
{
    public List<CatalogItem> CatalogItems { get; set; } = new();
    public int PageCount { get; set; } = 0;
}
