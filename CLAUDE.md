# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Free Manga Downloader 2 (FMD2): a Lazarus / Free Pascal desktop app whose website support is
written in Lua. This checkout is a **fork of `dazedcat19/FMD2` whose purpose is a Linux
(x86_64, LCL gtk2) port**, developed on the `linux-build` branch. `master` is kept as a clean
mirror of upstream and is never committed to directly.

Upstream only ships Windows build modes; everything Linux-specific here (the `Linux64` build
mode, `patches/`, `build-dist-linux.sh`, `sync-upstream.sh`, `dist/README-linux.txt`) is this
fork's work. There is no automated test suite: verification means building and running the app.

## Building on Linux

Toolchain: apt `lazarus` (3.0, at `/usr/lib/lazarus/3.0`), `fpc` 3.2.2, `libgtk2.0-dev`,
`liblua5.4-dev`, `libpcre2-dev`, `patchelf`. Runtime: `p7zip-full` (provides `7za`, used for
CBZ/ZIP packing and extracting server manga lists), `libssl3` (libcrypto.so.3 is linked at
load time since upstream's X25519 code, so the binary won't start without it),
`libsqlite3-0`, `libwebp7`.

1. **Third-party packages live in `3rd/` (gitignored).** Clone them, then apply the fork's
   fixes from `patches/` (see `patches/README.md`):
   `git -C 3rd/<pkg> apply ../../patches/<file>.patch`. Packages: CustomControls, dcpcrypt,
   internettools (+ copy `flre`/`pucu` `.pas` into its `data/`), metadarkstyle, multilog,
   richmemo, vtv (VirtualTreeView, branch `lazarus-v5`). Synapse is **relocated into
   `baseunits/synapse` as `laz_synapse`** so the project and internettools share one copy.
2. **Use an isolated lazbuild config** (`--pcp=<dir>`) rather than `~/.lazarus`. Register every
   `.lpk` under `3rd/` with `lazbuild --pcp=<dir> --lazarusdir=/usr/lib/lazarus/3.0
   --add-package-link <lpk>`, and register `baseunits/synapse/laz_synapse.lpk` **last** so it,
   not `3rd/synapse`, owns the `laz_synapse` name. A lost link shows up as
   `Broken dependency: laz_synapse`.
3. Build (always clean, see gotcha below) and restore the rpath:
   ```sh
   lazbuild -B --pcp=<dir> --lazarusdir=/usr/lib/lazarus/3.0 --build-mode=Linux64 --widgetset=gtk2 mangadownloader/md.lpi
   patchelf --set-rpath '$ORIGIN' bin/x86_64-linux/fmd
   patchelf --print-rpath bin/x86_64-linux/fmd   # must print $ORIGIN
   ```
   Gotcha: an incremental relink can silently produce a smaller binary with an empty rpath, and
   then `libduktape_fmd.so` fails to dlopen. Lazarus mangles `$ORIGIN` in LinkerOptions, hence
   the patchelf step.
4. **Runtime assets resolve relative to the executable**, and `bin/` is gitignored, so after a
   clean checkout recreate them:
   ```sh
   cd bin/x86_64-linux && ln -sfn ../../lua lua && ln -sfn ../../languages languages \
     && ln -sfn ../../images images && ln -sfn ../../readme.rtf . && ln -sfn ../../changelog.txt . \
     && cp ../../dist/config.json .
   ```
   `libduktape_fmd.so` (Duktape 2.7.0 built with the `module-duktape`/`module-node` extras;
   Ubuntu's libduktape lacks `duk_module_duktape_init`) must also sit in `bin/x86_64-linux/`.
   It is not in the repo. `scripts/build-luapb-linux.sh` builds `pb.so` (lua-protobuf, needed
   by MangaPlus) into the same directory; FMD prepends its own directory to Lua's
   `package.cpath` on Unix, matching Windows' `!\?.dll`.
5. `./build-dist-linux.sh` stages binary + assets + launcher into `dist/FMD2-x86_64-linux/`
   and a tarball.

Other build facts:
- Editing only a `.lfm` does **not** trigger a rebuild of the unit's embedded resource. `touch`
  the matching `.pas`.
- `-dUseCThreads` must stay in the Linux64 mode and `cthreads` must remain the first unit in
  `md.lpr`, or startup fails with runtime error 232/211.
- For gdb-usable traces, temporarily set the Linux64 mode to `-O0`, VariablesInRegisters=False,
  GenerateDebugInfo=True, StripSymbols=False, UseExternalDbgSyms=False. **Do not commit these
  flags**; `git checkout mangadownloader/md.lpi` reverts them (lazbuild rewrites the Windows
  modes' flags too). `-dDEBUGINFO -gl` is what makes FMD's own crash dialog print a
  symbolicated stack.
- `baseunits/revision.inc` and the "Build Time" shown in crash reports are stale on Linux
  (the Windows release has a pre-build regen step via `git2revision.bat`). Use the binary's
  mtime to identify a build.
- Windows release: `make_release_win.bat` (builds `updaterslim` + `Win32`/`Win64` modes, packs
  with `7za`, writes `latest_version.json`). `scripts/install_submodules.bat` is upstream's
  package setup for Windows.

## Running and testing

- Writable data goes under `APPDATA_DIRECTORY` (`userdata/`, `data/`, `backup/`), which
  defaults to the exe dir. Set **`FMD_DATA_DIR`** (pointing at the *parent* of `userdata/`) to
  run an isolated instance without touching a real install. Read-only assets (`lua/`,
  `images/`, `languages/`, `config.json`, `readme.rtf`, `changelog.txt`) always come from the
  exe dir.
- `userdata/settings.json` is tolerant of partial content. Useful keys:
  `{"general":{"OneInstanceOnly":false}}` to run alongside another instance,
  `{"logger":{"Enabled":true,"LogFileName":"..."}}` for a file log (no rebuild needed).
- Headless GUI testing: `Xvfb :99 -screen 0 1600x1000x24 &`, run the sandbox copy with
  `DISPLAY=:99 FMD_DATA_DIR=<sandbox>`, screenshot with `import -window root`, drive with
  `xdotool` (VTV rows need keyboard selection; mouse clicks don't register headless). Kill only
  sandbox processes (match the exe path or `FMD_DATA_DIR` in `/proc/<pid>/environ`); the user
  may be running their own instance. Decline the "Modules update found" dialog in a sandbox
  whose `lua/` is a symlink into the repo.
- `--lua-dofile` makes FMD load Lua modules from source on every call instead of cached
  bytecode. Other flags are documented in README.md.

## Architecture

**Entry point** `mangadownloader/md.lpr` parses flags, reads a few settings, enforces single
instance via SimpleIPC, sets up MultiLog + SimpleException, then creates `TMainForm`
(`mangadownloader/forms/frmMain.pas`, the very large main UI: Downloads, Favorites, Manga
List, Manga Info, Options tabs). All other dialogs are in `mangadownloader/forms/`.

**`baseunits/`** holds everything non-UI:
- `FMDOptions.pas`: every path constant (`FMD_DIRECTORY`, `APPDATA_DIRECTORY`,
  `USERDATA_FOLDER`, `LUA_WEBSITEMODULE_FOLDER`...). `FMDVars.pas`: global singletons.
  `uBaseUnit.pas`: shared helpers (path sanitising `CorrectPathComponent`/`CustomRename`,
  AES `EncryptString`/`DecryptString` used for stored credentials).
- Threading: `BaseThread.pas` defines `TBaseThread` (every worker is `FreeOnTerminate`) and
  `WaitForThread`, the bounded, message-pumping wait that **all main-thread waits must use**
  instead of `WaitFor`.
- Managers (each owns a container list plus worker threads):
  `uDownloadsManager` (`TDownloadManager` > `TTaskContainer`/`TTaskThread` per chapter >
  `TDownloadThread` per image; also fires the completion notification and `uPacker`),
  `uFavoritesManager` (`TFavoriteTask` runs a check across `TFavoriteThread`s),
  `uUpdateThread` (manga-list refresh), `uSilentThread` (background "add to downloads /
  favorites"), `uGetMangaInfosThread`.
- Persistence: `SQLiteData.pas` is the base (commit/flush queue), with `DownloadsDB`,
  `FavoritesDB`, `DownloadedChaptersDB` in `userdata/` and `DBDataProcess.pas` for the
  per-site manga lists in `data/<site>.db` (the all-sites view ATTACHes them; the attach limit
  comes from the system SQLite).
  A download task's row is written back only when its thread ends (`TTaskThread.Destroy`),
  so a hung task still shows its add-time status in the DB; check the output folder instead.
- Lua runs on worker threads. A count hook in `LuaNewBaseState` aborts a script once its
  thread is terminated. Never raise a Lua error (`luaL_error`, a C longjmp) from a Pascal
  callback that holds a managed local; it skips the implicit finalization frame and crashes.
- Networking: **all HTTP goes through `httpsendthread.pas` `THTTPSendThread`** (Synapse +
  OpenSSL 3, proxy incl. SOCKS). `GitHubRepoV3.pas` drives the in-app Lua module updater and
  has no token support (unauthenticated 60/hr limit; "Failed to connect to GitHub API" usually
  means rate-limited).
- Output: `uPacker` (7za for cbz/zip), `Img2Pdf`, `uEpub`, `uComicInfo`; `imagemagickmanager`
  for optional conversion; `webp.pas`, `pcre2lib.pas`, `Duktape.pas` are dynamic bindings to
  system libs.

**Website modules.** `WebsiteModules.pas` defines `TModuleContainer` with `On*` callbacks
(`OnGetNameAndLink`, `OnGetInfo`, `OnGetPageNumber`, `OnDownloadImage`...) and the
`TWebsiteModules` registry. `baseunits/lua/LuaWebsiteModules.pas` scans `lua/modules/*.lua`,
runs each file's `Init()` (which calls `NewWebsiteModule()` and assigns handler *names*), and
dispatches the callbacks into Lua; the other `Lua*.pas` units expose Pascal objects to scripts
(`HTTP`, `MODULE`, `TASK`, `MANGAINFO`, `UPDATELIST`, `LINKS`/`NAMES`, XQuery, PCRE2, Duktape, crypto). Module IDs are
content hashes and identical across platforms. `docs/LUA-REFERENCE.md` is the full scripting
API guide; `lua/templates/` holds shared CMS templates (Madara, FoOlSlide, etc.),
`lua/utils/` helpers, `lua/websitebypass/` anti-bot handlers.

**Local `lua/` edits are temporary.** The in-app updater re-downloads `lua/` straight from
upstream `master` (`config.json` `[GitHub]`), so a fix under `lua/` is overwritten the next time
upstream touches that file. Send Lua fixes upstream; `sync-upstream.sh` prints the list of
local Lua changes as a reminder. The updater also saves HTTP error bodies as `.lua` files
(e.g. `429: Too Many Requests`), silently killing a site; check installs for modules whose
first bytes are a digit or `<`.

## Upstream sync

`./sync-upstream.sh` syncs the GitHub fork's master from upstream, fast-forwards local master,
and merges master into the current branch (`--fetch-only` skips the merge). It refuses to run
on master or with a dirty tree, so stash the md.lpi debug flags first. After a clean merge,
rebuild and run: a textual merge says nothing about whether upstream's changes still work with
the port.

## Conventions for the port

- **Root-cause fixes only.** No hard-coded pixel offsets or padding to compensate for a
  symptom; results must derive from real metrics (AutoSize, explicit anchors, theme colours)
  and survive theme/font/DPI changes. `baseunits/uGuiSpacing.pas` is the single spacing knob.
- **No direct toolkit calls and no new `{$IFDEF LCLgtk2}`** in FMD code. The widgetset is a
  build flag; the decision to stay on gtk2 was made deliberately, so don't propose a switch.
  Windows-only code goes under `{$IFDEF WINDOWS}` with a Unix counterpart, not a stub.
- **External processes:** never hand-quote `TProcess.Parameters` and never route a path
  through `TProcess.CommandLine`/`QuotedStr`/LCL `OpenDocument` on Unix. Pass a literal arg
  array via `uMisc.RunExternalProcess`, resolve binaries with `FindDefaultExecutablePath`.
  Avoid `poNewConsole` (Unix wraps the command in a terminal emulator).
- **GTK2 raises where Win32 returns ''**: guard every `cb.Items...[cb.ItemIndex]` with
  `ItemIndex > -1`.
- **UI from workers must be `Synchronize`d** and guarded by `isExiting`; waits on the main
  thread use `WaitForThread`.
- **C bindings must use pointer-width types** (`size_t = SizeUInt`, never `Cardinal`). A
  Linux-only crash with a corrupted-pointer signature that works under 32-bit Wine points here.
- Filesystem components are capped at 255 bytes (`CorrectPathComponent`); the Windows `\\?\`
  prefix only lifts the total-path limit and must stay Windows-only.
- Prefer `-O0` rebuilds before dismissing a gdb trace as optimiser noise; FPC does **not**
  warn on an uninitialised `Result` assigned only inside a conditional.

## Known Linux gaps

Windows-only and not ported: Win32 dark-style theming (Linux relies on the GTK2 theme), OLE
drag-drop in `frmDropTarget`, the monitor-change handler. AppImage builds run but render a
black window on hosts whose GTK2 modules pull in GTK3; the fix is to build the AppDir on a
clean minimal base.
