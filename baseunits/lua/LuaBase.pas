unit LuaBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, {$ifdef luajit}lua{$else}{$ifdef lua54}lua54{$else}lua53{$endif}{$endif};

procedure LuaBaseRegisterBasic(const L: Plua_State); inline;
procedure LuaBaseRegisterCreateObject(const L: Plua_State); inline;
procedure LuaBaseRegisterAll(const L: Plua_State);

function LuaDoFile(const AFileName: String; const AFuncName: String = ''): Plua_State;
function LuaNewBaseState: Plua_State;
procedure LuaCallFunction(const L: Plua_State; const AFuncName: String);
function LuaGetReturnString(const ReturnCode: Integer): String;

function LuaDumpFileToStream(const AFileName: String): TMemoryStream; overload;
function LuaDumpFileToStream(const L: Plua_State; const AFileName: String): TMemoryStream; overload;
function LuaLoadFromStream(const L: Plua_State; const AStream: TMemoryStream; const AName: String): Integer; inline;
function LuaLoadFromStreamOrFile(const L: Plua_State; const AStream: TMemoryStream; const AFileName: String): Integer; inline;

procedure LuaExecute(const L: Plua_State; const AStream: TMemoryStream; const AFileName: String; const NResult: Integer = 0);

function _luawriter(L: Plua_State; const p: Pointer; sz: size_t; ud: Pointer): Integer; cdecl;

var
  AlwaysLoadLuaFromFile: Boolean = {$ifdef DEVBUILD}True{$else}False{$endif};

implementation

uses
  Math, BaseThread, FMDOptions, uBaseUnit,
  LuaPackage, LuaClass, LuaUtils,
  LuaCriticalSection, LuaMemoryStream,
  LuaBaseUnit, LuaSynaUtil,
  // -- lua object create
  LuaXQuery,
  // -- in lua 'require "name"'
  LuaFMD,
  LuaPCRE2,
  LuaDuktape,
  LuaCrypto,
  LuaFileUtil,
  LuaGZip,
  LuaStrings,
  LuaImagePuzzle,
  LuaMangaFox,
  LuaLogger,
  LuaSubprocess;

function luabase_print(L: Plua_State): Integer; cdecl;
var
  i: Integer;
  S: String;
begin
  Result := 0;
  S := '';
  for i := 1 to lua_gettop(L) do
  begin
    if i > 1 then S := S + #9;
    case lua_type(L, i) of
      LUA_TBOOLEAN: S := S + BoolToStr(lua_toboolean(L, i), 'true', 'false');
      LUA_TNIL:     S := S + 'nil';
      else          S := S + luaToString(L, i);
    end;
  end;
  SendLog(S);
end;

// Sleep in slices and stop early once the owning thread has been told to
// stop, so a module's delay loop reacts to Stop within a quarter second
// instead of finishing the whole delay first. Code running on the main
// thread (or any non-FMD thread) keeps the plain sleep.
function luabase_sleep(L: Plua_State): Integer; cdecl;
var
  ms, slice: Integer;
  t: TThread;
begin
  Result := 0;
  ms := lua_tointeger(L, 1);
  t := TThread.CurrentThread;
  if not (t is TBaseThread) then
  begin
    Sleep(ms);
    Exit;
  end;
  while (ms > 0) and (not TBaseThread(t).IsTerminated) do
  begin
    slice := Min(ms, 250);
    Sleep(slice);
    Dec(ms, slice);
  end;
end;

procedure LuaBaseRegisterBasic(const L: Plua_State);
begin
  luaPushFunctionGlobal(L, 'print', @luabase_print);
  luaPushFunctionGlobal(L, 'sleep', @luabase_sleep);
end;

procedure LuaBaseRegisterCreateObject(const L: Plua_State);
begin
  luaXQueryRegister(L);
end;

procedure LuaBaseRegisterAll(const L: Plua_State);
begin
  LuaBaseRegisterBasic(L);
  LuaBaseRegisterCreateObject(L);
  //luaClassRegisterAll(L); // empty right now

  luaBaseUnitRegister(L);
  luaSynaUtilRegister(L);
end;

function LuaDoFile(const AFileName: String; const AFuncName: String
  ): Plua_State;
var
  r: Integer;
begin
  Result := nil;
  if not FileExists(AFileName) then Exit;
  Result := luaL_newstate;
  try
    luaL_openlibs(Result);
    LuaBaseRegisterAll(Result);
    r := luaL_loadfile(Result, PAnsiChar(AFileName));
    if r <> 0 then
      raise Exception.Create('luaL_loadfile ' + LuaGetReturnString(r) + ': ' + luaToString(Result, -1));
    r := lua_pcall(Result, 0, LUA_MULTRET, 0);
    if r <> 0 then
      raise Exception.Create('lua_pcall ' + LuaGetReturnString(r) + ': ' + luaToString(Result, -1));
    if AFuncName <> '' then
      LuaCallFunction(Result, AFuncName);
  except
    on E: Exception do
      SendLogException('LuaDoFile()>', E);
  end;
end;

// Count hook, run by the VM every few hundred instructions on whichever
// thread is executing the state. Once that thread has been told to stop,
// every HTTP call already returns False at once, so a module's own retry
// loop just spins and the thread never ends (FanFox's chapterfun loop did
// exactly that, and the stopped task kept its download slot). Raising from
// here unwinds the Lua call to the lua_pcall that started it and lets the
// thread finish. It must be raised from this frame and no other: lua_error
// is a C longjmp, which would skip the implicit finalization frame of any
// Pascal function holding a managed local, so this hook keeps none.
procedure luabase_terminatehook(L: Plua_State; ar: Plua_Debug); cdecl;
var
  t: TThread;
begin
  t := TThread.CurrentThread;
  if (t is TBaseThread) and TBaseThread(t).IsTerminated then
    luaL_error(L, '%s', PAnsiChar('aborted: thread terminated'));
end;

function LuaNewBaseState: Plua_State;
begin
  Result := luaL_newstate;
  try
    luaL_openlibs(Result);
    LuaBaseRegisterAll(Result);
    LuaPackage.RegisterLoader(Result);
    {$ifndef windows}
    // Windows' default cpath starts with "!\?.dll", the program directory,
    // which is where FMD ships C modules such as pb.dll. Lua's Unix default
    // has no equivalent and only searches system paths and the current
    // directory, so put the program directory first here too.
    lua_getglobal(Result, 'package');
    lua_pushstring(Result, PAnsiChar(FMD_DIRECTORY + '?.so;'));
    lua_getfield(Result, -2, 'cpath');
    lua_concat(Result, 2);
    lua_setfield(Result, -2, 'cpath');
    lua_pop(Result, 1);
    {$endif}
    lua_sethook(Result, @luabase_terminatehook, LUA_MASKCOUNT, 1000);
  except
    on E: Exception do
      SendLogException('LuaNewBaseState()>', E);
  end;
end;

procedure LuaCallFunction(const L: Plua_State; const AFuncName: String);
var
  r: Integer;
begin
  lua_getglobal(L, PAnsiChar(AFuncName));
  if lua_isnoneornil(L, -1) then
  begin
    lua_settop(L, 1);
    raise Exception.Create('No function name ' + AnsiQuotedStr(AFuncName, '"'));
  end;
  r := lua_pcall(L, 0, LUA_MULTRET, 0);
  if r <> 0 then
    raise Exception.Create(Format('LuaCallFunction("%s") %s: %s', [AFuncName, LuaGetReturnString(r), luaToString(L, -1)]));
end;

function LuaGetReturnString(const ReturnCode: Integer): String;
begin
  case ReturnCode of
    0:             Result := 'LUA_OK';
    LUA_YIELD_:    Result := 'LUA_YIELD';
    LUA_ERRRUN:    Result := 'LUA_ERRRUN';
    LUA_ERRSYNTAX: Result := 'LUA_ERRSYNTAX';
    LUA_ERRMEM:    Result := 'LUA_ERRMEM';
    LUA_ERRERR:    Result := 'LUA_ERRERR';
    {$ifndef luajit}
    //LUA_ERRGCMM:   Result := 'LUA_ERRGCMM';
    LUA_ERRFILE:   Result := 'LUA_ERRFILE';
    {$endif}
    else
      Result := IntToStr(ReturnCode);
  end;
end;

function _luawriter(L: Plua_State; const p: Pointer; sz: size_t; ud: Pointer): Integer; cdecl;
begin
  if TMemoryStream(ud).Write(p^, sz) <> sz then
    Result := 1
  else
    Result := 0;
end;

function LuaDumpFileToStream(const AFileName: String): TMemoryStream;
var
  L: Plua_State;
begin
  if not FileExists(AFileName) then Exit;
  L := luaL_newstate;
  try
    luaL_openlibs(L);
    Result := LuaDumpFileToStream(L, AFileName);
  finally
    lua_close(L);
  end;
end;

function LuaDumpFileToStream(const L: Plua_State; const AFileName: String
  ): TMemoryStream;
var
  r: Integer;
begin
  Result := nil;
  if not FileExists(AFileName) then Exit;
  try
    r := luaL_loadfile(L, PAnsiChar(AFileName));
    if r <> 0 then
      raise Exception.Create('luaL_loadfile ' + LuaGetReturnString(r) + ': ' + luaToString(L, -1));
    // disabled strip to print line info
    Result := TMemoryStream.Create;
    r := lua_dump(L, @_luawriter, Result{$ifndef luajit}, 0{$endif});
    if r <> 0 then
    begin
      FreeAndNil(Result);
      raise Exception.Create('lua_dump ' + LuaGetReturnString(r) + ': ' + luaToString(L, -1));
    end;
  except
    on E: Exception do
      SendLogException('LuaDumpFileToStream()>', E);
  end;
end;

function LuaLoadFromStream(const L: Plua_State; const AStream: TMemoryStream;
  const AName: String): Integer;
begin
  Result := luaL_loadbuffer(L, AStream.Memory, AStream.Size, PAnsiChar(AName));
end;

function LuaLoadFromStreamOrFile(const L: Plua_State;
  const AStream: TMemoryStream; const AFileName: String): Integer;
begin
  if (not AlwaysLoadLuaFromFile) and (AStream <> nil) then
    Result := luaL_loadbuffer(L, AStream.Memory, AStream.Size, PAnsiChar(AFileName))
  else
    Result := luaL_loadfile(L, PAnsiChar(AFileName));
end;

procedure LuaExecute(const L: Plua_State; const AStream: TMemoryStream;
  const AFileName: String; const NResult: Integer);
var
  r: Integer;
begin
  r := LuaLoadFromStreamOrFile(L, AStream, AFileName);
  if r <> 0 then
    raise Exception.Create(Format('luaL_loadfile() %s: %s', [LuaGetReturnString(r), luaToString(L, -1)]));
  r := lua_pcall(L, 0, NResult, 0);
  if r <> 0 then
    raise Exception.Create(Format('lua_pcall %s: %s', [LuaGetReturnString(r), luaToString(L, -1)]));
end;

end.
