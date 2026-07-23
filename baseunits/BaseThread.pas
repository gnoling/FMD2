unit BaseThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, MultiLog;

const
  // How long a wait for a worker thread may block before it gives up. Waits
  // done while tearing the app down get the longer one, since giving up there
  // means abandoning a thread that is still touching data we are about to
  // free; waits done in response to a click get the shorter one, because the
  // window is unresponsive for the whole duration.
  ThreadWaitTimeoutShutdown = 30000;
  ThreadWaitTimeoutInteractive = 10000;

type

  { TBaseThread }

  TBaseThread = class(TThread)
  private
    FOnCustomTerminate: TNotifyEvent;
    function GetTerminated: Boolean;
  protected
    procedure CallOnCustomTerminate; inline;
    {$if FPC_FULLVERSION >= 30202}
    procedure TerminatedSet; override;
    {$else}
  public
    procedure Terminate;
    {$endif}
  public
    constructor Create(CreateSuspended: Boolean = True);
    destructor Destroy; override;
    property IsTerminated: Boolean read GetTerminated;
    property OnCustomTerminate: TNotifyEvent read FOnCustomTerminate write FOnCustomTerminate;
  end;

// Wait for AThread to finish, but never for longer than ATimeoutMS.
//
// TThread.WaitFor called on the main thread spins on CheckSynchronize alone
// (rtl/unix/tthread.inc), so it services the synchronize queue but never runs
// the widgetset message loop: the window stops painting and stops responding
// for as long as the wait lasts, and if the worker never finishes the process
// has to be killed. Anything that waits without pumping at all -- a bare
// Sleep loop, say -- is worse still, because a worker sitting in Synchronize
// can then never complete and the two deadlock outright.
//
// This keeps the queue moving and puts a bound on the whole thing. On timeout
// it names the thread in the log and returns False, which turns "the UI froze"
// into "we waited 30s for <this>", and leaves the caller to decide whether it
// can carry on without it.
function WaitForThread(const AThread: TThread; const AWhat: String;
  const ATimeoutMS: Integer): Boolean;

implementation

const
  ThreadWaitPollMS = 10;

function WaitForThread(const AThread: TThread; const AWhat: String;
  const ATimeoutMS: Integer): Boolean;
var
  Deadline: QWord;
  OnMainThread: Boolean;
begin
  Result := True;
  if not Assigned(AThread) then Exit;

  OnMainThread := MainThreadID = GetCurrentThreadID;
  Deadline := GetTickCount64 + QWord(ATimeoutMS);

  // Finished is set before the thread runs its teardown, so this leaves the
  // loop at the same point TThread.WaitFor would have.
  while not AThread.Finished do
  begin
    if GetTickCount64 >= Deadline then
    begin
      Logger.SendWarning(Format(
        'Gave up after %dms waiting for %s to finish, it is still running.',
        [ATimeoutMS, AWhat]));
      Exit(False);
    end;
    if OnMainThread then
      CheckSynchronize(ThreadWaitPollMS)
    else
      Sleep(ThreadWaitPollMS);
  end;

  // Now that it has finished this joins instead of blocking, which is what
  // reaps the thread.
  AThread.WaitFor;
end;

{ TBaseThread }

function TBaseThread.GetTerminated: Boolean;
begin
  Result := Self.Terminated;
end;

procedure TBaseThread.CallOnCustomTerminate;
begin
  FOnCustomTerminate(Self);
end;

{$if FPC_FULLVERSION >= 30202}
procedure TBaseThread.TerminatedSet;
begin
{$else}
procedure TBaseThread.Terminate;
begin
  inherited Terminate;
{$endif}
  if Assigned(FOnCustomTerminate) then
    FOnCustomTerminate(Self);
end;

constructor TBaseThread.Create(CreateSuspended: Boolean);
begin
  inherited Create(CreateSuspended);
  FreeOnTerminate := True;
end;

destructor TBaseThread.Destroy;
begin
  inherited Destroy;
end;

end.

