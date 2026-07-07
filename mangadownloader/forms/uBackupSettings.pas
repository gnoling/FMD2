unit uBackupSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes,SysUtils,FileUtil,Process;

function GetBackupTodayFileName:String;
procedure DoBackupToday;
procedure WriteBackupToFile(const AFileName:String);

var
  BackupLimit:Integer=7;

implementation

uses FMDOptions;

function GetBackupTodayFileName:String;
begin
  Result:=BACKUP_FOLDER+BACKUP_FILE_PREFIX+FormatDateTime('yyyymmdd',Now)+'.'+BACKUP_FILE_EXT;
end;

procedure DoBackupToday;
var
  bfile:String;
  blist:TStringList;
  i:Integer;
begin
  bfile:=GetBackupTodayFileName;
  if not FileExists(bfile) then
  begin
    WriteBackupToFile(bfile);
    blist:=TStringList.Create;
    try
      blist.Sorted:=False;
      FindAllFiles(blist,BACKUP_FOLDER,BACKUP_FILE_PREFIX+'*.'+BACKUP_FILE_EXT,False,faAnyFile);
      blist.Sort;
      if blist.Count>BackupLimit-1 then
        for i:=0 to blist.Count-BackupLimit do
          DeleteFile(blist[i]);
    finally
      blist.Free;
    end;
  end;
end;

function CleanPath(const s:String):String;
begin
  Result:=StringReplace(s,FMD_DIRECTORY,'',[]);
end;

procedure WriteBackupToFile(const AFileName:String);
begin
  if not DirectoryExists(BACKUP_FOLDER) then
    ForceDirectories(BACKUP_FOLDER);
  with TProcess.Create(nil) do try
    Executable:=CURRENT_ZIP_EXE;
    CurrentDirectory:=FMD_DIRECTORY;
    {$IFDEF WINDOWS}
    // Detach the child console so no window flashes. On Unix TProcess
    // implements poNewConsole by wrapping the command in a terminal emulator
    // (e.g. "xfce4-terminal -e"), which mangles the arguments and the backup
    // never runs.
    Options:=Options+[poNewConsole];
    {$ENDIF}
    ShowWindow:=swoHIDE;
    Parameters.Add('a');
    Parameters.Add(AFileName);
    Parameters.Add('-stl');
    Parameters.Add('-ssw');
    Parameters.Add(CleanPath(SETTINGS_FILE));
    Parameters.Add(CleanPath(ACCOUNTS_FILE));
    Parameters.Add(CleanPath(MODULES_FILE));
    Parameters.Add(CleanPath(LUA_REPO_FILE));
    Parameters.Add(CleanPath(LUA_REPO_WORK_FILE));
    Parameters.Add(CleanPath(DOWNLOADSDB_FILE));
    Parameters.Add(CleanPath(DOWNLOADEDCHAPTERSDB_FILE));
    Parameters.Add(CleanPath(FAVORITESDB_FILE));
    Execute;
  finally
    Free;
  end;
end;

end.

