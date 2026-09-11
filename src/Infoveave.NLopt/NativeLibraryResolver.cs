using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json;

namespace Infoveave.NLopt;

internal static class NativeLibraryResolver
{
    private const string LogicalLibraryName = "Infoveave.NLopt.Native";
    private static readonly object Gate = new();
    private static nint nativeHandle;
    private static bool installed;

    internal static void Install()
    {
        lock (Gate)
        {
            if (installed)
            {
                return;
            }

            NativeLibrary.SetDllImportResolver(typeof(NativeLibraryResolver).Assembly, Resolve);
            installed = true;
        }
    }

    private static nint Resolve(string libraryName, System.Reflection.Assembly assembly, DllImportSearchPath? searchPath)
    {
        if (libraryName != LogicalLibraryName)
        {
            return 0;
        }

        lock (Gate)
        {
            if (nativeHandle != 0)
            {
                return nativeHandle;
            }

            var runtimeRoot = Path.Combine(AppContext.BaseDirectory, "nlopt");
            var (runtimeIdentifier, nativeRelativePath) = GetRuntime();
            var nativePath = VerifyBundle(runtimeRoot, runtimeIdentifier, nativeRelativePath);
            nativeHandle = NativeLibrary.Load(nativePath);
            return nativeHandle;
        }
    }

    private static (string RuntimeIdentifier, string NativeRelativePath) GetRuntime()
    {
        if (OperatingSystem.IsLinux() && RuntimeInformation.ProcessArchitecture == Architecture.X64)
        {
            return ("linux-x64", "native/libnlopt.so");
        }
        if (OperatingSystem.IsWindows() && RuntimeInformation.ProcessArchitecture == Architecture.X64)
        {
            return ("win-x64", "native/nlopt.dll");
        }
        if (OperatingSystem.IsMacOS() && RuntimeInformation.ProcessArchitecture == Architecture.Arm64)
        {
            return ("osx-arm64", "native/libnlopt.dylib");
        }

        throw new PlatformNotSupportedException(
            $"Infoveave.NLopt has no verified runtime bundle for {RuntimeInformation.OSDescription} {RuntimeInformation.ProcessArchitecture}.");
    }

    private static string VerifyBundle(string runtimeRoot, string expectedRid, string expectedNativePath)
    {
        var manifestPath = Path.Combine(runtimeRoot, "manifest.json");
        if (!File.Exists(manifestPath))
        {
            throw new DllNotFoundException(
                $"The verified NLopt runtime manifest was not found at '{manifestPath}'. " +
                "Acquire the matching runtime bundle and copy its nlopt directory to the application output.");
        }

        try
        {
            using var manifest = JsonDocument.Parse(File.ReadAllBytes(manifestPath));
            var root = manifest.RootElement;
            Require(root.GetProperty("schemaVersion").GetInt32() == 1, "manifest schema");
            Require(root.GetProperty("runtimeCompatibility").GetString() == "managed-api-v1", "managed compatibility");
            Require(root.GetProperty("nativeVersion").GetString() == "2.11.0", "native version");
            Require(root.GetProperty("rid").GetString() == expectedRid, "runtime identifier");
            Require(root.GetProperty("nativeLibrary").GetString() == expectedNativePath, "native library path");
            var source = root.GetProperty("source");
            Require(source.GetProperty("commit").GetString() == "88c424d4f458412787df96fcc95218acbca224fd", "source commit");
            Require(source.GetProperty("archiveSha256").GetString() == "53e552d83e9294d67db37f0f4a23f15933a9ef698485301a18b98b40004cf0de", "source archive SHA-256");

            var nativeEntry = root.GetProperty("files")
                .EnumerateArray()
                .Single(entry => entry.GetProperty("path").GetString() == expectedNativePath);
            var nativePath = Path.GetFullPath(
                Path.Combine(runtimeRoot, expectedNativePath.Replace('/', Path.DirectorySeparatorChar)));
            var normalizedRoot = Path.GetFullPath(runtimeRoot) + Path.DirectorySeparatorChar;
            Require(nativePath.StartsWith(normalizedRoot, StringComparison.Ordinal), "native library path safety");
            Require(File.Exists(nativePath), "native library presence");
            var actualHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(nativePath))).ToLowerInvariant();
            Require(nativeEntry.GetProperty("sha256").GetString() == actualHash, "native library SHA-256");
            Require(nativeEntry.GetProperty("size").GetInt64() == new FileInfo(nativePath).Length, "native library size");
            return nativePath;
        }
        catch (Exception exception) when (exception is not DllNotFoundException)
        {
            throw new DllNotFoundException(
                $"The NLopt runtime bundle at '{runtimeRoot}' is invalid: {exception.Message}",
                exception);
        }
    }

    private static void Require(bool condition, string field)
    {
        if (!condition)
        {
            throw new InvalidDataException($"Unexpected {field}.");
        }
    }
}
