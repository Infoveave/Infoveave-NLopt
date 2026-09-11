using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;

namespace Infoveave.NLopt;

/// <summary>Owns one native NLopt optimizer.</summary>
public sealed unsafe class NloptOptimizer : IDisposable
{
    private static readonly NativeMethods.NativeFunction NativeCallback = InvokeCallback;
    private readonly object gate = new();
    private readonly SafeNloptHandle handle = null!;
    private readonly List<GCHandle> callbackHandles = [];
    private readonly List<NloptFunction> callbackFunctions = [];
    private bool disposed;
    private bool running;
    private int stopRequested;
    private CancellationToken cancellationToken;
    private ExceptionDispatchInfo? callbackException;

    /// <summary>Creates an optimizer for the selected algorithm and dimension count.</summary>
    public NloptOptimizer(NloptAlgorithm algorithm, int dimensions)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(dimensions, 1);
        if (!Enum.IsDefined(algorithm))
        {
            throw new ArgumentOutOfRangeException(nameof(algorithm));
        }

        Algorithm = algorithm;
        Dimensions = dimensions;
        handle = NativeMethods.Create(algorithm, checked((uint)dimensions));
        if (handle.IsInvalid)
        {
            handle.Dispose();
            throw new NloptException(NloptResult.OutOfMemory, "NLopt could not create an optimizer.");
        }
    }

    /// <summary>Gets the native algorithm owned by this optimizer.</summary>
    public NloptAlgorithm Algorithm { get; }

    /// <summary>Gets the number of optimization variables.</summary>
    public int Dimensions { get; }

    /// <summary>Gets the version reported by the explicitly bundled NLopt library.</summary>
    public static NloptVersion NativeVersion
    {
        get
        {
            NativeMethods.Version(out var major, out var minor, out var patch);
            return new NloptVersion(major, minor, patch);
        }
    }

    /// <summary>Releases unmanaged resources when explicit disposal was missed.</summary>
    ~NloptOptimizer()
    {
        DisposeCore();
    }

    /// <summary>Sets one lower bound per optimization variable.</summary>
    public unsafe void SetLowerBounds(ReadOnlySpan<double> bounds)
    {
        ValidateBounds(bounds, nameof(bounds));
        lock (gate)
        {
            EnsureConfigurable();
            fixed (double* pointer = bounds)
            {
                ThrowOnError(NativeMethods.SetLowerBounds(handle, pointer), "set lower bounds");
            }
        }
    }

    /// <summary>Sets one upper bound per optimization variable.</summary>
    public unsafe void SetUpperBounds(ReadOnlySpan<double> bounds)
    {
        ValidateBounds(bounds, nameof(bounds));
        lock (gate)
        {
            EnsureConfigurable();
            fixed (double* pointer = bounds)
            {
                ThrowOnError(NativeMethods.SetUpperBounds(handle, pointer), "set upper bounds");
            }
        }
    }

    /// <summary>Sets the objective function to minimize.</summary>
    public void SetMinObjective(NloptFunction objective)
    {
        ArgumentNullException.ThrowIfNull(objective);
        AddCallback(objective, (callback, data) => NativeMethods.SetMinObjective(handle, callback, data), "set objective");
    }

    /// <summary>Adds an inequality constraint using NLopt's <c>g(x) &lt;= 0</c> convention.</summary>
    public void AddInequalityConstraint(NloptFunction constraint, double tolerance)
    {
        ArgumentNullException.ThrowIfNull(constraint);
        ValidateNonNegativeFinite(tolerance, nameof(tolerance));
        AddCallback(
            constraint,
            (callback, data) => NativeMethods.AddInequalityConstraint(handle, callback, data, tolerance),
            "add inequality constraint");
    }

    /// <summary>Stops when the objective reaches the supplied value.</summary>
    public void SetStopValue(double value)
    {
        if (!double.IsFinite(value))
        {
            throw new ArgumentOutOfRangeException(nameof(value));
        }

        Configure(() => NativeMethods.SetStopValue(handle, value), "set stop value");
    }

    /// <summary>Sets absolute and relative objective tolerances.</summary>
    public void SetFunctionTolerance(double absolute, double relative)
    {
        ValidateNonNegativeFinite(absolute, nameof(absolute));
        ValidateNonNegativeFinite(relative, nameof(relative));
        lock (gate)
        {
            EnsureConfigurable();
            ThrowOnError(NativeMethods.SetFunctionToleranceAbsolute(handle, absolute), "set absolute function tolerance");
            ThrowOnError(NativeMethods.SetFunctionToleranceRelative(handle, relative), "set relative function tolerance");
        }
    }

    /// <summary>Sets absolute and relative parameter tolerances.</summary>
    public void SetParameterTolerance(double absolute, double relative)
    {
        ValidateNonNegativeFinite(absolute, nameof(absolute));
        ValidateNonNegativeFinite(relative, nameof(relative));
        lock (gate)
        {
            EnsureConfigurable();
            ThrowOnError(NativeMethods.SetParameterToleranceAbsolute(handle, absolute), "set absolute parameter tolerance");
            ThrowOnError(NativeMethods.SetParameterToleranceRelative(handle, relative), "set relative parameter tolerance");
        }
    }

    /// <summary>Sets the maximum number of objective evaluations.</summary>
    public void SetMaximumEvaluations(int maximumEvaluations)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(maximumEvaluations, 1);
        Configure(() => NativeMethods.SetMaximumEvaluations(handle, maximumEvaluations), "set maximum evaluations");
    }

    /// <summary>Sets the maximum wall-clock optimization time.</summary>
    public void SetMaximumTime(TimeSpan maximumTime)
    {
        var seconds = maximumTime.TotalSeconds;
        if (!double.IsFinite(seconds) || seconds <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maximumTime));
        }

        Configure(() => NativeMethods.SetMaximumTime(handle, seconds), "set maximum time");
    }

    /// <summary>Sets one positive initial step per optimization variable.</summary>
    public unsafe void SetInitialStep(ReadOnlySpan<double> step)
    {
        ValidateVector(step, nameof(step), value => double.IsFinite(value) && value > 0);
        lock (gate)
        {
            EnsureConfigurable();
            fixed (double* pointer = step)
            {
                ThrowOnError(NativeMethods.SetInitialStep(handle, pointer), "set initial step");
            }
        }
    }

    /// <summary>Runs the configured optimization and updates <paramref name="variables"/> in place.</summary>
    public unsafe NloptOptimizationResult Optimize(
        Span<double> variables,
        CancellationToken cancellationToken = default)
    {
        ValidateVector(variables, nameof(variables), double.IsFinite);
        lock (gate)
        {
            EnsureNotDisposed();
            if (running)
            {
                throw new InvalidOperationException("This optimizer is already running.");
            }

            running = true;
            stopRequested = 0;
            callbackException = null;
            this.cancellationToken = cancellationToken;
        }

        try
        {
            double objectiveValue;
            NloptResult result;
            fixed (double* pointer = variables)
            {
                result = NativeMethods.Optimize(handle, pointer, &objectiveValue);
            }

            callbackException?.Throw();
            cancellationToken.ThrowIfCancellationRequested();
            return new NloptOptimizationResult(result, objectiveValue);
        }
        finally
        {
            lock (gate)
            {
                this.cancellationToken = default;
                running = false;
            }
        }
    }

    /// <summary>Requests that a running optimization stop at its next callback boundary.</summary>
    public void RequestStop()
    {
        lock (gate)
        {
            EnsureNotDisposed();
            if (running)
            {
                Volatile.Write(ref stopRequested, 1);
            }
        }
    }

    /// <inheritdoc />
    public void Dispose()
    {
        lock (gate)
        {
            if (disposed)
            {
                return;
            }
            if (running)
            {
                throw new InvalidOperationException("A running optimizer cannot be disposed.");
            }

            disposed = true;
            DisposeCore();
            GC.SuppressFinalize(this);
        }
    }

    private static unsafe double InvokeCallback(uint dimensions, double* variables, double* gradient, nint data)
    {
        NloptOptimizer? owner = null;
        try
        {
            var registration = (CallbackRegistration?)GCHandle.FromIntPtr(data).Target;
            if (registration is null || !registration.Owner.TryGetTarget(out owner))
            {
                return double.NaN;
            }

            if (owner.ShouldStop())
            {
                NativeMethods.ForceStop(owner.handle);
                return double.NaN;
            }

            var variableSpan = new ReadOnlySpan<double>(variables, checked((int)dimensions));
            var gradientSpan = gradient is null
                ? Span<double>.Empty
                : new Span<double>(gradient, checked((int)dimensions));
            return owner.callbackFunctions[registration.CallbackIndex](variableSpan, gradientSpan);
        }
        catch (Exception exception)
        {
            if (owner is not null)
            {
                try
                {
                    Interlocked.CompareExchange(
                        ref owner.callbackException,
                        ExceptionDispatchInfo.Capture(exception),
                        null);
                    NativeMethods.ForceStop(owner.handle);
                }
                catch
                {
                    // Nothing managed may escape a callback invoked by native code.
                }
            }
            return double.NaN;
        }
    }

    private bool ShouldStop() =>
        Volatile.Read(ref stopRequested) != 0 || cancellationToken.IsCancellationRequested;

    private void AddCallback(
        NloptFunction function,
        Func<nint, nint, NloptResult> configure,
        string operation)
    {
        lock (gate)
        {
            EnsureConfigurable();
            var callbackIndex = callbackFunctions.Count;
            callbackFunctions.Add(function);
            var registrationHandle = GCHandle.Alloc(
                new CallbackRegistration(new WeakReference<NloptOptimizer>(this), callbackIndex));
            try
            {
                var callback = Marshal.GetFunctionPointerForDelegate(NativeCallback);
                ThrowOnError(configure(callback, GCHandle.ToIntPtr(registrationHandle)), operation);
                callbackHandles.Add(registrationHandle);
            }
            catch
            {
                registrationHandle.Free();
                callbackFunctions.RemoveAt(callbackIndex);
                throw;
            }
        }
    }

    private void Configure(Func<NloptResult> configure, string operation)
    {
        lock (gate)
        {
            EnsureConfigurable();
            ThrowOnError(configure(), operation);
        }
    }

    private void ValidateBounds(ReadOnlySpan<double> values, string parameterName) =>
        ValidateVector(values, parameterName, value => !double.IsNaN(value));

    private void ValidateVector(ReadOnlySpan<double> values, string parameterName, Func<double, bool> predicate)
    {
        if (values.Length != Dimensions)
        {
            throw new ArgumentException($"Expected exactly {Dimensions} values.", parameterName);
        }
        foreach (var value in values)
        {
            if (!predicate(value))
            {
                throw new ArgumentOutOfRangeException(parameterName);
            }
        }
    }

    private static void ValidateNonNegativeFinite(double value, string parameterName)
    {
        if (!double.IsFinite(value) || value < 0)
        {
            throw new ArgumentOutOfRangeException(parameterName);
        }
    }

    private static void ThrowOnError(NloptResult result, string operation)
    {
        if (result < 0)
        {
            throw new NloptException(result, $"NLopt could not {operation}: {result}.");
        }
    }

    private void EnsureConfigurable()
    {
        EnsureNotDisposed();
        if (running)
        {
            throw new InvalidOperationException("A running optimizer cannot be configured.");
        }
    }

    private void EnsureNotDisposed() => ObjectDisposedException.ThrowIf(disposed, this);

    private void DisposeCore()
    {
        foreach (var callbackHandle in callbackHandles)
        {
            if (callbackHandle.IsAllocated)
            {
                callbackHandle.Free();
            }
        }
        callbackHandles.Clear();
        callbackFunctions.Clear();
        handle?.Dispose();
    }

    private sealed record CallbackRegistration(WeakReference<NloptOptimizer> Owner, int CallbackIndex);
}
