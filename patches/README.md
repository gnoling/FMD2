# Third-party patches for the Linux build

`3rd/` is gitignored (packages are cloned there separately), so local fixes to
those packages live here as patch files. After a fresh clone of the third-party
repos into `3rd/`, apply each with:

    git -C 3rd/<package> apply ../../patches/<file>.patch

- `vtv-linux-build.patch` - VirtualTreeView: Move -> System.Move (name clash on FPC/Linux).
- `internettools-linux-build.patch` - depend on laz_synapse / use the shared synapse in baseunits/synapse.
- `synapse-linux-build.patch` - laz_synapse package tweaks for the relocated shared copy.
- `richmemo-linux-build.patch` - RichMemo build fix for Linux.
- `CustomControls-texthint-windows-only.patch` - the hand-drawn TextHint overlay
  (a Windows dark-mode workaround) double-paints over the LCL emulated hint on
  GTK2, leaving a glyph artifact in the corner of every hinted edit; make it
  Windows-only.
