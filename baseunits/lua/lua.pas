(******************************************************************************
 *                                                                            *
 *  File:        lua.pas                                                      *
 *  Authors:     TeCGraf           (C headers + actual Lua libraries)         *
 *               Lavergne Thomas   (original translation to Pascal)           *
 *               Bram Kuijvenhoven (update to Lua 5.1.1 for FreePascal)       *
 *  Description: Basic Lua library                                            *
 *                                                                            *
 ******************************************************************************)

(*
** $Id: lua.h,v 1.175 2003/03/18 12:31:39 roberto Exp $
** Lua - An Extensible Extension Language
** TeCGraf: Computer Graphics Technology Group, PUC-Rio, Brazil
** http://www.lua.org   mailto:info@lua.org
** See Copyright Notice at the end of this file
*)
(*
** Updated to Lua 5.1.1 by Bram Kuijvenhoven (bram at kuijvenhoven dot net),
**   Hexis BV (http://www.hexis.nl), the Netherlands
** Notes:
**    - Only tested with FPC (FreePascal Compiler)
**    - Using LuaBinaries styled DLL/SO names, which include version names
**    - LUA_YIELD was suffixed by '_' for avoiding name collision
*)
(*
** Translated to pascal by Lavergne Thomas
** Notes :
**    - Pointers type was prefixed with 'P'
**    - lua_upvalueindex constant was transformed to function
**    - Some compatibility function was isolated because with it you must have
**      lualib.
**    - LUA_VERSION was suffixed by '_' for avoiding name collision.
** Bug reports :
**    - thomas.lavergne@laposte.net
**   In french or in english
*)

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

unit lua;

interface

const
{$IFDEF UNIX}
  LUA_NAME = 'liblua.so.5.1';
  LUA_LIB_NAME = 'liblua.so.5.1';
{$ELSE}
  LUA_NAME = 'lua51.dll';
  LUA_LIB_NAME = 'lua51.dll';
{$ENDIF}

type
  // C size_t is pointer-width (8 bytes on 64-bit); Cardinal is always 32-bit,
  // which corrupts the stack when the C library writes an 8-byte length. See lua54.pas.
  size_t = SizeUInt;
  Psize_t = ^size_t;

const
  LUA_VERSION = 'Lua 5.1';
  LUA_RELEASE = 'Lua 5.1.1';
  LUA_VERSION_NUM = 501;
  LUA_COPYRIGHT = 'Copyright (C) 1994-2006 Lua.org, PUC-Rio';
  LUA_AUTHORS = 'R. Ierusalimschy, L. H. de Figueiredo & W. Celes';

(* option for multiple returns in `lua_pcall' and `lua_call' *)
  LUA_MULTRET = -1;

(*
** pseudo-indices
*)
  LUA_REGISTRYINDEX = -10000;
  LUA_ENVIRONINDEX  = -10001;
  LUA_GLOBALSINDEX  = -10002;

function lua_upvalueindex(I: Integer): Integer;

const
(* thread status; 0 is OK *)
  LUA_YIELD_    = 1;
  LUA_ERRRUN    = 2;
  LUA_ERRSYNTAX = 3;
  LUA_ERRMEM    = 4;
  LUA_ERRERR    = 5;

type
  Plua_State = Pointer;

  lua_CFunction = function(L: Plua_State): Integer; cdecl;

(*
** functions that read/write blocks when loading/dumping Lua chunks
*)
type
  lua_Reader = function(L: Plua_State; ud: Pointer; sz: Psize_t): PChar; cdecl;
  lua_Writer = function(L: Plua_State; const p: Pointer; sz: size_t; ud: Pointer): Integer; cdecl;

(*
** prototype for memory-allocation functions
*)
  lua_Alloc = function(ud, ptr: Pointer; osize, nsize: size_t): Pointer; cdecl;

(*
** basic types
*)
const
  LUA_TNONE          = -1;

  LUA_TNIL           = 0;
  LUA_TBOOLEAN       = 1;
  LUA_TLIGHTUSERDATA = 2;
  LUA_TNUMBER        = 3;
  LUA_TSTRING        = 4;
  LUA_TTABLE         = 5;
  LUA_TFUNCTION      = 6;
  LUA_TUSERDATA      = 7;
  LUA_TTHREAD        = 8;

(* minimum Lua stack available to a C function *)
  LUA_MINSTACK = 20;

type
(* Type of Numbers in Lua *)
  lua_Number = Double;
  lua_Integer = PtrInt;

(*
** state manipulation
*)
function lua_newstate(f: lua_Alloc; ud: Pointer): Plua_state; cdecl; external LUA_NAME;
procedure lua_close(L: Plua_State); cdecl; external LUA_NAME;
function lua_newthread(L: Plua_State): Plua_State; cdecl; external LUA_NAME;

function lua_atpanic(L: Plua_State; panicf: lua_CFunction): lua_CFunction; cdecl; external LUA_NAME;

(*
** basic stack manipulation
*)
function lua_gettop(L: Plua_State): Integer; cdecl; external LUA_NAME;
procedure lua_settop(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_pushvalue(L: Plua_State; Idx: Integer); cdecl; external LUA_NAME;
procedure lua_remove(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_insert(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_replace(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
function lua_checkstack(L: Plua_State; sz: Integer): LongBool; cdecl; external LUA_NAME;

procedure lua_xmove(from, to_: Plua_State; n: Integer); cdecl; external LUA_NAME;

(*
** access functions (stack -> C)
*)
function lua_isnumber(L: Plua_State; idx: Integer): LongBool; cdecl; external LUA_NAME;
function lua_isstring(L: Plua_State; idx: Integer): LongBool; cdecl; external LUA_NAME;
function lua_iscfunction(L: Plua_State; idx: Integer): LongBool; cdecl; external LUA_NAME;
function lua_isuserdata(L: Plua_State; idx: Integer): LongBool; cdecl; external LUA_NAME;
function lua_type(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_NAME;
function lua_typename(L: Plua_State; tp: Integer): PChar; cdecl; external LUA_NAME;

function lua_equal(L: Plua_State; idx1, idx2: Integer): LongBool; cdecl; external LUA_NAME;
function lua_rawequal(L: Plua_State; idx1, idx2: Integer): LongBool; cdecl; external LUA_NAME;
function lua_lessthan(L: Plua_State; idx1, idx2: Integer): LongBool; cdecl; external LUA_NAME;

function lua_tonumber(L: Plua_State; idx: Integer): lua_Number; cdecl; external LUA_NAME;
function lua_tointeger(L: Plua_State; idx: Integer): lua_Integer; cdecl; external LUA_NAME;
function lua_toboolean(L: Plua_State; idx: Integer): LongBool; cdecl; external LUA_NAME;
function lua_tolstring(L: Plua_State; idx: Integer; len: Psize_t): PChar; cdecl; external LUA_NAME;
function lua_objlen(L: Plua_State; idx: Integer): size_t; cdecl; external LUA_NAME;
function lua_tocfunction(L: Plua_State; idx: Integer): lua_CFunction; cdecl; external LUA_NAME;
function lua_touserdata(L: Plua_State; idx: Integer): Pointer; cdecl; external LUA_NAME;
function lua_tothread(L: Plua_State; idx: Integer): Plua_State; cdecl; external LUA_NAME;
function lua_topointer(L: Plua_State; idx: Integer): Pointer; cdecl; external LUA_NAME;

(*
** push functions (C -> stack)
*)
procedure lua_pushnil(L: Plua_State); cdecl; external LUA_NAME;
procedure lua_pushnumber(L: Plua_State; n: lua_Number); cdecl; external LUA_NAME;
procedure lua_pushinteger(L: Plua_State; n: lua_Integer); cdecl; external LUA_NAME;
procedure lua_pushlstring(L: Plua_State; const s: PChar; l_: size_t); cdecl; external LUA_NAME;
procedure lua_pushstring(L: Plua_State; const s: PChar); cdecl; external LUA_NAME;
function lua_pushvfstring(L: Plua_State; const fmt: PChar; argp: Pointer): PChar; cdecl; external LUA_NAME;
function lua_pushfstring(L: Plua_State; const fmt: PChar): PChar; cdecl; varargs; external LUA_NAME;
procedure lua_pushcclosure(L: Plua_State; fn: lua_CFunction; n: Integer); cdecl; external LUA_NAME;
procedure lua_pushboolean(L: Plua_State; b: LongBool); cdecl; external LUA_NAME;
procedure lua_pushlightuserdata(L: Plua_State; p: Pointer); cdecl; external LUA_NAME;
procedure lua_pushthread(L: Plua_State); cdecl; external LUA_NAME;

(*
** get functions (Lua -> stack)
*)
procedure lua_gettable(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_getfield(L: Plua_state; idx: Integer; k: PChar); cdecl; external LUA_NAME;
procedure lua_rawget(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_rawgeti(L: Plua_State; idx, n: Integer); cdecl; external LUA_NAME;
procedure lua_createtable(L: Plua_State; narr, nrec: Integer); cdecl; external LUA_NAME;
function lua_newuserdata(L: Plua_State; sz: size_t): Pointer; cdecl; external LUA_NAME;
function lua_getmetatable(L: Plua_State; objindex: Integer): Integer; cdecl; external LUA_NAME;
procedure lua_getfenv(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;

(*
** set functions (stack -> Lua)
*)
procedure lua_settable(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_setfield(L: Plua_State; idx: Integer; k: PChar); cdecl; external LUA_NAME;
procedure lua_rawset(L: Plua_State; idx: Integer); cdecl; external LUA_NAME;
procedure lua_rawseti(L: Plua_State; idx, n: Integer); cdecl; external LUA_NAME;
function lua_setmetatable(L: Plua_State; objindex: Integer): Integer; cdecl; external LUA_NAME;
function lua_setfenv(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_NAME;

(*
** `load' and `call' functions (load and run Lua code)
*)
procedure lua_call(L: Plua_State; nargs, nresults: Integer); cdecl; external LUA_NAME;
function lua_pcall(L: Plua_State; nargs, nresults, errf: Integer): Integer; cdecl; external LUA_NAME;
function lua_cpcall(L: Plua_State; func: lua_CFunction; ud: Pointer): Integer; cdecl; external LUA_NAME;
function lua_load(L: Plua_State; reader: lua_Reader; dt: Pointer; const chunkname: PChar): Integer; cdecl; external LUA_NAME;

function lua_dump(L: Plua_State; writer: lua_Writer; data: Pointer): Integer; cdecl; external LUA_NAME;

(*
** coroutine functions
*)
function lua_yield(L: Plua_State; nresults: Integer): Integer; cdecl; external LUA_NAME;
function lua_resume(L: Plua_State; narg: Integer): Integer; cdecl; external LUA_NAME;
function lua_status(L: Plua_State): Integer; cdecl; external LUA_NAME;

(*
** Garbage-collection functions and options
*)
const
  LUA_GCSTOP       = 0;
  LUA_GCRESTART    = 1;
  LUA_GCCOLLECT    = 2;
  LUA_GCCOUNT      = 3;
  LUA_GCCOUNTB     = 4;
  LUA_GCSTEP       = 5;
  LUA_GCSETPAUSE   = 6;
  LUA_GCSETSTEPMUL = 7;

function lua_gc(L: Plua_State; what, data: Integer): Integer; cdecl; external LUA_NAME;

(*
** miscellaneous functions
*)
function lua_error(L: Plua_State): Integer; cdecl; external LUA_NAME;

function lua_next(L: Plua_State; idx: Integer): Integer; cdecl; external LUA_NAME;

procedure lua_concat(L: Plua_State; n: Integer); cdecl; external LUA_NAME;

function lua_getallocf(L: Plua_State; ud: PPointer): lua_Alloc; cdecl; external LUA_NAME;
procedure lua_setallocf(L: Plua_State; f: lua_Alloc; ud: Pointer); cdecl; external LUA_NAME;

(*
** ===============================================================
** some useful macros
** ===============================================================
*)

procedure lua_pop(L: Plua_State; n: Integer);

procedure lua_newtable(L: Plua_state);

procedure lua_register(L: Plua_State; const n: PChar; f: lua_CFunction);
procedure lua_pushcfunction(L: Plua_State; f: lua_CFunction);

function lua_strlen(L: Plua_state; i: Integer): size_t;

function lua_isfunction(L: Plua_State; n: Integer): Boolean;
function lua_istable(L: Plua_State; n: Integer): Boolean;
function lua_islightuserdata(L: Plua_State; n: Integer): Boolean;
function lua_isnil(L: Plua_State; n: Integer): Boolean;
function lua_isboolean(L: Plua_State; n: Integer): Boolean;
function lua_isthread(L: Plua_State; n: Integer): Boolean;
function lua_isnone(L: Plua_State; n: Integer): Boolean;
function lua_isnoneornil(L: Plua_State; n: Integer): Boolean;

procedure lua_pushliteral(L: Plua_State; s: PChar);

procedure lua_setglobal(L: Plua_State; const s: PChar);
procedure lua_getglobal(L: Plua_State; const s: PChar);

function lua_tostring(L: Plua_State; i: Integer): PChar;

(*
** compatibility macros and functions
*)

procedure lua_getregistry(L: Plua_State);

function lua_getgccount(L: Plua_State): Integer;

type
  lua_Chunkreader = lua_Reader;
  lua_Chunkwriter = lua_Writer;

(*
** {======================================================================
** Debug API
** =======================================================================
*)

const
  LUA_HOOKCALL    = 0;
  LUA_HOOKRET     = 1;
  LUA_HOOKLINE    = 2;
  LUA_HOOKCOUNT   = 3;
  LUA_HOOKTAILRET = 4;

const
  LUA_MASKCALL  = 1 shl Ord(LUA_HOOKCALL);
  LUA_MASKRET   = 1 shl Ord(LUA_HOOKRET);
  LUA_MASKLINE  = 1 shl Ord(LUA_HOOKLINE);
  LUA_MASKCOUNT = 1 shl Ord(LUA_HOOKCOUNT);

const
  LUA_IDSIZE = 60;

type
  lua_Debug = record           (* activation record *)
    event: Integer;
    name: PChar;               (* (n) *)
    namewhat: PChar;           (* (n) `global', `local', `field', `method' *)
    what: PChar;               (* (S) `Lua', `C', `main', `tail'*)
    source: PChar;             (* (S) *)
    currentline: Integer;      (* (l) *)
    nups: Integer;             (* (u) number of upvalues *)
    linedefined: Integer;      (* (S) *)
    lastlinedefined: Integer;  (* (S) *)
    short_src: array[0..LUA_IDSIZE - 1] of Char; (* (S) *)
    (* private part *)
    i_ci: Integer;              (* active function *)
  end;
  Plua_Debug = ^lua_Debug;

  lua_Hook = procedure(L: Plua_State; ar: Plua_Debug); cdecl;

function lua_getstack(L: Plua_State; level: Integer; ar: Plua_Debug): Integer; cdecl;
function lua_getinfo(L: Plua_State; const what: PChar; ar: Plua_Debug): Integer; cdecl;
function lua_getlocal(L: Plua_State; const ar: Plua_Debug; n: Integer): PChar; cdecl;
function lua_setlocal(L: Plua_State; const ar: Plua_Debug; n: Integer): PChar; cdecl;
function lua_getupvalue(L: Plua_State; funcindex: Integer; n: Integer): PChar; cdecl;
function lua_setupvalue(L: Plua_State; funcindex: Integer; n: Integer): PChar; cdecl;

function lua_sethook(L: Plua_State; func: lua_Hook; mask: Integer; count: Integer): Integer; cdecl;
//function lua_gethook(L: Plua_State): lua_Hook; cdecl;
function lua_gethookmask(L: Plua_State): Integer; cdecl;
function lua_gethookcount(L: Plua_State): Integer; cdecl;

(******************************************************************************
 *                                                                            *
 *  File:        lauxlib.pas                                                  *
 *  Authors:     TeCGraf           (C headers + actual Lua libraries)         *
 *               Lavergne Thomas   (original translation to Pascal)           *
 *               Bram Kuijvenhoven (update to Lua 5.1.1 for FreePascal)       *
 *  Description: Lua auxiliary library                                        *
 *                                                                            *
 ******************************************************************************)

(*
** $Id: lauxlib.h,v 1.59 2003/03/18 12:25:32 roberto Exp $
** Auxiliary functions for building Lua libraries
** See Copyright Notice in lua.h
*)
(*
** Translated to pascal by Lavergne Thomas
** Notes :
**    - Pointers type was prefixed with 'P'
** Bug reports :
**    - thomas.lavergne@laposte.net
**   In french or in english
*)

// functions added for Pascal
procedure lua_pushstring(L: Plua_State; const s: string);

// compatibilty macros
function luaL_getn(L: Plua_State; n: Integer): Integer; // calls lua_objlen
procedure luaL_setn(L: Plua_State; t, n: Integer); // does nothing!

type
  luaL_reg = record
    name: PChar;
    func: lua_CFunction;
  end;
  PluaL_reg = ^luaL_reg;

procedure luaL_openlib(L: Plua_State; const libname: PChar; const lr: PluaL_reg; nup: Integer); cdecl;
procedure luaL_register(L: Plua_State; const libname: PChar; const lr: PluaL_reg); cdecl;
function luaL_getmetafield(L: Plua_State; obj: Integer; const e: PChar): Integer; cdecl;
function luaL_callmeta(L: Plua_State; obj: Integer; const e: PChar): Integer; cdecl;
function luaL_typerror(L: Plua_State; narg: Integer; const tname: PChar): Integer; cdecl;
function luaL_argerror(L: Plua_State; numarg: Integer; const extramsg: PChar): Integer; cdecl;
function luaL_checklstring(L: Plua_State; numArg: Integer; l_: Psize_t): PChar; cdecl;
function luaL_optlstring(L: Plua_State; numArg: Integer; const def: PChar; l_: Psize_t): PChar; cdecl;
function luaL_checknumber(L: Plua_State; numArg: Integer): lua_Number; cdecl;
function luaL_optnumber(L: Plua_State; nArg: Integer; def: lua_Number): lua_Number; cdecl;
function luaL_checkinteger(L: Plua_State; numArg: Integer): lua_Integer; cdecl;
function luaL_optinteger(L: Plua_State; nArg: Integer; def: lua_Integer): lua_Integer; cdecl;

procedure luaL_checkstack(L: Plua_State; sz: Integer; const msg: PChar); cdecl;
procedure luaL_checktype(L: Plua_State; narg, t: Integer); cdecl;
procedure luaL_checkany(L: Plua_State; narg: Integer); cdecl;

function luaL_newmetatable(L: Plua_State; const tname: PChar): Integer; cdecl;
function luaL_checkudata(L: Plua_State; ud: Integer; const tname: PChar): Pointer; cdecl;

procedure luaL_where(L: Plua_State; lvl: Integer); cdecl;
function luaL_error(L: Plua_State; const fmt: PChar; args: array of const): Integer; cdecl; external LUA_LIB_NAME; // note: C's ... to array of const conversion is not portable to Delphi

function luaL_checkoption(L: Plua_State; narg: Integer; def: PChar; lst: PPChar): Integer; cdecl;

function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl;
procedure luaL_unref(L: Plua_State; t, ref: Integer); cdecl;

function luaL_loadfile(L: Plua_State; const filename: PChar): Integer; cdecl;
function luaL_loadbuffer(L: Plua_State; const buff: PChar; size: size_t; const name: PChar): Integer; cdecl;
function luaL_loadstring(L: Plua_State; const s: PChar): Integer; cdecl;

function luaL_newstate: Plua_State; cdecl;
function lua_open: Plua_State; // compatibility; moved from unit lua to lauxlib because it needs luaL_newstate

function luaL_gsub(L: Plua_State; const s, p, r: PChar): PChar; cdecl;
function luaL_findtable(L: Plua_State; idx: Integer; const fname: PChar; szhint: Integer): PChar; cdecl;

(*
** ===============================================================
** some useful macros
** ===============================================================
*)

procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PChar);
function luaL_checkstring(L: Plua_State; n: Integer): PChar;
function luaL_optstring(L: Plua_State; n: Integer; d: PChar): PChar;
function luaL_checkint(L: Plua_State; n: Integer): Integer;
function luaL_checklong(L: Plua_State; n: Integer): LongInt;
function luaL_optint(L: Plua_State; n: Integer; d: Double): Integer;
function luaL_optlong(L: Plua_State; n: Integer; d: Double): LongInt;

function luaL_typename(L: Plua_State; i: Integer): PChar;

function lua_dofile(L: Plua_State; const filename: PChar): Integer;
function lua_dostring(L: Plua_State; const str: PChar): Integer;

procedure lua_Lgetmetatable(L: Plua_State; tname: PChar);

// not translated:
// #define luaL_opt(L,f,n,d)	(lua_isnoneornil(L,(n)) ? (d) : f(L,(n)))


(*
** =======================================================
** Generic Buffer manipulation
** =======================================================
*)

const
  // note: this is just arbitrary, as it related to the BUFSIZ defined in stdio.h ...
  LUAL_BUFFERSIZE = 4096;

type
  luaL_Buffer = record
    p: PChar;       (* current position in buffer *)
    lvl: Integer;   (* number of strings in the stack (level) *)
    L: Plua_State;
    buffer: array [0..LUAL_BUFFERSIZE - 1] of Char; // warning: see note above about LUAL_BUFFERSIZE
  end;
  PluaL_Buffer = ^luaL_Buffer;

procedure luaL_addchar(B: PluaL_Buffer; c: Char); // warning: see note above about LUAL_BUFFERSIZE

(* compatibility only (alias for luaL_addchar) *)
procedure luaL_putchar(B: PluaL_Buffer; c: Char); // warning: see note above about LUAL_BUFFERSIZE

procedure luaL_addsize(B: PluaL_Buffer; n: Integer);

procedure luaL_buffinit(L: Plua_State; B: PluaL_Buffer); cdecl;
function luaL_prepbuffer(B: PluaL_Buffer): PChar; cdecl;
procedure luaL_addlstring(B: PluaL_Buffer; const s: PChar; l: size_t); cdecl;
procedure luaL_addstring(B: PluaL_Buffer; const s: PChar); cdecl;
procedure luaL_addvalue(B: PluaL_Buffer); cdecl;
procedure luaL_pushresult(B: PluaL_Buffer); cdecl;


(* compatibility with ref system *)

(* pre-defined references *)
const
  LUA_NOREF  = -2;
  LUA_REFNIL = -1;

procedure lua_unref(L: Plua_State; ref: Integer);
procedure lua_getref(L: Plua_State; ref: Integer);

(*
** Compatibility macros and functions
*)

function luaL_check_lstr(L: Plua_State; numArg: Integer; len: Psize_t): PChar;
function luaL_opt_lstr(L: Plua_State; numArg: Integer; const def: PChar; len: Psize_t): PChar;
function luaL_check_number(L: Plua_State; numArg: Integer): lua_Number;
function luaL_opt_number(L: Plua_State; nArg: Integer; def: lua_Number): lua_Number;
procedure luaL_arg_check(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PChar);
function luaL_check_string(L: Plua_State; n: Integer): PChar;
function luaL_opt_string(L: Plua_State; n: Integer; d: PChar): PChar;
function luaL_check_int(L: Plua_State; n: Integer): Integer;
function luaL_check_long(L: Plua_State; n: Integer): LongInt;
function luaL_opt_int(L: Plua_State; n: Integer; d: Double): Integer;
function luaL_opt_long(L: Plua_State; n: Integer; d: Double): LongInt;

(******************************************************************************
 *                                                                            *
 *  File:        lualib.pas                                                   *
 *  Authors:     TeCGraf           (C headers + actual Lua libraries)         *
 *               Lavergne Thomas   (original translation to Pascal)           *
 *               Bram Kuijvenhoven (update to Lua 5.1.1 for FreePascal)       *
 *  Description: Standard Lua libraries                                       *
 *                                                                            *
 ******************************************************************************)

(*
** $Id: lualib.h,v 1.28 2003/03/18 12:24:26 roberto Exp $
** Lua standard libraries
** See Copyright Notice in lua.h
*)
(*
** Translated to pascal by Lavergne Thomas
** Bug reports :
**    - thomas.lavergne@laposte.net
**   In french or in english
*)

const
  LUA_COLIBNAME = 'coroutine';
  LUA_TABLIBNAME = 'table';
  LUA_IOLIBNAME = 'io';
  LUA_OSLIBNAME = 'os';
  LUA_STRLINAME = 'string';
  LUA_MATHLIBNAME = 'math';
  LUA_DBLIBNAME = 'debug';
  LUA_LOADLIBNAME = 'package';

function luaopen_base(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;
function luaopen_table(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;
function luaopen_io(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;
function luaopen_string(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;
function luaopen_math(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;
function luaopen_debug(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;
function luaopen_package(L: Plua_State): LongBool; cdecl; external LUA_LIB_NAME;

(* open all previous libraries *)
procedure luaL_openlibs(L: Plua_State); cdecl; external LUA_LIB_NAME;

(* compatibility code *)

function lua_baselibopen(L: Plua_State): LongBool;
function lua_tablibopen(L: Plua_State): LongBool;
function lua_iolibopen(L: Plua_State): LongBool;
function lua_strlibopen(L: Plua_State): LongBool;
function lua_mathlibopen(L: Plua_State): LongBool;
function lua_dblibopen(L: Plua_State): LongBool;

implementation

function lua_upvalueindex(I: Integer): Integer;
begin
  Result := LUA_GLOBALSINDEX - i;
end;

procedure lua_pop(L: Plua_State; n: Integer);
begin
  lua_settop(L, -n - 1);
end;

procedure lua_newtable(L: Plua_State);
begin
  lua_createtable(L, 0, 0);
end;

procedure lua_register(L: Plua_State; const n: PChar; f: lua_CFunction);
begin
  lua_pushcfunction(L, f);
  lua_setglobal(L, n);
end;

procedure lua_pushcfunction(L: Plua_State; f: lua_CFunction);
begin
  lua_pushcclosure(L, f, 0);
end;

function lua_strlen(L: Plua_State; i: Integer): size_t;
begin
  Result := lua_objlen(L, i);
end;

function lua_isfunction(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TFUNCTION;
end;

function lua_istable(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TTABLE;
end;

function lua_islightuserdata(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TLIGHTUSERDATA;
end;

function lua_isnil(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TNIL;
end;

function lua_isboolean(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TBOOLEAN;
end;

function lua_isthread(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TTHREAD;
end;

function lua_isnone(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) = LUA_TNONE;
end;

function lua_isnoneornil(L: Plua_State; n: Integer): Boolean;
begin
  Result := lua_type(L, n) <= 0;
end;

procedure lua_pushliteral(L: Plua_State; s: PChar);
begin
  lua_pushlstring(L, s, Length(s));
end;

procedure lua_setglobal(L: Plua_State; const s: PChar);
begin
  lua_setfield(L, LUA_GLOBALSINDEX, s);
end;

procedure lua_getglobal(L: Plua_State; const s: PChar);
begin
  lua_getfield(L, LUA_GLOBALSINDEX, s);
end;

function lua_tostring(L: Plua_State; i: Integer): PChar;
begin
  Result := lua_tolstring(L, i, nil);
end;


procedure lua_getregistry(L: Plua_State);
begin
  lua_pushvalue(L, LUA_REGISTRYINDEX);
end;

function lua_getgccount(L: Plua_State): Integer;
begin
  Result := lua_gc(L, LUA_GCCOUNT, 0);
end;

(*
** {======================================================================
** Debug API
** =======================================================================
*)

function lua_getstack(L: Plua_State; level: Integer; ar: Plua_Debug): Integer; cdecl; external LUA_NAME;
function lua_getinfo(L: Plua_State; const what: PChar; ar: Plua_Debug): Integer; cdecl; external LUA_NAME;
function lua_getlocal(L: Plua_State; const ar: Plua_Debug; n: Integer): PChar; cdecl; external LUA_NAME;
function lua_setlocal(L: Plua_State; const ar: Plua_Debug; n: Integer): PChar; cdecl; external LUA_NAME;
function lua_getupvalue(L: Plua_State; funcindex: Integer; n: Integer): PChar; cdecl; external LUA_NAME;
function lua_setupvalue(L: Plua_State; funcindex: Integer; n: Integer): PChar; cdecl; external LUA_NAME;
function lua_sethook(L: Plua_State; func: lua_Hook; mask: Integer; count: Integer): Integer; cdecl; external LUA_NAME;
//function lua_gethook(L: Plua_State): lua_Hook; cdecl; external LUA_NAME;
function lua_gethookmask(L: Plua_State): Integer; cdecl; external LUA_NAME;
function lua_gethookcount(L: Plua_State): Integer; cdecl; external LUA_NAME;

procedure lua_pushstring(L: Plua_State; const s: string);
begin
  lua_pushlstring(L, PChar(s), Length(s));
end;

function luaL_getn(L: Plua_State; n: Integer): Integer;
begin
  Result := lua_objlen(L, n);
end;

procedure luaL_setn(L: Plua_State; t, n: Integer);
begin
  // does nothing as this operation is deprecated
end;

procedure luaL_openlib(L: Plua_State; const libname: PChar; const lr: PluaL_reg; nup: Integer); cdecl; external LUA_LIB_NAME;
procedure luaL_register(L: Plua_State; const libname: PChar; const lr: PluaL_reg); cdecl; external LUA_LIB_NAME;
function luaL_getmetafield(L: Plua_State; obj: Integer; const e: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_callmeta(L: Plua_State; obj: Integer; const e: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_typerror(L: Plua_State; narg: Integer; const tname: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_argerror(L: Plua_State; numarg: Integer; const extramsg: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_checklstring(L: Plua_State; numArg: Integer; l_: Psize_t): PChar; cdecl; external LUA_LIB_NAME;
function luaL_optlstring(L: Plua_State; numArg: Integer; const def: PChar; l_: Psize_t): PChar; cdecl; external LUA_LIB_NAME;
function luaL_checknumber(L: Plua_State; numArg: Integer): lua_Number; cdecl; external LUA_LIB_NAME;
function luaL_optnumber(L: Plua_State; nArg: Integer; def: lua_Number): lua_Number; cdecl; external LUA_LIB_NAME;
function luaL_checkinteger(L: Plua_State; numArg: Integer): lua_Integer; cdecl; external LUA_LIB_NAME;
function luaL_optinteger(L: Plua_State; nArg: Integer; def: lua_Integer): lua_Integer; cdecl; external LUA_LIB_NAME;

procedure luaL_checkstack(L: Plua_State; sz: Integer; const msg: PChar); cdecl; external LUA_LIB_NAME;
procedure luaL_checktype(L: Plua_State; narg, t: Integer); cdecl; external LUA_LIB_NAME;
procedure luaL_checkany(L: Plua_State; narg: Integer); cdecl; external LUA_LIB_NAME;

function luaL_newmetatable(L: Plua_State; const tname: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_checkudata(L: Plua_State; ud: Integer; const tname: PChar): Pointer; cdecl; external LUA_LIB_NAME;

procedure luaL_where(L: Plua_State; lvl: Integer); cdecl; external LUA_LIB_NAME;
// function luaL_error(L: Plua_State; const fmt: PChar; args: array of const): Integer; cdecl; external LUA_LIB_NAME;

function luaL_checkoption(L: Plua_State; narg: Integer; def: PChar; lst: PPChar): Integer; cdecl; external LUA_LIB_NAME;

function luaL_ref(L: Plua_State; t: Integer): Integer; cdecl; external LUA_LIB_NAME;
procedure luaL_unref(L: Plua_State; t, ref: Integer); cdecl; external LUA_LIB_NAME;

function luaL_loadfile(L: Plua_State; const filename: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_loadbuffer(L: Plua_State; const buff: PChar; size: size_t; const name: PChar): Integer; cdecl; external LUA_LIB_NAME;
function luaL_loadstring(L: Plua_State; const s: PChar): Integer; cdecl; external LUA_LIB_NAME;

function luaL_newstate: Plua_State; cdecl; external LUA_LIB_NAME;

function lua_open: Plua_State;
begin
  Result := luaL_newstate;
end;

function luaL_gsub(L: Plua_State; const s, p, r: PChar): PChar; cdecl; external LUA_LIB_NAME;
function luaL_findtable(L: Plua_State; idx: Integer; const fname: PChar; szhint: Integer): PChar; cdecl; external LUA_LIB_NAME;

function luaL_typename(L: Plua_State; i: Integer): PChar;
begin
  Result := lua_typename(L, lua_type(L, i));
end;

function lua_dofile(L: Plua_State; const filename: PChar): Integer;
begin
  Result := luaL_loadfile(L, filename);
  if Result = 0 then
    Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;

function lua_dostring(L: Plua_State; const str: PChar): Integer;
begin
  Result := luaL_loadstring(L, str);
  if Result = 0 then
    Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;

procedure lua_Lgetmetatable(L: Plua_State; tname: PChar);
begin
  lua_getfield(L, LUA_REGISTRYINDEX, tname);
end;

procedure luaL_argcheck(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PChar);
begin
  if not cond then
    luaL_argerror(L, numarg, extramsg)
end;

function luaL_checkstring(L: Plua_State; n: Integer): PChar;
begin
  Result := luaL_checklstring(L, n, nil)
end;

function luaL_optstring(L: Plua_State; n: Integer; d: PChar): PChar;
begin
  Result := luaL_optlstring(L, n, d, nil)
end;

function luaL_checkint(L: Plua_State; n: Integer): Integer;
begin
  Result := Integer(Trunc(luaL_checknumber(L, n)))
end;

function luaL_checklong(L: Plua_State; n: Integer): LongInt;
begin
  Result := LongInt(Trunc(luaL_checknumber(L, n)))
end;

function luaL_optint(L: Plua_State; n: Integer; d: Double): Integer;
begin
  Result := Integer(Trunc(luaL_optnumber(L, n, d)))
end;

function luaL_optlong(L: Plua_State; n: Integer; d: Double): LongInt;
begin
  Result := LongInt(Trunc(luaL_optnumber(L, n, d)))
end;

procedure luaL_addchar(B: PluaL_Buffer; c: Char);
begin
  if Cardinal(@(B^.p)) < (Cardinal(@(B^.buffer[0])) + LUAL_BUFFERSIZE) then
    luaL_prepbuffer(B);
  B^.p[1] := c;
  B^.p := B^.p + 1;
end;

procedure luaL_putchar(B: PluaL_Buffer; c: Char);
begin
  luaL_addchar(B, c);
end;

procedure luaL_addsize(B: PluaL_Buffer; n: Integer);
begin
  B^.p := B^.p + n;
end;

procedure luaL_buffinit(L: Plua_State ; B: PluaL_Buffer); cdecl; external LUA_LIB_NAME;
function luaL_prepbuffer(B: PluaL_Buffer): PChar; cdecl; external LUA_LIB_NAME;
procedure luaL_addlstring(B: PluaL_Buffer; const s: PChar; l: size_t); cdecl; external LUA_LIB_NAME;
procedure luaL_addstring(B: PluaL_Buffer; const s: PChar); cdecl; external LUA_LIB_NAME;
procedure luaL_addvalue(B: PluaL_Buffer); cdecl; external LUA_LIB_NAME;
procedure luaL_pushresult(B: PluaL_Buffer); cdecl; external LUA_LIB_NAME;

procedure lua_unref(L: Plua_State; ref: Integer);
begin
  luaL_unref(L, LUA_REGISTRYINDEX, ref);
end;

procedure lua_getref(L: Plua_State; ref: Integer);
begin
  lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
end;

function luaL_check_lstr(L: Plua_State; numArg: Integer; len: Psize_t): PChar;
begin
  Result := luaL_checklstring(L, numArg, len);
end;

function luaL_opt_lstr(L: Plua_State; numArg: Integer; const def: PChar; len: Psize_t): PChar;
begin
  Result := luaL_optlstring(L, numArg, def, len);
end;

function luaL_check_number(L: Plua_State; numArg: Integer): lua_Number;
begin
  Result := luaL_checknumber(L, numArg);
end;

function luaL_opt_number(L: Plua_State; nArg: Integer; def: lua_Number): lua_Number;
begin
  Result := luaL_optnumber(L, nArg, def);
end;

procedure luaL_arg_check(L: Plua_State; cond: Boolean; numarg: Integer; extramsg: PChar);
begin
  luaL_argcheck(L, cond, numarg, extramsg);
end;

function luaL_check_string(L: Plua_State; n: Integer): PChar;
begin
  Result := luaL_checkstring(L, n);
end;

function luaL_opt_string(L: Plua_State; n: Integer; d: PChar): PChar;
begin
  Result := luaL_optstring(L, n, d);
end;

function luaL_check_int(L: Plua_State; n: Integer): Integer;
begin
  Result := luaL_checkint(L, n);
end;

function luaL_check_long(L: Plua_State; n: Integer): LongInt;
begin
  Result := luaL_checklong(L, n);
end;

function luaL_opt_int(L: Plua_State; n: Integer; d: Double): Integer;
begin
  Result := luaL_optint(L, n, d);
end;

function luaL_opt_long(L: Plua_State; n: Integer; d: Double): LongInt;
begin
  Result := luaL_optlong(L, n, d);
end;

function lua_baselibopen(L: Plua_State): LongBool;
begin
  Result := luaopen_base(L);
end;

function lua_tablibopen(L: Plua_State): LongBool;
begin
  Result := luaopen_table(L);
end;

function lua_iolibopen(L: Plua_State): LongBool;
begin
  Result := luaopen_io(L);
end;

function lua_strlibopen(L: Plua_State): LongBool;
begin
  Result := luaopen_string(L);
end;

function lua_mathlibopen(L: Plua_State): LongBool;
begin
  Result := luaopen_math(L);
end;

function lua_dblibopen(L: Plua_State): LongBool;
begin
  Result := luaopen_debug(L);
end;

(******************************************************************************
* Copyright (C) 1994-2003 Tecgraf, PUC-Rio.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************)
end.
