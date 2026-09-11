namespace Infoveave.NLopt;

/// <summary>Computes an objective or constraint and optionally its gradient.</summary>
/// <param name="variables">The current optimization variables.</param>
/// <param name="gradient">The gradient to populate, or an empty span when no gradient was requested.</param>
/// <returns>The objective or constraint value.</returns>
public delegate double NloptFunction(ReadOnlySpan<double> variables, Span<double> gradient);
