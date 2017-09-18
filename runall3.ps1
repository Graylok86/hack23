function Compile-Csharp ([string] $code, $FrameworkVersion="v2.0.50727", [Array]$References)
{
    #
    # Get an instance of the CSharp code provider
    #
    $cp = new-object Microsoft.CSharp.CSharpCodeProvider

    $framework = Join-Path $env:windir "Microsoft.NET\Framework\$FrameWorkVersion"
    $refs = new-object Collections.ArrayList
    $refs.AddRange( @("${framework}\System.dll",
        "${framework}\system.windows.forms.dll",
        "${framework}\System.data.dll",
        "${framework}\System.Drawing.dll",
        "${framework}\System.Xml.dll"))
    if ($references.Count -ge 1)
    {
        $refs.AddRange($References)
    }

    $cpar = New-Object System.CodeDom.Compiler.CompilerParameters
    $cpar.GenerateInMemory = $true
    $cpar.CompilerOptions = "-unsafe"    
    $cpar.GenerateExecutable = $false
    $cpar.OutputAssembly = "custom"
    $cpar.ReferencedAssemblies.AddRange($refs)
    $cr = $cp.CompileAssemblyFromSource($cpar, $code)

    if ( $cr.Errors.Count)
    {
        $codeLines = $code.Split("`n");
        foreach ($ce in $cr.Errors)
        {
            write-host "Error: $($codeLines[$($ce.Line - 1)])"
            $ce |out-default
        }
        Throw "INVALID DATA: Errors encountered while compiling code"
    }
}

$code = @'
using System;
using System.Runtime.InteropServices;

namespace test
{
    public class Testclass
    {
        public enum Protection
        {
            PAGE_NOACCESS = 0x01,
            PAGE_READONLY = 0x02,
            PAGE_READWRITE = 0x04,
            PAGE_WRITECOPY = 0x08,
            PAGE_EXECUTE = 0x10,
            PAGE_EXECUTE_READ = 0x20,
            PAGE_EXECUTE_READWRITE = 0x40,
            PAGE_EXECUTE_WRITECOPY = 0x80,
            PAGE_GUARD = 0x100,
            PAGE_NOCACHE = 0x200,
            PAGE_WRITECOMBINE = 0x400
        }

        [DllImport("kernel32.dll")]
        static extern bool VirtualProtect(uint lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
        [DllImport("kernel32.dll")]
        public static extern uint GetModuleHandle(string lpModuleName);

        public static void Patch()
        {
            uint addr = GetModuleHandle("kernel32.dll") + 0x55FD7;
            byte[] expected = new byte[] {0x8B, 0xFF, 0x55, 0x8B, 0xEC, 0x81, 0xEC, 0x84, 0x02, 0x00, 0x00};
            unsafe
            {
                byte* mem = (byte*)addr;
                for (int i = 0; i < expected.Length; ++i)
                {
                    if (mem[i] != expected[i])
                    {
                        System.Console.WriteLine("Expected bytes not found!");
                        return;
                    }
                }

	            uint oldProtect;                
                VirtualProtect(addr, 11, (uint)Protection.PAGE_EXECUTE_WRITECOPY, out oldProtect);
                byte[] patch = new byte[] {0xB8, 0x00, 0x00, 0x00, 0x00, 0xC2, 0x0C, 0x00, 0x90, 0x90, 0x90};
                for (int i = 0; i < patch.Length; ++i) mem[i] = patch[i];
                VirtualProtect(addr, 11, oldProtect,  out oldProtect);
            }
        }
    }
}
'@

compile-CSharp $code
[Test.TestClass]::Patch()