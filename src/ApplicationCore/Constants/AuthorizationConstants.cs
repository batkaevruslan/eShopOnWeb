namespace Microsoft.eShopWeb.ApplicationCore.Constants;

public class AuthorizationConstants
{
    public const string AuthKey = "AuthKeyOfDoomThatMustBeAMinimumNumberOfBytes";

    // TODO: Don't use this in production
    public const string DefaultPassword = "Pass@word1";

    // TODO: Change this to an environment variable
    public const string JwtSecretKey = "SecretKeyOfDoomThatMustBeAMinimumNumberOfBytes";
}
