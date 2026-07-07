FMD2 - Free Manga Downloader 2  (Linux x86_64 / GTK2 build)
===========================================================

This is a self-contained application folder. To run it:

    ./fmd.sh          (or:  ./fmd  )

Everything the app ships itself is in this folder:
    fmd                 - the program
    libduktape_fmd.so   - JavaScript engine used by site modules
    lua/                - website modules + Lua runtime scripts
    languages/          - UI translations
    images/             - UI icons
    config.json         - default module/website configuration
    fmd.sh              - launcher (runs ./fmd from this folder)

On first run it creates userdata/ (settings, download list, favorites) and,
when you download manga lists, data/ - both next to the program.


Runtime dependencies (NOT bundled - install from your distro)
-------------------------------------------------------------
This is a minimal build that uses your system's shared libraries. It needs a
desktop with GTK2 plus a handful of common libraries. On Debian/Ubuntu:

    sudo apt install \
        libgtk2.0-0 liblua5.4-0 libpcre2-8-0 libssl3 libsqlite3-0 \
        libwebp7 libbrotli1 libzstd1 p7zip-full

Notes:
  * libssl3  - if your system still ships OpenSSL 1.1, install libssl1.1
               instead; the app loads whichever it finds.
  * p7zip-full provides the "7za" command used to pack downloads into .cbz/.zip
               and to extract downloaded server manga-lists. Without it,
               downloading works but archiving/those lists will not.
  * imagemagick (optional) - only needed if you enable image format conversion
               in the options.

Fedora/openSUSE/Arch have equivalent packages (gtk2, lua5.4, pcre2, openssl,
sqlite, libwebp, brotli, zstd, p7zip).


Limitations vs the Windows build
--------------------------------
  * The "all sites" combined manga list attaches the system SQLite, which
    caps simultaneously-attached databases at 10 (the Windows build ships a
    custom SQLite with a 125 limit). The feature still works, just with fewer
    sites combined at once.
