namespace Infoveave.NLopt;

/// <summary>Contains NLopt's raw termination result and objective value.</summary>
/// <param name="Result">The raw native termination result.</param>
/// <param name="ObjectiveValue">The objective value returned by NLopt.</param>
public readonly record struct NloptOptimizationResult(NloptResult Result, double ObjectiveValue);
