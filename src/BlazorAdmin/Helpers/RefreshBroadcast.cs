using System;

namespace BlazorAdmin.Helpers;

internal sealed class RefreshBroadcast
{
    private static readonly Lazy<RefreshBroadcast>
        _lazy = new(() => new RefreshBroadcast());

    public static RefreshBroadcast Instance => _lazy.Value;

    private RefreshBroadcast()
    {
    }

    public event Action RefreshRequested;
    public void CallRequestRefresh()
    {
        RefreshRequested?.Invoke();
    }
}
