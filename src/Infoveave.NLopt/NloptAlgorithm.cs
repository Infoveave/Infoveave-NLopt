namespace Infoveave.NLopt;

/// <summary>Algorithms available in the Infoveave NLopt native build.</summary>
public enum NloptAlgorithm
{
    /// <summary>DIRECT global derivative-free search.</summary>
    Direct = 0,
    /// <summary>Locally biased DIRECT search.</summary>
    DirectL = 1,
    /// <summary>Randomized locally biased DIRECT search.</summary>
    DirectLRandomized = 2,
    /// <summary>DIRECT search without dimension scaling.</summary>
    DirectUnscaled = 3,
    /// <summary>Locally biased DIRECT search without dimension scaling.</summary>
    DirectLUnscaled = 4,
    /// <summary>Randomized locally biased DIRECT search without dimension scaling.</summary>
    DirectLRandomizedUnscaled = 5,
    /// <summary>Original DIRECT implementation.</summary>
    OriginalDirect = 6,
    /// <summary>Locally biased original DIRECT implementation.</summary>
    OriginalDirectL = 7,
    /// <summary>PRAXIS local derivative-free search.</summary>
    Praxis = 12,
    /// <summary>Controlled random search with local mutation.</summary>
    Crs2Lm = 19,
    /// <summary>Method of moving asymptotes.</summary>
    Mma = 24,
    /// <summary>COBYLA local derivative-free constrained search.</summary>
    Cobyla = 25,
    /// <summary>NEWUOA local derivative-free search.</summary>
    Newuoa = 26,
    /// <summary>Bound-constrained NEWUOA search.</summary>
    NewuoaBound = 27,
    /// <summary>Nelder-Mead simplex search.</summary>
    NelderMead = 28,
    /// <summary>Subplex local derivative-free search.</summary>
    Sbplx = 29,
    /// <summary>BOBYQA bound-constrained derivative-free search.</summary>
    Bobyqa = 34,
    /// <summary>ISRES global constrained search.</summary>
    Isres = 35,
    /// <summary>Sequential least-squares quadratic programming.</summary>
    Slsqp = 40,
    /// <summary>Conservative convex separable approximation.</summary>
    Ccsaq = 41,
    /// <summary>ESCH evolutionary global search.</summary>
    Esch = 42
}
