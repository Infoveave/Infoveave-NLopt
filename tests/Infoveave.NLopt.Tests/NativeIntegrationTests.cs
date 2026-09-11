using Xunit;
using System.Runtime.CompilerServices;

namespace Infoveave.NLopt.Tests;

public sealed class NativeIntegrationTests
{
    [Fact]
    public void NativeVersionMatchesTheVerifiedBundle()
    {
        Assert.Equal(new NloptVersion(2, 11, 0), NloptOptimizer.NativeVersion);
    }

    [Fact]
    public void CobylaSolvesABoundedProblem()
    {
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetLowerBounds([0.0]);
        optimizer.SetUpperBounds([4.0]);
        optimizer.SetMinObjective((variables, gradient) =>
        {
            if (!gradient.IsEmpty)
            {
                gradient[0] = 2.0 * (variables[0] - 2.0);
            }

            return Math.Pow(variables[0] - 2.0, 2.0);
        });
        optimizer.SetParameterTolerance(1e-10, 1e-8);
        optimizer.SetMaximumEvaluations(200);

        double[] variables = [0.5];
        var result = optimizer.Optimize(variables, TestContext.Current.CancellationToken);

        Assert.True((int)result.Result > 0, result.Result.ToString());
        Assert.Equal(2.0, variables[0], 5);
        Assert.True(result.ObjectiveValue < 1e-10);
    }

    [Fact]
    public void InequalityConstraintUsesLessThanOrEqualToZeroConvention()
    {
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetLowerBounds([-2.0]);
        optimizer.SetUpperBounds([2.0]);
        optimizer.SetMinObjective((variables, _) => variables[0] * variables[0]);
        optimizer.AddInequalityConstraint((variables, _) => 1.0 - variables[0], 1e-10);
        optimizer.SetParameterTolerance(1e-10, 1e-8);
        optimizer.SetMaximumEvaluations(300);

        double[] variables = [1.5];
        var result = optimizer.Optimize(variables, TestContext.Current.CancellationToken);

        Assert.True((int)result.Result > 0, result.Result.ToString());
        Assert.InRange(variables[0], 0.99999, 1.00001);
    }

    [Fact]
    public void ManagedCallbackExceptionsAreRethrownAfterNativeUnwinds()
    {
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetMinObjective((_, _) => throw new InvalidOperationException("objective failed"));
        optimizer.SetMaximumEvaluations(20);
        double[] variables = [0.0];

        var exception = Assert.Throws<InvalidOperationException>(
            () => optimizer.Optimize(variables, TestContext.Current.CancellationToken));

        Assert.Equal("objective failed", exception.Message);
    }

    [Fact]
    public void CancellationDoesNotDisposeTheOptimizer()
    {
        using var cancellation = new CancellationTokenSource();
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetMinObjective((variables, _) =>
        {
            cancellation.Cancel();
            return variables[0] * variables[0];
        });
        optimizer.SetMaximumEvaluations(20);
        double[] variables = [1.0];

#pragma warning disable xUnit1051 // This test intentionally supplies a token that it cancels from the callback.
        Assert.Throws<OperationCanceledException>(() => optimizer.Optimize(variables, cancellation.Token));
#pragma warning restore xUnit1051

        optimizer.SetMaximumEvaluations(10);
    }

    [Fact]
    public async Task RunningOptimizerRejectsConfigurationAndDisposalButAcceptsStopRequests()
    {
        using var callbackEntered = new ManualResetEventSlim();
        using var releaseCallback = new ManualResetEventSlim();
        var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetMinObjective((variables, _) =>
        {
            callbackEntered.Set();
            releaseCallback.Wait(TestContext.Current.CancellationToken);
            return variables[0] * variables[0];
        });
        optimizer.SetMaximumEvaluations(100);
        double[] variables = [1.0];
        var testCancellation = TestContext.Current.CancellationToken;
        var optimizeTask = Task.Run(() => optimizer.Optimize(variables, testCancellation), testCancellation);

        Assert.True(callbackEntered.Wait(TimeSpan.FromSeconds(5), testCancellation));
        Assert.Throws<InvalidOperationException>(() => optimizer.SetMaximumEvaluations(10));
        Assert.Throws<InvalidOperationException>(() => optimizer.Dispose());
        optimizer.RequestStop();
        releaseCallback.Set();

        var result = await optimizeTask;
        Assert.Equal(NloptResult.ForcedStop, result.Result);
        optimizer.Dispose();
    }

    [Fact]
    public void ManagedArgumentsAreValidatedBeforeEnteringNativeConfiguration()
    {
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 2);

        Assert.Throws<ArgumentException>(() => optimizer.SetLowerBounds([0.0]));
        Assert.Throws<ArgumentOutOfRangeException>(() => optimizer.SetUpperBounds([0.0, double.NaN]));
        Assert.Throws<ArgumentOutOfRangeException>(() => optimizer.SetInitialStep([1.0, 0.0]));
        Assert.Throws<ArgumentOutOfRangeException>(() => optimizer.SetMaximumEvaluations(0));
        Assert.Throws<ArgumentOutOfRangeException>(() => optimizer.SetMaximumTime(TimeSpan.Zero));
        Assert.Throws<ArgumentOutOfRangeException>(() => optimizer.SetFunctionTolerance(-1.0, 0.0));
        Assert.Throws<ArgumentException>(() => optimizer.Optimize([0.0], TestContext.Current.CancellationToken));
    }

    [Fact]
    public void DisposedOptimizerRejectsFurtherUse()
    {
        var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.Dispose();

        Assert.Throws<ObjectDisposedException>(() => optimizer.SetMaximumEvaluations(10));
        Assert.Throws<ObjectDisposedException>(() => optimizer.RequestStop());
        optimizer.Dispose();
    }

    [Fact]
    public void CallbackRegistrationDoesNotPermanentlyRootAnUndisposedOptimizer()
    {
        var optimizerReference = CreateUndisposedOptimizer();

        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();

        Assert.False(optimizerReference.IsAlive);
    }

    [Fact]
    public void CallbackSurvivesGarbageCollectionPressureDuringOptimization()
    {
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetLowerBounds([0.0]);
        optimizer.SetUpperBounds([4.0]);
        optimizer.SetMinObjective((variables, _) =>
        {
            GC.Collect();
            GC.WaitForPendingFinalizers();
            return Math.Pow(variables[0] - 2.0, 2.0);
        });
        optimizer.SetParameterTolerance(1e-10, 1e-8);
        optimizer.SetMaximumEvaluations(200);
        double[] variables = [0.5];

        var result = optimizer.Optimize(variables, TestContext.Current.CancellationToken);

        Assert.True((int)result.Result > 0, result.Result.ToString());
        Assert.Equal(2.0, variables[0], 5);
    }

    [Fact]
    public void RepeatedCreateAndDisposeIsSafe()
    {
        for (var iteration = 0; iteration < 100; iteration++)
        {
            using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
            optimizer.SetMaximumEvaluations(10);
        }
    }

    [Fact]
    public async Task IndependentOptimizersCanSolveConcurrently()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        using var rendezvous = new CountdownEvent(2);
        var first = Task.Run(() => SolveNear(1.0, cancellationToken, rendezvous), cancellationToken);
        var second = Task.Run(() => SolveNear(3.0, cancellationToken, rendezvous), cancellationToken);

        var results = await Task.WhenAll(first, second);

        Assert.Equal(1.0, results[0], 5);
        Assert.Equal(3.0, results[1], 5);
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    private static WeakReference CreateUndisposedOptimizer()
    {
        var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetMinObjective((variables, _) => variables[0] * variables[0]);
        return new WeakReference(optimizer);
    }

    private static double SolveNear(
        double target,
        CancellationToken cancellationToken,
        CountdownEvent? rendezvous = null)
    {
        var firstCallback = true;
        using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
        optimizer.SetLowerBounds([0.0]);
        optimizer.SetUpperBounds([4.0]);
        optimizer.SetMinObjective((variables, _) =>
        {
            if (firstCallback && rendezvous is not null)
            {
                firstCallback = false;
                rendezvous.Signal();
                if (!rendezvous.Wait(TimeSpan.FromSeconds(10), cancellationToken))
                {
                    throw new TimeoutException("Independent optimizer callbacks did not overlap.");
                }
            }
            return Math.Pow(variables[0] - target, 2.0);
        });
        optimizer.SetParameterTolerance(1e-10, 1e-8);
        optimizer.SetMaximumEvaluations(200);
        double[] variables = [2.0];
        var result = optimizer.Optimize(variables, cancellationToken);
        Assert.True((int)result.Result > 0, result.Result.ToString());
        return variables[0];
    }
}
