using Xunit;

namespace Infoveave.NLopt.Tests;

public sealed class PublicContractTests
{
    [Fact]
    public void ResultValuesMatchTheNativeAbi()
    {
        Assert.Equal(-5, (int)NloptResult.ForcedStop);
        Assert.Equal(-4, (int)NloptResult.RoundoffLimited);
        Assert.Equal(1, (int)NloptResult.Success);
        Assert.Equal(5, (int)NloptResult.MaximumEvaluationsReached);
        Assert.Equal(6, (int)NloptResult.MaximumTimeReached);
    }

    [Fact]
    public void AlgorithmValuesMatchTheNativeAbi()
    {
        Assert.Equal(0, (int)NloptAlgorithm.Direct);
        Assert.Equal(25, (int)NloptAlgorithm.Cobyla);
        Assert.Equal(42, (int)NloptAlgorithm.Esch);
    }

    [Fact]
    public void ZeroDimensionsAreRejectedBeforeLoadingNativeCode()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => new NloptOptimizer(NloptAlgorithm.Cobyla, 0));
    }
}
