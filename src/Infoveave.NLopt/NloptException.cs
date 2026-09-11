namespace Infoveave.NLopt;

/// <summary>Reports a native NLopt configuration failure.</summary>
public sealed class NloptException : Exception
{
    internal NloptException(NloptResult result, string message)
        : base(message)
    {
        Result = result;
    }

    /// <summary>Gets the raw native failure result.</summary>
    public NloptResult Result { get; }
}
