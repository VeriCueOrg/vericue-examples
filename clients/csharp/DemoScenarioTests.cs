// The canonical veriCue scenario, in C# (xUnit + the shipped VeriCue client).
//
// The identical four steps exist in Python (clients/python) and C++
// (clients/cpp):
//
//   1. address a stable object and check what it is;
//   2. drive a text input and read the resulting property;
//   3. click a checkbox and check the state actually changed;
//   4. capture a screenshot as a retained artifact.
//
// The connection is configured entirely from the environment, with the same
// variable names as the other two SDKs:
//
//   VERICUE_ENDPOINT   local IPC socket path  -> ConnectLocalAsync()
//   VERICUE_HOST/PORT  TCP                    -> ConnectAsync()
//   VERICUE_TOKEN      authentication token, optional on local IPC
//
// clients/csharp/run.sh starts demo_app and exports one of the two sets.

using System.Text.Json;
using VeriCue;
using Xunit;

namespace VeriCue.Examples;

/// <summary>
/// One connection shared by the whole test class: the veriCue trial licence
/// allows a single automation session at a time, and reconnecting per test
/// would buy nothing.
/// </summary>
public sealed class DemoAppConnection : IAsyncLifetime
{
    public VeriCueClient Client { get; } = new(timeout: TimeSpan.FromSeconds(10));

    public async Task InitializeAsync()
    {
        var endpoint = Environment.GetEnvironmentVariable("VERICUE_ENDPOINT");
        var port = Environment.GetEnvironmentVariable("VERICUE_PORT");
        var token = Environment.GetEnvironmentVariable("VERICUE_TOKEN");
        if (string.IsNullOrEmpty(token)) token = null;

        if (!string.IsNullOrEmpty(endpoint))
        {
            await Client.ConnectLocalAsync(endpoint, token);
        }
        else if (!string.IsNullOrEmpty(port))
        {
            var host = Environment.GetEnvironmentVariable("VERICUE_HOST") ?? "127.0.0.1";
            await Client.ConnectAsync(host, int.Parse(port), token);
        }
        else
        {
            throw new InvalidOperationException(
                "No veriCue endpoint configured. Run clients/csharp/run.sh, or set " +
                "VERICUE_ENDPOINT=<socket> (local IPC) or VERICUE_PORT=<n> " +
                "(TCP, with VERICUE_TOKEN if the app requires one).");
        }
    }

    public async Task DisposeAsync()
    {
        await Client.DisconnectAsync();
        await Client.DisposeAsync();
    }
}

public class DemoScenarioTests : IClassFixture<DemoAppConnection>
{
    // Object paths in demo_app (examples/demo_app/main.cpp). Every widget
    // there is given an explicit objectName, which is what makes these paths
    // stable.
    private const string Window = "DemoMainWindow";
    private const string Input = "DemoMainWindow/centralWidget/inputField";
    private const string Checkbox = "DemoMainWindow/centralWidget/enableCheck";
    private const string TypedText = "vericue";

    private readonly VeriCueClient _client;

    public DemoScenarioTests(DemoAppConnection connection) => _client = connection.Client;

    // Where screenshots and other retained evidence go. CI overrides it with
    // VERICUE_ARTIFACT_DIR and uploads the contents; see clients/ci/run.sh.
    private static string ArtifactDir()
    {
        var dir = Environment.GetEnvironmentVariable("VERICUE_ARTIFACT_DIR") ?? "vericue-artifacts";
        Directory.CreateDirectory(dir);
        return dir;
    }

    /// <summary>1. The object path resolves, and to the class we expect.</summary>
    [Fact]
    public async Task ObjectIsAddressable()
    {
        var found = await _client.FindObjectAsync(path: Checkbox);

        Assert.Equal("QCheckBox", found.GetProperty("className").GetString());
        Assert.Equal(Checkbox, found.GetProperty("path").GetString());
    }

    /// <summary>2. Input action: real key events, then read the property back.</summary>
    [Fact]
    public async Task TypingUpdatesTheTextProperty()
    {
        // Start from a known value, so the assertion is an equality and not a
        // "ends with" - TypeTextAsync appends at the cursor like a user would.
        await _client.SetPropertyAsync(Input, "text", "");

        await _client.TypeTextAsync(Input, TypedText);

        var text = (await _client.GetPropertiesAsync(Input, new[] { "text" }))
            .GetProperty("properties").GetProperty("text").GetString();
        Assert.Equal(TypedText, text);
    }

    /// <summary>3. State change: assert against the state before the click.</summary>
    [Fact]
    public async Task ClickTogglesTheCheckbox()
    {
        var before = await CheckedAsync();

        await _client.MouseClickAsync(Checkbox);

        Assert.NotEqual(before, await CheckedAsync());
    }

    /// <summary>4. Screenshot of the window, written where CI can retain it.</summary>
    [Fact]
    public async Task ScreenshotIsCaptured()
    {
        var shot = await _client.ScreenshotAsync(Window);
        var png = Convert.FromBase64String(shot.GetProperty("data").GetString()!);

        var output = Path.Combine(ArtifactDir(), "demo_app-csharp.png");
        await File.WriteAllBytesAsync(output, png);

        Assert.True(shot.GetProperty("width").GetInt32() > 0);
        Assert.True(shot.GetProperty("height").GetInt32() > 0);
        // PNG magic - proves the bytes survived the base64 round trip.
        Assert.Equal(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }, png[..8]);
        Assert.True(new FileInfo(output).Length > 0);
    }

    private async Task<bool> CheckedAsync()
    {
        var properties = await _client.GetPropertiesAsync(Checkbox, new[] { "checked" });
        return properties.GetProperty("properties").GetProperty("checked").GetBoolean();
    }
}
