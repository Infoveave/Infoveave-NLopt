using Consumer.TransitiveLibrary;

var version = NativeProbe.ReadVersion();
if (version != "2.11.0")
{
    throw new InvalidOperationException($"Unexpected transitive native version: {version}");
}

Console.WriteLine($"transitive-consumer-smoke: PASS ({version})");
