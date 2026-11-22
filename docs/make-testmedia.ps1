$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\testmedia" | Out-Null
# Generated PCM fixtures only. No copyrighted songs, codecs, libraries or downloads.
Add-Type @'
using System;
using System.IO;
public static class WmpTestMedia {
    public static void Wave(string path, int seconds, int frequency) {
        const int rate = 8000;
        int count = rate * seconds;
        using (var writer = new BinaryWriter(File.Create(path))) {
            writer.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            writer.Write(36 + count * 2);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt "));
            writer.Write(16); writer.Write((short)1); writer.Write((short)1);
            writer.Write(rate); writer.Write(rate * 2); writer.Write((short)2); writer.Write((short)16);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("data")); writer.Write(count * 2);
            for (int i = 0; i < count; i++) {
                double t = (double)i / rate;
                double envelope = Math.Min(1, Math.Min(t * 4, (seconds - t) * 4));
                double sample = .06 * Math.Sin(2 * Math.PI * frequency * t)
                    + .03 * Math.Sin(2 * Math.PI * frequency * 2 * t)
                    + .02 * Math.Sin(2 * Math.PI * (frequency / 2) * t);
                writer.Write((short)(sample * envelope * short.MaxValue));
            }
        }
    }
}
'@
[WmpTestMedia]::Wave("$PSScriptRoot\testmedia\01 Test Artist - Morning.wav", 36, 220)
[WmpTestMedia]::Wave("$PSScriptRoot\testmedia\02 Test Artist - A deliberately long track title for narrow playlist truncation.wav", 40, 294)
[WmpTestMedia]::Wave("$PSScriptRoot\testmedia\03 Test Artist - Afternoon.wav", 44, 330)
[WmpTestMedia]::Wave("$PSScriptRoot\testmedia\04 Test Artist - Evening.wav", 48, 392)
[IO.File]::WriteAllBytes("$PSScriptRoot\testmedia\Invalid media.wav", [Text.Encoding]::ASCII.GetBytes('Not a RIFF file; intentional decode-error fixture.'))
Get-ChildItem "$PSScriptRoot\testmedia" | Select-Object Name,Length
