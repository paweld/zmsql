{*********************************************************}
{                                                         }
{                       ZMSQL                             }
{            SQL enhanced in-memory dataset               }
{                                                         }
{   Original developer: Zlatko Matić, 2009                }
{             e-mail: matalab@gmail.com                   }
{  Milkovićeva 6, Mala Ostrna, 10370 Dugo Selo,  Croatia. }
{                                                         }
{*********************************************************}
{
    This file is copyright (c) 2011 by Zlatko Matić    
    
    This source code is distributed under
    the Library GNU General Public License (see the file 
    COPYING) with the following modification:

    As a special exception, the copyright holders of this library give you
    permission to link this library with independent modules to produce an
    executable, regardless of the license terms of these independent modules,
    and to copy and distribute the resulting executable under terms of your choice,
    provided that you also meet, for each linked independent module, the terms
    and conditions of the license of that module. An independent module is a module
    which is not derived from or based on this library. If you modify this
    library, you may extend this exception to your version of the library, but you are
    not obligated to do so. If you do not wish to do so, delete this exception
    statement from your version.

    If you didn't receive a copy of the file COPYING, contact:
          Free Software Foundation
          675 Mass Ave
          Cambridge, MA  02139
          USA   

    Modifications are made by Zlatko Matić and contributors for purposes of zmsql package.

 **********************************************************************}

{-----------------------------------------------------------------------------

The original developer of the code is Zlatko Matić
(matalab@gmail.com or matic.zlatko@gmail.com).

Contributor(s):

-Mario Ferrari (mario.ferrari@edis.it or mario@marioferrari.org)
 Changes enclosed within {MF begin} and {MF end}

Last Modified: 07.03.2014

Known Issues:

- Extremely slow query execution when more than one table joined in query when there is
additional where clause in query. It can be overcomed with "ASSIGN TO variable" non-standard expression
-->first execute query on a table with where clasue, assign resultset to a variable and then use
the variable in second query (instead of the table).
- JanSQL has problems with typecasts.
- Parameters support is currently quite limited. Basically, named parameters must be used and they are replaced by its values as literal strings.
-->You must enclose parameter identifiers in SQL string by quotes!

History (Change log):

ZMSQL version 0.1.0, 13.07.2011: by Zlatko Matić
ZMSQL version 0.1.1, 26.07.2011: by Zlatko Matić
ZMSQL version 0.1.2, 28.07.2011: by Zlatko Matić
ZMSQL version 0.1.3, 02.08.2011: by Zlatko Matić
ZMSQL version 0.1.5, 12.08.2011: by Zlatko Matić
ZMSQL version 0.1.6, 28.12.2011: by Zlatko Matić
ZMSQL version 0.1.7, 01.01.2012: by Zlatko Matić
ZMSQL version 0.1.8, 08.01.2012: by Zlatko Matić
ZMSQL version 0.1.9, 15.01.2012: by Zlatko Matić
ZMSQL version 0.1.10, 20.01.2012: by Zlatko Matić
ZMSQL version 0.1.11, 05.02.2012: by Zlatko Matić
ZMSQL version 0.1.12, 12.02.2012: by Zlatko Matić
ZMSQL version 0.1.13, 13.01.2013: by Zlatko Matić
ZMSQL version 0.1.14, 01.01.2014: by Zlatko Matić
ZMSQL version 0.1.15, 28.01.2014: by Zlatko Matić
      *Internal optimizations and bugfixes.
      *Autoincrement fields (ftAutoInc) are now working.
      *Improved visibility of TDataset methods and properties.
      *ZMQueryDataset now works with TBufDataset as ancestor (as in CodeTyphon v.4.70). ZMBufDataset upgraded to the current TBufDataset in CodeTyphon v. 4.70.
      *Added property MasterDetailFilter: Boolean which switches master/detail filtration on/off.
      *Removed property DecimalSeparator. ZMSQL now use system settings for decimal and thousand separator.
      *ZMQueryDataset can handle float value even if thousand separator is present (in a .csv file).
      *Better handling locale settings and conversion from ANSI to UTF8.
      *Persistent fields are working now.
      (Solved by a trick: persistent fields loaded from .lfm are recreated, propertis from old fields are copied to new fields and old fields are deleted.
ZMSQL version 0.1.16, 28.01.2014: by Zlatko Matić
      *Internal optimizations and bugfixes.
      *Creation of JanSQL instances moved from ZMConnection to ZMQueryDataset, in order that ZMQueryDataset can be used in multithreaded applications.
      *New properties (ReferentialUpdateFired, ReferentialDeleteFired, ReferentialInsertFired) that tells that a referential action is in progress.
ZMSQL version 0.1.17, 07.03.2014: by Mario Ferrari
      *Error situations that used ShowMessage now raise a generic exception containing the message itself. Only one ShowMessage remains for a design-time case.
ZMSQL version 0.1.18, 10.04.2014: by Zlatko Matić
	  *Bugfix release. There was funny bug in zmquerydataset destroy method - dataset would be saved prior destroying if persistent save was enebaled.
      This was wrong, causing saving CSV file copy in wrong directories.
ZMSQL version 0.1.19, 08.02.2015: by Zlatko Matić
      *New component TZMQueryBuilder, based on Open QBuilder Engine, is added to the zmsql package.
      TZMQueryBuilder uses TOQBEngineZmsql, which is TOQBEngine descendant.
      TOQBEngineZmsql is in based on code of the Open QBuilder Engine for SQLDB Sources created by Reinier Olislagers, modified and adapted for the ZMSQL by Zlatko Matić.
      It incorporates QBuilder visual query builder(Copyright (c) 1996-2003 Sergey Orlik , Copyright (c) 2003 Fast Reports, Inc.)
      *Added procedure TZMConnection.GetTableNames(FileList: TStrings);
      *Added procedure TZMQueryDataSet.LoadTableSchema;
-----------------------------------------------------------------------------}
unit ZMQueryDataSet;

{$mode objfpc}{$H+}

{$off DEFINE ZMBufDataset} //=== ct9999 for CodeTyphon ==============

{Use "$DEFINE ZMBufDataset" compiler directive to base TZMQueryDataset on TZMBufDataset
or use "$OFF DEFINE ZMBufDataset" compiler directive to base TZMQueryDataset on TBufDataset.
Optionally you can set {$DEFINE ZMBufDataset} in zmsql package under Options/Compiler Options/Other/Conditionals/Custom Options/Defines.
if you switch it on, TZMBufDataset is ancestor, if you swithc it off, TBufDataset is ancestor.}

interface

uses
  {$IFDEF UNIX}{ clocale, cwstring,}{$ENDIF}
  Classes, SysUtils, {LResources, Forms, Controls, Graphics, Dialogs,}
  db, TypInfo, fpDBExport, fpcsvexport, fpstdexports, SdfData, StrUtils,
  FileUtil, LConvEncoding, lazutf8,
  {$IFDEF ZMBufDataset}
  ZMBufDataset,
  {$ELSE}
  BufDataset,
  {$ENDIF}
  ZMConnection, jansql
  {$ifdef VISUAL}
  ,ComponentEditors, PropEdits,
  FormEditingIntf,
  FieldsEditor{$endif};

type

  TSourceData=(sdSdfDataset, sdJanSQL, sdOtherDataset, sdInternal);
  TInspectFields=(ifCreateFieldsFromFieldDefs, ifCreateFieldDefsAndFields, ifDoNothing, ifNewIsEmpty, ifOther);

  { TZMQueryDataSet }

 {$IFDEF ZMBufDataset}
 TZMQueryDataSet = class(TZMBufDataSet)
 {$ELSE}
 TZMQueryDataSet = class(TBufDataSet)
 {$ENDIF}

  private
    { Private declarations }
    FAutoIncIdx: integer;     /// edgarrod71@gmail.com
    FAutoIncValue: SizeInt;   /// edgarrod71@gmail.com
    FBulkInsert:Boolean;
    FCSVExporterExport: TCSVExporter;
    FDisableMasterDetailFiltration: Boolean;
    FDoReferentialUpdate:Boolean;
    FDynamicFieldsCreated: Boolean;
    FFieldCount:Integer;  //This is number of columns (fielddefs) that dataset will have after an action (after loading from a table, after loading from a dataset, after query execution....)
    FFieldsLoaded: boolean;  //// edgarrod71@gmail.com
    FJanSQLInstance:TjanSQL;
    FMasterDataSetTo: TList;
    FMasterDetailFiltration: Boolean;
    FMasterFields: TStrings;
    FMasterReferentialKeys: TList;
    FMasterSource: TDataSource;
    FMemoryDataSetOpened: Boolean;
    FOldMasterSource:TDataSource;
    FOldRecord:{$IFDEF ZMBufDataset} TZMBufDataSet {$ELSE} TBufDataSet {$ENDIF};
    FOriginalSQL:String;
    FOtherDatasetImport:TDataset;
    FParameters: TParams;
    FPersistentFieldsCreated: Boolean;
    FPersistentSave: Boolean;
    FPreparedSQL:String;
    FQueryExecuted: Boolean;
    FRecordCount:Longint;
    FRecordsetIndex:Integer;
    FReferentialDeleteFired: Boolean;
    FReferentialInsertFired: Boolean;
    FReferentialUpdateFired: Boolean;
    FSdfDatasetImport:TSdfDataset;
    FSlaveReferentialKeys: TList;
    FSourceData:TSourceData;
    FSQL: TStrings;
    FTableFile: TFileStream;
    FTableLoaded: Boolean;
    FTableName: String;
    FTableSaved: Boolean;
    FZMConnection: TZMConnection;
    procedure DoCopyFromDataset(pDataset:TDataset);
    procedure DoCreatePersistentFieldsFromFieldDefs;
    procedure DoLoadTableSchema;
    procedure DoLoadFromTable;
    procedure DoQueryExecute;
    procedure ManageFields;
    procedure SetConnection(const AValue: TZMConnection);
    procedure SetDynamicFieldsCreated(AValue: Boolean);
    procedure SetMasterDetailFiltration(AValue: Boolean);
    procedure SetMemoryDataSetOpened(AValue: Boolean);
    procedure SetDisableMasterDetailFiltration(const AValue: Boolean);
    procedure SetMasterDataSetTo(const AValue: TList);
    procedure SetMasterReferentialKeys(const AValue: TList);
    procedure SetPersistentFieldsCreated(AValue: Boolean);
    procedure SetSlaveReferentialKeys(const AValue: TList);
    procedure SetZMConnection(const AValue: TZMConnection);
    procedure SetMasterFields(const AValue: TStrings);
    procedure SetMasterSource(const AValue: TDataSource);
    procedure SetParameters(const AValue: TParams);
    procedure SetPersistentSave(const AValue: Boolean);
    procedure SetTableLoaded(const AValue: Boolean);
    procedure SetTableName(const AValue: String);
    procedure SetTableSaved(const AValue: Boolean);
    procedure SetQueryExecuted(const AValue: Boolean);
    procedure SetSQL(const AValue: TStrings);
    procedure PassQueryResult;
    procedure FieldsFromFieldDefs;
    procedure FieldsFromScratch;
    procedure EmptySdfDataSet;
    procedure ClearSdfDataSet;
    procedure InsertDataFromCSV;
    procedure InsertDataFromJanSQL;
    function InspectFields:TInspectFields;
    procedure UpdateMasterDataSetTo;
    procedure CopyARowFromDataset(pDataset: TDataSet);
    procedure UpdateFOldRecord;
    function FormatStringToFloat (pFloatString:string):Extended;
    procedure SetFloatDisplayFormat;
    procedure SetFloatPrecision;
    Function ZMInitializePersistentField(AOwner: TComponent; AFieldDef:TFieldDef; AOldPersistentField:TField): TField;
  protected
    { Protected declarations }

    procedure DoFilterRecord({var} out Acceptable: Boolean);override;
    procedure DoOnNewRecord; override;
    procedure DoAfterScroll;override;
    procedure DoBeforeDelete;override;
    procedure DoBeforeInsert;override;
    procedure DoBeforeEdit;override;
    procedure DoBeforePost;override;
    procedure DoAfterInsert;override;
    procedure DoAfterPost;override;
    procedure DoAfterDelete;override;
    procedure InternalRefresh;override; { TODO : To investigate procedure InternalRefresh;override;! Currently this method is overriden to do nothing. }
    procedure DoAfterClose;override;
    procedure dummyProc;

  public
    { Public declarations }
    //Master/detail filtration
    property MasterDataSetTo:TList read FMasterDataSetTo write SetMasterDataSetTo; // Defines datasets to which self is master in master/detail filtration.
    property DisableMasterDetailFiltration:Boolean read FDisableMasterDetailFiltration write SetDisableMasterDetailFiltration; //Master/detail filrtation should be temporarily desabled during bulk inserts or updates...
    //Properties needed for master/detail and referential integrity
    property MasterReferentialKeys:TList read FMasterReferentialKeys write SetMasterReferentialKeys;//Defines list of referential keys in which self is master dataset.
    property SlaveReferentialKeys:TList read FSlaveReferentialKeys write SetSlaveReferentialKeys; //Defines list of referential keys in which self is slave dataset.
    //Other
    procedure QueryExecute; //Executes SQL query defined in SQL property, on .csv files that are placed in folder defined in ZMConnection property. Resultset of select query is loaded into the the zmquerydataset (self).
    procedure PrepareQuery; //Prepares parameterized queries for execution: replaces parameters with parameter values for parameterized queries.
    procedure EmptyDataSet; //Deletes all records from dataset.
    procedure ClearDataSet; //Deletes records, fields and fielddefs.
    procedure CopyFromDataset (pDataset:TDataSet); //Copies schema and data from any TDataset.
    function SortDataset (const pFieldName:String):Boolean; //Ascending/Descending sorting of memory dataset.
    procedure LoadFromTable; //Loads data (or data and schema) from a .csv file (TableName.csv), set in property TableName, from path specified in ZMConnection property.
    procedure LoadTableSchema;//Load schema only (without data) from a .csv file (TableName.csv), set in property TableName, from path specified in ZMConnection property.
    function LoadTableFields: boolean;  // edgarrod71@gmail.com  Load fields from .csv file (TableName.csv), for single tables.
    procedure LoadLastRecord;
    procedure SaveToTable;overload; //Saves data and schema to a .csv file (TableName.csv), set in Tablename property, in path specified in ZMConnection property.
    procedure SaveToTable(pDecimaSeparator:Char);overload; //Saves data and schema to a .csv file (TableName.csv), set in Tablename property, in path specified in ZMConnection property.
    procedure CreateDynamicFieldsFromFieldDefs; // Creates fields from predefined fielddefs. To be used in design-time or run-time for memory dataset creation according to predefined fielddefs.
    procedure CreatePersistentFieldsFromFieldDefs; // Creates PERSISTENT fields from predefined fielddefs. To be used in design-time only.
    procedure MemoryDataSetOpen; //Executes CreateDynamicFieldsFromFieldDefs and set dataset to Active.
    procedure MemOpen;  /// MemoryDataSetOpen will be maintained for some time for compatibility, but is redundant to say ZMQueryDataSet.MemoryDataSetOpen, instead is shorter this definition...  edgarrod71@gmail.com
    procedure InitializePersistentFields; // Activates persistent fields loaded from .lfm.
    procedure ResetAutoInc(pStart:SizeInt); //Resets AutoIncrement value to an integer.
    function AddRecord(const Values: array of Const; pAutoIncPos: Integer=-1): boolean;  //// edgarrod71@gmail.com Adds a Record at the end of the DataSet.
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    property OldRecord:{$IFDEF ZMBufDataset} TZMBufDataSet {$ELSE} TBufDataSet {$ENDIF} read FOldRecord; //Last delete/insert/edit is preserved in this property.
    property AutoIncValue: SizeInt read FAutoIncValue;
    property ReferentialUpdateFired:Boolean read FReferentialUpdateFired; //Signalize that referential update is in progress
    property ReferentialDeleteFired:Boolean read FReferentialDeleteFired; //Signalize that referential delete is in progress
    property ReferentialInsertFired:Boolean read FReferentialInsertFired; //Signalize that referential insert is in progress
    property FieldsLoaded: Boolean read FFieldsLoaded write FFieldsLoaded;   //// edgarrod71@gmail.com
    procedure Insert; virtual;  //// edgarrod71@gmail.com
    procedure Post; override;   //// edgarrod71@gmail.com
  published
    { Published declarations }
    property ZMConnection:TZMConnection read FZMConnection write SetConnection; //Defines "database" folder path where .csv tables are placed. Instantiates JanSQL database engine.
    property SQL:TStrings read FSQL write SetSQL; //Unprepared SQL query text.
    property QueryExecuted:Boolean read FQueryExecuted write SetQueryExecuted;  //"True" executes QueryExecute and loads resultset into dataset.
    property TableName:String read FTableName write SetTableName; //Name of .csv file (without extension) from which is data loaded by LoadFromTable and to which is data and schema saved by SaveToTable.
    property TableLoaded:Boolean read FTableLoaded write SetTableLoaded; //"True" executes LoadFromTable and loads resultset into dataset.
    property TableSaved:Boolean read FTableSaved write SetTableSaved; //"True" executes SaveToTable and saves dataset to .csv file defined in TableName property, placed in folder specified by ZMConnection property.
    property DynamicFieldsCreated:Boolean read FDynamicFieldsCreated write SetDynamicFieldsCreated; //"True" executes CreateDynamicFieldsFromFieldDefs, which creates fields from predefined fielddefs.
    property PeristentFieldsCreated:Boolean read FPersistentFieldsCreated write SetPersistentFieldsCreated; //"True" executes CreatePersistentFieldsFromFieldDefs, which creates PERSISTENT fields from predefined fielddefs.
    property MemoryDataSetOpened:Boolean read FMemoryDataSetOpened write SetMemoryDataSetOpened; //"True" executes CreateDynamicFieldsFromFieldDefs and activates dataset for editing.
    property PersistentSave:Boolean read FPersistentSave write SetPersistentSave; //If "True", insert/delete/edit will immediately be written to underlying .csv file. If "False", then dataset is only in-memory.
    property Parameters: TParams read FParameters write SetParameters; //Parameters for parameterized SQL text.
    //Read-only properties for getting info about referential integrity
    property MasterRefKeysList:TList read FMasterReferentialKeys;//List of referential keys in which self is master dataset.
    property SlaveRefKeysList:TList read FSlaveReferentialKeys; //List of referential keys in which self is slave dataset.
    //Master/detail filtration
    property MasterFields: TStrings read FMasterFields write SetMasterFields; //Fields in masterdatasource, (separated by ";") to be used for master/detail filtration.
    property MasterSource: TDataSource read FMasterSource  write SetMasterSource;//Master datasource for master/detail filtration.
    property MasterDetailFiltration: Boolean read FMasterDetailFiltration write SetMasterDetailFiltration; //Switches master/detail filtration on/off.
    property MasterDataSetToList:TList read FMasterDataSetTo; // List of datasets to which self is master in master/detail filtration.

    //Inherited properties from TZMBufDataset
     property State;
     //property Fields;
     Property FieldDefs;
     property Filter;
     property Filtered;
     property FilterOptions;
     property Active;
     property AutoCalcFields;
     property BeforeOpen;
     property AfterOpen;
     property BeforeClose;
     property AfterClose;
     property BeforeInsert;
     property AfterInsert;
     property BeforeEdit;
     property AfterEdit;
     property BeforePost;
     property AfterPost;
     property BeforeCancel;
     property AfterCancel;
     property BeforeDelete;
     property AfterDelete;
     property BeforeScroll;
     property AfterScroll;
     property BeforeRefresh;
     property AfterRefresh;
     property OnCalcFields;
     property OnDeleteError;
     property OnEditError;
     property OnFilterRecord;
     property OnNewRecord;
     property OnPostError;
  end;

implementation

uses
  Variants,
  ZMReferentialKey;

const
  C: Char = ';';


{ TZMQueryDataSet }

procedure TZMQueryDataSet.SetZMConnection(const AValue: TZMConnection);
begin
  if FZMConnection=AValue then exit;
  FZMConnection := AValue;
end;

procedure TZMQueryDataSet.SetConnection(const AValue: TZMConnection);
begin
  if FZMConnection=AValue then exit;
  FZMConnection := AValue;
end;

procedure TZMQueryDataSet.DoQueryExecute;
var
  vSqlResult:Integer;
  vSqlText:String;
  vDisableMasterDetailFiltration:Boolean;
begin
  try
    vDisableMasterDetailFiltration:=DisableMasterDetailFiltration;
    //Set bulk insert flag and suppress master/detail filtration
    FBulkInsert := True;
    DisableMasterDetailFiltration:=True;
    if not ZMConnection.Connected then
      ZMConnection.Connect;
    //Free existing and create new JanSQL database -->It seems that this is neccessary when changing connection.
    { TODO : Investigate why JanSQL sometimes fails to correctly execute consecutive queries in the same jansql instance. Values stay from previous query.
This is a serious bug in jansql.
As a temporary solution, jansql instance is recreated for every query. }
    FJanSQLInstance.Free;
    FJanSQLInstance:=TJanSQL.Create;

    try
      //Connect to JanSQL "database".
      vSqlText:='connect to '''+ZMConnection.DatabasePath{Full}+'''';
      {ShowMessage(vSqlText);}
      vSqlResult:=FJanSQLInstance.SQLDirect(vSqlText);
      if vSqlResult<>0 then
        {ShowMessage('Successfully connected to database:'+ZMConnection.DatabasePath)}
      else
        {MF begin}
        // was: ShowMessage('Connection to database: '+ ZMConnection.DatabasePath +' failed! Error: '+FJanSQLInstance.Error);
        raise Exception.Create('Connection to database: '+ ZMConnection.DatabasePath +' failed! Error: '+FJanSQLInstance.Error);
        {MF end}
      {ShowMessage(IntToStr(vSqlResult));}
    finally
      FJanSQLInstance.ReleaseRecordset(vSqlResult);
    end;

    //Delete previous records
    Close; //This closes dataset and delets all records from memory
    {EmptyDataSet;} //This would be alternative to Close, but it has problems if DisableMasterDetailFiltration=True.
    //Prepare SQL string
    PrepareQuery;
    //Execute query in JanSQL engine
    try
      FRecordsetIndex:=0;
      {ShowMessage('Prepared SQL: '+FPreparedSQL);}
      FRecordsetIndex:=FJanSQLInstance.SQLDirect(FPreparedSQL);
      {ShowMessage(IntToStr(FRecordsetIndex));}
      {ShowMessage('FJanSQLInstance.RecordsetCount: '+IntToStr(FJanSQLInstance.RecordsetCount));}
    except
      {MF begin}
      // was: ShowMessage ('Error while trying to execute query.' +FJanSQLInstance.Error);
      on e:Exception do begin
        raise Exception.Create('Error while trying to execute query.' +FJanSQLInstance.Error);
      end;
      {MF end}
    end;
    //If there is a resultset, pass it to ZMQueryDataSet.
    if FRecordsetIndex>0 then
      begin
        try
          try
            //Load query result into zmquerydataset
            PassQueryResult;
          finally
            //Persistent save
            if (FPersistentSave=True) then
              begin
                if (FTableName<>null) then SaveToTable
                   {MF begin}
                   // was: else ShowMessage('Dataset '+Name+' can not be saved ' +'because TableName property is not set');
                   else raise Exception.Create('Dataset '+Name+' can not be saved '#10 +'because TableName property is not set');
                   {MF end}
              end;
          end;
        finally
          FJanSQLInstance.ReleaseRecordset(FRecordsetIndex);
          FRecordsetIndex:=0;
        end;
      end;
  finally
    //Remove bulk insert flag and enable master/detail filtration
    FBulkInsert:=False;
    DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
  end;
end;

procedure TZMQueryDataSet.ManageFields;
begin
  //Decide what to do with FieldDefs and Fields
  {ShowMessage('InspectFields for dataset: '+self.Name);}
  Case InspectFields of
  ifCreateFieldsFromFieldDefs:
    begin
      {ShowMessage('InspectFields for dataset: '+self.Name+', '+InspectFields function returned ifCreateFieldsFromFieldDefs.');}
      FieldsFromFieldDefs;  //Create fields from fielddefs
      //Deal with mutually exclusive properties
////      FDynamicFieldsCreated:=True;
////      FPersistentFieldsCreated:=False;
    end;
  ifCreateFieldDefsAndFields:
    begin
      {ShowMessage('InspectFields for dataset: '+self.Name+', '+'InspectFields function returned ifCreateFieldDefsAndFields.');}
      FieldsFromScratch; //Create both fielddefs and fields
      //Deal with mutually exclusive properties
      FDynamicFieldsCreated:=True;
      FPersistentFieldsCreated:=False;
    end;
   ifDoNothing:
     begin
       {ShowMessage('InspectFields for dataset: '+self.Name+', '+'InspectFields function returned ifDoNothing.');}
       //Do nothing
     end;
   ifNewIsEmpty:
    begin
      {MF begin}
      // was: ShowMessage('InspectFields for dataset: '+self.Name+', '+'Error: InspectFields function returned ifNewIsEmpty! Canceling...');
      raise Exception.Create('InspectFields for dataset: '+self.Name+', '+'Error: InspectFields function returned ifNewIsEmpty! Canceling...');
      {MF end}
    end;
    ifOther:
    begin
      {MF begin}
      // was: ShowMessage('InspectFields for dataset: '+self.Name+', '+'Error: InspectFields function returned ifOther! Canceling...');
      raise Exception.Create('InspectFields for dataset: '+self.Name+', '+'Error: InspectFields function returned ifOther! Canceling...');
      {MF end}
    end;
  end;
end;

procedure TZMQueryDataSet.DoLoadTableSchema;
var
  vDisableMasterDetailFiltration:Boolean;
begin
  try
    vDisableMasterDetailFiltration:=DisableMasterDetailFiltration;
    //Set bulk inbsert flag and suppress master/detail filtration
    FBulkInsert:=True;
    DisableMasterDetailFiltration:=True;
    if not ZMConnection.Connected then
        ZMConnection.Connect;
    //Delete previous records
    Close; //This closes dataset and delets all records from memory
    {EmptyDataSet;} //This would be alternative to Close, but it has problems if DisableMasterDetailFiltration=True.
//    with FSdfDatasetImport do begin
      FSdfDatasetImport.Close;
      FSdfDatasetImport.FileName:=ZMConnection.DatabasePath{Full}+ TableName + '.csv';
      FSdfDatasetImport.FirstLineAsSchema:=True;
      FSdfDatasetImport.Delimiter := C;
      FSdfDatasetImport.FileMustExist:=False;
      FSdfDatasetImport.Open;
      //Let object knows data source...
      FSourceData:=sdSdfDataset;
      FFieldCount:=FSdfDatasetImport.FieldDefs.Count;
      FRecordCount:=FSdfDatasetImport.RecordCount;
//    end;
    //Prepare ZMQueryDataset
    with self do begin
      Close;
      //Decide what to do with FieldDefs and Fields.
      ManageFields;
    end;
    Open;
  finally
    //UnSet bulk inbsert flag and Unsuppress master/detail filtration
    FBulkInsert:=False;
    DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
  end;
end;

procedure TZMQueryDataSet.DoLoadFromTable;
var
  vDisableMasterDetailFiltration:Boolean;
begin
  try
    vDisableMasterDetailFiltration:=DisableMasterDetailFiltration;
    //Set bulk insert flag and suppress master/detail filtration
    FBulkInsert:=True;
    DisableMasterDetailFiltration:=True;
    if not ZMConnection.Connected then
        ZMConnection.Connect;
    //Delete previous records
    Close; //This closes dataset and deletes all records from memory
    {EmptyDataSet;} //This would be alternative to Close, but it has problems if DisableMasterDetailFiltration=True.
    with FSdfDatasetImport do begin
      Close;
      FileName:=ZMConnection.DatabasePath{Full}+TableName+'.csv';
      FirstLineAsSchema:=True;
      FSdfDatasetImport.Delimiter:= C;
      FSdfDatasetImport.FileMustExist:=False;
      Open;
      //Let object knows data source...
      FSourceData:=sdSdfDataset;
      FFieldCount:=FieldDefs.Count;
      FRecordCount:=RecordCount;
    end;
    //Prepare ZMQueryDataset
    with self do begin
      Close;
      //Decide what to do with FieldDefs and Fields.
      ManageFields;
    end;
    Open;
    try
      //Insert data from the csv file.
      InsertDataFromCSV;
    finally
      //Persistent save
      if (FPersistentSave=True) then
        begin
          if (FTableName<>null) then SaveToTable
             {MF begin}
             // was: else ShowMessage('Dataset '+Name+' can not be saved because ' +'TableName property is not set');
             else raise Exception.Create('Dataset '+Name+' can not be saved because ' +'TableName property is not set');
             {MF end}
        end;
    end;
  finally
    //UnSet bulk inbsert flag and Unsuppress master/detail filtration
    FBulkInsert:=False;
    DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
  end;
end;

procedure TZMQueryDataSet.DoCopyFromDataset(pDataset:TDataset);
var
  n: Integer;
  vFieldCount: Integer;
  vFilter:String;
  vFiltered:Boolean;
  vDisableMasterDetailFiltration:Boolean;
begin
  vFieldCount:=pDataSet.FieldDefs.Count;
    if not ZMConnection.Connected then
        ZMConnection.Connect;
   //Delete previous records
   Close; //This closes dataset and delets all records from memory
   {EmptyDataSet;} //This would be alternative to Close, but it has problems if DisableMasterDetailFiltration=True.
   //Let object knows data source...
   FSourceData:=sdOtherDataset;
   FOtherDatasetImport:=pDataset;
   FFieldCount:=FOtherDatasetImport.FieldDefs.Count;
   FRecordCount:=FOtherDatasetImport.RecordCount;
   //Prepare ZMQueryDataset
   with self do begin
    Close;
    //Decide what to do with FieldDefs and Fields
    ManageFields;
   end;
   Open;
   //Insert Fields Data.
   try
     //Remember whethere pDataSet was filtered.
     vFilter:=pDataSet.Filter;
     vFiltered:=pDataSet.Filtered;
     if (pDataSet is TZMQueryDataSet) then vDisableMasterDetailFiltration:=(pDataSet as TZMQueryDataSet).DisableMasterDetailFiltration;
     //Disable filter for the pDataSet
     pDataSet.Filter:='';
     pDataSet.Filtered:=False;
     if (pDataSet is TZMQueryDataSet) then (pDataSet as TZMQueryDataSet).DisableMasterDetailFiltration:=True;
     //iterate through pDataSet and copy values
     pDataSet.First;
     while not pDataSet.EOF do begin
       Append;
       for n:=0 to vFieldCount-1 do begin
         if FieldDefs[n].DataType<>ftAutoInc then begin
           Fields[n].Value:=pDataSet.Fields[n].Value;
         end;
       end;
       Post;
       pDataSet.Next;
     end;
   finally
     //restore filter if existed
     pDataSet.Filter:=vFilter;
     pDataSet.Filtered:=vFiltered;
     if (pDataSet is TZMQueryDataSet) then (pDataSet as TZMQueryDataSet).DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
   end;
end;

procedure TZMQueryDataSet.DoCreatePersistentFieldsFromFieldDefs;
var
  NewField: TField;
  FieldDef: TFieldDef;
  i: integer;

  function FieldNameToPascalIdentifer(const AName: string): string;
   var
     i : integer;
   begin
     Result := '';
     // FieldName is an ansistring
     for i := 1 to Length(AName) do
       if AName[i] in ['0'..'9','a'..'z','A'..'Z','_'] then
         Result := Result + AName[i];
     if (Length(Result) > 0) and (not (Result[1] in ['0'..'9'])) then
         Exit;
     if Assigned(FieldDef.FieldClass) then
     begin
       Result := FieldDef.FieldClass.ClassName + Result;
       if Copy(Result, 1, 1) = 'T' then
         Result := Copy(Result, 2, Length(Result) - 1);
     end
     else
       Result := 'Field' + Result;
   end;


  function CreateFieldName(Owner: TComponent; const AName: string): string;
  var
    C: TComponent;
    j:integer;
     begin
       for j := 0 to Owner.ComponentCount - 1 do
//       for C in Owner do
       begin
         if CompareText(Owner.Components[j].Name, AName) = 0 then
//         if CompareText(C.Name, AName) = 0 then
         begin
           {$ifdef VISUAL}
           Result := FormEditingHook.CreateUniqueComponentName(NewField);
           {$endif}
           exit;
         end;
       end;
       Result := AName;
     end;

 begin

   //This procedure creates PERSISTENT Fields from predefined FieldDefs.
  for I := 0 to Pred(fielddefs.Count) do
  with FieldDefs.Items[I] do begin
    FieldDef := Fielddefs.Items[I];
    if DataType<>ftUnknown then begin
      //Create new field and set it's unique name.

      NewField:=CreateField(self.Owner); //Owner ---> this makes created field to be persistent and visible in object inspector.

      {
      NewField:=ZMCreateField(self.Owner,FieldDef); //Owner ---> this makes created field to be persistent and visible in object inspector.
      }
      NewField.Name := CreateFieldName(self.Owner, self.Name + FieldNameToPascalIdentifer(NewField.FieldName));
      end;
      //Set initial properties of the field.
      NewField.FieldKind:=fkData;
      NewField.SetFieldType(FieldDef.DataType);
      NewField.Size:=FieldDef.Size;
      { TODO : Is there any possible way to set read-only property FieldNo??? }
      {NewField.FieldNo:=FieldDef.FieldNo};
    end;
end;

procedure TZMQueryDataSet.SetDynamicFieldsCreated(AValue: Boolean);
begin
  if FDynamicFieldsCreated=AValue then exit;
  if AValue then  //// if AValue=True then edgarrod71@gmail.com
      try
        CreateDynamicFieldsFromFieldDefs;
        {FDynamicFieldsCreated:=AValue;} //Removed to CreateDynamicFieldsFromFieldDefs procedure.
      except
        FDynamicFieldsCreated:=False;
        Active:=False;
      end
  else //// if AValue=False then edgarrod71@gmail.com
      try
        { TODO : To reconsider what action in case of SetDynamicFieldsCreated=False.
        Currently set to do nothing.
Caution: if we clear dynamic fields, persistent fields will be deleted too. }
        {
        Active:=False;
        Fields.Clear;
        }
      finally
        FDynamicFieldsCreated:=AValue;
        Active:=False;
        //Deal with mutually exclusive properties.
        FMemoryDataSetOpened:=False;
        FTableLoaded:=False;
        FQueryExecuted:=False;
      end;
end;

procedure TZMQueryDataSet.SetMasterDetailFiltration(AValue: Boolean);
begin
  if FMasterDetailFiltration=AValue then Exit;
  FMasterDetailFiltration:=AValue;
  FDisableMasterDetailFiltration := not AValue;
  Filtered := AValue;
  if Active then Refresh;
end;

procedure TZMQueryDataSet.SetMemoryDataSetOpened(AValue: Boolean);
begin
  if FMemoryDataSetOpened=AValue then Exit;
  if AValue then //// if (AValue=True) then edgarrod71@gmail.com
      try
        MemoryDataSetOpen;
        {FMemoryDataSetOpened:=AValue;} //This is removed to MemoryDataSetOpen procedure.
      except
        FMemoryDataSetOpened:=False;
        Active:=False;
      end
  else ///// if (AValue=False) then edgarrod71@gmail.com
      try
        Close; //This closes dataset and delets all records from memory
        {EmptyDataSet;} //This would be alternative to Close, but it has problems if DisableMasterDetailFiltration=True.
      finally
        FMemoryDataSetOpened:=AValue;
        Active:=False;
      end;
end;

procedure TZMQueryDataSet.SetDisableMasterDetailFiltration(const AValue: Boolean);
begin
  if FDisableMasterDetailFiltration=AValue then exit;
  FDisableMasterDetailFiltration:=AValue;  ///// edgarrod71@gmail.com
  FMasterDetailFiltration := not AValue;  //// FMasterDetailFiltration := FDisableMasterDetailFiltration = false
  Filtered := not AValue;   //// Filtered := FDisableMasterDetailFiltration = false
  if Active then Refresh;
end;

procedure TZMQueryDataSet.SetMasterDataSetTo(const AValue: TList);
begin
  if FMasterDataSetTo=AValue then exit;
  FMasterDataSetTo:=AValue;
end;

procedure TZMQueryDataSet.SetMasterReferentialKeys(const AValue: TList);
begin
  if FMasterReferentialKeys=AValue then exit;
  FMasterReferentialKeys:=AValue;
end;

procedure TZMQueryDataSet.SetPersistentFieldsCreated(AValue: Boolean);
 { TODO : To solve problems with persistent fields }
begin
  if FPersistentFieldsCreated=AValue then exit;
  if AValue then //// if AValue=True then edgarrod71@gmail.com
      try
        //In design-time only, because, in run-time persistent fields should be streamed from .lfm?
        if (csDesigning in ComponentState)
            and not (csLoading in ComponentState)
            and not (csReading in ComponentState)
          then begin
            raise Exception.Create('I am going to create persistent fields from fielddefs.');
            //ShowMessage('I am going to create persistent fields from fielddefs.');
            CreatePersistentFieldsFromFieldDefs;
          end;
        {FPersistentFieldsCreated:=AValue; //Removed to CreatePersistentFieldsFromFieldDefs procedure.}
        { TODO : Setting FPersistentFieldsCreated to True is temporarily disabled, because if PersistentFieldsCreated is True, then persistent fields will be loaded twice (once from stream and second time here) when project loading in design-time.... }
         FPersistentFieldsCreated:=False; //POOR SOLUTION
      except
        FPersistentFieldsCreated:=False;
        Active:=False;
      end
  else
  /////if AValue=False then  { TODO : To reconsider what to do on SetPersistentFieldsCreated=False. Currently set to do nothing. }
    FPersistentFieldsCreated:=AValue;
end;

procedure TZMQueryDataSet.SetSlaveReferentialKeys(const AValue: TList);
begin
  if FSlaveReferentialKeys=AValue then exit;
  FSlaveReferentialKeys:=AValue;
end;

procedure TZMQueryDataSet.SetMasterFields(const AValue: TStrings);
begin
  if FMasterFields=AValue then exit;
  FMasterFields.Assign(AValue);
end;

procedure TZMQueryDataSet.SetMasterSource(const AValue: TDataSource);
begin
  if FMasterSource=AValue then exit;
  //Remember old master source
  if Assigned (FMasterSource) then begin
    FOldMasterSource:=FMasterSource;
  end;
  //Set new master data source
  FMasterSource:=AValue;
  UpdateMasterDataSetTo;
end;

procedure TZMQueryDataSet.UpdateMasterDataSetTo;
var
  vAlreadyInList, vToAddNew,vToRemoveOld:Boolean;
begin
  if Assigned (FMasterSource)
     then vAlreadyInList:=(TObject(FMasterSource.DataSet) as TZMQueryDataSet).MasterDataSetTo.IndexOf(self)>=0
     else vAlreadyInList:=False;
  //Inspect how to update detail datasets list
  if ((FOldMasterSource<>FMasterSource) and Assigned(FMasterSource))
     then vToAddNew:=True else vToAddNew:=False;
  if ((FOldMasterSource<>FMasterSource) and (vAlreadyInList=True) and Assigned(FOldMasterSource))
     then vToRemoveOld:=True else vToRemoveOld:=False;
  //Update detail datasets list
  //Append dataset to the list of datasets for which the dataset is master dataset
  if (vToAddNew=True) then begin
    (TObject(FMasterSource.DataSet) as TZMQueryDataSet).MasterDataSetTo.Add(self);
  end;
  //Remove dataset from the list of datasets for which the dataset is master dataset
  if (vToRemoveOld=True)  then begin
    (TObject(FOldMasterSource.DataSet) as TZMQueryDataSet).MasterDataSetTo.Remove(self);
  end;
end;

procedure TZMQueryDataSet.SetParameters(const AValue: TParams);
begin
  if FParameters=AValue then exit;
  FParameters:=AValue;
end;

procedure TZMQueryDataSet.SetPersistentSave(const AValue: Boolean);
begin
  if FPersistentSave=AValue then exit;
  FPersistentSave:=AValue;
end;

procedure TZMQueryDataSet.SetTableLoaded(const AValue: Boolean);
begin
  if FTableLoaded=AValue then exit;
  if AValue then ////if AValue=True then  edgarrod71@gmail.com
      try
        LoadFromTable;
        {FTableLoaded:=AValue; } //This is removed inside LoadFromTable procedure.
      except
        FTableLoaded:=False;
        Active:=False;
      end
  else ////if AValue=False then edgarrod71@gmail.com
      try
        Close; //This closes dataset and deletes all records from memory
        {EmptyDataSet;} //This would be alternative to Close, but it has problems if DisableMasterDetailFiltration=True.
      finally
        FTableLoaded:=AValue;
        Active:=False;
      end;
end;

procedure TZMQueryDataSet.SetTableName(const AValue: String);
begin
  if FTableName=AValue then exit;
  FTableName:=AValue;
end;

procedure TZMQueryDataSet.SetTableSaved(const AValue: Boolean);
begin
  if FTableSaved=AValue then exit;
  if AValue then /////if AValue=True then  edgarrod71@gmail.com
      try
        SaveToTable;
        FTableSaved:=AValue;
      finally
        FTableSaved:=False;
      end
  else ////if AValue=False then
      FTableSaved:=AValue;
end;

procedure TZMQueryDataSet.SetQueryExecuted(const AValue: Boolean);
begin
  if FQueryExecuted=AValue then exit;
  if AValue then ///  if AValue=True then edgarrod71@gmail.com
      try
        if not ZMConnection.Connected then
            ZMConnection.Connect;  ////.Connected:=True;  edgarrod71@gmail.com
        QueryExecute;
        {FQueryExecuted :=AValue;} //Moved to QueryExecute procedure.
      except
        FQueryExecuted :=False;
        Active:=False;
      end
  else     /// if AValue = false  edgarrod71@gmail.com
      try
        EmptyDataSet; //Delete records from the dataset.
        FJanSQLInstance.ReleaseRecordset(FRecordsetIndex);
      finally
        FQueryExecuted:=AValue;
        Active:=False;
      end;
end;

procedure TZMQueryDataSet.SetSQL(const AValue: TStrings);
begin
  if FSQL=AValue then exit;
  FSQL.Assign(AValue);
end;

procedure TZMQueryDataSet.PassQueryResult;
begin
  FSourceData:=sdJanSQL;
  FRecordCount:=FJanSQLInstance.RecordSets[FRecordsetIndex].recordcount;
  FFieldCount:=FJanSQLInstance.RecordSets[FRecordsetIndex].fieldcount;
  with self do begin
    //Decide what to do with FieldDefs and Fields
    ManageFields;
    //OpenDataset
    Open;
    InsertDataFromJanSQL;
  end;
end;

procedure TZMQueryDataSet.EmptyDataSet;
//This procedure deletes all records from dataset.
var
   vFilter:String;
   vFiltered:Boolean;
begin
  with self do begin
    //This is incredible slow in MemDataset, seems to be faster in TBufDataset!
    try    //// test edgarrod71@gmail.com I put Fields.Count inactive,
          //// because if RecordCount>0 means that Fields were loaded!!!
      if ({(Fields.Count>0) and }(RecordCount>0) and Active{=True)}) then begin
        try
          DisableControls;  // edgarrod71@gmail.com
          //Rememeber filter and disable it while deleting records.
          vFilter:=Filter;
          vFiltered:=Filtered;
          Filter:='';
          Filtered:=False;
          //Delete records.
          first;
          repeat
            Delete;
          until EOF;
        finally
          //Reestablish filter if existed before deletion.
          Filter:=vFilter;
          Filtered:=vFiltered;
          Refresh; //I'm not sure whether this is neccessary...
          EnableControls;
        end;
      end;
    except
      {MF begin}
      // was: ShowMessage('Error in EmptyDataset method, dataset: '+self.Name);
      on e:Exception do begin
        raise Exception.Create('Error in EmptyDataset method, dataset: '+self.Name);
      end;
      {MF end}
    end;
  end;
end;

procedure TZMQueryDataSet.ClearDataSet;
//This procedure deletes both fielddefs and fields, with all data...
begin
  with self do begin
    if Active{=True} then Close;
    FieldDefs.Clear;
    Fields.Clear;
  end;   {Why doesn't it delete all?}
end;

procedure TZMQueryDataSet.CopyFromDataset(pDataset: TDataSet);
//This procedure can copy any dataset data (and if neccessary schema too) to zmquerydataset
var
   vDisableMasterDetailFiltration:Boolean;
   vFilter:String;
   vFiltered:Boolean;
begin
  //First, see whether there are present persistent fields and whether they need initialization.
  InitializePersistentFields;
  with self do begin
    try     
      DisableControls;
      pDataSet.DisableControls;
      //Remember filters
      vDisableMasterDetailFiltration:=DisableMasterDetailFiltration;
      vFilter:=Filter;
      vFiltered:=Filtered;
      //Set bulk inbsert flag and suppress master/detail filtration, remove filters
      FBulkInsert:=True;
      DisableMasterDetailFiltration:=True;
      Filter:='';
      Filtered:=False;
      //Do copy from pDataSet
      DoCopyFromDataset(pDataset);
    finally
      FBulkInsert:=False;
      DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
      Filter:=vFilter;
      Filtered:=vFiltered;
      EnableControls;
      pDataset.EnableControls;
    end;
  end;
end;

procedure TZMQueryDataSet.CopyARowFromDataset(pDataset: TDataSet);
var
  vFieldDef:TFieldDef;
  vFieldCount:Integer;
  i,n:Integer;
begin
  vFieldCount:=pDataSet.FieldDefs.Count;
  with self do begin
    try
      //Set bulk insert flag
      FBulkInsert:=True;
      ClearDataSet;
      DisableControls;
      //Create FieldDefs.
      for i:=0 to vFieldCount-1 do begin
        vFieldDef:=FieldDefs.AddFieldDef;
        vFieldDef.Name:=pDataSet.FieldDefs[i].Name;
        if pDataSet.FieldDefs[i].DataType=ftAutoInc then vFieldDef.DataType:=ftInteger
          else vFieldDef.DataType:=pDataSet.FieldDefs[i].DataType;
        vFieldDef.Size:=pDataSet.FieldDefs[i].Size;
        vFieldDef.Required:=pDataSet.FieldDefs[i].Required;
      end;
      MaxIndexesCount:=(2*(FieldDefs.Count)+3);
      CreateDataSet;  //In case of TBufDataset ancestor.
      Open;
      //Insert current record from pDataSet.
      Append;
      for n:=0 to vFieldCount-1 do begin
        Fields[n].Value:=pDataSet.Fields[n].Value;
      end;
      Post;
    finally
      //Remove bulk inbsert flag
      FBulkInsert:=False;
      EnableControls;
    end;
  end;
end;

procedure TZMQueryDataSet.UpdateFOldRecord;
begin
  //For referential filtration
  if Active and (FBulkInsert=False) then
    TZMQueryDataSet(FOldRecord).CopyARowFromDataSet(self);
end;

function TZMQueryDataSet.FormatStringToFloat(pFloatString: string):Extended;
//Transform float value inside a string with adequate decimal separator.
var
 // modified by edgarrod71@gmail.com
  vFloatString, vLeftPart, vRightPart:String;
  vDelimiterPos, I: SizeInt;
  Dp, Tp, vDecSep: Char;

  function StrToNumber(aStr:string): string;
  var
    P: Pchar;
  begin
    p := @aStr[1];
    result := '';
    repeat
      if p^ in ['0'..'9','-'] then
        result += p^;
      inc(p);
    until (p = #0) or (p = '');
  end;

  function GetDecSep(aStr: String): Char;
  var
    Pa, Pb: PChar;
  begin
    I := length(aStr);
    Pa := @aStr[1];
    Pb := @aStr[I];
    if (Pa <= Pb) and not(Pb^ in [Dp, Tp]) then
    repeat
      dec(Pb)
    until (Pa > Pb) or (Pb^ in [Dp, TP]);
    vDelimiterPos := Pb - Pa + 1;
    result := Pb^;
  end;

begin
    Result := 0.00;
    if pFloatString <> '' then begin
      Dp := SysUtils.DefaultFormatSettings.DecimalSeparator;
      Tp := SysUtils.DefaultFormatSettings.ThousandSeparator;
      vDecSep := GetDecSep(pFloatString);
      if vDecSep <> Dp then
        case vDecSep of
            '.': vDecSep := ',';
            ',': vDecSep := '.';
        end;
      vLeftPart := StrToNumber(copy(pFloatString, 1, Pred(vDelimiterPos)));
      vRightPart := copy(pFloatString, Succ(vDelimiterPos), I-Pred(vDelimiterPos));
      vFloatString := vLeftPart + vDecSep + vRightPart;
      result := StrToFloat(vFloatString);
    end
end;

function TZMQueryDataSet.SortDataset(const pFieldName: String):Boolean;
var
  i: Integer;
  vIndexDefs: TIndexDefs;
  vIndexName: String;
  vIndexOptions: TIndexOptions;
  vField: TField;
begin
  Result := False;
  vField := Fields.FindField(pFieldName);
  //If invalid field name, exit.
  if vField = nil then Exit;
  //if invalid field type, exit.
  if {(vField is TObjectField) or} (vField is TBlobField) or
    {(vField is TAggregateField) or} (vField is TVariantField)
     or (vField is TBinaryField) then Exit;
  //Get IndexDefs and IndexName using RTTI
  if IsPublishedProp(self, 'IndexDefs') then
    vIndexDefs := GetObjectProp(self, 'IndexDefs') as TIndexDefs
  else
    Exit;
  if IsPublishedProp(self, 'IndexName') then
    vIndexName := GetStrProp(self, 'IndexName')
  else
    Exit;
  //Ensure IndexDefs is up-to-date
  IndexDefs.Update;
  //If an ascending index is already in use,
  //switch to a descending index
  if vIndexName = pFieldName + '__IdxA'
  then
    begin
      vIndexName := pFieldName + '__IdxD';
      vIndexOptions := [ixDescending];
    end
  else
    begin
      vIndexName := pFieldName + '__IdxA';
      vIndexOptions := [];
    end;
  //Look for existing index
  for i := 0 to Pred(IndexDefs.Count) do
  begin
    if vIndexDefs[i].Name = vIndexName then
      begin
        Result := True;
        Break
      end;  //if
  end; // for
  //If existing index not found, create one
  if not Result then
      begin
        if vIndexName=pFieldName + '__IdxD' then
          AddIndex(vIndexName, pFieldName, vIndexOptions, pFieldName)
        else
          AddIndex(vIndexName, pFieldName, vIndexOptions);
        Result := True;
      end; // if not
  //Set the index
  SetStrProp(self, 'IndexName', vIndexName);
end;

procedure TZMQueryDataSet.LoadFromTable;
begin
  DisableControls;
  //First, see whether there are present persistent fields and whether they need initialization.
  InitializePersistentFields;
  try
    try
      DoLoadFromTable;
      //If everything goes well, ensure that corresponding property is set accordingly.
      FTableLoaded:=True;
      //Set mutually exclusive properties to False.
      FQueryExecuted:=False;
      FMemoryDataSetOpened:=False;
    except
      FTableLoaded:=False;
      Active:=False;
    end;
  finally
    //Refresh self
    if Active then refresh;
    FSdfDatasetImport.Close;
    EnableControls;
  end;
end;

procedure TZMQueryDataSet.LoadTableSchema;
begin
  DisableControls;
  //First, see whether there are present persistent fields and whether they need initialization.
  InitializePersistentFields;
  try
    try
      DoLoadTableSchema;
      //If everything goes well, ensure that corresponding property is set accordingly.
      FTableLoaded:=True;
      //Set mutually exclusive properties to False.
      FQueryExecuted:=False;
      FMemoryDataSetOpened:=False;
    except
      FTableLoaded:=False;
      Active:=False;
    end;
  finally
    //Refresh self
    if Active then refresh;
    FSdfDatasetImport.Close;
    EnableControls;
  end;
end;

procedure TZMQueryDataSet.SaveToTable;overload;
var
  vFiltered:Boolean;
  vFilter:String;
  vBookmark:TBookmark;
  vDisableMasterDetailFiltration:Boolean;
begin
  try
    DisableControls;
    vDisableMasterDetailFiltration:=DisableMasterDetailFiltration;
    //Disable Master/Detail filtration
    DisableMasterDetailFiltration:=True;
    //Get bookmark
    vBookmark:=GetBookmark;
    //Get filter
    if Filtered=True then vFiltered:=True else vFiltered:=False;
    vFilter:=Filter;
    //Temporary disable filters
    Filtered:=False;
    //Refresh in order to disable filters
    DisableControls;
    if active then Refresh;
    if active then First;
    EnableControls;
    with FCSVExporterExport do begin
     Dataset:=self;
     FileName:=ZMConnection.DatabasePath{Full}+TableName+'.csv';
     FromCurrent:=False;
     FormatSettings.FieldDelimiter:= C;
     FormatSettings.HeaderRow:=True;
   //  FormatSettings.QuoteStrings:=[qsAlways];   //=== ct9999 in FPC SVN 30449 NOT Exists ====
     FormatSettings.BooleanFalse:='False';
     FormatSettings.BooleanTrue:='True';
     FormatSettings.DateFormat:='yyyy-mm-dd';
     FormatSettings.DateTimeFormat:='yyyy-mm-dd hh:mm:ss';
     //Set decimal separator.
     FormatSettings.DecimalSeparator:=SysUtils.DefaultFormatSettings.DecimalSeparator;
     Execute;
   end;
   //Restore filters.
    Filter:=vFilter;
    Filtered:=vFiltered;
   //Goto bookmark
   if ((BookmarkAvailable) and (BookmarkValid(vBookmark))) then
     GotoBookmark(vBookmark);
  finally
    //Enable Master/Detail filtration
    DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
    //Refresh in order to enable filters
    if Active then Refresh;
    FreeBookmark(vBookmark);
    EnableControls;
  end;
end;

procedure TZMQueryDataSet.SaveToTable(pDecimaSeparator: Char);
var
  vFiltered:Boolean;
  vFilter:String;
  vBookmark:TBookmark;
  vDisableMasterDetailFiltration:Boolean;
begin
  try
    DisableControls;
    vDisableMasterDetailFiltration:=DisableMasterDetailFiltration;
    //Disable Master/Detail filtration
    DisableMasterDetailFiltration:=True;
    //Get bookmark
    vBookmark:=GetBookmark;
    //Get filter
    if Filtered=True then vFiltered:=True else vFiltered:=False;
    vFilter:=Filter;
    //Temporary disable filters
    if Active then Filtered:=False;
    if Active then Refresh;
    //Goto first record.
    First;
    with FCSVExporterExport do begin
     Dataset:=self;
     {FileName:=ZMConnection.DatabasePathFull+TableName+'.txt';}
     FileName:=ZMConnection.DatabasePath{Full}+TableName+'.csv';
     FromCurrent:=False;
     FormatSettings.FieldDelimiter:= C;
     FormatSettings.HeaderRow:=True;
  //   FormatSettings.QuoteStrings:=[qsAlways];  //=== ct9999 in FPC SVN 30449 NOT Exists ====
     FormatSettings.BooleanFalse:='False';
     FormatSettings.BooleanTrue:='True';
     FormatSettings.DateFormat:='yyyy-mm-dd';
     FormatSettings.DateTimeFormat:='yyyy-mm-dd hh:mm:ss';
     FormatSettings.DecimalSeparator:=pDecimaSeparator;
     Execute;
   end;
   //Restore filters.
    Filter:=vFilter;
    Filtered:=vFiltered;
   //Goto bookmark
   if ((BookmarkAvailable) and (BookmarkValid(vBookmark))) then
     GotoBookmark(vBookmark);
  finally
    //Enable Master/Detail filtration
    DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
    if Active then Refresh;
    FreeBookmark(vBookmark);
    EnableControls;
  end;
end;

procedure TZMQueryDataSet.CreateDynamicFieldsFromFieldDefs;
//This procedure is used to create Fields from FieldDefs, create the dataset and make it active.
begin
  //Prepare ZMQueryDataset
  with self do begin
     FSourceData:=sdInternal;
     FFieldCount:=FieldDefs.Count;
    try
      Close;
      //Decide what to do with FieldDefs and Fields
      ManageFields;  //If matching persistent fields (match in FieldName and number) are already created, do nothing.
      //If everything goes ok, set the property accordingly.
      {FDynamicFieldsCreated:=True;}
    except
      FDynamicFieldsCreated:=False;
      Active:=False;
    end;
  end;
end;

procedure TZMQueryDataSet.CreatePersistentFieldsFromFieldDefs;
//This procedure is used to create PERSISTENT Fields from FieldDefs.
{var strMsg:String;}
begin
  with self do begin
    FSourceData:=sdInternal;
    FFieldCount:=FieldDefs.Count;
    try
      Close;
      // Create PERSISTENT fields from FieldDefs
      { TODO : To investigate BindFields(False) and DefaultFields in ZMBufDataset and TBufDataset.
In Delphi, BindFields(False) disconnects  fields object from underlying fields, but it seems that currently this does not work here?
Also, DefaultFields should be False in case of persistent fields and True in case of dynamic fields. However, it seems that sometimes it is False even if only dynamic fields are created.}
      {
      if InspectFields=ifDoNothing {This means that there are already created corresponding persistent fields.} then begin
        ShowMessage('InspectFields=ifDoNothing');
        if DefaultFields=False {DefaultFields=False means Persistent Fields exist} then begin
          ShowMessage('DefaultFields=False');
          Exit;
        end;
      end;
      }
      Fields.Clear;
      //DefaultFields should be False in case of persistent fields?
      SetDefaultFields(False);
      DoCreatePersistentFieldsFromFieldDefs;
      BindFields(True); //Connect persistent Fields objects to underlying Fields.
      //If everything goes ok, set the property accordingly.
      FPersistentFieldsCreated:=True;
      //Deal mutually exclusive property
      FDynamicFieldsCreated:=False;
    except
      {MF begin}
      // was: ShowMessage('I can not create persistent fields!');
      // was: FPersistentFieldsCreated:=False;
      // was: Active:=False;
      on e:Exception do begin
        FPersistentFieldsCreated:=False;
        Active:=False;
        raise Exception.Create('I can not create persistent fields!');
      end;
      {MF end}
    end;
  end;
end;

procedure TZMQueryDataSet.MemOpen;
//This procedure creates dataset fields (if not created) and opens the dataset for insert/edit.
//To be used for activation of memory datasets that will not be filled by sql query,
//nor be loaded from stored tables.
begin
 //First, see whether there are present persistent fields and whether they need initialization.
 InitializePersistentFields;
 FSourceData:=sdInternal;
 FFieldCount:=FieldDefs.Count;
 try
   //First, deal with creating dataset anew...
   ManageFields;
   //Then, open the dataset
   Active:=True;
   //If everything goes OK, then set the property accordingly.
   FMemoryDataSetOpened:=True;
   //Set mutually exclusive properties to false.
   FQueryExecuted:=False;
   FTableLoaded:=False;
 except
   FMemoryDataSetOpened:=False;
   Active:=False;
 end;
end;

procedure TZMQueryDataSet.MemoryDataSetOpen;
begin
  MemOpen;
end;

procedure TZMQueryDataSet.FieldsFromFieldDefs;
var
  vFieldDefsCount: Integer;
//Here we create dynamic fields from predefined fielddefs.
begin
//  with self do begin
    close;
    Fields.Clear;
    vFieldDefsCount := FieldDefs.Count;

    if (vFieldDefsCount > 0) then begin  ////edgarrod71@gmail.com  supposed Fields.Count is 0!!!
      //Set MaxIndexes count if not manually set
      if (MaxIndexesCount = Null) or (MaxIndexesCount < (2 * vFieldDefsCount + 3)) then
            MaxIndexesCount:= 2 * vFieldDefsCount + 3;
      //Set precision for float fields
      SetFloatPrecision;
      CreateDataset; //Creates Fields from FieldDefs  /// Aquí es donde se bloquea... edgarrod71@gmail.com
    end;
    //Set display format for float fields
    SetFloatDisplayFormat;
    //Set property DynamicFieldsCreated to True
    FDynamicFieldsCreated:=True;
    FPersistentFieldsCreated:=False;
end;

procedure TZMQueryDataSet.FieldsFromScratch;
//Here we create both fielddefs and fields.
var
   vFieldDef:TFieldDef;
   vCurrentFieldSize, vMaxFieldSize, i, n:Integer;
begin
  with self do begin
    if Active{=True} then Close;
    //Clears both fielddefs and fields....
    Fields.Clear;
    FieldDefs.Clear;
    //Create new FieldDefs.
    for n:=0 to FFieldCount-1 do begin
      vFieldDef:=FieldDefs.AddFieldDef;
      case FSourceData of
        sdJanSQL:vFieldDef.Name:=FJanSQLInstance.recordsets[FRecordsetIndex].FieldNames[n];
        sdSdfDataset:vFieldDef.Name:=FSdfDatasetImport.FieldDefs[n].Name;
        sdOtherDataset:vFieldDef.Name:=FOtherDatasetImport.FieldDefs[n].Name;
      end;
      //Determine FieldDef properties
      case FSourceData of
        sdJanSQL:
          begin
            vFieldDef.DataType:=ftString;//TODO: In procedure FieldsFromScratch add other fielddefs DataType recognition, besides ftString.
            vFieldDef.Required:=False;
            vFieldDef.Precision:=0;
            vFieldDef.Attributes:=[];
          end;
        sdSdfDataset:
          begin
            vFieldDef.DataType:=FSdfDatasetImport.FieldDefs[n].DataType;
            vFieldDef.Required:=False;
            vFieldDef.Precision:=0;
            vFieldDef.Attributes:=[];
          end;
        sdOtherDataset:
          begin
            vFieldDef.DataType:=FOtherDatasetImport.FieldDefs[n].DataType;
            vFieldDef.Required:=FOtherDatasetImport.FieldDefs[n].Required;
            vFieldDef.Precision:=FOtherDatasetImport.FieldDefs[n].Precision;
            vFieldDef.Attributes:=FOtherDatasetImport.FieldDefs[n].Attributes;
          end;
      end;
      //Determine FieldDef.Size property!
      vMaxFieldSize:=0;
      vCurrentFieldSize:=0;
      case FSourceData of
        sdSdfDataset: vFieldDef.Size:=FSdfDatasetImport.Fields[n].Size;
        sdJanSQL:
          begin
            for i:=0 to FRecordCount-1 do begin
              vCurrentFieldSize:=Length(FJanSQLInstance.RecordSets[FRecordsetIndex].records[i].fields[n].value);
              if vCurrentFieldSize>vMaxFieldSize then vMaxFieldSize:=vCurrentFieldSize;
            end;
            if vMaxFieldSize>0 then vFieldDef.Size:=vMaxFieldSize else vFieldDef.Size:=255;
          end;
        sdOtherDataset: vFieldDef.Size:=FOtherDatasetImport.Fields[n].Size;
      end;
      //Set MaxIndexes count
      if ((MaxIndexesCount=Null)
        or (MaxIndexesCount<(2*(FieldDefs.Count)+3)))
      then MaxIndexesCount:=(2*(FieldDefs.Count)+3);
    end;
    //Set precision for float fields
    SetFloatPrecision;
    CreateDataSet;//Creates Fields from FieldDefs
    //Set display format for float fields
    SetFloatDisplayFormat;
    //Set property DynamicFieldsCreated to True
    FDynamicFieldsCreated:=True;
    FPersistentFieldsCreated:=False;
  end;
end;

procedure TZMQueryDataSet.EmptySdfDataSet;
begin
  with FSdfDatasetImport do begin
    if Active=False then Open;
    while not EOF do begin
      Delete;
    end;
  end;
end;

procedure TZMQueryDataSet.ClearSdfDataSet;
begin
  with FSdfDatasetImport do begin
    if Active=True then Close;
      FieldDefs.Clear;
      Fields.Clear;
  end;
end;

procedure TZMQueryDataSet.dummyProc;
begin

end;

function makeMethod(data, code: Pointer): TMethod;
begin
  result.data := data;
  result.code := code;
end;

procedure TZMQueryDataSet.InsertDataFromCSV;
{type
   TProc = procedure {(DataSet: TDataSet)} of object;
const
  NullMethod: TMethod = (Code: nil; Data: nil);}
var
   i:SizeInt;
   vFieldString:string;
{   DS: TBufDataSet;
   P: ^TRTLMethod;
   tmpProc: TRTLMethod;//TProc; //TDataSetNotifyEvent;}
begin
  if not Active then Open;
  if not FSdfDatasetImport.Active then FSdfDatasetImport.Open;
  DisableControls;    //// Seem not to be working because the program enters in AfterScroll event!!!!

{  tmpProc := TDataSetnotifyEvent(@DoAfterScroll);  //// edgarrod71@gmail.com WORKAROUND!!!!
}
{  tmpProc := @DoAfterScroll;
  tmpProc := TRTLMethod(@DoAfterScroll);

  SetMethodProp(Self, 'OnAfterScroll', NullMethod);
    P^ := @DoAfterScroll;
    tmpProc := TProc(@DoAfterScroll);
    tmpProc := TProc(MakeMethod(Self, P));}

//  DoAfterScroll := TDataSetNotifyEvent(MakeMethod(Self, @tmpProc));
{  TZMQueryDataSet(Self).DoAfterScroll := nil;
  TMethod(DoAfterScroll).data := Pointer(Self);}
//  DoAfterScroll := TDataSetNotifyEvent(@dummyProc);

  FSdfDatasetImport.First;
  FAutoIncValue := 0;
  while not FSdfDatasetImport.EOF do begin
    Append;
    for i := 0 to Pred(FFieldCount) do begin
      if FieldDefs[i].DataType <> ftAutoInc then begin
        vFieldString := FSdfDatasetImport.Fields[i].AsString;
        try
          case Fields[i].DataType of //Fields of Float type require special transformation.
              ftFloat:
                Fields[i].Value := FormatStringToFloat(vFieldString);  //Format value with appropriate decimal separator.
              ftInteger: begin
                if (vFieldString[1] in ['1'..'9','-']) then
                   Fields[i].Value := StrToInt(vFieldString)
                else
                   Fields[i].AsString := FSdfDatasetImport.Fields[i].AsString;
              end;
              else begin   //Other field types.
                 //Convert string to UTF8
                 {vFieldString:=AnsiToUTF8(vFieldString);}
                 vFieldString:=ConvertEncoding(vFieldString, GuessEncoding(vFieldString),EncodingUTF8);
                 Fields[i].Value:=vFieldString;
              end;
          end; {case}
        except
          Fields[i].Value:=FSdfDatasetImport.Fields[i].Value;
        end;
      end
      else { BECAUSE IT IS FTAUTOINC } begin   /// edgarrod71@gmail.com
        if FSdfDatasetImport.Fields[i].AsInteger > FAutoIncValue then
          FAutoIncValue := FSdfDatasetImport.Fields[i].AsInteger;
        Fields[i].AsInteger := FSdfDatasetImport.Fields[i].AsInteger;
      end; {try}
    end;
    Post;
    FSdfDatasetImport.Next;
  end;

  //DoAfterScroll := TDataSetNotifyEvent(makeMethod(nil, @tmpProc));
//  tmpProc := nil;

  if Active then begin
    Refresh;
    First;
  end;
  EnableControls;
end;

procedure TZMQueryDataSet.InsertDataFromJanSQL;
var
   i,n:integer;
   vFieldString:string;
begin
  if Active=False then Open;
  with self do begin
    FAutoIncValue := 0;
    try
    for i:=0 to Pred(FRecordCount) do begin
      Append;
      //Iterate columns
      for n:=0 to pred(FFieldCount) do begin
        if FieldDefs[n].DataType<>ftAutoInc then begin
          vFieldString:=FJanSQLInstance.RecordSets[FRecordsetIndex].records[i].fields[n].value;
          //Convert string to UTF8
          {vFieldString:=AnsiToUTF8(vFieldString);}
          vFieldString:=ConvertEncoding(vFieldString, GuessEncoding(vFieldString),EncodingUTF8);
          //Float fields need special transformation
          case Fields[n].DataType of  /// edgarrod71@gmail.com
            ftFloat: begin
              try
                //Format value with appropriate decimal separator.
                Fields[n].Value:=FormatStringToFloat(vFieldString);
              except
                Fields[n].AsString:=vFieldString;
              end;
            end;
            ftInteger: begin
                 if (vFieldString[1] in ['1'..'9','-']) then  /// must start with a valid number
                     Fields[i].Value := StrToInt(vFieldString)
                 else
                     Fields[n].AsString:=vFieldString;
            end;
              //Other types of fields.
            else Fields[n].Value := vFieldString;
          end; {case}
        end
        else { BECAUSE IT IS FTAUTOINC } begin   /// edgarrod71@gmail.com
          if FJanSQLInstance.RecordSets[FRecordsetIndex].records[i].fields[n].value > FAutoIncValue then
            FAutoIncValue := FJanSQLInstance.RecordSets[FRecordsetIndex].records[i].fields[n].value;
          Fields[i].AsInteger := FJanSQLInstance.RecordSets[FRecordsetIndex].records[i].Fields[n].value;
        end;
      end;
      Post;
    end;
    except
      raise exception.Create('error en I='+IntToStr(i));
    end;
    if Active then begin
      Refresh;
      First;
    end;
  end;
end;

function TZMQueryDataSet.InspectFields:TInspectFields;
//This function compares old and new dataset and detects whether fielddefs and fields should be created or not.
//TInspectFields=(ifCreateFieldsFromFieldDefs, ifCreateFieldDefsAndFields, ifDoNothing, ifNewIsEmpty, ifOther);
var
   vNewFieldNames, vOldFieldNames:String;
   vNewFieldDefNames, vOldFieldDefNames:String;
   i, vFieldDefsCount:Integer;
   vFieldCountMatch:Boolean;
   vFieldDefNamesMatch:Boolean;
   vNewIsEmpty:Boolean;
   vFieldType: TFieldType;
begin
  //Set default values
  Result:=ifOther;
///  vFieldCountMatch:=False; edgarrod71@gmail.com
  vFieldDefNamesMatch:=false;
  vNewIsEmpty:=False;
  vOldFieldNames:='';
  vOldFieldDefNames:='';
  vNewFieldNames:='';
  vNewFieldDefNames:='';
  vFieldDefsCount := FieldDefs.Count;
  //Iterate through Old Dataset (assumption: There cannot be fields without fielddefs).
    //FieldDefs
    for i:=0 to pred(vFieldDefsCount) do begin
      vOldFieldDefNames += FieldDefs[i].Name + C;
      vFieldType := FieldDefs[i].DataType;
      if (vFieldType = ftAutoInc) and (FAutoIncIdx = -1) then
           FAutoIncIdx := I;   { Question (edgarrod71@gmail.com)::: how many AutoIncrement fields must syncronize with this? I suppose it must be only one! }
      //Fields
      if (Fields.Count>0) and (Fields.Count >= (i + 1)) then
            vOldFieldNames += Fields[i].FieldName + C;
      end;
//  end;
  //Iterate through New Dataset
  if boolean(FFieldCount) then begin  //// FFieldCount>0
    if FSourceData = sdInternal then
        vNewFieldDefNames := vOldFieldDefNames  //// avoids to enter in the next loop!  edgarrod71@gmail.com
    else
    for i:=0 to pred(FFieldCount) do begin
      case FSourceData of
        sdJanSQL:vNewFieldDefNames += FJanSQLInstance.recordsets[FRecordsetIndex].FieldNames[i]+ C;
        sdSdfDataset:vNewFieldDefNames += FSdfDatasetImport.FieldDefs[i].Name+ C;
        sdOtherDataset:vNewFieldDefNames += FOtherDatasetImport.FieldDefs[i].Name+ C;
////        sdInternal: vNewFieldDefNames += FieldDefs[i].Name+';';  //// Old Code, review it to eliminate
      end;
    end;
    vNewFieldNames := vNewFieldDefNames;  /// edgarrod71@gmail.com  took it out from the loop...
  end;
  //Inspect whether number of columns is same in old and new dataset
  vFieldCountMatch := FieldDefs.Count = FFieldCount; /// edgarrod71@gmail.com then vFieldCountMatch:=True;
  //Inspect whether new dataset is empty (with no columns)
  vNewIsEmpty := vNewFieldDefNames = '';  /// edgarrod71@gmail.com then vNewIsEmpty:=True;
  //Inspect whether fielddef names match
  vFieldDefNamesMatch := vNewFieldDefNames = vOldFieldDefNames; /// edgarrod71@gmail.com then vFieldDefNamesMatch:=True else vFieldDefNamesMatch:=False;

  if vNewIsEmpty then    /// Modified by edgarrod71@gmail.com
      Result := ifNewIsEmpty
  else {if vNewIsEmpty=false} begin
      if vFieldCountMatch and vFieldDefNamesMatch then
          if vOldFieldNames = vNewFieldNames then
              Result := ifDoNothing
          else
              Result := ifCreateFieldsFromfieldDefs
      else  { and (vFieldCountMatch=False) or (vFieldDefNamesMatch=False) then }
          Result := ifCreateFieldDefsAndFields;
  end;
end;

procedure TZMQueryDataSet.DoFilterRecord({var} out Acceptable: Boolean);
var
  i, vCount:Integer;
  namDetail, namMaster: String;
  DetailField, MasterField: TField;
begin
  //inherited behavior
  inherited DoFilterRecord(Acceptable);

  //New behavior
  if not Acceptable then exit;

  //Filter detail dataset if all conditions are met.
  if (not FBulkInsert)
    and (not DisableMasterDetailFiltration)
    and (Assigned(MasterFields))
    and (Assigned(MasterSource))
    and (FMasterDetailFiltration)
    and (Active)
    and (MasterSource.DataSet.Active) then
  begin
    vCount:=0;
    Filtered:=True; //Ensure dataset is filtered
    for i:=0 to MasterFields.Count-1 do begin
      //try
       namDetail := MasterFields.Names[i];
       if namDetail <> '' then begin
         // if Name=Value (Detail field=Master field) pair is provided...
         namMaster := MasterFields.ValueFromIndex[i];
       end else begin
         // if single name is provided for both detail and master field
         namMaster := FMasterFields[i];
         namDetail := namMaster;
       end;
       DetailField := FieldByName(namDetail);
       MasterField := MasterSource.Dataset.FieldByName(namMaster);
       if VarSameValue(Detailfield.Value, Masterfield.Value) then
         inc(vCount);
    end;
    Acceptable := (vCount=MasterFields.Count);

    //Refresh slave datasets
    if not ControlsDisabled then  //// edgarrod71@gmail.com
      DoAfterScroll;
  end;
end;

procedure TZMQueryDataSet.DoOnNewRecord;
begin
  inherited DoOnNewRecord;
 {New behavior}

 { TODO : This is only temporary solution until bug(s) regarding ftAutoInc in TBufDataset is solved.
The bug is: when new dataset is created and opened, autoincrement fields are working correctly. But, if dataset is closed and reopened, autoincrement fields are not working anymore.
See bug report: http://bugs.freepascal.org/view.php?id=25628
Also, as currently implemented in TBufDataset, ftAutoInc can't be used for referential integrity in zmquerydataset.}
{ BUG CORRECTED!!!! edgarrod71@gmail.com }   /// no estoy seguro si la segunda condición vale...
  if (FAutoIncIdx > -1) {and (Fields[FAutoIncIdx].DataType = ftAutoInc)} then
    Fields[FAutoIncIdx].AsInteger := Succ(FAutoIncValue);
end;

procedure TZMQueryDataSet.DoAfterScroll;
var
   i:Integer;
begin
  inherited DoAfterScroll;
  {New behavior}
  //For master/detail filtration
  if Assigned (FMasterDatasetTo) then begin
    for i:=0 to FMasterDatasetTo.Count-1 do begin
      if ((TZMQueryDataSet(FMasterDatasetTo.Items[i]).Active) and (Active)
          and (TZMQueryDataSet(FMasterDatasetTo.Items[i]).Fields.Count>0)
          and (Fields.Count>0)
          {and (TZMQueryDataSet(FMasterDatasetTo.Items[i]).FieldDefs.Count=TZMQueryDataSet(FMasterDatasetTo.Items[i]).Fields.Count)}  ///// WHY THIS CHECK HERE?
          {and (FieldDefs.Count=Fields.Count)}  //// why to ask?  supposed the dataset is open because it has FIELDS!!!
          and (TZMQueryDataSet(FMasterDatasetTo.Items[i]).RecordCount>0)
          and (RecordCount>0)
          and (DisableMasterDetailFiltration=False)
          and (FBulkInsert=False))
      then begin
        //Detail datasets must be refreshed in order master/detail filtration take effect.
        if TZMQueryDataSet(FMasterDatasetTo.Items[i]).Active then TZMQueryDataSet(FMasterDatasetTo.Items[i]).Refresh;
        if TZMQueryDataSet(FMasterDatasetTo.Items[i]).Active then TZMQueryDataSet(FMasterDatasetTo.Items[i]).First;
      end;
    end;
  end;
end;

procedure TZMQueryDataSet.DoBeforeEdit;
begin
  inherited DoBeforeEdit;
  {New behavior}
  //Save OldRecord  
  if FBulkInsert=False then UpdateFOldRecord;
end;

procedure TZMQueryDataSet.DoBeforeInsert;
var
   I: integer;
begin
  inherited DoBeforeInsert;

  {New behavior}
  //Save OldRecord  
  if FBulkInsert=False then UpdateFOldRecord;
end;
 
procedure TZMQueryDataSet.DoBeforeDelete;
var
   SlaveDataSet:TZMQueryDataSet;
   ReferentialKey:TZMReferentialKey;
   ReferentialKind:TZMReferentialKind;
   i:Integer;
   vFilter:String;
   vFiltered:Boolean;
   vDoReferentialDelete:Boolean;
   vSlaveBookmark:TBookmark;
   vDisableMasterDetailFiltration:Boolean;

  function InspectReferentialDeleteCondition: Boolean;
  var
    vDoReferentialDelete: Boolean;
    vCount: Integer;
    n: Integer;
  begin
    //Inspect whether referential conditions are met
    vCount:=0;
    vDoReferentialDelete:=False;
    for n:=0 to ReferentialKey.JoinedFields.Count-1 do begin
      try
        //If MasterField=SlaveField pair is provided in JoinedFields item.
        if SlaveDataSet.FieldByName(ReferentialKey.JoinedFields.Names[n]).AsString
          =FOldRecord.FieldByName(ReferentialKey.JoinedFields.ValueFromIndex[n]).AsString
          then Inc(vCount);
      except
        //If MasterField=SlaveField pair is not provided in JoinedFields item.
        if SlaveDataSet.FieldByName(ReferentialKey.JoinedFields.Names[n]).AsString
          =FOldRecord.FieldByName(ReferentialKey.JoinedFields[n]).AsString
          then Inc(vCount);
      end;
      if vCount=ReferentialKey.JoinedFields.Count then vDoReferentialDelete:=True;
    end;
    Result:=vDoReferentialDelete;
  end;

begin
  inherited DoBeforeDelete;
  {New behavior}
  //Save OldRecord  
  if FBulkInsert=False then UpdateFOldRecord;
  //Referential Delete
  if Assigned(FMasterReferentialKeys) then begin
    for i:=0 to FMasterReferentialKeys.Count-1 do begin
      ReferentialKey:=TObject(FMasterReferentialKeys[i]) as TZMReferentialKey;
      SlaveDataSet:=ReferentialKey.SlaveDataSet;
      ReferentialKind:=ReferentialKey.ReferentialKind;
      if ((SlaveDataSet.Active) and (Active)
         and (ReferentialKey.Enabled=True)
         and (SlaveDataSet.Fields.Count>0) and (SlaveDataSet.FieldDefs.Count=SlaveDataSet.Fields.Count)
         and (FieldDefs.Count>0) and (FieldDefs.Count=Fields.Count)
         and Assigned(ReferentialKey.JoinedFields)
         and (rkDelete in ReferentialKind)
         and (FBulkInsert=False)) then begin
        try
          //Signalize referential delete
          FReferentialDeleteFired:=True;
          SlaveDataSet.DisableControls;
          vSlaveBookmark:=SlaveDataSet.GetBookmark;
          //Enforce referential delete. self=MasterDataset
          try
            //Delete records in SlaveDataset
            begin
              DisableControls;
              try
                vFilter:=SlaveDataSet.Filter;
                vFiltered:=SlaveDataSet.Filtered;
                vDisableMasterDetailFiltration:=SlaveDataSet.DisableMasterDetailFiltration;
                //Disable DoFilterRecord
                SlaveDataSet.DisableMasterDetailFiltration:=True;
                SlaveDataSet.Filtered:=False;
                //Iterate through records in SlaveDataSet and update every record.
                if SlaveDataSet.Active then SlaveDataSet.Refresh;
                if Slavedataset.Active then SlaveDataSet.First;
                while not SlaveDataSet.EOF do begin
                  vDoReferentialDelete:=InspectReferentialDeleteCondition;
                  //Do referential delete
                  if vDoReferentialDelete=True then
                    begin
                      SlaveDataSet.Delete;
                    end
                  else SlaveDataSet.Next;
                end;
                { TODO : To investigate why this test to bookmark validity gives wrong result and crashes the application...}
                {
                if ((SlaveDataSet.BookmarkAvailable) and (SlaveDataSet.BookmarkValid(vSlaveBookmark))) then begin
                  SlaveDataSet.GotoBookmark(vSlaveBookmark);
                end;
                }
              finally
                //Enable DoFilterRecord
                SlaveDataSet.DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
                SlaveDataSet.Filter:=vFilter;
                SlaveDataSet.Filtered:=vFiltered;
              end;
              EnableControls;
            end;
          finally
            if SlaveDataSet.Active then SlaveDataSet.Refresh;
          end;
        finally
          FReferentialDeleteFired:=False;
          SlaveDataSet.FreeBookmark(vSlaveBookmark);
          SlaveDataSet.EnableControls;
        end;
      end;
    end;
  end;
end;

procedure TZMQueryDataSet.DoBeforePost;
var
  MasterDataSet:TZMQueryDataSet;
  ReferentialKey:TZMReferentialKey;
  i:Integer;
begin
  inherited DoBeforePost;
{  if FAutoIncIdx > -1 then
     FAutoIncValue := Fields[FAutoIncIdx].AsInteger;}
  if (FAutoIncIdx > -1) and (state = dsInsert) then
        FAutoIncValue := succ(FAutoIncValue);

  {New behavior}
  //Ensure that masterdatasets are not in edit state
  if (Assigned(FSlaveReferentialKeys))
    then begin
    for i:=0 to FSlaveReferentialKeys.Count-1 do begin
      ReferentialKey:=TObject(FSlaveReferentialKeys[i]) as TZMReferentialKey;
      MasterDataSet:=ReferentialKey.MasterDataSet;
      if (
        (MasterDataSet.State=dsEdit)
        and (MasterDataSet.Active) and (Active)
        and (FBulkInsert=False)
        and (ReferentialKey.Enabled=True)
        and Assigned(ReferentialKey.JoinedFields)
        )
        then begin
          MasterDataSet.Post;
      end;
    end;
  end;
  FDoReferentialUpdate := State = dsEdit;
{  if State=dsEdit then FDoReferentialUpdate:=True
    else FDoReferentialUpdate:=False;}
end;

procedure TZMQueryDataSet.DoAfterInsert;
var
   MasterDataSet:TZMQueryDataSet;
   ReferentialKey:TZMReferentialKey;
   ReferentialKind:TZMReferentialKind;
   i,n:Integer;
begin
  inherited DoAfterInsert;
  //Referential Insert - self as SlaveDataset
  if Assigned(FSlaveReferentialKeys) then begin
    for i:=0 to FSlaveReferentialKeys.Count-1 do begin
      ReferentialKey:=TObject(FSlaveReferentialKeys[i]) as TZMReferentialKey;
      MasterDataSet:=ReferentialKey.MasterDataSet;
      ReferentialKind:=ReferentialKey.ReferentialKind;
      if ((MasterDataSet.Active) and (Active)
           and (MasterDataSet.FieldDefs.Count>0) and (MasterDataSet.FieldDefs.Count=MasterDataSet.Fields.Count)
           and (Fields.Count>0) and (FieldDefs.Count=Fields.Count)
           and (ReferentialKey.Enabled=True)
           and Assigned(ReferentialKey.JoinedFields)
           and (rkInsert in ReferentialKind)
           and (FBulkInsert=False))
      then begin
        try
          //Signalize referential insert
           FReferentialInsertFired:=True;
          //Enforce referential insert for self as SlaveDataSet
          DisableControls;
          for n:=0 to ReferentialKey.JoinedFields.Count-1 do begin
             try
               //If MasterField=SlaveField pair is provided in JoinedFields item.
               FieldByName(ReferentialKey.JoinedFields.Names[n]).Value:=MasterDataSet.FieldByName(ReferentialKey.JoinedFields.ValueFromIndex[n]).Value;
             except
               //If MasterField=SlaveField pair is not provided in JoinedFields item.
               FieldByName(ReferentialKey.JoinedFields[n]).Value:=MasterDataSet.FieldByName(ReferentialKey.JoinedFields[n]).Value;
             end;
          end;
        finally
          FReferentialInsertFired:=False;
          EnableControls;
        end;
      end;
    end;
  end;
  //Refresh slave datasets
  if not boolean(ControlsDisabled) then    //// edgarrod71@gmail.com  even in DisabledControls put it called Scroll!!!
    DoAfterScroll;
end;

procedure TZMQueryDataSet.DoAfterPost;
var
   {MasterDataSet:TZMQueryDataSet;}
   SlaveDataSet:TZMQueryDataSet;
   ReferentialKey:TZMReferentialKey;
   ReferentialKind:TZMReferentialKind;
   i,n:Integer;
   vFilter:String;
   vFiltered:Boolean;
   vDisableMasterDetailFiltration:Boolean;
   vDoReferentialUpdate:Boolean;
   vSlaveBookmark:TBookmark;

  function InspectReferentialUpdateCondition: Boolean;
  var
    vDoReferentialUpdate: Boolean;
    vCount: Integer;
    j:Integer;
  begin
    //Inspect whether referential conditions are met
    vCount:=0;
    vDoReferentialUpdate:=False;
    for j:=0 to ReferentialKey.JoinedFields.Count-1 do begin
      try
        //If MasterField=SlaveField pair is provided in JoinedFields item.
        if SlaveDataSet.FieldByName(ReferentialKey.JoinedFields.Names[j]).AsString
          =FOldRecord.FieldByName(ReferentialKey.JoinedFields.ValueFromIndex[j]).AsString
          then Inc(vCount);
      except
        //If MasterField=SlaveField pair is not provided in JoinedFields item.
        if SlaveDataSet.FieldByName(ReferentialKey.JoinedFields.Names[j]).AsString
          =FOldRecord.FieldByName(ReferentialKey.JoinedFields[j]).AsString
          then Inc(vCount);
      end;
      if vCount=ReferentialKey.JoinedFields.Count then vDoReferentialUpdate:=True;
    end;
    Result:=vDoReferentialUpdate;
  end;

begin
  inherited DoAfterPost;
  {New behavior}
  //Persistent save
  if (FPersistentSave{=True}) and (FBulkInsert=False) then
    if (FTableName<>null) then SaveToTable
       {MF begin}
       // was: else ShowMessage('Dataset can not be saved because TableName property is not set');
       else raise Exception.Create('Dataset can not be saved because TableName property is not set');
       {MF end}
  if FDoReferentialUpdate=False then exit;
  //Referential Update; self as Master Dataset
  if Assigned(FMasterReferentialKeys) then begin
    for i:=0 to FMasterReferentialKeys.Count-1 do begin
      ReferentialKey:=TObject(FMasterReferentialKeys[i]) as TZMReferentialKey;
      SlaveDataSet:=ReferentialKey.SlaveDataSet;
      ReferentialKind:=ReferentialKey.ReferentialKind;
      if ((SlaveDataSet.Active) and (Active)
           and (SlaveDataSet.FieldDefs.Count>0) and (SlaveDataSet.FieldDefs.Count=SlaveDataSet.Fields.Count)
           and (Fields.Count>0) and (FieldDefs.Count=Fields.Count)
           and (ReferentialKey.Enabled=True)
           and Assigned(ReferentialKey.JoinedFields)
           and (rkUpdate in ReferentialKind)
           and (FBulkInsert=False))
      then begin
        try
          //Signalize referential update
          FReferentialUpdateFired:=True;
          //Update records in SlaveDataset
          SlaveDataSet.DisableControls;
          vSlaveBookmark:=SlaveDataSet.GetBookmark;
          begin
            try
              vFilter:=SlaveDataSet.Filter;
              vFiltered:=SlaveDataSet.Filtered;
              vDisableMasterDetailFiltration:=SlaveDataSet.DisableMasterDetailFiltration;
              //Disable DoFilterRecord
              SlaveDataSet.DisableMasterDetailFiltration:=True;
              SlaveDataSet.Filtered:=False;
              //Iterate through records in SlaveDataSet and update every record.
              if SlaveDataSet.Active then SlaveDataSet.Refresh;
              if SlaveDataSet.Active then SlaveDataSet.First;
              while not SlaveDataSet.EOF do begin
                vDoReferentialUpdate:=InspectReferentialUpdateCondition;
                //Do referential update
                if vDoReferentialUpdate=True then begin
                  SlaveDataSet.Edit;
                  //Enforce referential update for SlaveDataSet
       	  for n:=0 to ReferentialKey.JoinedFields.Count-1 do begin
                    try
    		      //If MasterField=SlaveField pair is provided in JoinedFields item.
    		      SlaveDataSet.FieldByName(ReferentialKey.JoinedFields.Names[n]).Value
                        :=FieldByName(ReferentialKey.JoinedFields.ValueFromIndex[n]).Value;
    		    except
    		      //If MasterField=SlaveField pair is not provided in JoinedFields item.
    		      SlaveDataSet.FieldByName(ReferentialKey.JoinedFields[n]).Value
                        :=FieldByName(ReferentialKey.JoinedFields[n]).Value;
    		    end;
                  end;
                  SlaveDataSet.Post;
                end;
                SlaveDataSet.Next;
              end;
              try
                if ((SlaveDataSet.BookmarkAvailable) and (SlaveDataSet.BookmarkValid(vSlaveBookmark))) then
                   SlaveDataSet.GotoBookmark(vSlaveBookmark);
              except
              end;
            finally
              //Enable DoFilterRecord
              SlaveDataSet.DisableMasterDetailFiltration:=vDisableMasterDetailFiltration;
              SlaveDataSet.Filter:=vFilter;
              SlaveDataSet.Filtered:=vFiltered;
            end;
          end;
        finally
          FReferentialUpdateFired:=False;
          if SlaveDataSet.Active then SlaveDataSet.Refresh;
          SlaveDataSet.FreeBookmark(vSlaveBookmark);
          SlaveDataSet.EnableControls;
        end;
      end;
    end;
  end;
  //Refresh slave datasets
  if not ControlsDisabled then
      DoAfterScroll;
end;

procedure TZMQueryDataSet.DoAfterDelete;
begin
  inherited DoAfterDelete;
  {New behavior}
  //Persistent save
  if ((FPersistentSave{=True}) and (FBulkInsert=False)) then
    begin
      if (FTableName<>null) then SaveToTable
         {MF begin}
         // was: else ShowMessage('Dataset can not be saved because TableName property is not set');
         else raise Exception.Create('Dataset can not be saved because TableName property is not set');
         {MF end}
    end;
  //Refresh slave datasets
  if not ControlsDisabled then  //// edgarrod71@gmail.com
     DoAfterScroll;
end;

procedure TZMQueryDataSet.InternalRefresh;
begin
 //Do nothing. TBufDataSet's InternalRefresh does troubles.
 //It seems that what in TDataSet's Refresh method is implemented is quite enough for ZMQueryDataset.
 {
 inherited InternalRefresh;
 }
end;

procedure TZMQueryDataSet.DoAfterClose;
begin
  inherited DoAfterClose;
  //Deal with mutually exclusive properties
  FTableLoaded := False;
  FQueryExecuted := False;
  FMemoryDataSetOpened := False;
  //Reset autoincrement counter
  FAutoIncValue:=0;
end;

procedure TZMQueryDataSet.QueryExecute;
begin
  try
    DisableControls;
    //First, see whether there are present persistent fields and whether they need initialization.
    InitializePersistentFields;
    try
      DoQueryExecute;
      //If everything goes OK, then set the property accordingly.
      FQueryExecuted := True;
      //Set mutually exclusive properties to false.
      FTableLoaded := False;
      FMemoryDataSetOpened := False;
    except
      FQueryExecuted := False;
      Active := False;
    end;
  finally
    //Refresh self
    if Active then refresh;
    EnableControls
  end;
end;

procedure TZMQueryDataSet.PrepareQuery;
{This is temporary simple solution of passing parameters to query SQL string before execution}
var
   i:Integer;
begin
  FOriginalSQL:='';
  FPreparedSQL:='';
  for i:=0 to FSQL.Count-1 do begin
    FOriginalSQL:=FOriginalSQL+' '+FSQL.Strings[i];
  end;
  FPreparedSQL:=FOriginalSQL;
  if (Assigned(Parameters) and (Parameters.Count>0)) then begin
     for i:=0 to Parameters.Count-1 do begin
       //Apply parameters by name
       FPreparedSQL:=AnsiReplaceText(FPreparedSQL,':'+Parameters[i].Name,Parameters[i].Value);//There must be better way...
     end;
  end;
  {ShowMessage('Prepared query:'+FPreparedSQL);}
end;

constructor TZMQueryDataSet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  {
  //JanSQL instance
  FJanSQLInstance:=TJanSQL.Create;
  }
  FAutoIncValue := 0;  /// edgarrod71@gmail.com
  FAutoIncIdx := -1;   /// edgarrod71@gmail.com  -1 means no AutoIncIdx; >0 means there is and position of it
  FTableFile := nil;
  FFieldsLoaded := false;
  //SQL
  FSQL := TStringList.Create;
  //Master/detail filtration
  FMasterFields:=TStringList.Create;
  FMasterDataSetTo:=TList.Create;
  //Referential integrity
  FMasterReferentialKeys:=TList.Create;
  FSlaveReferentialKeys:=TList.Create;
  //Import/export
  FSdfDatasetImport:=TSdfDataset.Create(nil);
  FCSVExporterExport:=TCSVExporter.Create(nil);
  //Parameters
  FParameters:=TParams.Create;
  //FOldRecord
  FOldRecord:={$IFDEF ZMBufDataset} TZMBufDataSet{$ELSE}TBufDataSet{$ENDIF}.Create(nil);
end;

destructor TZMQueryDataSet.Destroy;
begin
    if Assigned(FTableFile) then
        FreeAndNil(FTableFile);
 //Import/Export
  if FSdfDatasetImport.Active{=True} then FSdfDatasetImport.Close;
  FreeAndNil(FSdfDatasetImport);
  FreeAndNil(FCSVExporterExport);
  //FOldRecord
  FreeAndNil(FOldRecord);
  //Parameters
  FreeAndNil(FParameters);
  //SQL
  FreeAndNil(FSQL);
  //Master/detail
  FreeAndNil(FMasterFields);
  FreeAndNil(FMasterDataSetTo);
  //Referential integrity
  FreeAndNil(FMasterReferentialKeys);
  FreeAndNil(FSlaveReferentialKeys);
  //JanSQL
  if FRecordsetIndex>0 then FJanSQLInstance.ReleaseRecordset(FRecordsetIndex);
  if Assigned(FJanSQLInstance) then FreeAndNil(FJanSQLInstance);
  //inherited
  inherited Destroy;
end;

procedure TZMQueryDataSet.SetFloatDisplayFormat;
var
   vFD: TCollectionItem;
begin
 //If FloatDisplayFormat property is set, then take it...
  if (Assigned(FZMConnection) and (FZMConnection.FloatDisplayFormat<>'')
     and (FZMConnection.FloatDisplayFormat<>Null)) then begin
    //Set display format for Float type
    for vFD in FieldDefs do     //// edgarrod71@gmail.com
      if ((TFieldDef(vFD).DataType=ftFloat)
        and ((Fields[vFD.Index] as TFloatField).DisplayFormat='')) //Manually set property value has precendance than property set in ZMConnection.
        then begin
          (Fields[vFD.Index] as TFloatField).DisplayFormat
            := FZMConnection.FloatDisplayFormat;
        end;
  end;
end;

procedure TZMQueryDataSet.SetFloatPrecision;
var
   vFD: TCollectionItem;
begin
 //If FloatPrecision property is set, then take it...
  if (Assigned(FZMConnection) and (FZMConnection.FloatPrecision<>0)
  and (FZMConnection.FloatPrecision <> Null)) then
    //Set precision for Float type
    for vFD in FieldDefs do     /// edgarrod71@gmail.com
      if (TFieldDef(vFD).DataType=ftFloat)
        and (TFieldDef(vFD).Precision = 0) then //Manually set property value has precendance than property set in ZMConnection.
          TFieldDef(vFD).Precision := FZMConnection.FloatPrecision;
end;

function TZMQueryDataSet.ZMInitializePersistentField(AOwner: TComponent; AFieldDef: TFieldDef; AOldPersistentField:TField): TField;
Var
   TheNewPeristentField : TFieldClass;
   vName:String;
begin
  {TheNewPeristentField:=GetFieldClass(AFieldDef.DataType);
  if TheNewPeristentField=Nil then
    DatabaseErrorFmt(SUnknownFieldType,[FName]);
  Result:=TheNewPeristentField.Create(AOwner);  }

  TheNewPeristentField:=GetFieldClass(AFieldDef.DataType);
  {TheNewPeristentField:=AOldPersistentField.ClassType;}

  Result:=TheNewPeristentField.Create(AOwner);
  Try
    //Copy all properties from old persistent field.
    Result.Size:={AFieldDef.Size;}AOldPersistentField.Size;
    Result.Required:={AFieldDef.Required;}AOldPersistentField.Required;
    Result.FieldName:={AFieldDef.Name;}AOldPersistentField.Name;
    Result.DisplayLabel:={AFieldDef.DisplayName;}AOldPersistentField.DisplayName;
    Result.{SetFieldType(AFieldDef.DataType);}SetFieldType(AOldPersistentField.DataType);
    Result.ReadOnly:= {(faReadOnly in AFieldDef.Attributes);}AOldPersistentField.ReadOnly;

    //Other properties
    Result.Required:=AOldPersistentField.Required;
    {Result.DisplayName:=AOldPersistentField.DisplayName;}
    Result.Alignment:=AOldPersistentField.Alignment;
    Result.AttributeSet:=AOldPersistentField.AttributeSet;
    Result.Calculated:=AOldPersistentField.Calculated;
    Result.ConstraintErrorMessage:=AOldPersistentField.ConstraintErrorMessage;
    Result.CustomConstraint:=AOldPersistentField.CustomConstraint;
    {Result.DataSet:=AOldPersistentField.DataSet;}
    Result.DefaultExpression:=AOldPersistentField.DefaultExpression;
    Result.DisplayWidth:=AOldPersistentField.DisplayWidth;
    Result.EditMask:=AOldPersistentField.EditMask;
    Result.FieldKind:=AOldPersistentField.FieldKind;
    Result.ImportedConstraint:=AOldPersistentField.ImportedConstraint;
    Result.Index:=AOldPersistentField.Index;
    Result.KeyFields:=AOldPersistentField.KeyFields;
    Result.Lookup:=AOldPersistentField.Lookup;
    Result.LookupCache:=AOldPersistentField.LookupCache;
    Result.LookupDataSet:=AOldPersistentField.LookupDataSet;
    Result.LookupKeyFields:=AOldPersistentField.LookupKeyFields;
    Result.LookupResultField:=AOldPersistentField.LookupResultField;
    {Result.IsBlob:=AOldPersistentField.IsBlob;}
    Result.OnChange:=AOldPersistentField.OnChange;
    Result.OnGetText:=AOldPersistentField.OnGetText;
    Result.OnSetText:=AOldPersistentField.OnSetText;
    Result.OnValidate:=AOldPersistentField.OnValidate;
    Result.Origin:=AOldPersistentField.Origin;
    Result.ProviderFlags:=AOldPersistentField.ProviderFlags;
    {Result.Text:=AOldPersistentField.Text;}
    Result.ValidChars:=AOldPersistentField.ValidChars;
    Result.Tag:=AOldPersistentField.Tag;
    Result.Visible:=AOldPersistentField.Visible;
    Result.DesignInfo:=AOldPersistentField.DesignInfo;
    {
    Result.Dataset:=self;
    }

    If (Result is TFloatField) then
      TFloatField(Result).Precision:={AFieldDef.Precision;}TFloatField(AOldPersistentField).Precision;
    if (Result is TBCDField) then
      TBCDField(Result).Precision:={AFieldDef.Precision;}TBCDField(AOldPersistentField).Precision;
    if (Result is TFmtBCDField) then
      TFmtBCDField(Result).Precision:={AFieldDef.Precision;}TFmtBCDField(AOldPersistentField).Precision;

    //Set Name of the new persistent fields and delete old persistent field.
    vName:=AOldPersistentField.Name;
    FreeAndNil(AOldPersistentField);
    Result.Name:=vName;

  except
    FreeAndNil(Result);
    Raise;
  end;
end;

procedure TZMQueryDataSet.InitializePersistentFields;
var
   i:Integer;
   vPersistentFields:Boolean;
   vFieldNoPresent:Boolean;
   vFieldsCount, vFieldDefsCount: Integer;
begin
   //Initialize persistent fields
   //First detetect whether persistent fields are loaded from .lfm
   vPersistentFields:=False;
   vFieldNoPresent:=True;
   vFieldsCount := Fields.Count;           //// remember to reassign to the
   vFieldDefsCount := FieldDefs.Count;     //// next IF
  if boolean(vFieldDefsCount) and (vFieldsCount = vFieldDefsCount) then begin // if ((Fields.Count=FieldDefs.Count) and (FieldDefs.Count>0)) then begin
    vPersistentFields:=True;
    for i:=0 to pred(vFieldDefsCount) do begin
      if FieldDefs[i].Name <> Fields[i].FieldName then vPersistentFields:=False;
      if Fields[i].FieldNo=0 then vFieldNoPresent:=False;
    end;
 end;
/////// if ((vPersistentFields{=True}) and (vFieldNoPresent=False)) then vPersistentFieldsNeedInitialization:=True;
 //If there are persistent fields and need recreation, then recreate them.
////// if (vPersistentFieldsNeedInitialization{=True}) then begin
 if vPersistentFields{=True} and (vFieldNoPresent=False) then begin
    SetDefaultFields(False);
   for i := 0 to pred(vFieldDefsCount) do
     ZMInitializePersistentField(self.Owner, FieldDefs[i], self.FindField(FieldDefs[i].Name));
   BindFields(True);
 end;
end;

procedure TZMQueryDataSet.ResetAutoInc(pStart: SizeInt);
begin
  FAutoIncValue:=pStart;
end;

function TZMQueryDataSet.LoadTableFields: boolean;  //// edgarrod71@gmail.com
var
   S, fName, fField: string;
   P: PChar;

  procedure FillFieldDefs;
  var
    vFieldDef: TFieldDef;
  begin
      if FieldDefs.Count > 0 then
        FieldDefs.Clear;
      P := @S[1];
      if P <> '' then
      repeat  /// This gets the Fields from File and updates FieldDefs...
          fField := '';
          repeat
              fField += P^;
              inc(P);
          until P^ in [#0, #10, #13, C];
          if P^ = C then inc(P);
          vFieldDef := FieldDefs.AddFieldDef;
          vFieldDef.Name := fField;
          vFieldDef.DataType:=ftString;
          vFieldDef.Size := 1024;
          vFieldDef.Required:=False;
          vFieldDef.Precision:=0;
          vFieldDef.Attributes:=[];

      until (P^ in [#0, #10, #13]){ or (P = '')};
  end;

begin
    Result := false;
    if FileName <> '' then
       fName := FileName
    else
    if TableName <> '' then
       fName := TableName + '.csv';
    if fName <> '' then begin
        if Assigned(FTableFile) then
          FreeAndNil(FTableFile);
        try
          FTableFile := TFileStream.Create(fName, fmOpenReadWrite);
          SetLength(S, FTableFile.Size);
          FTableFile.Read(S[1], FTableFile.Size);
          FillFieldDefs;
          CreateDynamicFieldsFromFieldDefs;  /// this ManageFields
        finally
          if Active then  //// it must be closed, but not sure if here we can close it!!!
            Close;
          Result := true;
          FFieldsLoaded := true;
        end;
    end;
end;

procedure TZMQueryDataSet.LoadLastRecord;  //// edgarrod71@gmail.com
var
   I: integer;
   P: PChar;

begin
  if not FFieldsLoaded then
    LoadTableFields;
  I := FTableFile.Seek(0, soFromEnd);  /// se supone que FTableFile está abierto
  /// result no va aquí, se supone que se cargue en un registro...
//  Result := '';       AQUI VOY!!!
//      P := @S[I];
      repeat
//          Result := (P-1)^ + Result;            //// for this, file must have a #10 at the end of file
          dec(P);
      until ((P-1)^ in [#10, #13]);
end;

function TZMQueryDataSet.AddRecord(const Values: array of const;
  pAutoIncPos: Integer): boolean;  //// edgarrod71@gmail.com
var
   i: integer;
   value: string;

begin
    Result := false;
    if not FFieldsLoaded and Active then
      try
          AppendRecord(Values);
      finally
          result := true;
      end
    else begin
      if not FFieldsLoaded then
          LoadTableFields;

      if (length(Values) = FieldDefs.Count) then begin  { Inserta el último registro }

        // TO-DO: if pAutoIncPos > -1 then check the position, the LastRecord and AutoInc-it!
//                T := GetLastRecord;   /// I must do something with this...
          /// Hay que cargar el último registro!!! no recuerdo para qué
          value := '';
          for i := 0 to High(Values) do begin
            case Values[i].vType of
              vtWideString: value := WideString(Values[i].VWideString);
              vtAnsiString: value := AnsiString(Values[i].vAnsiString);
              vtExtended: value := floatToStr(Values[i].vExtended^);
              vtInteger: value := IntToStr(Values[i].vInteger);
              vtPChar: value := Values[i].vPChar^;
              vtString: value := Values[i].vString^;
            end;
            if i <> High(Values) then
                value += C
            else
                value += #10;
            Result := boolean(FTableFile.Write(PChar(value)^, length(value)));
          end;
      end
      else
          raise Exception.Create('Fields Count Differ from Table' + FTableFile.FileName + '!');
      end;
end;

procedure TZMQueryDataSet.Insert;  //// edgarrod71@gmail.com
begin
  case State of
    dsBrowse: inherited Insert;
    dsEdit, dsInsert: Post;
    dsInactive: begin
       if FFieldsLoaded then
         MemOpen;
         inherited Insert;
    end;
  end;
end;

procedure TZMQueryDataSet.Post;  //// edgarrod71@gmail.com
var
   I, FC: integer;
   AOC: array of TVarRec;
   VR: ^TVarRec;
begin
  if FFieldsLoaded then
    try
      FC := Fields.Count;
      SetLength(AOC, FC);
      VR := @AOC[0];
      for I := 0 to FC - 1 do begin
          VR[I].vType := vtWideString;
          case VR[I].vType of  /// edgarrod71@gmail.com Possible items (just in case)
            vtWideString: WideString(VR[I].VWideString) := Fields[i].AsWideString;
            vtInteger: VR[I].VInteger := Fields[I].AsInteger;
           // vtAnsiString: AnsiString(VR[I].VAnsiString) := Fields[i].AsAnsiString;
            vtString: String(VR[I].VString) := Fields[I].AsString;
          end;
      end;
      AddRecord(AOC);
    finally
      Close;
    end
  else
    if Active then
      inherited post;
end;


initialization

RegisterClasses ( [{ ftUnknown} Tfield,
    { ftString} TStringField,
    { ftSmallint} TSmallIntField,
    { ftInteger} TLongintField,
    { ftWord} TWordField,
    { ftBoolean} TBooleanField,
    { ftFloat} TFloatField,
    { ftCurrency} TCurrencyField,
    { ftBCD} TBCDField,
    { ftDate} TDateField,
    { ftTime} TTimeField,
    { ftDateTime} TDateTimeField,
    { ftBytes} TBytesField,
    { ftVarBytes} TVarBytesField,
    { ftAutoInc} TAutoIncField,
    { ftBlob} TBlobField,
    { ftMemo} TMemoField,
    { ftGraphic} TGraphicField,
    { ftFmtMemo} TBlobField,
    { ftParadoxOle} TBlobField,
    { ftDBaseOle} TBlobField,
    { ftTypedBinary} TBlobField,
    { ftFixedChar} TStringField,
    { ftWideString} TWideStringField,
    { ftLargeint} TLargeIntField,
    { ftOraBlob} TBlobField,
    { ftOraClob} TMemoField,
    { ftVariant} TVariantField,
    { ftGuid} TGuidField,
    { ftFMTBcd} TFMTBCDField,
    { ftFixedWideString} TWideStringField,
    { ftWideMemo} TWideMemoField             ]);

end.
