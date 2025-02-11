using System;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace PublicApiIntegrationTests;

[TestClass]
public class LoadTests
{
    private readonly HttpClient _httpClient = new();
    private int _counter;
    [TestMethod]
    public async Task Load()
    {
        var tasks = Enumerable.Range(1, 1000000).Select(_ => SendRequestAsync()).ToArray();
        await Task.WhenAll(tasks);
        Console.WriteLine(_counter);
    }

    private readonly SemaphoreSlim _sem = new (1000);
    private async Task SendRequestAsync()
    {
        await _sem.WaitAsync();
        try
        {
            // avoid hardcode?
            await _httpClient.GetAsync("https://eshoppublicapi-d13jf.azurewebsites.net/api/catalog-items");
            Interlocked.Increment(ref _counter);
        }
        finally
        {
            _sem.Release();
        }
    }
}
