using Infoveave.NLopt;

namespace Consumer.ClassLibrary;

public static class OptimizerFactory
{
    public static NloptOptimizer Create() => new(NloptAlgorithm.Cobyla, 1);
}
