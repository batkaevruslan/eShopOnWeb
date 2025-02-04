namespace BlazorShared.Authorization;

public static class Constants
{
    public static class Roles
    {
        public const string Administrators = "Administrators";
        public const string PRODUCT_MANAGERS = "Product Managers";
    }

    public static class RoleCombinations
    {
        public const string ADMIN_PORTAL_ROLES = $"{Roles.Administrators},{Roles.PRODUCT_MANAGERS}";
    }
}
