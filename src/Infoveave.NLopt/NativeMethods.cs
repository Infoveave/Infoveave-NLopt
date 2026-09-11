using System.Runtime.InteropServices;

namespace Infoveave.NLopt;

internal static unsafe class NativeMethods
{
    private const string LibraryName = "Infoveave.NLopt.Native";

    static NativeMethods()
    {
        NativeLibraryResolver.Install();
    }

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    internal delegate double NativeFunction(uint dimensions, double* variables, double* gradient, nint data);

    [DllImport(LibraryName, EntryPoint = "nlopt_create", CallingConvention = CallingConvention.Cdecl)]
    internal static extern SafeNloptHandle Create(NloptAlgorithm algorithm, uint dimensions);

    [DllImport(LibraryName, EntryPoint = "nlopt_destroy", CallingConvention = CallingConvention.Cdecl)]
    internal static extern void Destroy(nint optimizer);

    [DllImport(LibraryName, EntryPoint = "nlopt_version", CallingConvention = CallingConvention.Cdecl)]
    internal static extern void Version(out int major, out int minor, out int patch);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_lower_bounds", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetLowerBounds(SafeNloptHandle optimizer, double* bounds);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_upper_bounds", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetUpperBounds(SafeNloptHandle optimizer, double* bounds);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_min_objective", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetMinObjective(SafeNloptHandle optimizer, nint callback, nint data);

    [DllImport(LibraryName, EntryPoint = "nlopt_add_inequality_constraint", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult AddInequalityConstraint(
        SafeNloptHandle optimizer,
        nint callback,
        nint data,
        double tolerance);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_stopval", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetStopValue(SafeNloptHandle optimizer, double value);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_ftol_abs", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetFunctionToleranceAbsolute(SafeNloptHandle optimizer, double tolerance);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_ftol_rel", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetFunctionToleranceRelative(SafeNloptHandle optimizer, double tolerance);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_xtol_abs1", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetParameterToleranceAbsolute(SafeNloptHandle optimizer, double tolerance);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_xtol_rel", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetParameterToleranceRelative(SafeNloptHandle optimizer, double tolerance);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_maxeval", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetMaximumEvaluations(SafeNloptHandle optimizer, int maximumEvaluations);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_maxtime", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetMaximumTime(SafeNloptHandle optimizer, double maximumTimeSeconds);

    [DllImport(LibraryName, EntryPoint = "nlopt_set_initial_step", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult SetInitialStep(SafeNloptHandle optimizer, double* step);

    [DllImport(LibraryName, EntryPoint = "nlopt_optimize", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult Optimize(SafeNloptHandle optimizer, double* variables, double* objectiveValue);

    [DllImport(LibraryName, EntryPoint = "nlopt_force_stop", CallingConvention = CallingConvention.Cdecl)]
    internal static extern NloptResult ForceStop(SafeNloptHandle optimizer);
}
