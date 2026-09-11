using Infoveave.NLopt;

if (NloptOptimizer.NativeVersion != new NloptVersion(2, 11, 0))
{
    throw new InvalidOperationException($"Unexpected native version: {NloptOptimizer.NativeVersion}");
}

using var optimizer = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
optimizer.SetLowerBounds([0.0]);
optimizer.SetUpperBounds([4.0]);
optimizer.SetMinObjective((variables, _) => Math.Pow(variables[0] - 2.0, 2.0));
optimizer.SetParameterTolerance(1e-10, 1e-8);
optimizer.SetMaximumEvaluations(200);
double[] variables = [0.5];
var result = optimizer.Optimize(variables);
if ((int)result.Result <= 0 || Math.Abs(variables[0] - 2.0) > 1e-5)
{
    throw new InvalidOperationException($"Optimization failed: {result.Result}, x={variables[0]}");
}

Console.WriteLine($"consumer-smoke: PASS ({NloptOptimizer.NativeVersion})");

using (var constrained = new NloptOptimizer(NloptAlgorithm.Cobyla, 1))
{
    constrained.SetLowerBounds([-2.0]);
    constrained.SetUpperBounds([2.0]);
    constrained.SetMinObjective((values, _) => values[0] * values[0]);
    constrained.AddInequalityConstraint((values, _) => 1.0 - values[0], 1e-10);
    constrained.SetParameterTolerance(1e-10, 1e-8);
    constrained.SetMaximumEvaluations(300);
    double[] constrainedVariables = [1.5];
    var constrainedResult = constrained.Optimize(constrainedVariables);
    if ((int)constrainedResult.Result <= 0 || Math.Abs(constrainedVariables[0] - 1.0) > 1e-5)
    {
        throw new InvalidOperationException("Published constrained solve failed.");
    }
}

using (var cancellation = new CancellationTokenSource())
using (var cancellable = new NloptOptimizer(NloptAlgorithm.Cobyla, 1))
{
    cancellable.SetMinObjective((values, _) =>
    {
        cancellation.Cancel();
        return values[0] * values[0];
    });
    cancellable.SetMaximumEvaluations(20);
    double[] cancellableVariables = [1.0];
    try
    {
        cancellable.Optimize(cancellableVariables, cancellation.Token);
        throw new InvalidOperationException("Published cancellation did not stop optimization.");
    }
    catch (OperationCanceledException)
    {
    }
}

for (var iteration = 0; iteration < 100; iteration++)
{
    using var disposable = new NloptOptimizer(NloptAlgorithm.Cobyla, 1);
    disposable.SetMaximumEvaluations(5);
}

Console.WriteLine("published-behavior-smoke: PASS");
