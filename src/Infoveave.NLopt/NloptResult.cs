namespace Infoveave.NLopt;

/// <summary>Raw NLopt return codes.</summary>
public enum NloptResult
{
    /// <summary>Unspecified native failure.</summary>
    Failure = -1,
    /// <summary>Native arguments were invalid.</summary>
    InvalidArguments = -2,
    /// <summary>Native allocation failed.</summary>
    OutOfMemory = -3,
    /// <summary>Roundoff prevented further progress.</summary>
    RoundoffLimited = -4,
    /// <summary>Optimization was explicitly stopped.</summary>
    ForcedStop = -5,
    /// <summary>Optimization completed successfully without a more specific reason.</summary>
    Success = 1,
    /// <summary>The configured objective stop value was reached.</summary>
    StopValueReached = 2,
    /// <summary>A configured function tolerance was reached.</summary>
    FunctionToleranceReached = 3,
    /// <summary>A configured parameter tolerance was reached.</summary>
    ParameterToleranceReached = 4,
    /// <summary>The maximum evaluation count was reached.</summary>
    MaximumEvaluationsReached = 5,
    /// <summary>The maximum elapsed time was reached.</summary>
    MaximumTimeReached = 6
}
