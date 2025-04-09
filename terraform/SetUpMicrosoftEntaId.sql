CREATE USER "eShopPublicApi-d13jf" FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER "eShopPublicApi-d13jf";
ALTER ROLE db_datawriter ADD MEMBER "eShopPublicApi-d13jf";
ALTER ROLE db_ddladmin ADD MEMBER "eShopPublicApi-d13jf";

CREATE USER "eShopWeb1" FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER "eShopWeb1";
ALTER ROLE db_datawriter ADD MEMBER "eShopWeb1";
ALTER ROLE db_ddladmin ADD MEMBER "eShopWeb1";

CREATE USER "eShopWeb2" FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER "eShopWeb2";
ALTER ROLE db_datawriter ADD MEMBER "eShopWeb2";
ALTER ROLE db_ddladmin ADD MEMBER "eShopWeb2";


CREATE USER "eShopWeb2/slots/staging" FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER "eShopWeb2/slots/staging";
ALTER ROLE db_datawriter ADD MEMBER "eShopWeb2/slots/staging";
ALTER ROLE db_ddladmin ADD MEMBER "eShopWeb2/slots/staging";