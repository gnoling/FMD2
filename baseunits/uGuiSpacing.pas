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
  ExtCtrls, ComCtrls, Forms;

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

procedure ApplyUniformSpacing(AParent: TWinControl; const Amount: Integer);
var
  i: Integer;
  c: TControl;
begin
  if AParent = nil then Exit;
  for i := 0 to AParent.ControlCount - 1 do
  begin
    c := AParent.Controls[i];

    // Splitters ARE the gap between panels; toolbar buttons are spaced by the
    // toolbar itself. Leave both alone.
    if (c is TSplitter) or (c is TToolButton) or (c.Parent is TToolBar) then
      Continue;

    if HasNoSpacing(c) then
      c.BorderSpacing.Around := Amount;

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
