using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.UnitTests.Builders;

public class OrderBuilder
{
    private Order _order;
    public string TestBuyerId => "12345";
    public int TestCatalogItemId => 234;
    public string TestProductName => "Test Product Name";
    public string TestPictureUri => "http://test.com/image.jpg";
    public decimal _testUnitPrice = 1.23m;
    public int _testUnits = 3;
    public CatalogItemOrdered TestCatalogItemOrdered { get; }

    public OrderBuilder()
    {
        TestCatalogItemOrdered = new CatalogItemOrdered(TestCatalogItemId, TestProductName, TestPictureUri);
        _order = WithDefaultValues();
    }

    public Order Build()
    {
        return _order;
    }

    public Order WithDefaultValues()
    {
        var orderItem = new OrderItem(TestCatalogItemOrdered, _testUnitPrice, _testUnits);
        var itemList = new List<OrderItem>() { orderItem };
        _order = new Order(TestBuyerId, new AddressBuilder().WithDefaultValues(), itemList);
        return _order;
    }

    public Order WithNoItems()
    {
        _order = new Order(TestBuyerId, new AddressBuilder().WithDefaultValues(), new List<OrderItem>());
        return _order;
    }

    public Order WithItems(List<OrderItem> items)
    {
        _order = new Order(TestBuyerId, new AddressBuilder().WithDefaultValues(), items);
        return _order;
    }
}
