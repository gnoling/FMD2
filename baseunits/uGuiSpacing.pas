{
  Small utility to give a form's controls a consistent bit of breathing room.

  FMD's forms were laid out very tightly (controls flush against each other and
  the window edges). Rather than hand-editing every .lfm, this walks the control
  tree at runtime and applies a modest BorderSpacing to any control the designer
  left with no spacing. FMD's layouts are predominantly Align/Anchor based, so
  the layout manager simply reflows with the added margins.
}
unit uGuiSpacing;

{$mode objfpc}{$H+}

interface

uses
  Controls;

const
  DEFAULT_GUI_SPACING = 3;

// Recursively apply a uniform BorderSpacing to AParent's children that have no
// designer-set spacing. Safe to call once after a form is constructed.
procedure ApplyUniformSpacing(AParent: TWinControl;
  const Amount: Integer = DEFAULT_GUI_SPACING);

// Install a global hook so every form created from now on (dialogs included)
// gets the uniform spacing automatically. Call once at startup.
procedure InstallGlobalSpacing(const Amount: Integer = DEFAULT_GUI_SPACING);

implementation

uses
  ExtCtrls, ComCtrls, Forms, GroupedEdit;

type
  TGuiSpacer = class
    Amount: Integer;
    procedure OnNewForm(Sender: TObject; Form: TCustomForm);
  end;

var
  GuiSpacer: TGuiSpacer = nil;

function HasNoSpacing(const C: TControl): Boolean;
begin
  with C.BorderSpacing do
    Result := (Around = 0) and (Left = 0) and (Top = 0) and
              (Right = 0) and (Bottom = 0);
end;

// Spacing for one edge. Controls anchored to a SIBLING's matching edge (or
// center) are alignment chains - e.g. a column of checkboxes each anchored
// AnchorSideLeft to the one above. Spacing on that edge shifts every link by
// Amount relative to its anchor and the offsets accumulate down the chain
// (that's how the Options checkboxes ended up randomly indented), so those
// edges get no spacing. Opposite-edge anchors (flow layouts) and parent-edge
// anchors (margins) keep it.
function EdgeAmount(const C: TControl; const AKind: TAnchorKind;
  const Amount: Integer): Integer;
var
  side: TAnchorSide;
begin
  Result := Amount;
  side := C.AnchorSide[AKind];
  if (side.Control = nil) or (side.Control = C.Parent) then
    Exit;
  case AKind of
    // asrTop aliases asrLeft, asrBottom aliases asrRight
    akLeft, akTop:
      if side.Side in [asrTop, asrCenter] then
        Result := 0;
    akRight, akBottom:
      if side.Side in [asrBottom, asrCenter] then
        Result := 0;
  end;
end;

// True when every child of AParent is Align=alClient - i.e. AParent is a thin
// wrapper (or overlay stack) whose content is meant to fill it exactly. The
// wrapper itself already carries the outer spacing; spacing its filler again
// stacks up an inset per nesting level (the manga cover sat 3 levels deep and
// drifted away from the info text box that has a single designed margin).
function IsFillerOnlyParent(const AParent: TWinControl): Boolean;
var
  i: Integer;
begin
  Result := AParent.ControlCount > 0;
  for i := 0 to AParent.ControlCount - 1 do
    if AParent.Controls[i].Align <> alClient then
      Exit(False);
end;

procedure ApplyUniformSpacing(AParent: TWinControl; const Amount: Integer);
var
  i: Integer;
  c: TControl;
  fillersOnly: Boolean;
begin
  if AParent = nil then Exit;
  // Composite edits (TEditButton & co) lay out their embedded edit/button
  // themselves; margins on those internals squeeze the text and detach the
  // button.
  if AParent is TCustomAbstractGroupedEdit then Exit;
  fillersOnly := IsFillerOnlyParent(AParent);
  for i := 0 to AParent.ControlCount - 1 do
  begin
    c := AParent.Controls[i];

    // Splitters ARE the gap between panels; toolbar buttons are spaced by the
    // toolbar itself. Leave both alone.
    if (c is TSplitter) or (c is TToolButton) or (c.Parent is TToolBar) then
      Continue;

    if HasNoSpacing(c) and not (fillersOnly and (c.Align = alClient)) then
    begin
      c.BorderSpacing.Left   := EdgeAmount(c, akLeft, Amount);
      c.BorderSpacing.Top    := EdgeAmount(c, akTop, Amount);
      c.BorderSpacing.Right  := EdgeAmount(c, akRight, Amount);
      c.BorderSpacing.Bottom := EdgeAmount(c, akBottom, Amount);
    end;

    if c is TWinControl then
      ApplyUniformSpacing(TWinControl(c), Amount);
  end;
end;

procedure TGuiSpacer.OnNewForm(Sender: TObject; Form: TCustomForm);
begin
  ApplyUniformSpacing(Form, Amount);
end;

procedure InstallGlobalSpacing(const Amount: Integer);
begin
  if GuiSpacer = nil then
    GuiSpacer := TGuiSpacer.Create;
  GuiSpacer.Amount := Amount;
  Screen.AddHandlerNewFormCreated(@GuiSpacer.OnNewForm);
end;

finalization
  GuiSpacer.Free;

end.
