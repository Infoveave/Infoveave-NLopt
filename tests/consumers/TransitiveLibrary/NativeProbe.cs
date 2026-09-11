using Infoveave.NLopt;

namespace Consumer.TransitiveLibrary;

public static class NativeProbe
{
    public static string ReadVersion()
    {
        var version = NloptOptimizer.NativeVersion;
        return $"{version.Major}.{version.Minor}.{version.Patch}";
    }
}
