﻿var builder = DistributedApplication.CreateBuilder(args);

builder
    .AddProject<Projects.PublicApi>(nameof(Projects.PublicApi).ToLower());

builder
    .AddProject<Projects.Web>(nameof(Projects.Web).ToLower());

builder
    .AddProject<Projects.BlazorAdmin>(nameof(Projects.BlazorAdmin).ToLower());

builder.Build().Run();
