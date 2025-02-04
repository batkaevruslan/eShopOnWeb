﻿using System.Collections.Generic;

namespace BlazorAdmin.Authorization;

public class UserInfo
{
    public static readonly UserInfo _anonymous = new();
    public bool IsAuthenticated { get; set; }
    public string NameClaimType { get; set; }
    public string RoleClaimType { get; set; }
    public string Token { get; set; }
    public IEnumerable<ClaimValue> Claims { get; set; }
}
