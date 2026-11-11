# Slot widget library generator

Builds the original `quickhack\hud\slot.inkwidget` library (item `Slot`: a 56-pixel canvas with an `icon` image that points at the game's quickhack atlas) and packs it into `archive/pc/mod/quickhack.archive`.

Requires .NET 10. The WolvenKit.Core package ships `libkraken.so` / `kraken.dll` next to the built exe; that is enough to write the in-widget buffers. This packer writes an uncompressed Cyberpunk 2.5 archive (no Oodle), which the game can load.

From the repo root:

```
dotnet run --project tools/quickhack-widget/quickhack-widget.csproj -- tools/quickhack-widget/slot.inkwidget archive/pc/mod/quickhack.archive
```

Copy the new `quickhack.archive` into the install zip as `archive/pc/mod/quickhack.archive`, with `bin` and `r6` at the zip root.
