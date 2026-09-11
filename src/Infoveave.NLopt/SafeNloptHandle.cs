using Microsoft.Win32.SafeHandles;

namespace Infoveave.NLopt;

internal sealed class SafeNloptHandle : SafeHandleZeroOrMinusOneIsInvalid
{
    private SafeNloptHandle()
        : base(true)
    {
    }

    protected override bool ReleaseHandle()
    {
        NativeMethods.Destroy(handle);
        return true;
    }
}
