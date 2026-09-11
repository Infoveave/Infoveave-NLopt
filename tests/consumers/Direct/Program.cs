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
