{
        License: GPLv2
        This unit is a part of Free Manga Downloader
}

unit DBDataProcess;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LazFileUtils, FMDOptions, MultiLog, sqlite3conn,
  sqlite3backup, sqlite3dyn, sqldb, DB, RegExpr, SQLiteData;

type
  TFieldValuePair = record
    Field: String;
    Value: String;
  end;

  TRowMapEntry = record
    RowID: Int64;
    SiteIndex: Integer; // -1 = main DB (FModule), else index into FAttachedSites
  end;

  { TDBDataProcess }

  TDBDataProcess = class(TObject)
  private
    FGuardian: TRTLCriticalSection;
    FConn: TSQLite3ConnectionH;
    FTrans: TSQLTransaction;
    FQuery: TSQLQuery;
    FRegxp: TRegExpr;
    FModule: Pointer;
    FWebsite: String;
    FTableName: String;
    FRecordCount: Integer;
    FFiltered: Boolean;
    FFilterAllSites: Boolean;
    FFilterApplied: Boolean;
    FAllSitesAttached: Boolean;
    FSitesList: TStringList;
    FAttachedSites: TStringList;
    FSQLSelect: String;
    FFilterSQL: String;
    FLinks: TStringList;
    FRecNo: Integer;
    // Fast random-access path: instead of buffering every row in FQuery
    // (TBufDataset accumulates a blob buffer per memo field per row -> O(n^2)
    // as you scroll a large list), keep an ordered array of (site,rowid)
    // entries and fetch only the visible rows on demand via prepared stmts.
    // Covers both the plain single-site view (SiteIndex always -1) and the
    // all-sites filtered view (one fetch stmt per attached schema).
    FRowMap: array of TRowMapEntry;
    FRowMapSQL: String;
    FRowMapValid: Boolean;
    FRowStmts: array of Psqlite3_stmt; // index = SiteIndex+1, prepared lazily
    FRowStmtCur: Psqlite3_stmt;        // stmt holding the currently cached row
    FRowStmtIndex: Integer;
    FRowStmtHasRow: Boolean;
    function GetLinkCount: Integer;
    procedure ResetRecNo(Dataset: TDataSet);
    function EnsureRowMap: Boolean;
    function RowMapFetch(const AIndex: Integer): Boolean;
    procedure InvalidateRowMap;
  protected
    procedure CreateTable;
    procedure CreateField(const FieldName: String);
    procedure CheckFieldsExist(const ATableName: String);
    procedure ConvertNewTable(const TableParams: String);
    procedure VacuumTable;
    procedure GetRecordCount;
    procedure AddSQLCond(const sqltext: String; useOR: Boolean = False);
    procedure AddSQLSimpleFilter(const fieldname, Value: String;
      useNOT: Boolean = False; useOR: Boolean = False; useRegexp: Boolean = False);
    procedure AddSQLPairedFilter(const Pairs: array of TFieldValuePair;
      useNOT: Boolean = False; useOR: Boolean = False; useRegexp: Boolean = False);
    function GetConnected: Boolean;
    function InternalOpen(const FilePath: String = ''): Boolean;
    function GetWebsiteName(const RecIndex: Integer): String;
    function GetValue(const RecIndex, FieldIndex: Integer): String;
    function GetValueInt(const RecIndex, FieldIndex: Integer): Integer;
    procedure AttachAllSites;
    procedure DetachAllSites;
    function ExecuteDirect(SQL: String): Boolean;
    function CheckWebsiteAndFilePath(const AWebsite: String; var AFilePath: String): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Lock; inline;
    procedure Unlock; inline;

    function Connect(const AWebsite: String): Boolean;
    function ConnectFile(const AFile: String): Boolean;
    function Open(const AWebsite: String = ''): Boolean;
    function OpenTable(const ATableName: String = '';
      CheckRecordCount: Boolean = False): Boolean;
    function TableExist(const ATableName: String): Boolean;
    function RegexEscapeInput(const Input: String): String;
    function RegexEscapeAltTitles(const ATitle: String): String;
    function Search(ATitle: String): Boolean;
    function CanFilter(const checkedGenres, uncheckedGenres: TStringList;
      const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
      const {%H-}minusDay: Integer;
      const haveAllChecked, searchNewManga: Boolean): Boolean;
    function Filter(const checkedGenres, uncheckedGenres: TStringList;
      const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
      const minusDay: Integer; const haveAllChecked, searchNewManga: Boolean;
      const useRegExpr: Boolean = False): Boolean;
    function WebsiteLoaded(const AWebsite: String): Boolean;
    function LinkExist(const ALink: String): Boolean;

    procedure InitLocateLink;
    procedure DoneLocateLink;
    procedure CreateDatabase(const AWebsite: String = '');
    procedure GetFieldNames(const List: TStringList);
    procedure Close;
    procedure CloseTable;
    procedure Save;
    procedure Backup(const AWebsite: String);
    procedure Refresh(RecheckDataCount: Boolean = False);
    function AddData(Const Title, AltTitles, Link, Authors, Artists, Genres, Status, Summary: String;
      NumChapter, JDN: Integer): Boolean; overload;
    function AddData(Const Title, AltTitles, Link, Authors, Artists, Genres, Status, Summary: String;
      NumChapter: Integer; JDN: TDateTime): Boolean; overload; inline;
    function UpdateData(Const Title, AltTitles, Link, Authors, Artists, Genres, Status, Summary: String;
      NumChapter: Integer; AWebsite: String = ''): Boolean;
    function DeleteData(const RecIndex: Integer): Boolean;
    procedure Commit;
    procedure Rollback;
    procedure RemoveFilter;
    procedure Sort;

    function GetModule(const RecIndex: Integer): Pointer;
    function GoToRecNo(const ARecIndex: Integer): Boolean;

    property Module: Pointer read FModule;
    property Website: String read FWebsite write FWebsite;
    property TableName: String read FTableName write FTableName;
    property Connected: Boolean read GetConnected;
    property RecordCount: Integer read FRecordCount;
    property Filtered: Boolean read FFiltered;
    property FilterAllSites: Boolean read FFilterAllSites write FFilterAllSites;
    property SitesList: TStringList read FSitesList write FSitesList;
    property WebsiteName[const RecIndex: Integer]: String read GetWebsiteName;
    property Value[const RecIndex, FieldIndex: Integer]: String read GetValue; default;
    property ValueInt[const RecIndex, FieldIndex: Integer]: Integer read GetValueInt;
    property LinkCount: Integer read GetLinkCount;
    property Connection: TSQLite3ConnectionH read FConn;
    property Transaction: TSQLTransaction read FTrans;
    property Table: TSQLQuery read FQuery;
  end;

const
  DBDataProcessParam = '"link","title","alttitles","authors","artists","genres","status","summary","numchapter","jdn"';
  DBDataProcessParamInsert = ':link,:title,:alttitles,:authors,:artists,:genres,:status,:summary,:numchapter,:jdn';
  DBDataProcessParams: array [0..9] of ShortString =
    ('link', 'title', 'alttitles', 'authors', 'artists', 'genres', 'status',
    'summary', 'numchapter', 'jdn');
  DBTempFieldWebsiteIndex = Length(DBDataProcessParams);
  DBDataProccesCreateParam =
    '"link" TEXT NOT NULL PRIMARY KEY,' +
    '"title" TEXT,' +
    '"alttitles" TEXT,' +
    '"authors" TEXT,' +
    '"artists" TEXT,' +
    '"genres" TEXT,' +
    '"status" TEXT,' +
    '"summary" TEXT,' +
    '"numchapter" INTEGER,' +
    '"jdn" INTEGER';

function DBDataFilePath(const AModuleID: String): String;
function DBDataFileExist(const AModuleID: String): Boolean;
procedure CopyDBDataProcess(const AWebsite, NWebsite: String);
function DeleteDBDataProcess(const AWebsite: String): Boolean;
procedure OverwriteDBDataProcess(const AWebsite, NWebsite: String);

implementation

uses
  uBaseUnit, WebsiteModules;

function NaturalCompareCallback({%H-}user: pointer; len1: longint;
  data1: pointer; len2: longint; data2: pointer): longint; cdecl;
var
  s1, s2: String;
begin
  SetString(s1, data1, len1);
  SetString(s2, data2, len2);
  Result := NaturalCompareStr(s1, s2);
end;

procedure RegexCallback(context: PSqlite3_Context; argc: longint;
  argv: PPSqlite3_Value); cdecl;
var
  regexp, Text: PChar;
  regex: TRegExpr;
begin
  if sqlite3_user_data(context) = nil then
  begin
    sqlite3_result_int64(context, 0);
    Exit;
  end;

  if argc <> 2 then
  begin
    sqlite3_result_int64(context, 0);
    Exit;
  end;

  regexp := sqlite3_value_text(argv[0]);
  Text := sqlite3_value_text(argv[1]);

  if (regexp = nil) or (Text = nil) then
  begin
    sqlite3_result_int64(context, 0);
    Exit;
  end;

  try
    regex := TRegExpr(sqlite3_user_data(context));
    regex.Expression := regexp;
    sqlite3_result_int64(context, int64(regex.Exec(Text)));
  except
    sqlite3_result_int64(context, 0);
  end;
end;

function QuotedLike(const S: String): String;
begin
  Result := QuotedStr('%' + S + '%');
end;

function DBDataFilePath(const AModuleID: String): String;
begin
  Result := DATA_FOLDER + AModuleID + DBDATA_EXT;
end;

function DBDataFileExist(const AModuleID: String): Boolean;
begin
  Result := FileExists(DATA_FOLDER + AModuleID + DBDATA_EXT);
end;

procedure CopyDBDataProcess(const AWebsite, NWebsite: String);
begin
  if NWebsite = '' then
  begin
    Exit;
  end;

  if DBDataFileExist(AWebsite) then
  begin
    try
      CopyFile(DATA_FOLDER + AWebsite + DBDATA_EXT,
        DATA_FOLDER + NWebsite + DBDATA_EXT,
        [cffPreserveTime, cffOverwriteFile], True);
    except
      on E: Exception do
        SendLogException('CopyDBDataProcess.Error!', E);
    end;
  end;
end;

function DeleteDBDataProcess(const AWebsite: String): Boolean;
var
  tryc: Integer;
begin
  Result := not FileExists(DATA_FOLDER + AWebsite + DBDATA_EXT);

  if Result = False then
  begin
    tryc := 0;
    while not DeleteFile(DATA_FOLDER + AWebsite + DBDATA_EXT) do
    begin
      if tryc > 3 then
      begin
        Break;
      end;

      Inc(tryc);
      Sleep(250);
    end;

    Result := not FileExists(DATA_FOLDER + AWebsite + DBDATA_EXT);
  end;
end;

procedure OverwriteDBDataProcess(const AWebsite, NWebsite: String);
begin
  if FileExists(DATA_FOLDER + NWebsite + DBDATA_EXT) then
  begin
    if DeleteDBDataProcess(AWebsite) then
    begin
      RenameFile(DATA_FOLDER + NWebsite + DBDATA_EXT,
        DATA_FOLDER + AWebsite + DBDATA_EXT);
    end;
  end;
end;

{ TDBDataProcess }

function TDBDataProcess.GetLinkCount: Integer;
begin
  if Assigned(FLinks) then
  begin
    Result := FLinks.Count;
  end
  else
  begin
    Result := 0;
  end;
end;

procedure TDBDataProcess.ResetRecNo(Dataset: TDataSet);
begin
  // Position unknown after open/insert/delete/edit/refresh; force an absolute
  // seek on the next access rather than trusting a stale step direction.
  FRecNo := -1;
end;

procedure TDBDataProcess.InvalidateRowMap;
var
  i: Integer;
begin
  FRowMapValid := False;
  FRowStmtIndex := -1;
  FRowStmtHasRow := False;
  FRowStmtCur := nil;
  for i := 0 to High(FRowStmts) do
  begin
    if FRowStmts[i] <> nil then
    begin
      sqlite3_finalize(FRowStmts[i]);
      FRowStmts[i] := nil;
    end;
  end;
  SetLength(FRowStmts, 0);
end;

function TDBDataProcess.EnsureRowMap: Boolean;
var
  st: Psqlite3_stmt;
  sql, rowsql, line: String;
  lines: TStringList;
  n, cap, i, branches: Integer;
  allsites, hasorder: Boolean;
begin
  Result := False;
  if not FQuery.Active then
  begin
    Exit;
  end;

  if FRowMapValid then
  begin
    if FQuery.SQL.Text = FRowMapSQL then
      Exit(True)
    else
      InvalidateRowMap;
  end;

  // Dispatch on the SQL shape, not on FAllSitesAttached: Filter's exception
  // handler can restore the plain single-site SQL while sites stay attached.
  // Branch headers of the all-sites UNION built by Filter start with
  // 'SELECT *,' (adding the "website" pseudo-column); the plain view is a
  // single 'SELECT * FROM ...'.
  allsites := False;
  for i := 0 to FQuery.SQL.Count - 1 do
  begin
    if LeftStr(FQuery.SQL[i], 9) = 'SELECT *,' then
    begin
      allsites := True;
      Break;
    end;
  end;

  InvalidateRowMap;
  rowsql := '';

  if allsites then
  begin
    // All-sites view: rowid alone is not unique, so build a (site,rowid) map.
    // Transform each union branch header
    //   SELECT *, "<i>" AS "website" FROM <schema-qualified table>
    // into
    //   SELECT _rowid_ AS "rid", "title", "<i>" AS "website" FROM ...
    // keeping every other line (WHERE clauses, Search-inserted AND lines,
    // UNION ALL, parentheses, ORDER BY "title") verbatim. "title" must stay
    // projected for the outer ORDER BY to resolve.
    branches := 0;
    hasorder := False;
    lines := TStringList.Create;
    try
      lines.Assign(FQuery.SQL);
      for i := 0 to lines.Count - 1 do
      begin
        line := lines[i];
        if LeftStr(line, 9) = 'SELECT *,' then
        begin
          lines[i] := 'SELECT _rowid_ AS "rid", "title",' + Copy(line, 10, Length(line));
          Inc(branches);
        end
        else if Pos('ORDER BY', line) > 0 then
          hasorder := True;
      end;
      // Shape check: one branch per attached site plus the main table, and an
      // ORDER BY to define the row order. Anything else means Filter's SQL
      // format changed; fall back to the FQuery path rather than risk a map
      // that doesn't match the displayed order.
      if (branches <> FAttachedSites.Count + 1) or (not hasorder) then
      begin
        Exit;
      end;
      rowsql := lines.Text;
    finally
      lines.Free;
    end;
  end
  else
  begin
    sql := Trim(FQuery.SQL.Text);
    if UpperCase(LeftStr(sql, 8)) <> 'SELECT *' then
    begin
      Exit;
    end;

    // Build the ordered rowid array from the same FROM/WHERE/ORDER BY clause,
    // selecting only rowid (no blobs -> no buffer blow-up). Same trick as
    // GetRecordCount uses for COUNT().
    rowsql := 'SELECT _rowid_ ' + Copy(sql, 9, Length(sql));
    // With no ORDER BY, "SELECT *" scans the table (rowid order) while
    // "SELECT _rowid_" may use the link primary-key index (link order). Pin the
    // rowid query to rowid order so the map matches the displayed row order.
    if Pos('ORDER BY', UpperCase(sql)) = 0 then
      rowsql := rowsql + ' ORDER BY _rowid_';
  end;

  n := 0;
  if sqlite3_prepare_v2(FConn.Handle, PAnsiChar(rowsql), -1, @st, nil) = SQLITE_OK then
  begin
    try
      cap := FRecordCount + 16;
      SetLength(FRowMap, cap);
      while sqlite3_step(st) = SQLITE_ROW do
      begin
        if n >= cap then
        begin
          cap := (cap * 2) + 16;
          SetLength(FRowMap, cap);
        end;
        FRowMap[n].RowID := sqlite3_column_int64(st, 0);
        if allsites then
          FRowMap[n].SiteIndex := sqlite3_column_int(st, 2)
        else
          FRowMap[n].SiteIndex := -1;
        Inc(n);
      end;
    finally
      sqlite3_finalize(st);
    end;
  end
  else
  begin
    Exit;
  end;
  SetLength(FRowMap, n);

  // Per-site single-row fetch statements (indexed, depth-independent) are
  // prepared lazily in RowMapFetch; just size the slots here. Column order of
  // each 'SELECT * FROM <table>' matches DATA_PARAM_* indices.
  if allsites then
    SetLength(FRowStmts, FAttachedSites.Count + 1)
  else
    SetLength(FRowStmts, 1);
  for i := 0 to High(FRowStmts) do
    FRowStmts[i] := nil;

  FRowStmtIndex := -1;
  FRowStmtHasRow := False;
  FRowStmtCur := nil;
  FRowMapSQL := FQuery.SQL.Text;
  FRowMapValid := True;
  Result := True;
end;

function TDBDataProcess.RowMapFetch(const AIndex: Integer): Boolean;
var
  slot: Integer;
  st: Psqlite3_stmt;
  fetchsql: String;
begin
  if (AIndex >= 0) and (AIndex = FRowStmtIndex) then
  begin
    Exit(FRowStmtHasRow);
  end;
  Result := False;
  if (AIndex < 0) or (AIndex >= Length(FRowMap)) then
  begin
    Exit;
  end;

  slot := FRowMap[AIndex].SiteIndex + 1;
  if (slot < 0) or (slot > High(FRowStmts)) then
  begin
    Exit;
  end;

  // Prepare the per-site fetch statement on first use.
  if FRowStmts[slot] = nil then
  begin
    if slot = 0 then
      fetchsql := FSQLSelect + ' WHERE _rowid_ = ?'
    else
      fetchsql := 'SELECT * FROM "' + FAttachedSites[slot - 1] + '"."' +
        FTableName + '" WHERE _rowid_ = ?';
    if sqlite3_prepare_v2(FConn.Handle, PAnsiChar(fetchsql), -1,
      @FRowStmts[slot], nil) <> SQLITE_OK then
    begin
      FRowStmts[slot] := nil;
      Exit;
    end;
  end;
  st := FRowStmts[slot];

  // Reset the previously fetched statement too, so no stmt is left sitting in
  // SQLITE_ROW state against an attached schema (which would block DETACH).
  if (FRowStmtCur <> nil) and (FRowStmtCur <> st) then
  begin
    sqlite3_reset(FRowStmtCur);
  end;

  sqlite3_reset(st);
  sqlite3_bind_int64(st, 1, FRowMap[AIndex].RowID);
  FRowStmtHasRow := sqlite3_step(st) = SQLITE_ROW;
  FRowStmtCur := st;
  FRowStmtIndex := AIndex;
  Result := FRowStmtHasRow;
end;

function TDBDataProcess.GoToRecNo(const ARecIndex: Integer): Boolean;
begin
  // In single-site mode positioning is handled by the rowid map; this is just
  // the validity guard callers use before reading (and warms the row cache).
  if EnsureRowMap then
  begin
    Result := (ARecIndex >= 0) and (ARecIndex < Length(FRowMap));
    if Result then
      RowMapFetch(ARecIndex);
    Exit;
  end;

  // FRecNo tracks the cursor position ourselves so we never touch the
  // TBufDataset.RecNo getter, which walks the record list from the head (O(n)).
  if FRecNo = ARecIndex then
  begin
    Exit(True);
  end;

  Result := False;
  if (ARecIndex < 0) or (ARecIndex > RecordCount) then
  begin
    Exit;
  end;

  try
    // Sequential scrolling is by far the common case. Stepping with Next/Prior
    // is O(1); assigning RecNo re-walks the list from the start (O(n)), which
    // turns a downward scroll over a large list into O(n^2) (the "jerky crawl").
    if (FRecNo >= 0) and (FRecNo = ARecIndex - 1) then
      FQuery.Next
    else if (FRecNo >= 0) and (FRecNo = ARecIndex + 1) then
      FQuery.Prior
    else
      FQuery.RecNo := ARecIndex + 1;
    FRecNo := ARecIndex;
    Result := True;
  except
  end;
end;

procedure TDBDataProcess.CreateTable;
begin
  if FConn.Connected then
  begin
    FConn.ExecuteDirect('DROP TABLE IF EXISTS "' + FTableName + '"');
    FConn.ExecuteDirect('CREATE TABLE "' + FTableName + '" (' +
      DBDataProccesCreateParam + ');');
    FTrans.CommitRetaining;
  end;
end;

procedure TDBDataProcess.CreateField(const FieldName: String);
begin
  if FConn.Connected then
  begin
    FConn.ExecuteDirect('ALTER TABLE "' + FTableName + '" ADD COLUMN "' + FieldName + '" TEXT;');
    FTrans.CommitRetaining;
  end;
end;

procedure TDBDataProcess.ConvertNewTable(const TableParams: String);
var
  qactive: Boolean;
begin
  if not FConn.Connected then
  begin
    Exit;
  end;

  try
    qactive := FQuery.Active;
    if FQuery.Active then
    begin
      FQuery.Close;
    end;

    with FConn do
    begin
      try
        ExecuteDirect('ALTER TABLE "' + FTableName + '" RENAME TO "' + FTableName + '_old"');
        ExecuteDirect('CREATE TABLE "' + FTableName + '" (' + DBDataProccesCreateParam + ');');
        ExecuteDirect('INSERT INTO "' + FTableName + '" (' + TableParams + ') SELECT ' + TableParams + ' FROM "' + FTableName + '_old"');
        ExecuteDirect('DROP TABLE "' + FTableName + '_old"');
        VacuumTable;
      except
        on E: Exception do
          SendLogException(Self.ClassName + '[' + Website + '].Convert.Error!', E);
      end;
    end;
    FTrans.Commit;

    if qactive <> FQuery.Active then
    begin
      FQuery.Active := qactive;
    end;
  except
    FTrans.Rollback;
  end;
end;

procedure TDBDataProcess.VacuumTable;
var
  queryactive: Boolean;
begin
  if FConn.Connected then
  begin
    queryactive := FQuery.Active;
    FQuery.Close;

    with FConn do
    begin
      try
        ExecuteDirect('END TRANSACTION');
        ExecuteDirect('VACUUM');
      except
      end;
      ExecuteDirect('BEGIN TRANSACTION');
    end;

    if FQuery.Active <> queryactive then
    begin
      FQuery.Active := queryactive;
    end;
  end;
end;

procedure TDBDataProcess.GetRecordCount;
var
  bsql: String;
begin
  FRecordCount := 0;
  bsql := Trim(FQuery.SQL.Text);

  if UpperCase(LeftStr(bsql, 8)) = 'SELECT *' then
  begin
    FRecordCount := StrToIntDef(FConn.ExecuteQuery('SELECT COUNT("link") ' + copy(bsql, 9, length(bsql))), 0);
  end;
end;

procedure TDBDataProcess.AddSQLCond(const sqltext: String; useOR: Boolean);
begin
  with FQuery.SQL do
  begin
    if Count > 0 then
    begin
      if (Strings[Count - 1] <> '(') and
        (UpCase(Trim(Strings[Count - 1])) <> 'WHERE') then
      begin
        if useOR then
        begin
          Add('OR');
        end
        else
        begin
          Add('AND');
        end;
      end;
    end;

    Add(sqltext);
  end;
end;

procedure TDBDataProcess.AddSQLSimpleFilter(const fieldname, Value: String;
  useNOT: Boolean; useOR: Boolean; useRegexp: Boolean);
var
  svalue: String;
  scond: String;
begin
  svalue := LowerCase(Trim(Value));

  if (fieldname = '') or (svalue = '') then
  begin
    Exit;
  end;

  if useNOT then
  begin
    scond := ' NOT';
  end
  else
  begin
    scond := '';
  end;

  if useRegexp then
  begin
    AddSQLCond('LOWER("' + fieldname + '")' + scond + ' REGEXP ' + QuotedStr(svalue), useOR);
  end
  else
  begin
    AddSQLCond('LOWER("' + fieldname + '")' + scond + ' LIKE ' + QuotedLike(svalue), useOR);
  end;
end;

procedure TDBDataProcess.AddSQLPairedFilter(const Pairs: array of TFieldValuePair;
  useNOT, useOR, useRegexp: Boolean);
var
  i: Integer;
  scond, svalue, sqlCondition: String;
begin
  sqlCondition := '';

  for i := 0 to High(Pairs) do
  begin
    if (Pairs[i].Field = '') or (Pairs[i].Value = '') then
    begin
      Continue;
    end;

    svalue := LowerCase(Trim(Pairs[i].Value));

    if useNOT then
    begin
      scond := ' NOT';
    end
    else
    begin
      scond := '';
    end;

    if useRegexp then
    begin
      sqlCondition := sqlCondition + 'LOWER("' + Pairs[i].Field + '")' + scond + ' REGEXP ' + QuotedStr(svalue);
    end
    else
    begin
      sqlCondition := sqlCondition + 'LOWER("' + Pairs[i].Field + '")' + scond + ' LIKE ' + QuotedLike(svalue);
    end;

    if i < High(Pairs) then
    begin
      sqlCondition := sqlCondition + ' OR '; // Add OR between pair conditions
    end;
  end;

  if sqlCondition <> '' then
  begin
    AddSQLCond('(' + sqlCondition + ')', useOR);
  end;
end;

function TDBDataProcess.GetConnected: Boolean;
begin
  Result := FConn.Connected;
end;

function TDBDataProcess.InternalOpen(const FilePath: String): Boolean;
begin
  Result := False;

  if FilePath <> '' then
  begin
    FConn.DatabaseName := FilePath;
  end;

  if FConn.DatabaseName = '' then
  begin
    Exit;
  end;

  try
    FConn.CharSet := 'UTF8';
    FConn.Connected := True;
    sqlite3_create_collation(FConn.Handle, PAnsiChar('NATCMP'), SQLITE_UTF8, nil,
      @NaturalCompareCallback);
    sqlite3_create_function(FConn.Handle, PAnsiChar('REGEXP'), 2, SQLITE_UTF8, FRegxp,
      @RegexCallback, nil, nil);
    FTrans.Active := True;
  except
    on E: Exception do
    begin
      SendLogException(Self.ClassName + '[' + Website + '].InternalOpen.Error!', E);
      Result := False;
    end;
  end;

  Result := FConn.Connected;
end;

function TDBDataProcess.GetWebsiteName(const RecIndex: Integer): String;
begin
  if FAllSitesAttached then
  begin
    try
      // Never read the row through FQuery when the map is valid: SQLite's sort
      // is not stable, so the buffered cursor can order duplicate titles
      // differently than the map and attribute the wrong site to the row.
      if EnsureRowMap then
      begin
        if (RecIndex >= 0) and (RecIndex < Length(FRowMap)) then
          Result := IntToStr(FRowMap[RecIndex].SiteIndex);
      end
      else
      if GoToRecNo(RecIndex) then
        Result := FQuery.Fields[DBTempFieldWebsiteIndex].AsString;
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].GetWebsiteName Error!' +
        'RecIndex: ' + IntToStr(RecIndex), E);
    end;
  end
  else
  begin
    Result := FWebsite;
  end;
end;

function TDBDataProcess.GetValue(const RecIndex, FieldIndex: Integer): String;
var
  p: PAnsiChar;
begin
  if FieldIndex in [DATA_PARAM_NUMCHAPTER,DATA_PARAM_JDN] then
  begin
    Result := '0';
  end
  else
  begin
    Result := '';
  end;

  if EnsureRowMap then
  begin
    if RowMapFetch(RecIndex) then
    begin
      p := PAnsiChar(sqlite3_column_text(FRowStmtCur, FieldIndex));
      if p <> nil then
        Result := String(p);
    end;
    Exit;
  end;

  if FQuery.Active = False then
  begin
    Exit;
  end;

  if GoToRecNo(RecIndex) then
  begin
    Result := FQuery.Fields[FieldIndex].AsString;
  end;
end;

function TDBDataProcess.GetValueInt(const RecIndex, FieldIndex: Integer
  ): Integer;
begin
  Result := 0;
  if not (FieldIndex in [DATA_PARAM_NUMCHAPTER,DATA_PARAM_JDN]) then
  begin
    Exit;
  end;

  if EnsureRowMap then
  begin
    if RowMapFetch(RecIndex) then
      Result := sqlite3_column_int(FRowStmtCur, FieldIndex);
    Exit;
  end;

  if FQuery.Active = False then
  begin
    Exit;
  end;

  if GoToRecNo(RecIndex) then
  begin
    Result := FQuery.Fields[FieldIndex].AsInteger;
  end;
end;

procedure TDBDataProcess.AttachAllSites;

  procedure RemoveCurrentSite;
  var
    j: Integer;
  begin
    if SitesList.Count > 0 then
    begin
      for j := 0 to SitesList.Count - 1 do
      begin
        if Pointer(SitesList.Objects[j]) = FModule then
        begin
          SitesList.Delete(j);
          Break;
        end;
      end;
    end;
  end;

var
  i, attachedMax, attachedLimit: Integer;
  m: TModuleContainer;
  tempDataProcess: TDBDataProcess;
begin
  RemoveCurrentSite;
  if (not FConn.Connected) or (SitesList.Count = 0) then
  begin
    Exit;
  end;

  DetachAllSites;
  FConn.ExecuteDirect('END TRANSACTION');
  // The bundled Windows sqlite3.dll is a custom build with a 125 attach limit;
  // ask the library for its actual limit (e.g. system SQLite defaults to 10)
  // so hitting it gives the warning below instead of an ATTACH exception that
  // aborts the loop mid-way.
  attachedLimit := 125;
  if Assigned(sqlite3_limit) then
  begin
    i := sqlite3_limit(FConn.Handle, SQLITE_LIMIT_ATTACHED, -1);
    if i > 0 then
      attachedLimit := i;
  end;
  attachedMax := attachedLimit;
  tempDataProcess := TDBDataProcess.Create;

  try
    for i := 0 to SitesList.Count - 1 do
    begin
      if attachedMax = 0 then
      begin
        SendLogWarning(ClassName + '[' + Website + '].AttachAllSites.Warning! Can''t attach all sites, the attached-database limit of ' + IntToStr(attachedLimit) + ' reached.');
        Break;
      end;

      m := TModuleContainer(FSitesList.Objects[i]);
      if (FAttachedSites.IndexOf(m.ID) = -1) and (FileExists(DBDataFilePath(m.ID))) then
      begin
        tempDataProcess.Open(m.ID); // Check database structure so theres no errors if databases mismatch
        attachedMax := attachedMax - 1;
        FConn.ExecuteDirect('ATTACH ' + QuotedStr(DBDataFilePath(m.ID)) + ' AS "' + m.ID + '"');
        FAttachedSites.AddObject(m.ID, m);
      end;
    end;
  except
    on E: Exception do
      SendLogException(ClassName + '[' + Website + '].AttachAllSites.Error!' +
        ' try to attach ' + QuotedStr(SitesList[i]), E)
  end;

  tempDataProcess.Close;
  tempDataProcess.Free;
  FConn.ExecuteDirect('BEGIN TRANSACTION');
  FAllSitesAttached := FAttachedSites.Count > 0;
end;

procedure TDBDataProcess.DetachAllSites;
var
  i: Integer;
  queryactive: Boolean;
begin
  if (not FConn.Connected) or (FAttachedSites.Count = 0) then
  begin
    Exit;
  end;

  queryactive := FQuery.Active;
  if FQuery.Active then
  begin
    FQuery.Close;
  end;

  // Finalize the per-site row-fetch statements first: a statement left in
  // SQLITE_ROW state against an attached schema makes DETACH fail with
  // "database is locked".
  InvalidateRowMap;

  FTrans.CommitRetaining;
  FConn.ExecuteDirect('END TRANSACTION');
  for i := FAttachedSites.Count - 1 downto 0 do
  begin
    try
      FConn.ExecuteDirect('DETACH "' + FAttachedSites[i] + '"');
      FAttachedSites.Delete(i);
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].DetachAllSites.Error!', E);
    end;
  end;

  FConn.ExecuteDirect('BEGIN TRANSACTION');
  FAllSitesAttached := FAttachedSites.Count > 0;

  if FQuery.Active <> queryactive then
  begin
    FQuery.Active := queryactive;
  end;
end;

function TDBDataProcess.ExecuteDirect(SQL: String): Boolean;
begin
  Result := False;

  if FConn.Connected then
  begin
    try
      FConn.ExecuteDirect(SQL);
      Result := True;
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].ExecuteDirect.Error!'#13#10 +
          'SQL: ' + SQL, E);
    end;
  end;
end;

function TDBDataProcess.CheckWebsiteAndFilePath(const AWebsite: String;
  var AFilePath: String): Boolean;
begin
  if FWebsite <> AWebsite then
  begin
    FWebsite := AWebsite;
  end;

  if FWebsite <> '' then
  begin
    FModule := Modules.LocateModule(AWebsite);
    AFilePath := DATA_FOLDER + FWebsite + DBDATA_EXT;
    Result := FileExists(AFilePath);
  end
  else
  begin
    FModule := Nil;
    AFilePath := '';
    Result := False;
  end;
end;

constructor TDBDataProcess.Create;
begin
  inherited Create;
  InitCriticalSection(FGuardian);
  FConn := TSQLite3ConnectionH.Create(nil);
  FTrans := TSQLTransaction.Create(nil);
  FQuery := TSQLQuery.Create(nil);
  FConn.Transaction := FTrans;
  FQuery.PacketRecords := 25;
  FQuery.DataBase := FTrans.DataBase;
  FQuery.Transaction := FTrans;
  FRegxp := TRegExpr.Create;
  FRegxp.ModifierI := True;
  FSitesList := TStringList.Create;
  FAttachedSites := TStringList.Create;
  FTableName := 'masterlist';
  FSQLSelect := 'SELECT * FROM "' + FTableName + '"';
  FRecordCount := 0;
  FFiltered := False;
  FFilterAllSites := False;
  FFilterApplied := False;
  FFilterSQL := '';
  FAllSitesAttached := False;
  FRowMapValid := False;
  FRowStmtCur := nil;
  FRowStmtIndex := -1;
  FRowStmtHasRow := False;

  ResetRecNo(nil);
  FQuery.AfterOpen := @ResetRecNo;
  FQuery.AfterInsert := @ResetRecNo;
  FQuery.AfterDelete := @ResetRecNo;
  FQuery.AfterEdit := @ResetRecNo;
  FQuery.AfterRefresh := @ResetRecNo;
end;

destructor TDBDataProcess.Destroy;
begin
  try
    if FConn.Connected then
    begin
      FQuery.Close;
      Commit;
      Close;
    end;
  except
    on E: Exception do
      SendLogException(Self.ClassName+'['+Website+'].Destroy.Error!', E);
  end;

  InvalidateRowMap;   // ensure the rowid stmt is finalized before teardown
  DoneLocateLink;
  FAttachedSites.Free;
  FSitesList.Free;
  FQuery.Free;
  FTrans.Free;
  FConn.Free;
  FRegxp.Free;
  Finalize(FGuardian);
  inherited Destroy;
end;

procedure TDBDataProcess.Lock;
begin
  EnterCriticalSection(FGuardian);
end;

procedure TDBDataProcess.Unlock;
begin
  LeaveCriticalSection(FGuardian);
end;

function TDBDataProcess.Connect(const AWebsite: String): Boolean;
var
  filepath: String = '';
begin
  if CheckWebsiteAndFilePath(AWebsite, filepath) then
  begin
    Result := InternalOpen(filepath);
  end
  else
  begin
    Result := False;
  end;
end;

function TDBDataProcess.ConnectFile(const AFile: String): Boolean;
begin
  try
    Result := InternalOpen(AFile);
  except
    Result := False;
  end;
end;

function TDBDataProcess.Open(const AWebsite: String): Boolean;
begin
  Close;
  Result := False;

  if Connect(AWebsite) then
  begin
    try
      if not TableExist(FTableName) then
      begin
        CreateTable;
      end;

      OpenTable(FTableName, True);
      CheckFieldsExist(FTableName);
      Result := FQuery.Active;
    except
      on E: Exception do
        SendLogException(Self.ClassName + '.Open.Error!', E);
    end;
  end;
end;

function TDBDataProcess.OpenTable(const ATableName: String;
  CheckRecordCount: Boolean): Boolean;
begin
  Result := False;

  if FConn.Connected then
  begin
    try
      if ATableName <> '' then
      begin
        FTableName := ATableName;
      end;

      if FTableName = '' then
      begin
        Exit;
      end;

      if TableExist(FTableName) then
      begin
        if FQuery.Active then
        begin
          FQuery.Close;
        end;

        if FTrans.Active=False then
        begin
          FTrans.Active := True;
        end;

        FSQLSelect := 'SELECT * FROM "' + FTableName + '"';
        FQuery.SQL.Text := FSQLSelect;

        if CheckRecordCount then
        begin
          GetRecordCount;
        end;

        FQuery.Open;
      end;
    except
      on E: Exception do
        SendLogException(Self.ClassName+'['+Website+'].OpenTable.Error!', E);
    end;
  end;

  Result := FQuery.Active;
end;

function TDBDataProcess.TableExist(const ATableName: String): Boolean;
var
  ts: TStringList;
  i: Integer;
begin
  Result := False;

  if FConn.Connected then
  begin
    ts := TStringList.Create;
    try
      FConn.GetTableNames(ts);
      ts.Sorted := True;
      Result := ts.Find(ATableName, i);
    finally
      ts.Free;
    end;
  end;
end;

procedure TDBDataProcess.CheckFieldsExist(const ATableName: String);
var
  ts: TStringList;
  i, j: Integer;
  FieldName, TableParams: String;
  FoundMissing: Boolean;
begin
  FoundMissing := False;
  TableParams := '';

  if FConn.Connected then
  begin
    ts := TStringList.Create;
    try
      FConn.GetFieldNames(ATableName, ts);
      ts.Sorted := True;
      for j := Low(DBDataProcessParams) to High(DBDataProcessParams) do
      begin
        FieldName := DBDataProcessParams[j];

        if ts.Find(FieldName, i) then
        begin
          if j > 0 then
          begin
            TableParams := TableParams + ',';
          end;

          TableParams := TableParams + '"' + FieldName + '"';
        end
        else
        begin
          FoundMissing := True;
        end;
      end;

      if FoundMissing then
      begin
        ConvertNewTable(TableParams);
      end;
    finally
      ts.Free;
    end;
  end;
end;

procedure TDBDataProcess.Close;
begin
  FRecordCount := 0;

  if FConn.Connected then
  begin
    try
      InvalidateRowMap;   // finalize the rowid stmt before closing the handle
      SetLength(FRowMap, 0);
      FQuery.Close;
      RemoveFilter;
      FConn.Close;
      FConn.DatabaseName := '';
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].Close.Error!', E);
    end;
  end;
end;

procedure TDBDataProcess.CloseTable;
begin
  if FQuery.Active then
  begin
    FRecordCount := 0;
    RemoveFilter;
    FQuery.Close;
  end;
end;

procedure TDBDataProcess.Save;
begin
  Commit;
end;

procedure TDBDataProcess.Backup(const AWebsite: String);
begin
  if AWebsite = '' then
  begin
    Exit;
  end;

  if FConn.Connected then
  begin
    with TSQLite3Backup.Create do
    begin
      try
        Backup(FConn, DATA_FOLDER + AWebsite + DBDATA_EXT);
      finally
        Free;
      end;
    end;
  end;
end;

procedure TDBDataProcess.Refresh(RecheckDataCount: Boolean);
begin
  if FConn.Connected then
  begin
    InvalidateRowMap;   // data may have changed; rebuild on next read
    if FQuery.Active then
    begin
      if RecheckDataCount then
      begin
        GetRecordCount;
      end;

      FQuery.Refresh;
    end
    else
    if Trim(FQuery.SQL.Text) <> '' then
    begin
      if RecheckDataCount then
      begin
        GetRecordCount;
      end;

      FQuery.Open;
    end;
  end;
end;

function TDBDataProcess.AddData(const Title, AltTitles, Link, Authors, Artists, Genres,
  Status, Summary: String; NumChapter, JDN: Integer): Boolean;
var
  sql: String;
  i: Integer;
begin
  Result := False;
  if (Link = '') or
     (not FConn.Connected) then
  begin
    Exit;
  end;

  try
    FQuery.SQL.Text := 'INSERT OR IGNORE INTO "' + FTableName + '" (' + DBDataProcessParam + ') VALUES (' + DBDataProcessParamInsert + ');';

    // Set parameters - the parameter binding handles escaping
    FQuery.Params.ParamByName('link').AsString := Link;
    FQuery.Params.ParamByName('title').AsString := Title;
    FQuery.Params.ParamByName('alttitles').AsString := AltTitles;
    FQuery.Params.ParamByName('authors').AsString := Authors;
    FQuery.Params.ParamByName('artists').AsString := Artists;
    FQuery.Params.ParamByName('genres').AsString := Genres;
    FQuery.Params.ParamByName('status').AsString := Status;
    FQuery.Params.ParamByName('summary').AsString := Summary;
    FQuery.Params.ParamByName('numchapter').AsInteger := NumChapter;
    FQuery.Params.ParamByName('jdn').AsInteger := JDN;

    if FQuery.Active then
    begin
      FQuery.Close;
    end;

    FQuery.ExecSQL;
    InvalidateRowMap;   // a new row was added; rebuild the map on next read

    sql := FQuery.SQL.Text;
    for i := 0 to FQuery.Params.Count - 1 do
    begin
      sql := StringReplace(sql, ':' + FQuery.Params[i].Name, QuotedStr(FQuery.Params[i].AsString), [rfReplaceAll, rfIgnoreCase]);
    end;

    // Check changes - close previous operation first
    FQuery.Close;
    FQuery.SQL.Text := 'SELECT changes()';
    FQuery.Open;
    Result := FQuery.Fields[0].AsInteger > 0;
    FQuery.Close;
  except
    on E: Exception do
      SendLogException(ClassName + '[' + Website + '].AddData.Error!' + LineEnding + sql, E);
  end;
end;

function TDBDataProcess.AddData(const Title, AltTitles, Link, Authors, Artists, Genres,
  Status, Summary: String; NumChapter: Integer; JDN: TDateTime): Boolean;
begin
  Result := AddData(Title, AltTitles, Link, Authors, Artists, Genres, Status, Summary,
    NumChapter, DateToJDN(JDN));
end;

function TDBDataProcess.UpdateData(const Title, AltTitles, Link, Authors, Artists, Genres,
  Status, Summary: String; NumChapter: Integer; AWebsite: String): Boolean;
var
  sql: String;
begin
  Result := False;
  if (Link = '') or
     (not FConn.Connected) then
  begin
    Exit;
  end;

  try
    sql := 'UPDATE ';
    if (AWebsite <> '') and (AWebsite <> FWebsite) and FAllSitesAttached then
    begin
      sql += '"' + AWebsite + '"."' + FTableName + '"';
    end
    else
    begin
      sql += '"' + FTableName + '"';
    end;

    sql += ' SET "title"=' + QuotedStr(Title) +
           ', "alttitles"=' + QuotedStr(AltTitles) +
           ', "authors"=' + QuotedStr(Authors) +
           ', "artists"=' + QuotedStr(Artists) +
           ', "genres"=' + QuotedStr(Genres) +
           ', "status"=' + QuotedStr(Status) +
           ', "summary"=' + QuotedStr(Summary) +
           ', "numchapter"=' + QuotedStr(IntToStr(NumChapter)) +
           ' WHERE ("link"=' + QuotedStr(Link) + ');';
    FConn.ExecuteDirect(sql);
    InvalidateRowMap;   // row contents (and possibly sort order) changed
    Result := True;
  except
    on E: Exception do
      SendLogException(ClassName + '[' + Website + '].UpdateData.Error!' + LineEnding + sql, E);
  end;
end;

function TDBDataProcess.DeleteData(const RecIndex: Integer): Boolean;
var
  k: Integer;
  tbl: String;
begin
  Result := False;
  try
    if EnsureRowMap then
    begin
      if (RecIndex < 0) or (RecIndex >= Length(FRowMap)) then
      begin
        Exit;
      end;
      // Delete straight from the table by rowid, then drop the entry from the
      // in-memory map so indices stay aligned with the caller's view (the UI
      // removes its rows in the same descending pass) without a mid-loop rebuild.
      // In the all-sites view the row lives in the attached site's own DB.
      if FRowMap[RecIndex].SiteIndex = -1 then
        tbl := '"' + FTableName + '"'
      else
        tbl := '"' + FAttachedSites[FRowMap[RecIndex].SiteIndex] + '"."' + FTableName + '"';
      FConn.ExecuteDirect('DELETE FROM ' + tbl + ' WHERE _rowid_ = ' + IntToStr(FRowMap[RecIndex].RowID));
      for k := RecIndex to High(FRowMap) - 1 do
        FRowMap[k] := FRowMap[k + 1];
      SetLength(FRowMap, Length(FRowMap) - 1);
      FRowMapSQL := FQuery.SQL.Text;   // map still matches the current SQL
      FRowStmtIndex := -1;             // drop the cached fetched row
      FRowStmtHasRow := False;
      Dec(FRecordCount);
      Result := True;
      Exit;
    end;

    if GoToRecNo(RecIndex) then
    begin
      FQuery.Delete;
      Dec(FRecordCount);
      Result := True;
    end;
  except
    on E: Exception do
      SendLogException(ClassName + '[' + Website + '].DeleteData.Error!',E);
  end;
end;

procedure TDBDataProcess.Commit;
var
  queryactive: Boolean;
begin
  if FConn.Connected then
  begin
    try
      queryactive := FQuery.Active;
      if FQuery.Active then
      begin
        FQuery.Close;
      end;

      FTrans.CommitRetaining;
      if FQuery.Active <> queryactive then
      begin
        FQuery.Active := queryactive;
      end;
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].Commit.Error!',E);
    end;
  end;
end;

procedure TDBDataProcess.Rollback;
begin
  if FConn.Connected then
  begin
    try
      FTrans.Rollback;
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].Rollback.Error!',E);
    end;
  end;
end;

function TDBDataProcess.RegexEscapeInput(const Input: String): String;
const
  RegexSpecialChars = ['.', '+', '*', '?', '^', '$', '(', ')', '[', ']', '{', '}', '|', '\'];
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(Input) do
  begin
    if CharInSet(Input[i], RegexSpecialChars) then
    begin
      Result := Result + '\'; // Add escape character
    end;

    Result := Result + Input[i];
  end;
end;

function TDBDataProcess.RegexEscapeAltTitles(const ATitle: String): String;
const
  HeadRegex = '(?i)(^|,)[ \\t\\r\\n]*';
  TailRegex = '[ \\t\\r\\n]*(,|$)';
begin
  Result := HeadRegex + RegexEscapeInput(ATitle) + TailRegex;
end;

function TDBDataProcess.Search(ATitle: String): Boolean;
var
  i: Integer;
  Titles: array[0..1] of TFieldValuePair;
begin
  if FQuery.Active then
  begin
    try
      FQuery.Close;
      with FQuery do
      begin
        SQL.Clear;
        if FFilterApplied then
        begin
          SQL.AddText(FFilterSQL);
        end
        else
        begin
          SQL.Add(FSQLSelect);
        end;

        if ATitle <> '' then
        begin
          if not FFilterApplied then
          begin
            SQL.Add('WHERE');
          end;

          if FAllSitesAttached then
          begin
            if SQL.Count > 0 then
            begin
              i := 0;
              while i < SQL.Count do
              begin
                if (SQL[i] = 'UNION ALL') or (SQL[i] = ')') then
                begin
                  SQL.Insert(i, 'AND');
                  SQL.Insert(i + 1, '("title" LIKE ' + QuotedLike(ATitle));
                  SQL.Insert(i + 2, 'OR');
                  SQL.Insert(i + 3, '"alttitles" LIKE ' + QuotedLike(ATitle) + ')');
                  Inc(i, 5);
                end
                else
                begin
                  Inc(i);
                end;
              end;
            end;
          end
          else
          begin
            Titles[0].Field := 'title';
            Titles[0].Value := ATitle;
            Titles[1].Field := 'alttitles';
            Titles[1].Value := ATitle;

            AddSQLPairedFilter(Titles);
          end;

          FFiltered := True;
        end
        else
        begin
          FFiltered := FFilterApplied;
        end;
      end;
      GetRecordCount;
      FQuery.Open;
    except
      on E: Exception do
        SendLogException(Self.ClassName + '[' + Website + '].Search.Error!'#13#10 +
          'SQL:'#13#10 + FQuery.SQL.Text, E);
    end;
  end;
  Result := FQuery.Active;

  if not Result then
  begin
    FFiltered := False;
    FRecordCount := 0;
  end;
end;

function TDBDataProcess.CanFilter(const checkedGenres, uncheckedGenres: TStringList;
  const stTitle, stAuthors, stArtists, stStatus, stSummary: String;
  const minusDay: Integer; const haveAllChecked, searchNewManga: Boolean): Boolean;
begin
  Result := False;
  if not FQuery.Active then
  begin
    Exit;
  end;

  if ((stTitle = '') and
    (stAuthors = '') and
    (stArtists = '') and
    (stSummary = '') and
    (stStatus = '4') and
    (checkedGenres.Count = 0) and
    (uncheckedGenres.Count = 0)) and
    (not searchNewManga) and
    haveAllChecked then
  begin
    Result := False;
  end
  else
  begin
    Result := True;
  end;
end;

function TDBDataProcess.Filter(const checkedGenres,
  uncheckedGenres: TStringList; const stTitle, stAuthors, stArtists, stStatus,
  stSummary: String; const minusDay: Integer; const haveAllChecked,
  searchNewManga: Boolean; const useRegExpr: Boolean): Boolean;
var
  tsql: String;
  i: Integer;
  filtersingle: Boolean;

  procedure GenerateSQLFilter;
  var
    j: Integer;
    Titles: array[0..1] of TFieldValuePair;
  begin
    // filter new manga based on date
    if searchNewManga then
    begin
      AddSQLCond('"jdn" > "' + IntToStr(DateToJDN(Now) - minusDay) + '"');
    end;

    // filter title
    Titles[0].Field := 'title';
    Titles[0].Value := stTitle;
    Titles[1].Field := 'alttitles';
    Titles[1].Value := stTitle;

    AddSQLPairedFilter(Titles, False, False, useRegExpr);

    // filter authors
    AddSQLSimpleFilter('authors', stAuthors, False, False, useRegExpr);

    // filter artists
    AddSQLSimpleFilter('artists', stArtists, False, False, useRegExpr);

    // filter summary
    AddSQLSimpleFilter('summary', stSummary, False, False, useRegExpr);

    // filter status
    if stStatus <> '4' then
    begin
      AddSQLCond('"status"="' + stStatus + '"');
    end;

    //filter checked genres
    if checkedGenres.Count > 0 then
    begin
      AddSQLCond('(');
      for j := 0 to checkedGenres.Count - 1 do
      begin
        AddSQLSimpleFilter('genres', checkedGenres[j], False,
          (not haveAllChecked), useRegExpr);
      end;

      FQuery.SQL.Add(')');
    end;

    //filter unchecked genres
    if uncheckedGenres.Count > 0 then
    begin
      AddSQLCond('(');
      for j := 0 to uncheckedGenres.Count - 1 do
      begin
        AddSQLSimpleFilter('genres', uncheckedGenres[j], True,
          (not haveAllChecked), useRegExpr);
      end;

      FQuery.SQL.Add(')');
    end;
  end;

begin
  Result := False;
  if FQuery.Active = False then
  begin
    Exit;
  end;

  if not CanFilter(checkedGenres, uncheckedGenres, stTitle, stAuthors,
    stArtists, stStatus, stSummary, minusDay, haveAllChecked, searchNewManga) then
  begin
    Exit;
  end;

  with FQuery do
  begin
    FQuery.Close;
    FRecordCount := 0;
    tsql := SQL.Text;
    SQL.Clear;
    try
      filtersingle := True;

      if FFilterAllSites and (FSitesList.Count > 0) then
      begin
        AttachAllSites;
        if FAttachedSites.Count > 0 then
        begin
          // NOTE: EnsureRowMap parses this SQL line-by-line (branch headers
          // must start with 'SELECT *,' and an ORDER BY line must exist) to
          // build its (site,rowid) fast path. Changing the shape here only
          // disables that fast path (it falls back to the buffered FQuery),
          // but keep them in sync for large-list scroll performance.
          SQL.Add('SELECT * FROM');
          SQL.Add('(');
          SQL.Add('SELECT *, "-1" AS "website" FROM "' + FTableName + '"');
          SQL.Add('WHERE');
          GenerateSQLFilter;

          for i := 0 to FAttachedSites.Count - 1 do
          begin
            SQL.Add('UNION ALL');
            SQL.Add('SELECT *, "' + IntToStr(i) + '" AS "website" FROM "' + FAttachedSites[i] + '"."' + FTableName + '"');
            SQL.Add('WHERE');
            GenerateSQLFilter;
          end;

          SQL.Add(')');
          SQL.Add('ORDER BY "title" COLLATE NATCMP');
          filtersingle := False;
        end;
      end;

      if filtersingle then
      begin
        SQL.Add(FSQLSelect);
        SQL.Add('WHERE');
        GenerateSQLFilter;
      end;

      Self.GetRecordCount;
      FQuery.Open;
      FFiltered := Active;
      FFilterApplied := FFiltered;

      if FFilterApplied then
      begin
        FFilterSQL := SQL.Text;
      end
      else
      begin
        FFilterSQL := '';
      end;
    except
      on E: Exception do
      begin
        SendLogException(Self.ClassName + '[' + Website + '].Filter.Error!'#13#10 +
          'SQL:'#13#10 + FQuery.SQL.Text, E);
        FQuery.Close;
        SQL.Text := tsql;
        Self.GetRecordCount;
        FQuery.Open;
        FFilterAllSites := False;
        FFiltered := False;
        FFilterApplied := False;
        FFilterSQL := '';
      end;
    end;
    Result := FFiltered;
  end;
end;

procedure TDBDataProcess.CreateDatabase(const AWebsite: String);
var
  filepath: String;
begin
  Close;
  if CheckWebsiteAndFilePath(AWebsite, filepath) then
  begin
    DeleteFile(filepath);
  end;

  if ForceDirectories(DATA_FOLDER) then
  begin
    InternalOpen(filepath);
    CreateTable;
  end;
end;

procedure TDBDataProcess.GetFieldNames(const List: TStringList);
begin
  if (List <> nil) and (FQuery.Active) then
  begin
    FQuery.GetFieldNames(List);
  end;
end;

procedure TDBDataProcess.RemoveFilter;
begin
  if FFiltered then
  begin
    FFilterAllSites := False;
    FFiltered := False;
    FFilterApplied := False;
    FFilterSQL := '';
    FQuery.SQL.Text := FSQLSelect;
    FRecordCount := 0;
    DetachAllSites;

    if FQuery.Active then
    begin
      OpenTable(FTableName, True);
    end;
  end;
end;

procedure TDBDataProcess.Sort;
var
  queryactive: Boolean;
begin
  if FConn.Connected then
  begin
    queryactive := FQuery.Active;
    FQuery.Close;
    with FConn do
    begin
      try
        ExecuteDirect('DROP TABLE IF EXISTS "' + FTableName + '_ordered"');
        ExecuteDirect('CREATE TABLE "' + FTableName + '_ordered" (' + DBDataProccesCreateParam + ')');
        ExecuteDirect('INSERT INTO "' + FTableName + '_ordered" (' + DBDataProcessParam + ') SELECT ' + DBDataProcessParam + ' FROM "' + FTableName + '" ORDER BY "title" COLLATE NATCMP');
        ExecuteDirect('DROP TABLE "' + FTableName + '"');
        ExecuteDirect('ALTER TABLE "' + FTableName + '_ordered" RENAME TO "' + FTableName + '"');
        FTrans.Commit;
        VacuumTable;
      except
        on E: Exception do
          SendLogException(Self.ClassName + '[' + Website + '].Sort.Error!', E);
      end;
    end;

    // The table was dropped/recreated, so every rowid changed; force a rebuild
    // (SQL text is unchanged, so the SQL-compare would not catch this).
    InvalidateRowMap;

    if FQuery.Active <> queryactive then
    begin
      FQuery.Active := queryactive;
    end;
  end;
end;

function TDBDataProcess.GetModule(const RecIndex: Integer): Pointer;
var
  i: LongInt;
begin
  if FAllSitesAttached then
  begin
    // See GetWebsiteName: read the site from the map, not the FQuery cursor.
    if EnsureRowMap then
    begin
      if (RecIndex >= 0) and (RecIndex < Length(FRowMap)) then
        i := FRowMap[RecIndex].SiteIndex
      else
        i := -1;
    end
    else
    if GoToRecNo(RecIndex) then
      i := FQuery.Fields[DBTempFieldWebsiteIndex].AsInteger
    else
      i := -1;

    if (i >= 0) and (i < FAttachedSites.Count) then
    begin
      Result := Pointer(FAttachedSites.Objects[i]);
    end
    else
    begin
      Result := FModule;
    end;
  end
  else
  begin
    Result := FModule;
  end;
end;

function TDBDataProcess.WebsiteLoaded(const AWebsite: String): Boolean;
var
  i: Integer;
begin
  Result := False;
  if FWebsite = AWebsite then
  begin
    Exit(True);
  end;

  if FAllSitesAttached then
  begin
    for i := 0 to FAttachedSites.Count - 1 do
    begin
      if FAttachedSites[i] = AWebsite then
      begin
        Result := True;
        Break;
      end;
    end;
  end;
end;

function TDBDataProcess.LinkExist(const ALink: String): Boolean;
var
  i: Integer;
begin
  if Assigned(FLinks) then
  begin
    Result := FLinks.Find(ALink, i);
  end
  else
  begin
    Result := False;
  end;
end;

procedure TDBDataProcess.InitLocateLink;
begin
  if Assigned(FLinks) then
  begin
    FLinks.Clear;
  end
  else
  begin
    FLinks := TStringList.Create;
  end;

  FLinks.Sorted := False;
  if FQuery.Active then
  begin
    FQuery.First;
    repeat
      FLinks.Add(FQuery.Fields[1].AsString);
      FQuery.Next;
    until FQuery.EOF;

    if FLinks.Count > 0 then
    begin
      FLinks.Sorted := True;
    end;
  end;
end;

procedure TDBDataProcess.DoneLocateLink;
begin
  if Assigned(FLinks) then
  begin
    FreeAndNil(FLinks);
  end;
end;

end.
