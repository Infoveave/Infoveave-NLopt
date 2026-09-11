namespace Infoveave.NLopt;

/// <summary>Identifies the loaded native NLopt version.</summary>
/// <param name="Major">The major version.</param>
/// <param name="Minor">The minor version.</param>
/// <param name="Patch">The patch version.</param>
public readonly record struct NloptVersion(int Major, int Minor, int Patch);
