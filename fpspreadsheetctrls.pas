{ fpspreadsheetctrls }

{@@ ----------------------------------------------------------------------------
  Unit fpspreadsheetctrls implements some visual controls which help to create
  a spreadsheet application without writing too much code.

  AUTHORS: Werner Pamler

  LICENSE: See the file COPYING.modifiedLGPL.txt, included in the Lazarus
           distribution, for details about the license.

  EXAMPLE
  * Add a WorkbookSource component to the form.
  * Add a WorksheetTabControl
  * Add a WorksheetGrid (from unit fpspreadsheetgrid)
  * Link their WorkbookSource properties to the added WorkbookSource component
  * Set the property FileName of the WorkbookSource to a spreadsheet file.

  --> The WorksheetTabControl displays tabs for each worksheet in the file, and
      the WorksheetGrid displays the worksheet according to the selected tab.
-------------------------------------------------------------------------------}
unit fpspreadsheetctrls;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ComCtrls, ValEdit, ActnList,
  fpspreadsheet, {%H-}fpsAllFormats;

type
  {@@ Event handler procedure for displaying a message if an error or
    warning occurs during reading of a workbook. }
  TsWorkbookSourceErrorEvent = procedure (Sender: TObject;
    const AMsg: String) of object;

  {@@ Describes during communication between WorkbookSource and visual controls
    which kind of item has changed: the workbook, the worksheet, a cell value,
    or a cell formatting }
  TsNotificationItem = (lniWorkbook, lniWorksheet, lniCell, lniSelection,
    lniAbortSelection);
  {@@ This set accompanies the notification between WorkbookSource and visual
    controls and describes which items have changed in the spreadsheet. }
  TsNotificationItems = set of TsNotificationItem;

  {@@ Identifier for an operation that will be executed at next cell select }
  TsPendingOperation = (poNone, poCopyFormat);

  { TsWorkbookSource }

  {@@ TsWorkbookSource links a workbook to the visual spreadsheet controls and
    help to display or edit the workbook without written code. }
  TsWorkbookSource = class(TComponent)
  private
    FWorkbook: TsWorkbook;
    FWorksheet: TsWorksheet;
    FListeners: TFPList;
    FAutoDetectFormat: Boolean;
    FFileName: TFileName;
    FFileFormat: TsSpreadsheetFormat;
    FPendingSelection: TsCellRangeArray;
    FPendingOperation: TsPendingOperation;
    FOptions: TsWorkbookOptions;
    FOnError: TsWorkbookSourceErrorEvent;

    procedure AbortSelection;
    procedure CellChangedHandler(Sender: TObject; ARow, ACol: Cardinal);
    procedure CellSelectedHandler(Sender: TObject; ARow, ACol: Cardinal);
    procedure InternalCreateNewWorkbook;
    procedure InternalLoadFromFile(AFileName: string; AAutoDetect: Boolean;
      AFormat: TsSpreadsheetFormat; AWorksheetIndex: Integer = 0);
    procedure SetFileName(const AFileName: TFileName);
    procedure SetOptions(AValue: TsWorkbookOptions);
    procedure WorksheetAddedHandler(Sender: TObject; ASheet: TsWorksheet);
    procedure WorksheetChangedHandler(Sender: TObject; ASheet: TsWorksheet);
    procedure WorksheetRemovedHandler(Sender: TObject; ASheetIndex: Integer);
    procedure WorksheetSelectedHandler(Sender: TObject; AWorksheet: TsWorksheet);

  protected
    procedure DoShowError(const AErrorMsg: String);
    procedure Loaded; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

  public
    procedure AddListener(AListener: TComponent);
    procedure RemoveListener(AListener: TComponent);
    procedure NotifyListeners(AChangedItems: TsNotificationItems; AData: Pointer = nil);

  public
    procedure CreateNewWorkbook;

    procedure LoadFromSpreadsheetFile(AFileName: string;
      AFormat: TsSpreadsheetFormat; AWorksheetIndex: Integer = 0); overload;
    procedure LoadFromSpreadsheetFile(AFileName: string;
      AWorksheetIndex: Integer = 0); overload;

    procedure SaveToSpreadsheetFile(AFileName: string;
      AOverwriteExisting: Boolean = true); overload;
    procedure SaveToSpreadsheetFile(AFileName: string; AFormat: TsSpreadsheetFormat;
      AOverwriteExisting: Boolean = true); overload;

    procedure SelectCell(ASheetRow, ASheetCol: Cardinal);
    procedure SelectWorksheet(AWorkSheet: TsWorksheet);

    procedure ExecutePendingOperation;
    procedure SetPendingOperation(AOperation: TsPendingOperation;
      const ASelection: TsCellRangeArray);

  public
    {@@ Workbook linked to the WorkbookSource }
    property Workbook: TsWorkbook read FWorkbook;
    {@@ Currently selected worksheet of the workbook }
    property Worksheet: TsWorksheet read FWorksheet;
    {@@ Indicates that which operation is waiting to be executed at next cell select }
    property PendingOperation: TsPendingOperation read FPendingOperation;

  published
    {@@ Automatically detects the fileformat when loading the spreadsheet file
      specified by FileName }
    property AutoDetectFormat: Boolean read FAutoDetectFormat write FAutoDetectFormat;
    {@@ File format of the next spreadsheet file to be loaded by means of the
      Filename property. Not used when AutoDetecteFormat is TRUE. }
    property FileFormat: TsSpreadsheetFormat read FFileFormat write FFileFormat default sfExcel8;
    {@@ Name of the loaded spreadsheet file which is loaded by assigning a file name
      to this property. Format detection is determined by the properties
      AutoDetectFormat and FileFormat. }
    property FileName: TFileName read FFileName write SetFileName;  // using this property loads the file at design-time!
    {@@ A set of options to be transferred to the workbook, for e.g. formula
      calculation etc. }
    property Options: TsWorkbookOptions read FOptions write SetOptions;
    {@@ A message box is displayey if an error occurs during loading of a
      spreadsheet. This behavior can be replaced by means of the event OnError. }
    property OnError: TsWorkbookSourceErrorEvent read FOnError write FOnError;
  end;


  { TsWorkbookTabControl }

  {@@ TsWorkbookTabControl is a tab control which displays the sheets of the
    workbook currently loaded by the WorkbookSource in tabs. Selecting another
    tab is communicated to other spreadsheet controls via the WorkbookSource. }
  TsWorkbookTabControl = class(TTabControl)
  private
    FWorkbookSource: TsWorkbookSource;
    procedure SetWorkbookSource(AValue: TsWorkbookSource);
  protected
    procedure Change; override;
    procedure GetSheetList(AList: TStrings);
    function GetWorkbook: TsWorkbook;
    function GetWorksheet: TsWorksheet;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure ListenerNotification(AChangedItems: TsNotificationItems;
      AData: Pointer = nil);
    {@@ The worksheet names of this workbook are currently displayed as tabs of the TabControl. }
    property Workbook: TsWorkbook read GetWorkbook;
    {@@ Identifies the worksheet which corresponds to the selected tab }
    property Worksheet: TsWorksheet read GetWorksheet;
  published
    {@@ Link to the WorkbookSource which provides the data. }
    property WorkbookSource: TsWorkbookSource read FWorkbookSource write SetWorkbookSource;
  end;


  { TsCellEdit }

  {@@ TsCellEdit allows to edit the content or formula of the active cell of a
    worksheet, simular to Excel's cell editor above the cell grid. }
  TsCellEdit = class(TMemo)
  private
    FWorkbookSource: TsWorkbookSource;
    function GetSelectedCell: PCell;
    function GetWorkbook: TsWorkbook;
    function GetWorksheet: TsWorksheet;
    procedure SetWorkbookSource(AValue: TsWorkbookSource);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ShowCell(ACell: PCell); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EditingDone; override;
    procedure ListenerNotification(AChangedItems: TsNotificationItems;
      AData: Pointer = nil);
    {@@ Pointer to the currently active cell in the workbook. This cell is
      displayed in the control and can be edited. }
    property SelectedCell: PCell read GetSelectedCell;
    {@@ Refers to the underlying workbook to which the edited cell belongs. }
    property Workbook: TsWorkbook read GetWorkbook;
    {@@ Refers to the underlying worksheet to which the edited cell belongs. }
    property Worksheet: TsWorksheet read GetWorksheet;
  published
    {@@ Link to the WorkbookSource which provides the workbook and worksheet. }
    property WorkbookSource: TsWorkbookSource read FWorkbookSource write SetWorkbookSource;
  end;


  { TsCellIndicator }

  {@@ TsCellIndicator displays the address of the currently active cell of the
    worksheet and workbook. Editing the address allows to jump to the corresponding
    cell. }
  TsCellIndicator = class(TEdit)
  private
    FWorkbookSource: TsWorkbookSource;
    function GetWorkbook: TsWorkbook;
    function GetWorksheet: TsWorksheet;
    procedure SetWorkbookSource(AValue: TsWorkbookSource);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EditingDone; override;
    procedure ListenerNotification(AChangedItems: TsNotificationItems;
      AData: Pointer = nil);
    {@@ Refers to the underlying worksheet to which the edited cell belongs. }
    property Workbook: TsWorkbook read GetWorkbook;
    {@@ Refers to the underlying worksheet to which the edited cell belongs. }
    property Worksheet: TsWorksheet read GetWorksheet;
  published
    {@@ Link to the WorkbookSource which provides the workbook and worksheet. }
    property WorkbookSource: TsWorkbookSource read FWorkbookSource write SetWorkbookSource;
    {@@ Inherited from TEdit, overridden to center the text in the control by default }
    property Alignment default taCenter;
  end;


  { TsCellCombobox }

  TsCellCombobox = class(TCombobox)
  private
    FWorkbookSource: TsWorkbookSource;
    function GetWorkbook: TsWorkbook;
    function GetWorksheet: TsWorksheet;
    procedure SetWorkbookSource(AValue: TsWorkbookSource);
  protected
    procedure ApplyFormatToCell(ACell: PCell); virtual;
    procedure ExtractFromCell(ACell: PCell); virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Populate; virtual;
    procedure Select; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ListenerNotification(AChangedItems: TsNotificationItems;
      AData: Pointer = nil);
    property Workbook: TsWorkbook read GetWorkbook;
    property Worksheet: TsWorksheet read GetWorksheet;
  published
    {@@ Link to the WorkbookSource which provides the workbook and worksheet. }
    property WorkbookSource: TsWorkbookSource read FWorkbookSource write SetWorkbookSource;
  end;


  { TsCellFontCombobox }

  TsCellFontCombobox = class(TsCellCombobox)
  protected
    function GetCellFont(ACell: PCell): TsFont;
  end;


  {TsFontNameCombobox }

  TsFontNameCombobox = class(TsCellFontCombobox)
  protected
    procedure ApplyFormatToCell(ACell: PCell); override;
    procedure ExtractFromCell(ACell: PCell); override;
    procedure Populate; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;


  {TsFontSizeCombobox }

  TsFontSizeCombobox = class(TsCellFontCombobox)
  protected
    procedure ApplyFormatToCell(ACell: PCell); override;
    procedure ExtractFromCell(ACell: PCell); override;
    procedure Populate; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;


  { TsSpreadsheetInspector }

  {@@ Classification of data displayed by the SpreadsheetInspector. Each item
    can be assigned to a tab of a TabControl. }
  TsInspectorMode = (imWorkbook, imWorksheet, imCellValue, imCellProperties);

  {@@ TsSpreadsheetInspector displays all properties of a workbook, worksheet,
    cell content and cell formatting in a way similar to the Object Inspector
    of Lazarus. }
  TsSpreadsheetInspector = class(TValueListEditor)
  private
    FWorkbookSource: TsWorkbookSource;
    FMode: TsInspectorMode;
    function GetWorkbook: TsWorkbook;
    function GetWorksheet: TsWorksheet;
    procedure SetMode(AValue: TsInspectorMode);
    procedure SetWorkbookSource(AValue: TsWorkbookSource);
  protected
    procedure DoUpdate; virtual;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure UpdateCellValue(ACell: PCell; AStrings: TStrings); virtual;
    procedure UpdateCellProperties(ACell: PCell; AStrings: TStrings); virtual;
    procedure UpdateWorkbook(AWorkbook: TsWorkbook; AStrings: TStrings); virtual;
    procedure UpdateWorksheet(ASheet: TsWorksheet; AStrings: TStrings); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ListenerNotification(AChangedItems: TsNotificationItems;
      AData: Pointer = nil);
    {@@ Refers to the underlying workbook which is displayed by the inspector. }
    property Workbook: TsWorkbook read GetWorkbook;
    {@@ Refers to the underlying worksheet which is displayed by the inspector. }
    property Worksheet: TsWorksheet read GetWorksheet;
  published
    {@@ Refers to the underlying worksheet from which the active cell is taken }
    property WorkbookSource: TsWorkbookSource read FWorkbookSource write SetWorkbookSource;
    {@@ Classification of data displayed by the SpreadsheetInspector. Each mode
      can be assigned to a tab of a TabControl. }
    property Mode: TsInspectorMode read FMode write SetMode;
    {@@ inherited from TValueListEditor, activates column titles and automatic
      column width adjustment by default }
    property DisplayOptions default [doColumnTitles, doAutoColResize];
    {@@ inherited from TValueListEditor. Turns of the fixed column by default}
    property FixedCols default 0;
  end;


procedure Register;


implementation

uses
  Types, TypInfo, Dialogs, Forms,
  fpsStrings, fpsUtils, fpSpreadsheetGrid;


{@@ ----------------------------------------------------------------------------
  Registers the spreadsheet components in the Lazarus component palette,
  page "FPSpreadsheet".
-------------------------------------------------------------------------------}
procedure Register;
begin
  RegisterComponents('FPSpreadsheet', [
    TsWorkbookSource, TsWorkbookTabControl, TsWorksheetGrid,
    TsCellEdit, TsCellIndicator, TsFontNameCombobox, TsFontSizeCombobox,
    TsSpreadsheetInspector
  ]);
end;


{------------------------------------------------------------------------------}
{                            TsWorkbookSource                                  }
{------------------------------------------------------------------------------}

{@@ ----------------------------------------------------------------------------
  Constructor of the WorkbookSource class. Creates the internal list for the
  notified ("listening") components, and creates an empty workbook.

  @param  AOwner  Component which is responsibile for destroying the
                  WorkbookSource.
-------------------------------------------------------------------------------}
constructor TsWorkbookSource.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FListeners := TFPList.Create;
  FFileFormat := sfExcel8;
  CreateNewWorkbook;
end;

{@@ ----------------------------------------------------------------------------
  Destructor of the WorkbookSource class.
  Cleans up the of listening component list and destroys the linked workbook.
-------------------------------------------------------------------------------}
destructor TsWorkbookSource.Destroy;
var
  i: Integer;
begin
  // Tell listeners that the workbook source will no longer exist
  for i:= FListeners.Count-1 downto 0 do
    RemoveListener(TComponent(FListeners[i]));
  // Destroy listener list
  FListeners.Free;
  // Destroy the instance of the workbook
  FWorkbook.Free;
  inherited Destroy;
end;

{@@ ----------------------------------------------------------------------------
  Generates a message to the grid to abort the selection process.
  Needed when copying a format (e.g.) cannot be executed due to overlapping
  ranges. Without the message, the grid would still be in selection mode.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.AbortSelection;
begin
  NotifyListeners([lniAbortSelection], nil);
end;

{@@ ----------------------------------------------------------------------------
  Adds a component to the listener list. All these components are notified of
  changes in the workbook.

  @param  AListener  Component to be added to the listener list notified of
                     changes
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.AddListener(AListener: TComponent);
begin
  if FListeners.IndexOf(AListener) = -1 then  // Avoid duplicates
    FListeners.Add(AListener);
end;

{@@ ----------------------------------------------------------------------------
  Event handler for the OnChangeCell event of TsWorksheet which is fired whenver
  cell content or formatting changes.

  @param   Sender   Pointer to the worksheet
  @param   ARow     Row index (in sheet notation) of the cell changed
  @param   ACol     Column index (in sheet notation) of the cell changed
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.CellChangedHandler(Sender: TObject;
  ARow, ACol: Cardinal);
begin
  if FWorksheet <> nil then
    NotifyListeners([lniCell], FWorksheet.FindCell(ARow, ACol));
end;

{@@ ----------------------------------------------------------------------------
  Event handler for the OnSelectCell event of TsWorksheet which is fired
  whenever another cell is selected in the worksheet. Notifies the listeners
  of the changed selection.

  @param  Sender   Pointer to the worksheet
  @param  ARow     Row index (in sheet notation) of the newly selected cell
  @param  ACol     Column index (in sheet notation) of the newly selected cell
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.CellSelectedHandler(Sender: TObject;
  ARow, ACol: Cardinal);
begin
  Unused(ARow, ACol);
  NotifyListeners([lniSelection]);

  if FPendingOperation <> poNone then
  begin
    ExecutePendingOperation;
    FPendingOperation := poNone;
  end;
end;

{@@ ----------------------------------------------------------------------------
  Creates a new empty workbook and adds a single worksheet
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.CreateNewWorkbook;
begin
  InternalCreateNewWorkbook;
  FWorksheet := FWorkbook.AddWorksheet('Sheet1');
  SelectWorksheet(FWorksheet);

  // notify listeners
  NotifyListeners([lniWorkbook, lniWorksheet, lniSelection]);
end;

{@@ ----------------------------------------------------------------------------
  An error has occured during loading of the workbook. Shows a message box by
  default. But a different behavior can be obtained by means of the OnError
  event.

  @param  AErrorMsg  Error message text created by the workbook reader and to be
                     displayed in a messagebox or by means of the OnError
                     handler.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.DoShowError(const AErrorMsg: String);
begin
  if Assigned(FOnError) then
    FOnError(self, AErrorMsg)
  else
    MessageDlg(AErrorMsg, mtError, [mbOK], 0);
end;

{@@ ----------------------------------------------------------------------------
  Executes a "pending operation"
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.ExecutePendingOperation;
var
  destSelection: TsCellRangeArray;
  srcCell, destCell: PCell;    // Pointers to source and destination cells
  i, j, k: Integer;
  ofsRow, ofsCol: LongInt;

  function DistinctRanges(R1, R2: TsCellRange): Boolean;
  begin
    Result := (R2.Col1 > R1.Col2) or (R1.Col1 > R2.Col2) or
              (R2.Row1 > R1.Row2) or (R1.Row1 > R2.Row2);
  end;

begin
  ofsRow := Worksheet.ActiveCellRow - FPendingSelection[0].Row1;
  ofsCol := Worksheet.ActiveCellCol - FPendingSelection[0].Col1;

  // Calculate destination ranges which begin at the active cell
  SetLength(destSelection, Length(FPendingSelection));
  for i := 0 to High(FPendingSelection) do
    destSelection[i] := TsCellRange(Rect(
      FPendingSelection[i].Row1 + ofsRow,
      FPendingSelection[i].Col1 + ofsCol,
      FPendingSelection[i].Row2 + ofsRow,
      FPendingSelection[i].Col2 + ofsCol
    ));

  // Check for intersection between source and destination ranges
  for i:=0 to High(FPendingSelection) do
    for j:=0 to High(FPendingSelection) do
      if not DistinctRanges(FPendingSelection[i], destSelection[j]) then
      begin
        MessageDlg('Source and destination selections are overlapping. Operation aborted.',
          mtError, [mbOK], 0);
        AbortSelection;
        exit;
      end;

  // Execute pending operation
  for i:=0 to High(FPendingSelection) do
    for j:=0 to FPendingSelection[i].Row2-FPendingSelection[i].Row1 do
      for k:=0 to FPendingSelection[i].Col2-FPendingSelection[i].Col1 do
      begin
        srcCell := Worksheet.FindCell(FPendingSelection[i].Row1+j, FPendingSelection[i].Col1+k);
        destCell := Worksheet.GetCell(destSelection[i].Row1+j, destSelection[i].Col1+k);
        case FPendingOperation of
          poCopyFormat: Worksheet.CopyFormat(srcCell, destCell);
        end;
      end;
end;

{@@ ----------------------------------------------------------------------------
  Internal helper method which creates a new workbook without sheets
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.InternalCreateNewWorkbook;
begin
  FreeAndNil(FWorkbook);
  FWorksheet := nil;
  FWorkbook := TsWorkbook.Create;
  FWorkbook.OnAddWorksheet := @WorksheetAddedHandler;
  FWorkbook.OnChangeWorksheet := @WorksheetChangedHandler;
  FWorkbook.OnRemoveWorksheet := @WorksheetRemovedHandler;
  FWorkbook.OnSelectWorksheet := @WorksheetSelectedHandler;
  // Pass options to workbook
  SetOptions(FOptions);
end;

{@@ ----------------------------------------------------------------------------
  Internal loader for the spreadsheet file. Is called with various combinations
  of arguments from several procedures.

  @param  AFilename        Name of the spreadsheet file to be loaded
  @param  AAutoDetect      Instructs the loader to automatically detect the
                           file format from the file extension or by temporarily
                           opening the file in all available formats. Note that
                           an exception is raised in the IDE when an incorrect
                           format is tested.
  @param  AFormat          Spreadsheet file format assumed for the loadeder.
                           Is ignored when AAutoDetect is false.
  @param  AWorksheetIndex  Index of the worksheet to be selected after loading.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.InternalLoadFromFile(AFileName: string;
  AAutoDetect: Boolean; AFormat: TsSpreadsheetFormat; AWorksheetIndex: Integer = 0);
begin
  // Create a new empty workbook
  InternalCreateNewWorkbook;

  // Read workbook from file and get worksheet
  if AAutoDetect then
    FWorkbook.ReadFromFile(AFileName)
  else
    FWorkbook.ReadFromFile(AFileName, AFormat);

  SelectWorksheet(FWorkbook.GetWorkSheetByIndex(AWorksheetIndex));

  // If required, display loading error message
  if FWorkbook.ErrorMsg <> '' then
    DoShowError(FWorkbook.ErrorMsg);
end;

{@@ ----------------------------------------------------------------------------
  Inherited method which is called after reading the WorkbookSource from the lfm
  file.
  Is overridden here to open a spreadsheet file if a file name has been assigned
  to the FileName property at design-time.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.Loaded;
begin
  inherited;
  if (FFileName <> '') then
    SetFileName(FFilename);
end;

{@@ ----------------------------------------------------------------------------
  Public spreadsheet loader to be used if file format is known.

  @param  AFilename        Name of the spreadsheet file to be loaded
  @param  AFormat          Spreadsheet file format assumed for the file
  @param  AWorksheetIndex  Index of the worksheet to be selected after loading.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.LoadFromSpreadsheetFile(AFileName: string;
  AFormat: TsSpreadsheetFormat; AWorksheetIndex: Integer = 0);
begin
  InternalLoadFromFile(AFileName, false, AFormat, AWorksheetIndex);
end;

{@@ ------------------------------------------------------------------------------
  Public spreadsheet loader to be used if file format is not known. The file
  format is determined from the file extension, or - if this is holds for
  several formats (such as .xls) - by assuming a format. Note that exceptions
  are raised in the IDE if in incorrect format is tested. This does not occur
  outside the IDE.

  @param  AFilename        Name of the spreadsheet file to be loaded
  @param  AWorksheetIndex  Index of the worksheet to be selected after loading.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.LoadFromSpreadsheetFile(AFileName: string;
  AWorksheetIndex: Integer = 0);
const
  sfNotNeeded = sfExcel8;
  // The parameter AFormat if InternalLoadFromFile is not needed here,
  // but the compiler wants a value...
begin
  InternalLoadFromFile(AFileName, true, sfNotNeeded, AWorksheetIndex);
end;

{@@ ----------------------------------------------------------------------------
  Notifies listeners of workbook, worksheet, cell, or selection changes.
  The changed item is identified by the parameter AChangedItems.

  @param  AChangedItems  A set of elements lniWorkbook, lniWorksheet,
                         lniCell, lniSelection which indicate which item has
                         changed.
  @param  AData          Additional information on the change. Is used only for
                         lniCell and points to the cell having a changed value
                         or formatting.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.NotifyListeners(AChangedItems: TsNotificationItems;
  AData: Pointer = nil);
var
  i: Integer;
begin
  for i:=0 to FListeners.Count-1 do
    if TObject(FListeners[i]) is TsCellCombobox then
      TsCellCombobox(FListeners[i]).ListenerNotification(AChangedItems, AData)
    else
    if TObject(FListeners[i]) is TsCellIndicator then
      TsCellIndicator(FListeners[i]).ListenerNotification(AChangedItems, AData)
    else
    if TObject(FListeners[i]) is TsCellEdit then
      TsCellEdit(FListeners[i]).ListenerNotification(AChangedItems, AData)
    else
    if TObject(FListeners[i]) is TsWorkbookTabControl then
      TsWorkbookTabControl(FListeners[i]).ListenerNotification(AChangedItems, AData)
    else
    if TObject(FListeners[i]) is TsWorksheetGrid then
      TsWorksheetGrid(FListeners[i]).ListenerNotification(AChangedItems, AData)
    else
    if TObject(FListeners[i]) is TsSpreadsheetInspector then
      TsSpreadsheetInspector(FListeners[i]).ListenerNotification(AChangedItems, AData)
    else                                    {
    if TObject(FListeners[i]) is TsSpreadsheetAction then
      TsSpreadsheetAction(FListeners[i]).ListenerNotifiation(AChangedItems, AData)
    else                                     }
      raise Exception.CreateFmt('Class %s is not prepared to be a spreadsheet listener.',
        [TObject(FListeners[i]).ClassName]);
end;

{@@ ----------------------------------------------------------------------------
  Removes a component from the listener list. The component is no longer
  notified of changes in workbook, worksheet or cells

  @param  AListener  Listening component to be removed
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.RemoveListener(AListener: TComponent);
var
  i: Integer;
begin
  for i:= FListeners.Count-1 downto 0 do
    if TComponent(FListeners[i]) = AListener then
    begin
      FListeners.Delete(i);
      if (AListener is TsCellCombobox) then
        TsCellCombobox(AListener).WorkbookSource := nil
      else
      if (AListener is TsCellIndicator) then
        TsCellIndicator(AListener).WorkbookSource := nil
      else
      if (AListener is TsCellEdit) then
        TsCellEdit(AListener).WorkbookSource := nil
      else
      if (AListener is TsWorkbookTabControl) then
        TsWorkbookTabControl(AListener).WorkbookSource := nil
      else
      if (AListener is TsWorksheetGrid) then
        TsWorksheetGrid(AListener).WorkbookSource := nil
      else
      if (AListener is TsSpreadsheetInspector) then
        TsSpreadsheetInspector(AListener).WorkbookSource := nil
      else                         {
      if (AListener is TsSpreadsheetAction) then
        TsSpreadsheetAction(AListener).WorksheetLink := nil
      else                          }
        raise Exception.CreateFmt('Class %s not prepared for listening.',[AListener.ClassName]);
      exit;
    end;
end;

{@@ ----------------------------------------------------------------------------
  Writes the workbook of the WorkbookSource component to a spreadsheet file.

  @param   AFileName          Name of the file to which the workbook is to be
                              saved.
  @param   AFormat            Spreadsheet file format in which the file is to be
                              saved.
  @param   AOverwriteExisting If the file already exists, it is overwritten in
                              the case of AOverwriteExisting = true, or an
                              exception is raised otherwise.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SaveToSpreadsheetFile(AFileName: String;
  AFormat: TsSpreadsheetFormat; AOverwriteExisting: Boolean = true);
begin
  if FWorkbook <> nil then begin
    FWorkbook.WriteToFile(AFileName, AFormat, AOverwriteExisting);

    // If required, display loading error message
    if FWorkbook.ErrorMsg <> '' then
      DoShowError(FWorkbook.ErrorMsg);
  end;
end;

{@@ ----------------------------------------------------------------------------
  Saves the workbook into a file with the specified file name.
  The file format is determined automatically from the extension.
  If this file name already exists the file is overwritten
  if AOverwriteExisting is true.

  @param   AFileName          Name of the file to which the workbook is to be
                              saved
                              If the file format is not known is is written
                              as BIFF8/XLS.
  @param   AOverwriteExisting If this file already exists it is overwritten if
                              AOverwriteExisting = true, or an exception is
                              raised if AOverwriteExisting = false.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SaveToSpreadsheetFile(AFileName: String;
  AOverwriteExisting: Boolean = true);
begin
  if FWorkbook <> nil then begin
    FWorkbook.WriteToFile(AFileName, AOverwriteExisting);

    // If required, display loading error message
    if FWorkbook.ErrorMsg <> '' then
      DoShowError(FWorkbook.ErrorMsg);
  end;
end;

{@@ ----------------------------------------------------------------------------
  Usually called by code or from the spreadsheet grid component. The
  method identifies a cell to be "selected".
  Stores its coordinates in the worksheet ("active cell") and notifies the
  listening controls
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SelectCell(ASheetRow, ASheetCol: Cardinal);
begin
  if FWorksheet <> nil then
  begin
    FWorksheet.SelectCell(ASheetRow, ASheetCol);
    NotifyListeners([lniSelection]);
  end;
end;

{@@ ----------------------------------------------------------------------------
  Selects a worksheet and notifies the controls. This method is usually called
  by code or from the worksheet tabcontrol.

  @param  AWorksheet  Instance of the newly selected worksheet.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SelectWorksheet(AWorkSheet: TsWorksheet);
begin
  FWorksheet := AWorksheet;
  if (FWorkbook <> nil) then
    FWorkbook.SelectWorksheet(AWorksheet);
end;

{@@ ----------------------------------------------------------------------------
  Setter for the file name property. Loads the spreadsheet file and uses the
  values of the properties AutoDetectFormat or FileFormat.
  Useful if the spreadsheet is to be loaded already at design time.
  But note that an exception can be raised if the file format cannot be
  determined from the file extension alone.

  @param  AFileName  Name of the spreadsheet file to be loaded.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SetFileName(const AFileName: TFileName);
begin
  if AFileName = '' then
  begin
    CreateNewWorkbook;
    FFileName := '';
    exit;
  end;

  if FileExists(AFileName) then
  begin
    if FAutoDetectFormat then
      LoadFromSpreadsheetFile(AFileName)
    else
      LoadFromSpreadsheetFile(AFileName, FFileFormat);
    FFileName := AFileName;
  end else
    raise Exception.CreateFmt(rsFileNotFound, [AFileName]);
end;

{@@ ----------------------------------------------------------------------------
  Setter for the property Options. Copies the options of the WorkbookSource
  to the workbook
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SetOptions(AValue: TsWorkbookOptions);
begin
  FOptions := AValue;
  if Workbook <> nil then
    Workbook.Options := FOptions;
end;

{@@ ----------------------------------------------------------------------------
  Defines a "pending operation" which will be executed at next cell select.
  Source of the operation is the selection passes as a parameter.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.SetPendingOperation(AOperation: TsPendingOperation;
  const ASelection: TsCellRangeArray);
var
  i: Integer;
begin
  SetLength(FPendingSelection, Length(ASelection));
  for i:=0 to High(FPendingSelection) do
    FPendingSelection[i] := ASelection[i];
  FPendingSelection := ASelection;
  FPendingOperation := AOperation;
end;

{@@ ----------------------------------------------------------------------------
  Event handler called whenever a new worksheet is added to the workbook

  @param  Sender   Pointer to the workbook to which a new worksheet has been added
  @param  ASheet   Worksheet which is added to the workbook.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.WorksheetAddedHandler(Sender: TObject;
  ASheet: TsWorksheet);
begin
  NotifyListeners([lniWorkbook]);
  SelectWorksheet(ASheet);
end;

{@@ ----------------------------------------------------------------------------
  Event handler canned whenever worksheet properties have changed.
  Currently only used for changing the workbook name.

  @param  Sender  Workbook containing the modified worksheet
  @param  ASheet  Worksheet which has been modified
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.WorksheetChangedHandler(Sender: TObject;
  ASheet: TsWorksheet);
begin
  Unused(ASheet);
  NotifyListeners([lniWorkbook, lniWorksheet]);
end;

{@@ ----------------------------------------------------------------------------
  Event handler called AFTER a worksheet has been removed (deleted) from
  the workbook

  @param  Sender       Points to the workbook from which the sheet has been
                       deleted
  @param  ASheetIndex  Index of the sheet that was deleted. The sheet itself
                       does not exist any more.
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.WorksheetRemovedHandler(Sender: TObject;
  ASheetIndex: Integer);
var
  i, sheetCount: Integer;
  sheet: TsWorksheet;
begin
  // It is very possible that the currently selected worksheet has been deleted.
  // Look for the selected worksheet in the workbook. Does it still exist? ...
  i := Workbook.GetWorksheetIndex(FWorksheet);
  if i = -1 then
  begin
    // ... no - it must have been the sheet deleted.
    // We have to select another worksheet.
    sheetCount := Workbook.GetWorksheetCount;
    if (ASheetIndex >= sheetCount) then
      sheet := Workbook.GetWorksheetByIndex(sheetCount-1)
    else
      sheet := Workbook.GetWorksheetbyIndex(ASheetIndex);
  end else
    sheet := FWorksheet;
  NotifyListeners([lniWorkbook]);
  SelectWorksheet(sheet);
end;

{@@ ----------------------------------------------------------------------------
  Event handler called whenever a the workbook makes a worksheet "active".

  @param  Sender      Workbook containing the worksheet
  @param  AWorksheet  Worksheet which has been activated
-------------------------------------------------------------------------------}
procedure TsWorkbookSource.WorksheetSelectedHandler(Sender: TObject;
  AWorksheet: TsWorksheet);
begin
  FWorksheet := AWorksheet;
  if FWorksheet <> nil then
  begin
    FWorksheet.OnChangeCell := @CellChangedHandler;
    FWorksheet.OnSelectCell := @CellSelectedHandler;
    FWorksheet.OnChangeFont := @CellChangedHandler;
    NotifyListeners([lniWorksheet]);
    SelectCell(FWorksheet.ActiveCellRow, FWorksheet.ActiveCellCol);
  end else
    NotifyListeners([lniWorksheet]);
end;


{------------------------------------------------------------------------------}
{                            TsWorkbookTabControl                              }
{------------------------------------------------------------------------------}

{@@ ----------------------------------------------------------------------------
  Destructor of the WorkbookTabControl.
  Removes itself from the WorkbookSource's listener list.
-------------------------------------------------------------------------------}
destructor TsWorkbookTabControl.Destroy;
begin
  if FWorkbookSource <> nil then FWorkbookSource.RemoveListener(self);
  inherited Destroy;
end;

{@@ ----------------------------------------------------------------------------
  The currently active tab has been changed. The WorkbookSource must activate
  the corresponding worksheet and notify its listening components of the change.
-------------------------------------------------------------------------------}
procedure TsWorkbookTabControl.Change;
begin
  if FWorkbookSource <> nil then
    FWorkbookSource.SelectWorksheet(Workbook.GetWorksheetByIndex(TabIndex));
  inherited;
end;

{@@ ----------------------------------------------------------------------------
  Creates a (string) list containing the names of the workbook's sheet names.
  Is called whenever the workbook changes.
-------------------------------------------------------------------------------}
procedure TsWorkbookTabControl.GetSheetList(AList: TStrings);
var
  i: Integer;
begin
  AList.Clear;
  if Workbook <> nil then
    for i:=0 to Workbook.GetWorksheetCount-1 do
      AList.Add(Workbook.GetWorksheetByIndex(i).Name);
end;

{@@ ----------------------------------------------------------------------------
  Getter method for property "Workbook"
-------------------------------------------------------------------------------}
function TsWorkbookTabControl.GetWorkbook: TsWorkbook;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Workbook
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for property "Worksheet"
-------------------------------------------------------------------------------}
function TsWorkbookTabControl.GetWorksheet: TsWorksheet;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Worksheet
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Notification message received from the WorkbookSource telling which
  spreadsheet item has changed.
  Responds to workbook changes by reading the worksheet names into the tabs,
  and to worksheet changes by selecting the tab corresponding to the selected
  worksheet.

  @param  AChangedItems  Set with elements identifying whether workbook, worksheet
                         cell content or cell formatting has changed
  @param  AData          Additional data, not used here
-------------------------------------------------------------------------------}
procedure TsWorkbookTabControl.ListenerNotification(
  AChangedItems: TsNotificationItems; AData: Pointer = nil);
var
  i: Integer;
  oldTabIndex: Integer;
  list: TStringList;
begin
  Unused(AData);

  // Workbook changed
  if (lniWorkbook in AChangedItems) then
  begin
    oldTabIndex := TabIndex;
    list := TStringList.Create;
    Tabs.BeginUpdate;
    try
      GetSheetList(list);
      Tabs.Assign(list);
      if (oldTabIndex = -1) and (Tabs.Count > 0) then
        TabIndex := 0
      else
      if oldTabIndex < Tabs.Count then
        TabIndex := oldTabIndex;
    finally
      list.Free;
      Tabs.EndUpdate;
    end;
  end;

  // Worksheet changed
  if (lniWorksheet in AChangedItems) and (Worksheet <> nil) then
  begin
    i := Tabs.IndexOf(Worksheet.Name);
    if i <> TabIndex then
      TabIndex := i;
  end;
end;

{@@ ----------------------------------------------------------------------------
  Standard component notification. Must clean up the WorkbookSource field
  when the workbook source is going to be deleted.
-------------------------------------------------------------------------------}
procedure TsWorkbookTabControl.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FWorkbookSource) then
    SetWorkbookSource(nil);
end;

{@@ ----------------------------------------------------------------------------
  Setter method for the WorkbookSource
-------------------------------------------------------------------------------}
procedure TsWorkbookTabControl.SetWorkbookSource(AValue: TsWorkbookSource);
begin
  if AValue = FWorkbookSource then
    exit;
  if FWorkbookSource <> nil then
    FWorkbookSource.RemoveListener(self);
  FWorkbookSource := AValue;
  if FWorkbookSource <> nil then
    FWorkbookSource.AddListener(self);
  ListenerNotification([lniWorkbook, lniWorksheet]);
end;


{------------------------------------------------------------------------------}
{                               TsCellEdit                                     }
{------------------------------------------------------------------------------}

{@@ ----------------------------------------------------------------------------
  Constructor of the spreadsheet edit control. Disables RETURN and TAB keys.
  RETURN characters can still be entered into the edited text by pressing
  CTRL+RETURN

  @param   AOwner   Component which is responsible to destroy the CellEdit
-------------------------------------------------------------------------------}
constructor TsCellEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  WantReturns := false;
  WantTabs := false;
  AutoSize := true;
end;

{@@ ----------------------------------------------------------------------------
  Destructor of the TsCellEdit. Removes itself from the WorkbookSource's
  listener list.
-------------------------------------------------------------------------------}
destructor TsCellEdit.Destroy;
begin
  if FWorkbookSource <> nil then FWorkbookSource.RemoveListener(self);
  inherited Destroy;
end;

{@@ ----------------------------------------------------------------------------
  EditingDone is called when the user presses the RETURN key to finish editing,
  or the TAB key which removes focus from the control, or clicks somewhere else
  The edited text is written to the worksheet which tries to figure out the
  data type. In particular, if the text begins with an equal sign ("=") then
  the text is assumed to be a formula.
-------------------------------------------------------------------------------}
procedure TsCellEdit.EditingDone;
var
  r, c: Cardinal;
  s: String;
begin
  if Worksheet = nil then
    exit;
  r := Worksheet.ActiveCellRow;
  c := Worksheet.ActiveCellCol;
  s := Lines.Text;
  if (s <> '') and (s[1] = '=') then
    Worksheet.WriteFormula(r, c, Copy(s, 2, Length(s)), true)
  else
    Worksheet.WriteCellValueAsString(r, c, s);
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property SelectedCell which points to the currently
  active cell in the selected worksheet
-------------------------------------------------------------------------------}
function TsCellEdit.GetSelectedCell: PCell;
begin
  if (Worksheet <> nil) then
    with Worksheet do
      Result := FindCell(ActiveCellRow, ActiveCellCol)
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Workbook which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsCellEdit.GetWorkbook: TsWorkbook;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Workbook
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Worksheet which is currently "selected" in the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsCellEdit.GetWorksheet: TsWorksheet;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Worksheet
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Notification message received from the WorkbookSource telling which item
  of the spreadsheet has changed.
  Responds to selection and cell changes by updating the cell content.

  @param  AChangedItems  Set with elements identifying whether workbook, worksheet
                         cell content or cell formatting has changed
  @param  AData          If AChangedItems contains nliCell then AData points to
                         the modified cell.
-------------------------------------------------------------------------------}
procedure TsCellEdit.ListenerNotification(
  AChangedItems: TsNotificationItems; AData: Pointer = nil);
begin
  if (FWorkbookSource = nil) then
    exit;

  if  (lniSelection in AChangedItems) or
     ((lniCell in AChangedItems) and (PCell(AData) = SelectedCell))
  then
    ShowCell(SelectedCell);
end;

{@@ ----------------------------------------------------------------------------
  Standard component notification. Called when the WorkbookSource is deleted.
-------------------------------------------------------------------------------}
procedure TsCellEdit.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FWorkbookSource) then
    SetWorkbookSource(nil);
end;

{@@ ----------------------------------------------------------------------------
  Setter method for the WorkbookSource
-------------------------------------------------------------------------------}
procedure TsCellEdit.SetWorkbookSource(AValue: TsWorkbookSource);
begin
  if AValue = FWorkbookSource then
    exit;
  if FWorkbookSource <> nil then
    FWorkbookSource.RemoveListener(self);
  FWorkbookSource := AValue;
  if FWorkbookSource <> nil then
    FWorkbookSource.AddListener(self);
  Text := '';
  ListenerNotification([lniSelection]);
end;

{@@ ----------------------------------------------------------------------------
  Loads the contents of a cell into the editor.
  Shows the formula if available, but not the calculation result.
  Numbers are displayed in full precision.
  Date and time values are shown in the long formats.

  @param  ACell  Pointer to the cell loaded into the cell editor.
-------------------------------------------------------------------------------}
procedure TsCellEdit.ShowCell(ACell: PCell);
var
  s: String;
begin
  if (FWorkbookSource <> nil) and (ACell <> nil) then
  begin
    s := Worksheet.ReadFormulaAsString(ACell, true);
    if s <> '' then begin
      if s[1] <> '=' then s := '=' + s;
      Lines.Text := s;
    end else
      case ACell^.ContentType of
        cctNumber:
          Lines.Text := FloatToStr(ACell^.NumberValue);
        cctDateTime:
          if ACell^.DateTimeValue < 1.0 then
            Lines.Text := FormatDateTime('tt', ACell^.DateTimeValue)
          else
            Lines.Text := FormatDateTime('c', ACell^.DateTimeValue);
        else
          Lines.Text := Worksheet.ReadAsUTF8Text(ACell);
      end;
  end else
    Clear;
end;


{------------------------------------------------------------------------------}
{                              TsCellIndicator                                 }
{------------------------------------------------------------------------------}

{@@ ----------------------------------------------------------------------------
  Constructor of the TsCellIndicator class. Is overridden to set the default
  value of the Alignment property to taCenter.
-------------------------------------------------------------------------------}
constructor TsCellIndicator.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Alignment := taCenter;
end;

{@@ ----------------------------------------------------------------------------
  Destructor of the cell indicator. Removes itself from the WorkbookSource's
  listener list.
-------------------------------------------------------------------------------}
destructor TsCellIndicator.Destroy;
begin
  if FWorkbookSource <> nil then FWorkbookSource.RemoveListener(self);
  inherited Destroy;
end;

{@@ ----------------------------------------------------------------------------
  EditingDone is called when the user presses the RETURN key to finish editing,
  or the TAB key which removes focus from the control, or clicks somewhere else
  The edited text is interpreted as a cell address. The corresponding cell is
  selected.
-------------------------------------------------------------------------------}
procedure TsCellIndicator.EditingDone;
var
  r, c: Cardinal;
begin
  if (WorkbookSource <> nil) and ParseCellString(Text, r, c) then
    WorkbookSource.SelectCell(r, c);
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Workbook which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsCellIndicator.GetWorkbook: TsWorkbook;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Workbook
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Worksheet which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsCellIndicator.GetWorksheet: TsWorksheet;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Worksheet
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  The cell indicator reacts to notification that the selection has changed
  and displays the address of the newly selected cell as editable text.

  @param  AChangedItems  Set with elements identifying whether workbook, worksheet
                         cell or selection has changed. Only the latter element
                         is considered by the cell indicator.
  @param  AData          If AChangedItems contains nliCell then AData points to
                         the modified cell.
-------------------------------------------------------------------------------}
procedure TsCellIndicator.ListenerNotification(AChangedItems: TsNotificationItems;
  AData: Pointer = nil);
begin
  Unused(AData);
  if (lniSelection in AChangedItems) and (Worksheet <> nil) then
    Text := GetCellString(Worksheet.ActiveCellRow, Worksheet.ActiveCellCol);
end;

{@@ ----------------------------------------------------------------------------
  Standard component notification called when the WorkbookSource is deleted.
-------------------------------------------------------------------------------}
procedure TsCellIndicator.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FWorkbookSource) then
    SetWorkbooksource(nil);
end;

{@@ ----------------------------------------------------------------------------
  Setter method for the WorkbookSource
-------------------------------------------------------------------------------}
procedure TsCellIndicator.SetWorkbookSource(AValue: TsWorkbookSource);
begin
  if AValue = FWorkbookSource then
    exit;
  if FWorkbookSource <> nil then
    FWorkbookSource.RemoveListener(self);
  FWorkbookSource := AValue;
  if FWorkbookSource <> nil then
    FWorkbookSource.AddListener(self);
  Text := '';
  ListenerNotification([lniSelection]);
end;


{------------------------------------------------------------------------------}
{                               TsCellCombobox                                 }
{------------------------------------------------------------------------------}

{@@ ----------------------------------------------------------------------------
  Constructor of the Cell Combobox. Populates the items list
-------------------------------------------------------------------------------}
constructor TsCellCombobox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Populate;
end;

{@@ ----------------------------------------------------------------------------
  Destructor of the WorkbookTabControl.
  Removes itself from the WorkbookSource's listener list.
-------------------------------------------------------------------------------}
destructor TsCellCombobox.Destroy;
begin
  if FWorkbookSource <> nil then FWorkbookSource.RemoveListener(self);
  inherited Destroy;
end;

{@@ ----------------------------------------------------------------------------
  Applies the format to a cell. Override according to the format item for
  which the combobox is responsible.
-------------------------------------------------------------------------------}
procedure TsCellCombobox.ApplyFormatToCell(ACell: PCell);
begin
end;

{@@ ----------------------------------------------------------------------------
  Extracts the format item the combobox is responsible for from the cell and
  selectes the corresponding combobox item.
-------------------------------------------------------------------------------}
procedure TsCellCombobox.ExtractFromCell(ACell: PCell);
begin
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Workbook which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsCellCombobox.GetWorkbook: TsWorkbook;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Workbook
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Worksheet which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsCellCombobox.GetWorksheet: TsWorksheet;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Worksheet
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Notification procedure received whenver "something" changes in the workbook.
  Reacts on all events.

  @param  AChangedItems  Set with elements identifying whether workbook, worksheet
                         cell or selection has changed.
  @param  AData          If AChangedItems contains nliCell then AData points to
                         the modified cell.
-------------------------------------------------------------------------------}
procedure TsCellCombobox.ListenerNotification(
  AChangedItems: TsNotificationItems; AData: Pointer = nil);
var
  activeCell: PCell;
begin
  Unused(AData);
  if worksheet = nil then
    exit;
  activeCell := Worksheet.FindCell(Worksheet.ActiveCellRow, Worksheet.ActiveCellCol);
  if ((lniCell in AChangedItems) and (PCell(AData) = activeCell)) or
     (lniSelection in AChangedItems)
  then
    ExtractFromCell(activeCell);
end;

{@@ ----------------------------------------------------------------------------
  Standard component notification method called when the WorkbookSource
  is deleted.
-------------------------------------------------------------------------------}
procedure TsCellCombobox.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FWorkbookSource) then
    SetWorkbookSource(nil);
end;

{@@ ----------------------------------------------------------------------------
  Descendants override this method to populate the items of the combobox.
-------------------------------------------------------------------------------}
procedure TsCellCombobox.Populate;
begin
end;

{@@ ----------------------------------------------------------------------------
  A new item in the combobox is selected. Changes the selected cells according
  to the Mode property by calling ApplyFormatToCell.
-------------------------------------------------------------------------------}
procedure TsCellCombobox.Select;
var
  r, c: Cardinal;
  range: Integer;
  sel: TsCellRangeArray;
  cell: PCell;
begin
  inherited Select;
  if Worksheet = nil then
    exit;
  sel := Worksheet.GetSelection;
  for range := 0 to High(sel) do
    for r := sel[range].Row1 to sel[range].Row2 do
      for c := sel[range].Col1 to sel[range].Col2 do
      begin
        cell := Worksheet.GetCell(r, c);  // Use "GetCell" here to format empty cells as well
        ApplyFormatToCell(cell);  // no check for nil required because of "GetCell"
      end;
end;

{@@ ----------------------------------------------------------------------------
  Setter method for the WorkbookSource
-------------------------------------------------------------------------------}
procedure TsCellCombobox.SetWorkbookSource(AValue: TsWorkbookSource);
begin
  if AValue = FWorkbookSource then
    exit;
  if FWorkbookSource <> nil then
    FWorkbookSource.RemoveListener(self);
  FWorkbookSource := AValue;
  if FWorkbookSource <> nil then
    FWorkbookSource.AddListener(self);
  Text := '';
  ListenerNotification([lniSelection]);
end;


{------------------------------------------------------------------------------}
{                             TsCellFontCombobox                               }
{------------------------------------------------------------------------------}

function TsCellFontCombobox.GetCellFont(ACell: PCell): TsFont;
begin
  if ACell = nil then
    Result := Workbook.GetDefaultFont
  else
  if (uffBold in ACell^.UsedFormattingFields) then
    Result := Workbook.GetFont(1)
  else
  if (uffFont in ACell^.UsedFormattingFields) then
    Result := Workbook.GetFont(ACell^.FontIndex)
  else
    Result := Workbook.GetDefaultFont;
end;


{------------------------------------------------------------------------------}
{                             TsFontNameCombobox                               }
{------------------------------------------------------------------------------}

constructor TsFontNameCombobox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 150;
end;

procedure TsFontNameCombobox.ApplyFormatToCell(ACell: PCell);
var
  fnt: TsFont;
begin
  if ItemIndex > -1 then
  begin
    fnt := GetCellFont(ACell);
    Worksheet.WriteFont(ACell, Items[ItemIndex], fnt.Size, fnt.Style, fnt.Color);
  end;
end;

procedure TsFontNameCombobox.ExtractFromCell(ACell: PCell);
var
  fnt: TsFont;
begin
  fnt := GetCellFont(ACell);
  ItemIndex := Items.IndexOf(fnt.FontName);
end;

procedure TsFontNameCombobox.Populate;
begin
  Items.Assign(Screen.Fonts);
end;


{------------------------------------------------------------------------------}
{                             TsFontSizeCombobox                               }
{------------------------------------------------------------------------------}

constructor TsFontSizeCombobox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 60;
end;

procedure TsFontSizeCombobox.ApplyFormatToCell(ACell: PCell);
var
  fnt: TsFont;
  fs: Double;
begin
  if ItemIndex > -1 then
  begin
    fs := StrToFloat(Items[ItemIndex]);
    fnt := GetCellFont(ACell);
    Worksheet.WriteFont(ACell, fnt.FontName, fs, fnt.Style, fnt.Color);
  end;
end;

procedure TsFontSizeCombobox.ExtractFromCell(ACell: PCell);
var
  fnt: TsFont;
begin
  fnt := GetCellFont(ACell);
  ItemIndex := Items.IndexOf(Format('%.0f', [fnt.Size]));
end;

procedure TsFontSizeCombobox.Populate;
begin
  with Items do
  begin
    Clear;
    Add('8');
    Add('9');
    Add('10');
    Add('11');
    Add('12');
    Add('14');
    Add('16');
    Add('18');
    Add('20');
    Add('22');
    Add('24');
    Add('26');
    Add('28');
    Add('32');
    Add('36');
    Add('48');
    Add('72');
  end;
end;


{------------------------------------------------------------------------------}
{                          TsSpreadsheetInspector                              }
{------------------------------------------------------------------------------}

{@@ ----------------------------------------------------------------------------
  Constructor of the TsSpreadsheetInspector class.
  Is overridden to set the default values of DisplayOptions and FixedCols, and
  to define the column captions.
-------------------------------------------------------------------------------}
constructor TsSpreadsheetInspector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DisplayOptions := DisplayOptions - [doKeyColFixed];
  FixedCols := 0;
  TitleCaptions.Add('Properties');
  TitleCaptions.Add('Values');
end;

{@@ ----------------------------------------------------------------------------
  Destructor of the spreadsheet inspector. Removes itself from the
  WorkbookSource's listener list.
-------------------------------------------------------------------------------}
destructor TsSpreadsheetInspector.Destroy;
begin
  if FWorkbookSource <> nil then FWorkbookSource.RemoveListener(self);
  inherited Destroy;
end;

{@@ ----------------------------------------------------------------------------
  Updates the data shown by the inspector grid. Display depends on the FMode
  setting (workbook, worksheet, cell values, cell properties).
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.DoUpdate;
var
  cell: PCell;
  sheet: TsWorksheet;
  book: TsWorkbook;
  list: TStringList;
begin
  cell := nil;
  sheet := nil;
  book := nil;
  if FWorkbookSource <> nil then
  begin
    book := FWorkbookSource.Workbook;
    sheet := FWorkbookSource.Worksheet;
    if sheet <> nil then
      cell := sheet.FindCell(sheet.ActiveCellRow, sheet.ActiveCellCol);
  end;

  list := TStringList.Create;
  try
    case FMode of
      imCellValue      : UpdateCellValue(cell, list);
      imCellProperties : UpdateCellProperties(cell, list);
      imWorksheet      : UpdateWorksheet(sheet, list);
      imWorkbook       : UpdateWorkbook(book, list);
    end;
    Strings.Assign(list);
  finally
    list.Free;
  end;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Workbook which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsSpreadsheetInspector.GetWorkbook: TsWorkbook;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Workbook
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Getter method for the property Worksheet which is currently loaded by the
  WorkbookSource
-------------------------------------------------------------------------------}
function TsSpreadsheetInspector.GetWorksheet: TsWorksheet;
begin
  if FWorkbookSource <> nil then
    Result := FWorkbookSource.Worksheet
  else
    Result := nil;
end;

{@@ ----------------------------------------------------------------------------
  Notification procedure received whenver "something" changes in the workbook.
  Reacts on all events.

  @param  AChangedItems  Set with elements identifying whether workbook, worksheet
                         cell or selection has changed.
  @param  AData          If AChangedItems contains nliCell then AData points to
                         the modified cell.
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.ListenerNotification(
  AChangedItems: TsNotificationItems; AData: Pointer = nil);
begin
  Unused(AData);
  case FMode of
    imWorkbook:
      if ([lniWorkbook, lniWorksheet]*AChangedItems <> []) then DoUpdate;
    imWorksheet:
      if ([lniWorksheet, lniSelection]*AChangedItems <> []) then DoUpdate;
    imCellValue, imCellProperties:
      if ([lniCell, lniSelection]*AChangedItems <> []) then DoUpdate;
  end;
end;

{@@ ----------------------------------------------------------------------------
  Standard component notification method called when the WorkbookSource
  is deleted.
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FWorkbookSource) then
    SetWorkbookSource(nil);
end;

{@@ ----------------------------------------------------------------------------
  Setter method for the Mode property. This property filters groups of properties
  for display (workbook-, worksheet-, cell value- or cell formatting-related
  data).
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.SetMode(AValue: TsInspectorMode);
begin
  if AValue = FMode then
    exit;
  FMode := AValue;
  DoUpdate;
end;

{@@ ----------------------------------------------------------------------------
  Setter method for the WorkbookSource
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.SetWorkbookSource(AValue: TsWorkbookSource);
begin
  if AValue = FWorkbookSource then
    exit;
  if FWorkbookSource <> nil then
    FWorkbookSource.RemoveListener(self);
  FWorkbookSource := AValue;
  if FWorkbookSource <> nil then
    FWorkbookSource.AddListener(self);
  ListenerNotification([lniWorkbook, lniWorksheet, lniSelection]);
end;

{@@ ----------------------------------------------------------------------------
  Creates a string list containing the formatting properties of a specific cell.
  The string list items are name-value pairs in the format "name=value".
  The string list is displayed in the inspector's grid.

  @param   ACell   Cell under investigation
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.UpdateCellProperties(ACell: PCell;
  AStrings: TStrings);
var
  s: String;
  cb: TsCellBorder;
  r1, r2, c1, c2: Cardinal;
begin
  if (ACell = nil) or not (uffFont in ACell^.UsedFormattingFields)
    then AStrings.Add('FontIndex=')
    else AStrings.Add(Format('FontIndex=%d (%s)', [
           ACell^.FontIndex,
           Workbook.GetFontAsString(ACell^.FontIndex)
         ]));

  if (ACell=nil) or not (uffTextRotation in ACell^.UsedFormattingFields)
    then AStrings.Add('TextRotation=')
    else AStrings.Add(Format('TextRotation=%s', [
           GetEnumName(TypeInfo(TsTextRotation), ord(ACell^.TextRotation))
         ]));

  if (ACell=nil) or not (uffHorAlign in ACell^.UsedFormattingFields)
    then AStrings.Add('HorAlignment=')
    else AStrings.Add(Format('HorAlignment=%s', [
           GetEnumName(TypeInfo(TsHorAlignment), ord(ACell^.HorAlignment))
         ]));

  if (ACell=nil) or not (uffVertAlign in ACell^.UsedFormattingFields)
    then AStrings.Add('VertAlignment=')
    else AStrings.Add(Format('VertAlignment=%s', [
           GetEnumName(TypeInfo(TsVertAlignment), ord(ACell^.VertAlignment))
         ]));

  if (ACell=nil) or not (uffBorder in ACell^.UsedFormattingFields) then
    AStrings.Add('Borders=')
  else
  begin
    s := '';
    for cb in TsCellBorder do
      if cb in ACell^.Border then
        s := s + ', ' + GetEnumName(TypeInfo(TsCellBorder), ord(cb));
    if s <> '' then Delete(s, 1, 2);
    AStrings.Add('Borders='+s);
  end;

  for cb in TsCellBorder do
    if ACell = nil then
      AStrings.Add(Format('BorderStyles[%s]=', [
        GetEnumName(TypeInfo(TsCellBorder), ord(cb))]))
    else
      AStrings.Add(Format('BorderStyles[%s]=%s, %s', [
        GetEnumName(TypeInfo(TsCellBorder), ord(cb)),
        GetEnumName(TypeInfo(TsLineStyle), ord(ACell^.BorderStyles[cbEast].LineStyle)),
        Workbook.GetColorName(ACell^.BorderStyles[cbEast].Color)]));

  if (ACell = nil) or not (uffBackgroundColor in ACell^.UsedformattingFields)
    then AStrings.Add('BackgroundColor=')
    else AStrings.Add(Format('BackgroundColor=%d (%s)', [
           ACell^.BackgroundColor,
           Workbook.GetColorName(ACell^.BackgroundColor)]));

  if (ACell = nil) or not (uffNumberFormat in ACell^.UsedFormattingFields) then
  begin
    AStrings.Add('NumberFormat=');
    AStrings.Add('NumberFormatStr=');
  end else
  begin
    AStrings.Add(Format('NumberFormat=%s', [
      GetEnumName(TypeInfo(TsNumberFormat), ord(ACell^.NumberFormat))]));
    AStrings.Add('NumberFormatStr=' + ACell^.NumberFormatStr);
  end;

  if (Worksheet = nil) or not Worksheet.IsMerged(ACell) then
    AStrings.Add('Merged range=')
  else
  begin
    Worksheet.FindMergedRange(ACell, r1, c1, r2, c2);
    AStrings.Add('Merged range=' + GetCellRangeString(r1, c1, r2, c2));
  end;
end;

{@@ ----------------------------------------------------------------------------
  Creates a string list containing the value data of a specific cell.
  The string list items are name-value pairs in the format "name=value".
  The string list is displayed in the inspector's grid.

  @param   ACell   Cell under investigation
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.UpdateCellValue(ACell: PCell; AStrings: TStrings);
begin
  if ACell = nil then
  begin
    if Worksheet <> nil then
    begin
      AStrings.Add(Format('Row=%d', [Worksheet.ActiveCellRow]));
      AStrings.Add(Format('Col=%d', [Worksheet.ActiveCellCol]));
    end else
    begin
      AStrings.Add('Row=');
      AStrings.Add('Col=');
    end;
    AStrings.Add('ContentType=(none)');
  end else
  begin
    AStrings.Add(Format('Row=%d', [ACell^.Row]));
    AStrings.Add(Format('Col=%d', [ACell^.Col]));
    AStrings.Add(Format('ContentType=%s', [
      GetEnumName(TypeInfo(TCellContentType), ord(ACell^.ContentType))
    ]));
    AStrings.Add(Format('NumberValue=%g', [ACell^.NumberValue]));
    AStrings.Add(Format('DateTimeValue=%g', [ACell^.DateTimeValue]));
    AStrings.Add(Format('UTF8StringValue=%s', [ACell^.UTF8StringValue]));
    AStrings.Add(Format('BoolValue=%s', [BoolToStr(ACell^.BoolValue)]));
    AStrings.Add(Format('ErrorValue=%s', [
      GetEnumName(TypeInfo(TsErrorValue), ord(ACell^.ErrorValue))
    ]));
    AStrings.Add(Format('FormulaValue=%s', [Worksheet.ReadFormulaAsString(ACell, true)])); //^.FormulaValue]));
    if ACell^.SharedFormulaBase = nil then
      AStrings.Add('SharedFormulaBase=')
    else
      AStrings.Add(Format('SharedFormulaBase=%s', [GetCellString(
        ACell^.SharedFormulaBase^.Row, ACell^.SharedFormulaBase^.Col)
      ]));
  end;
end;

{@@ ----------------------------------------------------------------------------
  Creates a string list containing the properties of the workbook.
  The string list items are name-value pairs in the format "name=value".
  The string list is displayed in the inspector's grid.

  @param   ACell   Cell under investigation
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.UpdateWorkbook(AWorkbook: TsWorkbook;
  AStrings: TStrings);
var
  bo: TsWorkbookOption;
  s: String;
  i: Integer;
begin
  if AWorkbook = nil then
  begin
    AStrings.Add('FileName=');
    AStrings.Add('FileFormat=');
    AStrings.Add('Options=');
    AStrings.Add('ActiveWorksheet=');
    AStrings.Add('FormatSettings=');
  end else
  begin
    AStrings.Add(Format('FileName=%s', [AWorkbook.FileName]));
    AStrings.Add(Format('FileFormat=%s', [
      GetEnumName(TypeInfo(TsSpreadsheetFormat), ord(AWorkbook.FileFormat))
    ]));

    if AWorkbook.ActiveWorksheet <> nil then
      AStrings.Add('ActiveWorksheet=' + AWorkbook.ActiveWorksheet.Name)
    else
      AStrings.Add('ActiveWorksheet=');

    s := '';
    for bo in TsWorkbookOption do
      if bo in AWorkbook.Options then
        s := s + ', ' + GetEnumName(TypeInfo(TsWorkbookOption), ord(bo));
    if s <> '' then Delete(s, 1, 2);
    AStrings.Add('Options='+s);

    AStrings.Add('FormatSettings=');
    AStrings.Add('  ThousandSeparator='+AWorkbook.FormatSettings.ThousandSeparator);
    AStrings.Add('  DecimalSeparator='+AWorkbook.FormatSettings.DecimalSeparator);
    AStrings.Add('  ListSeparator='+AWorkbook.FormatSettings.ListSeparator);
    AStrings.Add('  DateSeparator='+AWorkbook.FormatSettings.DateSeparator);
    AStrings.Add('  TimeSeparator='+AWorkbook.FormatSettings.TimeSeparator);
    AStrings.Add('  ShortDateFormat='+AWorkbook.FormatSettings.ShortDateFormat);
    AStrings.Add('  LongDateFormat='+AWorkbook.FormatSettings.LongDateFormat);
    AStrings.Add('  ShortTimeFormat='+AWorkbook.FormatSettings.ShortTimeFormat);
    AStrings.Add('  LongTimeFormat='+AWorkbook.FormatSettings.LongTimeFormat);
    AStrings.Add('  TimeAMString='+AWorkbook.FormatSettings.TimeAMString);
    AStrings.Add('  TimePMString='+AWorkbook.FormatSettings.TimePMString);
    s := AWorkbook.FormatSettings.ShortMonthNames[1];
    for i:=2 to 12 do
      s := s + ', ' + AWorkbook.FormatSettings.ShortMonthNames[i];
    AStrings.Add('  ShortMonthNames='+s);
    s := AWorkbook.FormatSettings.LongMonthnames[1];
    for i:=2 to 12 do
      s := s +', ' + AWorkbook.FormatSettings.LongMonthNames[i];
    AStrings.Add('  LongMontNames='+s);
    s := AWorkbook.FormatSettings.ShortDayNames[1];
    for i:=2 to 7 do
      s := s + ', ' + AWorkbook.FormatSettings.ShortDayNames[i];
    AStrings.Add('  ShortMonthNames='+s);
    s := AWorkbook.FormatSettings.LongDayNames[1];
    for i:=2 to 7 do
      s := s +', ' + AWorkbook.FormatSettings.LongDayNames[i];
    AStrings.Add('  LongMontNames='+s);
    AStrings.Add('  CurrencyString='+AWorkbook.FormatSettings.CurrencyString);
    AStrings.Add('  PosCurrencyFormat='+IntToStr(AWorkbook.FormatSettings.CurrencyFormat));
    AStrings.Add('  NegCurrencyFormat='+IntToStr(AWorkbook.FormatSettings.NegCurrFormat));
    AStrings.Add('  TwoDigitYearCenturyWindow='+IntToStr(AWorkbook.FormatSettings.TwoDigitYearCenturyWindow));
  end;
end;

{@@ ----------------------------------------------------------------------------
  Creates a string list containing the properties of a worksheet.
  The string list items are name-value pairs in the format "name=value".
  The string list is displayed in the inspector's grid.

  @param   ACell   Cell under investigation
-------------------------------------------------------------------------------}
procedure TsSpreadsheetInspector.UpdateWorksheet(ASheet: TsWorksheet;
  AStrings: TStrings);
begin
  if ASheet = nil then
  begin
    AStrings.Add('Name=');
    AStrings.Add('First row=');
    AStrings.Add('Last row=');
    AStrings.Add('First column=');
    AStrings.Add('Last column=');
    AStrings.Add('Active cell=');
    AStrings.Add('Selection=');
  end else
  begin
    AStrings.Add(Format('Name=%s', [ASheet.Name]));
    AStrings.Add(Format('First row=%d', [Integer(ASheet.GetFirstRowIndex)]));
    AStrings.Add(Format('Last row=%d', [ASheet.GetLastRowIndex]));
    AStrings.Add(Format('First column=%d', [Integer(ASheet.GetFirstColIndex)]));
    AStrings.Add(Format('Last column=%d', [ASheet.GetLastColIndex]));
    AStrings.Add(Format('Active cell=%s', [GetCellString(ASheet.ActiveCellRow, ASheet.ActiveCellCol)]));
    AStrings.Add(Format('Selection=%s', [ASheet.GetSelectionAsString]));
  end;
end;

end.
