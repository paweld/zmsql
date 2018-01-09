{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at
http://www.mozilla.org/NPL/NPL-1_1Final.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: janSQL.pas, released March 24, 2002.

The Initial Developer of the Original Code is Jan Verhoeven
(jan1.verhoeven@wxs.nl or http://jansfreeware.com).
Portions created by Jan Verhoeven are Copyright (C) 2002 Jan Verhoeven.
All Rights Reserved.

Contributor(s): ___________________.

Last Modified: 22.01.2014
Current Version: 1.2

Notes: This is a very fast single user SQL engine for text based tables

Known Issues:


History:
  1.1 25-mar-2002
      release recordset in subquery
      release sqloutput in selectfromjoin
      allow "unlimited" number of tables in join
      allow calculated updates: set field=expression
      modified TjanSQLRecord: fields are now objects (for future enhancements)
  1.0 24-mar-2002 : original release
-----------------------------------------------------------------------------}

//Changes by Rene Tegel
//* Added RollBack method
//* Modified "delete from" to accept "delete from <tablename>" syntax.

{Change log:

05.02.2011: By Zlatko Matić
  *In JanSQL.Create method added: DecimalSeparator:=SysUtils.DefaultFormatSettings.DecimalSeparator added,
  so that Jansql uses system decimal separator.
26.12.2013: By Zlatko Matić
  *.txt replaced with .csv, so that JanSQL now works with .csv extension instead .txt.
}



{$ifdef fpc}
   {$mode delphi} {$H+}
{$endif}

unit janSQL;

interface

uses
    {$IFDEF UNIX}{ clocale, cwstring,}{$ENDIF}
    {LCLIntf, } SysUtils, Classes,
    janSQLstrings, janSQLExpression2, janSQLTokenizer, mwStringHashList,
    {$IFNDEF VER130} //Delphi 5
  {$IFNDEF VER120} //Delphi 4
  { $ IFNDEF VER110} //BCB 3 - not sure if it compiles at all.
  {$IFNDEF VER100} //Delphi 3
  Variants
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  ;

type
  TCompareProc 	= procedure( Sender : TObject; i, j : Integer; var Result : Integer ) of object ;
  TSwapProc 	= procedure( Sender : TObject; i, j : Integer ) of object ;

  TjanSQLOperator=(jsunknown,jseq,jsne,jsgt,jsge,jslt,jsle);
  TjanSQLBoolean=(jsnone,jsand,jsor);

  TjanSQLSort=record
    FieldIndex:integer;
    SortAscending:boolean;
    SortNumeric:boolean;
  end;

  TjanSQLJoinIterator=record
    TableName:string;
    TableAlias:string;
    RecordSetIndex:integer;
    RecordCount:integer;
    CurrentRecord:integer;
  end;

  TjanSQLCalcField=class(TObject)
  private
    FCalc:TjanSQLExpression2;
    Fexpression: string;
    Fname: string;
    FFieldIndex: integer;
    procedure Setexpression(const Value: string);
    procedure Setname(const Value: string);
    function getValue: variant;
    procedure SetFieldIndex(const Value: integer);
  public
    constructor create;
    destructor  destroy;override;
    property expression:string read Fexpression write Setexpression;
    property name:string read Fname write Setname;
    property value:variant read getValue;
    property Calculator:TjanSQLExpression2 read FCalc;
    property FieldIndex:integer read FFieldIndex write SetFieldIndex;
  end;

  TjanSQLOutput=class(TObject)
  private
    FFields:TList;
    function getFieldCount: integer;
    function getField(index: integer): TjanSQLCalcField;
    function getFieldNames: string;
  public
    constructor create;
    destructor  destroy;override;
    procedure ClearFields;
    function  AddField:TjanSQLCalcField;
    property FieldNames:string read getFieldNames;
    property FieldCount:integer read getFieldCount;
    property Fields[index:integer]:TjanSQLCalcField read getField;
  end;

  TjanSQLField=record
    FieldName:string;
    FieldIndex:integer;
    FieldValue:string;
  end;

  TjanSQLFields=array of TjanSQLField;

  TjanSQLRecordField=class(TObject)
  private
    Fsum: double;
    Fsum2: double;
    Fcount: integer;
    Fvalue: variant;
    procedure Setcount(const Value: integer);
    procedure Setsum(const Value: double);
    procedure Setsum2(const Value: double);
    procedure Setvalue(const Value: variant);
  published
    property value:variant read Fvalue write Setvalue;
    property count:integer read Fcount write Setcount;
    property sum:double read Fsum write Setsum;
    property sum2:double read Fsum2 write Setsum2;
  end;


  TjanRecord=class(TObject)
  private
    FFields:TList;
    Fmark: boolean;
    Fcounter: integer;
    function getrow: string;
    procedure setrow(const Value: string);
    function getfield(index: integer): TjanSQLRecordField;
    procedure setfield(index: integer; const Value: string);
    procedure Setmark(const Value: boolean);
    procedure Setcounter(const Value: integer);
    procedure ClearFields;
  public
    constructor create;
    destructor  destroy; override;
    procedure AddField(value:string);
    function DeleteField(index:integer):boolean;
    property row:string read getrow write setrow;
    property fields[index:integer]:TjanSQLRecordField read getfield;
    property mark:boolean read Fmark write Setmark;
    property counter:integer read Fcounter write Setcounter;
  end;

  TjanRecordList=class(TList)
  private
  public
    destructor  destroy; override;
    procedure   Clear; override;
    procedure  delete(index:integer);
  end;

  TjanRecordSetList=class(TStringList)
  public
    destructor  destroy; override;
    procedure delete(index:integer);override;
  end;

  TjanRecordSet=class(TObject)
  private
    FRecordCursor:integer;
    Fname: string;
    FFieldNames:TStringList;
    FFieldFuncs:array of TTokenOperator;
    FRecords:TjanRecordList;
    Fpersistent: boolean;
    Fmodified: boolean;
    Fmatchrecord: integer;
    Falias: string;
    Fintermediate: boolean;
    procedure Setname(const Value: string);
    function getrecord(index: integer): TjanRecord;
    function getfieldvalue(index: variant): string;
    procedure setfieldvalue(index: variant; const Value: string);
    procedure Setpersistent(const Value: boolean);
    function getrecordcount: integer;
    procedure Setmodified(const Value: boolean);
    function getfieldcount: integer;
    procedure Setmatchrecord(const Value: integer);
    function getLongFieldList: string;
    function getShortFieldList: string;
    procedure Setalias(const Value: string);
    procedure Setintermediate(const Value: boolean);
  public
    constructor create;
    destructor  destroy; override;
    function LoadFromFile(filename:string):boolean;
    function SaveToFile(filename:string):boolean;
    function AddRecord:integer;
    function DeleteRecord(index:integer):boolean;
    function AddField(fieldname,value:string):integer;
    function DeleteField(index:variant):integer;
    function IndexOfField(fieldname:string):integer;
    function FindFieldValue(fieldindex:integer;fieldvalue:string):integer;
    procedure Clear;
    property Cursor: Integer read FRecordCursor write FRecordCursor;
    property name:string read Fname write Setname;
    property alias:string read Falias write Setalias;
    property persistent:boolean read Fpersistent write Setpersistent;
    property intermediate:boolean read Fintermediate write Setintermediate;
    property modified:boolean read Fmodified write Setmodified;
    property FieldNames:TStringList read FFieldNames;
    property ShortFieldList:string read getShortFieldList;
    property LongFieldList:string read getLongFieldList;
    property records[index:integer]:TjanRecord read getrecord;
    property fields[index:variant]:string read getfieldvalue write setfieldvalue;
    property recordcount:integer read getrecordcount;
    property fieldcount:integer read getfieldcount;
    property matchrecord:integer read Fmatchrecord write Setmatchrecord;
  end;

  TjanSQL=class;

  TjanSQLQuery=class(TObject)
  private
    FTokens:TList;
    FParser:TjanSQLExpression2;
    FEngine: TjanSQL;
    procedure SetEngine(const Value: TjanSQL);
    procedure ClearTokenList;
    function GetToken(index: integer): TToken;
    function getParser: TjanSQLExpression2;
  protected
  public
    constructor create;
    destructor  destroy;override;
    property Engine:TjanSQL read FEngine write SetEngine;
    property Tokens[index:integer]:TToken read GetToken;
    property Parser:TjanSQLExpression2 read getParser;
  end;

  TjanSQL = class(TObject)
  private
    FQueries:TList;
    gen:TStringList;
    FSQL:TstringList;
    FEparser:TjanSQLExpression2;
    FNameSpace:TmwStringHashList;
    FNameCounter:integer;
    Fcatalog: string;
    FInMemoryDatabase: Boolean; 
    FRecordSets:TjanRecordSetList;
    FMatchrecordSet: integer;
    FMatchingHaving: boolean;
    function getrecordset(index: integer): TjanRecordSet;
    function getRecordSetCount: integer;
    procedure getvariable(sender:Tobject;const VariableName:string;var VariableValue:variant;var handled:boolean);
    procedure procsubexpression(sender:Tobject;const subexpression:string;var subexpressionValue:variant;var handled:boolean);
    function SQLDirectStatement(query:TjanSQLQuery;value: string): integer;
    procedure Sort(aRecordset,From, Count : Integer;orderby:array of TjanSQLSort);
    procedure SortRecordSet(arecordset,From, Count : Integer;orderbylist:string;ascending:boolean);
    procedure GroupBy(arecordset:TjanRecordset;grouplist:string);
    function  Compare(arecordset,i, j : Integer;orderby:array of TjanSQLSort): Integer;
    procedure Swap(arecordset,i,j:Integer);
    procedure ClearQueries;
    function ISQL(value:string):integer;
    function uniqueName:string;
    function addRecordSet(aname:string):integer;
    function CreateTable(tablename,fields:string):integer;
    function DropTable(tablename:string):integer;
    function SaveTable(tablename:string):integer;
    function ReleaseTable(tablename:string):integer;
    function AddTableColumn(tablename,column,value:string):integer;
    function DropTableColumn(tablename,column:string):integer;
    function IndexOfTable(tablename:string):integer;
    function openTable(value:string;persistent:boolean):boolean;
    function InCatalog(value:string):boolean;
    function openCatalog(value:string):integer;
    function SelectFromJoin(query:TjanSQLQuery;selectfields,tablelist,wherecondition,orderbylist:string;ascending:boolean;wfrom,wtill:integer;grouplist,having,resultname:string):integer;
    function SelectFrom(query:TjanSQLQuery;tablename1,selectfields,wherecondition,orderbylist:string;ascending:boolean;wfrom,wtill:integer;grouplist,having,resultname:string):integer;
    function DeleteFrom(tablename1,wherecondition:string):integer;
    function InsertInto(tablename1,columns,values:string):integer;
    function Update(query:TjanSQLQuery;tablename1,updatelist,wherecondition:string):integer;
    function Commit(query:TjanSQLQuery):integer;
    function RollBack(query:TjanSQLQuery):integer;
    function AddQuery:TjanSQLQuery;
    function DeleteQuery(query:TjanSQLQuery):boolean;
    { Private declarations }
  protected
    { Protected declarations }
    function SQLSelect(query:TjanSQLQuery;aline,aname:string):integer;
    function SQLAssign(query:TjanSQLQuery;aline:string):integer;
    function SQLDelete(query:TjanSQLQuery;aline:string):integer;
    function SQLInsert(query:TjanSQLQuery;aline:string):integer;
    function SQLInsertSelect(query:TjanSQLQuery;aline:string):integer;
    function SQLUpdate(query:TjanSQLQuery;aline:string):integer;
    function SQLCreate(query:TjanSQLQuery;aline:string):integer;
    function SQLDrop(query:TjanSQLQuery;aline:string):integer;
    function SQLSaveTable(query:TjanSQLQuery;aline:string):integer;
    function SQLReleaseTable(query:TjanSQLQuery;aline:string):integer;
    function SQLAlter(query:TjanSQLQuery;aline:string):integer;
    function SQLCommit(query:TjanSQLQuery;aline:string):integer;
    function SQLRollBack(query:TjanSQLQuery;aline:string):integer;
    function SQLConnect(query:TjanSQLQuery;aline:string):integer;
  public
    { Public declarations }
    constructor create;
    destructor  destroy; override;
    function SQLDirect(value:string):integer;
    function ReleaseRecordset(arecordset:integer):boolean;
    function Error:string;
    property RecordSets[index:integer]:TjanRecordSet read getrecordset;
    property RecordSetCount:integer read getRecordSetCount;
    property NameSpace:TmwStringHashList read FNameSpace;
  published
    { Published declarations }
  end;


implementation

const
  cr = #13#10;  ////  cr = chr(13)+chr(10);

var
  FError: string;
  //FDebug: string;

procedure err(value:string);
begin
  Ferror:=value;
end;

procedure chop(var value:string;from:integer);
begin
  value:=trim(copy(value,from,maxint));
end;

{soner never used
function tokeninset(token,aset:string):boolean;
begin
end;
}
function parsetoken(const source:string;var token:string;var delimpos:integer;var delim:string):boolean;
var
  p,L:integer;
begin
  result:=false;
  L:=length(source);
  if L=0 then exit;
  p:=1;
  while (p<=L) and (not (source[p] in [',',' ',';','=','<','>','(',')'])) do
    inc(p);
  if p>L then begin
    token:=source;
    delim:='';
    delimpos:=0;
  end
  else begin
    token:=copy(source,1,p-1);
    delim:=copy(source,p,1);
    delimpos:=p;
  end;
  result:=true;
end;

function checktoken(source,token:string;var delimpos:integer;var delim:string):boolean;
var
  p,LS,LT:integer;
begin
  result:=false;
  p:=postext(token,source);
  if p<>1 then exit;
  LS:=length(source);
  LT:=length(token);
  if LS=LT then begin
    delim:='';
    delimpos:=0;
    result:=true;
    exit;
  end;
  if not (source[LT+1] in [' ',',',';','=','<','>']) then exit;
  result:=true;
  delim:=source[LT+1];
  delimpos:=LT+1;
end;

function string2operator(value:string):TjanSQLOperator;
begin
  result:=jsunknown;
  if value='=' then
    result:=jseq
  else if value='<>' then
    result:=jsne
  else if value='>' then
    result:=jsgt
  else if value='>=' then
    result:=jsge
  else if value='<' then
    result:=jslt
  else if value='<+' then
    result:=jsle;
end;

// split atext at ; into lines
procedure split(atext:string;alist:TStrings);

  //make semicosumn not holy, allow it in quoted values (rene):
  function posskipquoted (sep: char; text: String; offset: Integer): Integer;
  var quoted: char;
  begin
    result := 0;
    quoted := #0;
    while offset <= length(text) do
      begin
        if (quoted=#0) and (text[offset]=sep) then
          begin
            Result := offset;
            break;
          end;
        //Detect end of quoted values
        if (quoted <> #0) and (text[offset]=quoted) then
        begin
          quoted := #0;
          inc (offset);                                                            //Dak_Alpha
          Continue;                                                                //Dak_Alpha
        end;
        //Detect begin of quoted values
        if (quoted=#0) and (text[offset] in ['''', '"', '`']) then
          quoted := text[offset];
        if text[offset] = PathDelim then
          //additional step
          inc(offset);
        inc (offset);
      end;
  end;

var
  tmp:string;
  p1,p2,L:integer;
begin
  alist.Clear;
  L:=length(atext);
  if L=0 then exit;
  p1:=1;
  repeat
    //p2:=PosStr(';',atext,p1);
    p2 := posskipquoted(';', atext, p1);
    if p2>0 then begin
      tmp:=copy(atext,p1,p2-p1);
      alist.Append(tmp);
      if p2=L then
        alist.append('');
      p1:=p2+1;
      if p1>L then
        p1:=0;
    end
    else begin
      alist.append(copy(atext,p1,maxint));
      p1:=0;
    end;
  until p1=0;
end;

function join(alist:TStrings):string;
var
  i,c:integer;
begin
  result:='';
  c:=alist.count;
  if c=0 then exit;
  for i:=0 to c-1 do
    if i=0 then
      result:=alist[i]
    else
      result := result + ';' + alist[i];
end;


{ TjanSQL }

function TjanSQL.addRecordSet(aname: string): integer;
var
  rs:TjanRecordSet;
begin
  rs:=TjanRecordSet.create;
  rs.name:=aname;
  result:=FRecordSets.AddObject(aname,rs)+1;
end;

constructor TjanSQL.create;
begin
  inherited;
  { TODO : This should be completely removed. jansql should behave
  {        as rest of zmsql package... }
  {
  //Set decimal separator.
  //DecimalSeparator:='.'; //This was original value. Disabled by Z.Matić.
  //Note that DecimalSeparator=SysUtils.FormatSettings.DecimalSeparator
  DecimalSeparator:=SysUtils.DefaultFormatSettings.DecimalSeparator
  }
  FQueries:=TList.create;
  gen:=TStringList.create;
  FSQL:=TStringList.create;
  FNameSpace:=TmwStringHashList.create(tinyhash,HashSecondaryOne,HashCompare);
  FEParser:=TjanSQLExpression2.create;
  FEParser.onGetVariable:=getvariable;
  FrecordSets:=TjanRecordSetList.Create;
end;

destructor TjanSQL.destroy;
begin
  ClearQueries;
  FQueries.free;
  gen.free;
  FSQL.free;
  FEParser.free;
  FrecordSets.free;
  FNameSpace.free;
  inherited;
end;

// join 2 tables on fields in fieldset
// return index of resultset
// result -1 means failure
// fieldset has format field1=field2;field3=field3
function TjanSQL.getrecordset(index: integer): TjanRecordSet;
// 1 based
begin
  result:=nil;
  if (index<1) or (index>Frecordsets.Count) then exit;
  result:=TjanRecordset(FRecordsets.objects[index-1]);
end;

// joinfields are of format field1=field2;field3=field4
// all fields must be in table.field format
function TjanSQL.selectFromJoin(query:TjanSQLQuery;selectfields,tablelist,wherecondition,orderbylist:string;ascending:boolean;wfrom,wtill:integer;grouplist,having,resultname:string):integer;
var
  t1,t2,t3:integer;
  i,c,i3,c3:integer;
  idx:integer;
  bAggregate:boolean;
  selectfieldfunctions:array of TTokenOperator;
  tablecount, outputfieldcount:integer;
  sqloutput:TjanSQLOutput;
  tables:array of TjanSQLJoinIterator;

  function setgroupfunc(avalue:string;ii:integer):string;
  var
    ppo,ppc:integer;
    sfun:string;
  begin
    selectfieldfunctions[ii]:=toNone;
    result:=avalue;
    ppo:=posstr('(',avalue);
    if ppo>0 then begin
      ppc:=posstr(')',avalue,ppo);
      if ppc=0 then exit;
      sfun:=lowercase(trim(copy(avalue,1,ppo-1)));
      result:=copy(avalue,ppo+1,ppc-ppo-1);
      if sfun='count' then begin
        selectfieldfunctions[ii]:=tosqlCount;
        bAggregate:=true;
      end
      else if sfun='sum' then begin
        selectfieldfunctions[ii]:=tosqlSum;
        bAggregate:=true;
      end
      else if sfun='avg' then begin
        selectfieldfunctions[ii]:=tosqlAvg;
        bAggregate:=true;
      end
      else if sfun='max' then begin
        selectfieldfunctions[ii]:=tosqlMax;
        bAggregate:=true;
      end
      else if sfun='min' then begin
        selectfieldfunctions[ii]:=tosqlMin;
        bAggregate:=true;
      end

        else
          result:=avalue;
    end;
  end;


  function setoutputfields:boolean;
  var
    ii,cc:integer;
    ofld:TjanSQLCalcField;
    ppa:integer;
    sfield,prefield:string;
  begin
    result:=false;
    split(selectfields,gen);
    cc:=gen.count;
    outputfieldcount:=cc;
    setlength(selectfieldfunctions,cc);
    sqloutput:=TjanSQLOutput.create;
    for ii:=0 to cc-1 do begin
      ofld:=sqloutput.AddField;
      ofld.Calculator.onGetVariable:=GetVariable;
      sfield:=gen[ii];
      ppa:=pos('|',sfield);
      if ppa>0 then begin
        prefield:=copy(sfield,1,ppa-1);
        prefield:=setgroupfunc(prefield,ii);
        ofld.name:=copy(sfield,ppa+1,maxint);
        try
          ofld.expression:=prefield;
        except
          exit;
        end;
      end
      else begin
        ofld.name:=setgroupfunc(sfield,ii);
        try
          ofld.expression:=sfield;
        except
          exit;
        end;
      end;
    end;
    result:=true;
  end;



  procedure addresultoutput(r1,r2:integer);
  var
    ii,cc,ir:integer;
    ss:string;
    v:variant;
  begin
    ir:=recordsets[t3].AddRecord;
    cc:=sqloutput.FieldCount;
    FMatchrecordSet:=t1;
    recordsets[t1].matchrecord:=r1;
    recordsets[t2].matchrecord:=r2;
    for ii:=0 to cc-1 do begin
       v:=sqloutput.Fields[ii].value;
       ss:=v;
       recordsets[t3].records[ir].fields[ii].value:=ss;
    end;
  end;

  procedure addResultOutputEx;
  var
    ii,cc,ir: integer;
    ss: string;
    v: variant;
  begin
    ir:=recordsets[t3].AddRecord;
    cc:=sqloutput.FieldCount;
    FMatchrecordSet:=t1;
    for ii:=0 to tablecount-1 do
      recordsets[tables[ii].RecordSetIndex].matchrecord:=tables[ii].CurrentRecord;
    for ii:=0 to cc-1 do begin
       v:=sqloutput.Fields[ii].value;
       ss:=v;
       recordsets[t3].records[ir].fields[ii].value:=ss;
    end;
  end;



  function matchrecords(r1,r2:integer):boolean;
  begin
    recordsets[t1].matchrecord:=r1;
    recordsets[t2].matchrecord:=r2;
    result:=query.parser.Evaluate;
  end;

  function matchrecordsEx:boolean;
  var
    ii:integer;
  begin
    for ii:=0 to tablecount-1 do
      recordsets[tables[ii].RecordSetIndex].matchrecord:=tables[ii].CurrentRecord;
    result:=query.parser.Evaluate;
  end;


  function matchhaving(arecord:integer):boolean;
  begin
    recordsets[t3].matchrecord:=arecord;
    result:=query.Parser.evaluate;
  end;

  function expandall:string;
  begin
    result:=recordsets[t1].LongFieldList+';'+recordsets[t2].LongFieldList;
  end;

  function settables:boolean; // JV 25-03-2002
  // added alias option JV 27-03-2002
  var
    ii,tii,rrc,pp:integer;
    atom, atomalias:string;
  begin
    result:=false;
    setlength(tables,tablecount);
    for ii:=0 to tablecount-1 do begin
      atom:=gen[ii];
      pp:=pos('|',atom);
      if pp=0 then
        atomalias:=atom
      else begin
        atomalias:=copy(atom,pp+1,maxint);
        atom:=copy(atom,1,pp-1);
      end;
      tii:=indexoftable(atom);
      if tii=-1 then begin
        err('SELECT: can not find table '+atom); //soner moved here
        exit;
      end;
      rrc:=recordsets[tii].recordcount;
      if rrc=0 then begin
        err('SELECT: table '+atom+' has no records'); //soner moved here
        exit;
      end;
      recordsets[tii].alias:=atomalias;
      tables[ii].TableName:=atom;
      tables[ii].TableAlias:=atomalias;
      NameSpace.AddString(atom,tii,0);
      NameSpace.AddString(atomalias,tii,0);
      tables[ii].RecordSetIndex:=tii;
      tables[ii].CurrentRecord:=0;
      tables[ii].RecordCount:=rrc;
    end;
    result:=true;
  end;

  procedure matchtables(t:integer);
  var
    ii:integer;
  begin
    if t=tablecount-1 then
      for ii:=0 to tables[t].RecordCount-1 do begin
        tables[t].CurrentRecord:=ii;
        if matchrecordsEx then begin
           addresultoutputEx;
        end;
    end
    else
      for ii:=0 to tables[t].RecordCount-1 do begin
        tables[t].CurrentRecord:=ii;
        matchtables(t+1);
      end;

  end;
  
begin
  Fmatchinghaving:=false;
  bAggregate:=False; //fixed for FPC theo
  result:=0;
  split(tablelist,gen);
  //soner: err('SELECT: join table missing');
  tablecount:=gen.count;
  {soner original:
  if tablecount<2 then exit;
  if not settables then exit;
  }
  if (tablecount<2)or(not settables) then begin
    err('SELECT: join table missing');
    exit;
  end;

  if selectfields='' then begin
    err('SELECT: missing field list'); //soner moved here
    exit;
  end;
  if selectfields='*' then
    selectfields:=expandall;

{new code}
  if not setoutputfields then begin
    sqloutput.free;
    err('SELECT dev: can not set output fields'); //soner moved here
    exit;
  end;

  // join fields are present, now join
  if resultname<>'' then begin
    // check if this is a persistent table
    if InCatalog(resultname) then begin
      sqloutput.free;
      err('SELECT INTO: table '+resultname+' allready exists.'); //soner moved here
      exit;
    end;
    // check index
    idx:=Frecordsets.IndexOf(resultname);
    if idx=-1 then begin
      t3:=AddRecordSet(resultname);
      Recordsets[t3].intermediate:=true;
    end
    else begin
      // check if this is a intermediate one
      if recordsets[idx+1].intermediate then begin
        FRecordsets.delete(idx);
        t3:=AddRecordSet(resultname);
        Recordsets[t3].intermediate:=true;
      end
      else begin
        err('ASSIGN: table '+resultname+' is not a variable');
        sqloutput.free;
        exit;
      end;
    end;
  end
  else
    t3:=AddRecordSet(uniquename);
  result:=t3;

  // assign selectfields
  split(sqloutput.FieldNames, recordsets[t3].FieldNames);


  // copy field funcs
  c:=recordsets[t3].FieldNames.Count;
  setlength(recordsets[t3].FFieldFuncs,c);
  for i:=0 to c-1 do
    recordsets[t3].FFieldFuncs[i]:=selectfieldfunctions[i];
  if wfrom<>0 then begin
    query.Parser.GetTokenList(query.Ftokens,wfrom,wtill);
  end;

   matchtables(0);

  // process any group by clause
  if bAggregate and (recordsets[t3].recordcount>1) then
    groupby(recordsets[t3],grouplist);

  FMatchrecordSet:=t3;
  Fmatchinghaving:=true;
  c3:=recordsets[t3].recordcount;
  // process any having clause
  if (having<>'') and (c3<>0) then begin
    query.Parser.Expression:=having;
    for i3:=0 to c3-1 do
      recordsets[t3].records[i3].mark:=false;
    for i3:=0 to c3-1 do
      if not matchhaving(i3) then
        recordsets[t3].records[i3].mark:=true;
    for i3:=c3-1 downto 0 do
      if recordsets[t3].records[i3].mark then
        recordsets[t3].DeleteRecord(i3);
  end;
  // process any order by clause
  if (orderbylist<>'') and (recordsets[t3].recordcount>1) then
    sortRecordset(t3,0,recordsets[t3].recordcount,orderbylist,ascending);
  sqloutput.free;  // JV 25-03-2002
end;

function TjanSQL.openCatalog(value: string): integer;
begin
  result:=0;
  FInMemoryDatabase := trim(lowercase(value))=':memory:';
  if not (FInMemoryDatabase or directoryexists(value)) then begin
    err('Catalog '+value+' does not exist'); //soner moved here
    exit;
  end;
  FCatalog:=value;
  result:=-1;
end;

function TjanSQL.openTable(value: string;persistent:boolean): boolean;
var
  fn:string;
  rs:TjanRecordSet;
begin
  result:=false;
  if FInMemoryDatabase then //override
    persistent := false;
  if persistent then
    if not directoryexists(FCatalog) then exit;
  if FRecordSets.IndexOf(value)<>-1 then exit;
  {fn:=Fcatalog+PathDelim+value+'.txt';}
  fn:=Fcatalog+PathDelim+value+'.csv'; //Changed by Zlatko Matić, 26.12.2003
  if persistent then
    if not fileexists(fn) then exit;
  rs:=TjanRecordSet.create;
  rs.name:=value;
  rs.persistent:=persistent;
  FRecordSets.AddObject(value,rs);
  if persistent then
    result:=rs.LoadFromFile(fn);
end;


function TjanSQL.uniqueName: string;
begin
  result:='$$$'+inttostr(FNameCounter);
  inc(FNameCounter);
end;

function TjanSQL.SelectFrom(query:TjanSQLQuery;tablename1, selectfields,
  wherecondition,orderbylist: string;ascending:boolean;wfrom,wtill:integer;grouplist,having,resultname:string): integer;
var
  t1,t3:integer;
  i,c,i1,c1,i3,c3:integer;
  idx:integer;
  outputfieldcount:integer;
  selectfieldfunctions:array of TTokenOperator;
  bAggregate:boolean;
  sqloutput:TjanSQLOutput;


  function setgroupfunc(avalue:string;ii:integer):string;
  var
    ppo,ppc:integer;
    sfun:string;
  begin
    result:=avalue;
    selectfieldfunctions[ii]:=toNone;
    ppo:=posstr('(',avalue);
    if ppo>0 then begin
      ppc:=posstr(')',avalue,ppo);
      if ppc=0 then exit;
      sfun:=lowercase(trim(copy(avalue,1,ppo-1)));
      result:=copy(avalue,ppo+1,ppc-ppo-1);
      if sfun='count' then begin
        selectfieldfunctions[ii]:=tosqlCount;
        bAggregate:=true;
      end
      else if sfun='sum' then begin
        selectfieldfunctions[ii]:=tosqlSum;
        bAggregate:=true;
      end
      else if sfun='avg' then begin
        selectfieldfunctions[ii]:=tosqlAvg;
        bAggregate:=true;
      end
      else if sfun='max' then begin
        selectfieldfunctions[ii]:=tosqlMax;
        bAggregate:=true;
      end
      else if sfun='min' then begin
        selectfieldfunctions[ii]:=tosqlMin;
        bAggregate:=true;
      end
      else if sfun='stddev' then begin
        selectfieldfunctions[ii]:=tosqlStdDev;
        bAggregate:=true;
      end
        else
          result:=avalue;
    end;
  end;



  function setoutputfields:boolean;
  var
    ii,cc:integer;
    ofld:TjanSQLCalcField;
    ppa:integer;
    sfield,prefield:string;
  begin
    result:=false;
    split(selectfields,gen);
    cc:=gen.count;
    outputfieldcount:=cc;
    setlength(selectfieldfunctions,cc);
    sqloutput:=TjanSQLOutput.create;
    for ii:=0 to cc-1 do begin
      ofld:=sqloutput.AddField;
      ofld.Calculator.onGetVariable:=GetVariable;
      sfield:=gen[ii];
      ppa:=pos('|',sfield);
      if ppa>0 then begin
        prefield:=copy(sfield,1,ppa-1);
        prefield:=setgroupfunc(prefield,ii);
        ofld.name:=copy(sfield,ppa+1,maxint);
        try
          ofld.expression:=prefield;
        except
          exit;
        end;
      end
      else begin
        ofld.name:=setgroupfunc(sfield,ii);
        try
          ofld.expression:=sfield;
        except
          exit;
        end;
      end;
    end;
    result:=true;
  end;



  function matchwhere(arecord:integer):boolean;
  begin
    if wherecondition='' then
      result:=true
    else begin
      recordsets[t1].matchrecord:=arecord;
      result:=query.Parser.evaluate;
    end;
  end;

  function matchhaving(arecord:integer):boolean;
  begin
    recordsets[t3].matchrecord:=arecord;
    result:=query.Parser.evaluate;
  end;

  procedure addresultoutput(arecord:integer);
  var
    ii,cc,ir:integer;
    ss:string;
    v:variant;
  begin
    ir:=recordsets[t3].AddRecord;
    cc:=sqloutput.FieldCount;
    FMatchrecordSet:=t1;
    recordsets[t1].matchrecord:=arecord;
    for ii:=0 to cc-1 do begin
       v:=sqloutput.Fields[ii].value;
       ss:=v;
       recordsets[t3].records[ir].fields[ii].value:=ss;
    end;
  end;


  function expandall:string;
  // expand * fields to all fieldname
  begin
    result:=recordsets[t1].ShortFieldList;
  end;

begin
  Fmatchinghaving:=false;
  bAggregate:=false;
  result:=0;
  t1:=IndexOfTable(tablename1);

  if t1=-1 then begin
    err('SELECT: can not find table '+tablename1); //soner moved here
    exit;
  end;

  if selectfields='' then begin
    err('SELECT: no selected fields'); //soner moved here
    exit;
  end;
  if selectfields='*' then
    selectfields:=expandall;
  //soner never used: err('SELECT: can not find selected fields');

{new code}
  //soner moved: err('SELECT dev: can not set output fields');
  if not setoutputfields then begin
    sqloutput.free;
    err('SELECT dev: can not set output fields'); //soner moved here
    exit;
  end;

  if resultname<>'' then begin
    // check if this is a persistent table
    if InCatalog(resultname) then begin
      sqloutput.free;
      err('SELECT INTO: table '+resultname+' allready exists.'); //soner moved here
      exit;
    end;
    // check index
    idx:=Frecordsets.IndexOf(resultname);
    if idx=-1 then begin
      t3:=AddRecordSet(resultname);
      Recordsets[t3].intermediate:=true;
    end
    else begin
      // check if this is a intermediate one
      if recordsets[idx+1].intermediate then begin
        FRecordsets.delete(idx);
        t3:=AddRecordSet(resultname);
        Recordsets[t3].intermediate:=true;
      end
      else begin
        err('ASSIGN: table '+resultname+' is not a variable');
        sqloutput.free;
        exit;
      end;
    end;
  end
  else
    t3:=AddRecordSet(uniquename);
  // assign selectfields
  // if * then expand

  split(sqloutput.FieldNames, recordsets[t3].FieldNames);

  c1:=recordsets[t1].recordcount;
  //This is no error! If i select empty table, i need least field names!           //Dak_Alpha
//  err('SELECT FROM: no records');                                                //Dak_Alpha
//  if (c1=0) then  begin                                                          //Dak_Alpha
//    sqloutput.free;                                                              //Dak_Alpha
//    exit;                                                                        //Dak_Alpha
//  end;                                                                           //Dak_Alpha
  // copy field funcs
  c:=recordsets[t3].FieldNames.Count;
  setlength(recordsets[t3].FFieldFuncs,c);

  for i:=0 to c-1 do
    recordsets[t3].FFieldFuncs[i]:=selectfieldfunctions[i];

  FMatchrecordSet:=t1;
  if wfrom<>0 then begin
    query.Parser.GetTokenList(query.Ftokens,wfrom,wtill);
  end;
  for i1:=0 to c1-1 do
    if matchwhere(i1) then begin
       addresultoutput(i1);
    end;

  FMatchrecordSet:=t3;
  // process any group by clause
  if bAggregate and (recordsets[t3].recordcount>1) then begin
    groupby(recordsets[t3],grouplist);
  end;
  c3:=recordsets[t3].recordcount;
  Fmatchinghaving:=true;
  // process any having clause
  if (having<>'') and (c3<>0) then begin
    query.Parser.Expression:=having;
    for i3:=0 to c3-1 do
      recordsets[t3].records[i3].mark:=false;
    for i3:=0 to c3-1 do
      if not matchhaving(i3) then
        recordsets[t3].records[i3].mark:=true;
    for i3:=c3-1 downto 0 do
      if recordsets[t3].records[i3].mark then
        recordsets[t3].DeleteRecord(i3);
  end;

  // process any order by clause
  if (orderbylist<>'') and (recordsets[t3].recordcount>1) then
    sortrecordset(t3,0,recordsets[t3].recordcount,orderbylist,ascending);
  sqloutput.free;
  result:=t3;
end;

function TjanSQL.IndexOfTable(tablename: string): integer;
begin
  result:=Frecordsets.IndexOf(tablename);
  if result=-1 then begin
     //  auto open tables used in queries
     if not OpenTable(tablename,true) then exit;
     result:=Frecordsets.IndexOf(tablename);
  end;
  inc(result);
end;

function TjanSQL.CreateTable(tablename, fields: string): integer;
var
  fn,s:string;
begin
  result:=0;
  if tablename='' then exit;
  if fields='' then exit;
  {fn:=FCatalog+PathDelim+tablename+'.txt';}
  fn:=FCatalog+PathDelim+tablename+'.csv'; //Changed by Zlatko Matić, 26.12.2013.
  if fileexists(fn) then
  begin
    err('Table already exist');                                                    //Dak_Alpha
    exit;
  end;
  s:=fields;
  janSQLstrings.savestring(fn,s);
  result:=-1;
end;

function TjanSQL.DropTable(tablename: string): integer;
var
  fn:string;
  idx:integer;
begin
  result:=0;
  
  if tablename='' then begin
    err('DROP TABLE: table name missing'); //soner moved here
    exit;
  end;
  {fn:=FCatalog+PathDelim+tablename+'.txt';}
  fn:=FCatalog+PathDelim+tablename+'.csv'; //Changed by Zlatko Matić, 26.12.2013.
  if not fileexists(fn) then begin
    err('DROP TABLE: can not find file '+fn); //soner
    exit;
  end;
  deletefile(fn);
  idx:=FRecordSets.IndexOf(tablename);
  if idx<>-1 then
    FrecordSets.Delete(idx);
  result:=-1;
end;

function TjanSQL.DeleteFrom(tablename1, wherecondition: string): integer;
var
  c1,i1,t1:integer;


  function matchwhere(arecord:integer):boolean;
  begin
    FMatchrecordSet:=t1;
    recordsets[t1].matchrecord:=arecord;
    FEParser.Expression:=wherecondition;
    result:=FEParser.evaluate;
  end;

  procedure deletematch(arecord:integer);
  begin
    recordsets[t1].DeleteRecord(arecord);
  end;

begin
  result:=0;
  t1:=IndexOfTable(tablename1);
  if t1=-1 then exit;
  // check filter
  if wherecondition='' then exit;
  c1:=recordsets[t1].recordcount;
  if (c1=0) then exit;
  for i1:=c1-1 downto 0 do
    if matchwhere(i1) then
      DeleteMatch(i1);
  recordsets[t1].modified:=true;
  result:=-1;
end;

function TjanSQL.InsertInto(tablename1, columns, values: string): integer;
var
  t1,r1:integer;
  insertfields:TjanSQLFields;

  function parsevalues:boolean;
  var
    sline:string;
    LL,pp:integer;
  begin
    result:=false;
    LL:=0;
    sline:=trim(values);
    if sline='' then begin
      err('INSERT INTO parsing values:empty'); //soner moved here
      exit;
    end;
    repeat
      if sline[1]='''' then begin
        pp:=posstr('''',sline,2);
        if pp=0 then begin
          err('INSERT INTO parsing values: missing '' delimiter'); //soner moved here
          exit;
        end;
        inc(LL);
        setlength(insertfields,LL);
        insertfields[LL-1].FieldValue:=copy(sline,2,pp-2);
        sline:=trim(copy(sline,pp+1,maxint));
        if sline='' then // ready
          pp:=0
        else begin  // must have comma
          if sline[1]<>',' then begin
            err('INSERT INTO parsing values:missing ,'); //soner moved here
            exit;
          end;
          sline:=trim(copy(sline,2,maxint));
        end;
      end
      else begin
        pp:=posstr(',',sline);
        if pp=0 then begin // single value
          inc(LL);
          setlength(insertfields,LL);
          insertfields[LL-1].FieldValue:=trim(sline);
        end
        else begin
          inc(LL);
          setlength(insertfields,LL);
          insertfields[LL-1].FieldValue:=trim(copy(sline,1,pp-1));
          sline:=trim(copy(sline,pp,maxint));
          if sline='' then // ready
            pp:=0
          else begin  // must have comma
            if sline[1]<>',' then begin
              err('Missing , in '+sline); //soner moved here
              exit;
            end;
            sline:=trim(copy(sline,2,maxint));
          end;
        end;
      end;
    until pp=0;
    result:=true;
  end;

  function parsecolumns:boolean;
  var
    ii,LL,fii:integer;
    sline:string;
  begin
    result:=false;
    LL:=length(insertfields);
    if columns='' then begin
      for ii:=0 to LL-1 do
        insertfields[ii].FieldIndex:=ii;
    end
    else begin
      sline:=columns;
	  
      split(sline,gen);
      if gen.Count<>LL then begin // number of columns and values not the same
        err('INSERT INTO: number of columns and values is different'); //soner moved here
        exit;
      end;
      for ii:=0 to LL-1 do begin
        fii:=recordsets[t1].IndexOfField(gen[ii]);
        if fii=-1 then exit;
        insertfields[ii].FieldIndex:=fii;
      end;
    end;
    result:=true;
  end;

  procedure UpdateValues(arecord:integer);
  var
    ii,LL:integer;
  begin
    LL:=length(insertfields);
    if LL=0 then exit;
    for ii:=0 to LL-1 do
      recordsets[t1].records[arecord].fields[insertfields[ii].FieldIndex].value:=insertfields[ii].FieldValue;
  end;

  
begin
  result:=0;
  if tablename1='' then begin
    err('Missing table name in INSERT INTO component'); //soner moved here
    exit;
  end;
  if values='' then begin
    err('Missing values in VALUES component'); //soner moved here
    exit;
  end;
  t1:=IndexOfTable(tablename1);
  if t1=-1 then begin
    err('Table '+tablename1+' not open'); //soner moved here
    exit;
  end;
  if not parsevalues then exit;
  if not parsecolumns then exit;
  r1:=recordsets[t1].AddRecord;
  updatevalues(r1);
  result:=-1;
  recordsets[t1].modified:=true;
end;

function TjanSQL.Update(query:TjanSQLQuery;tablename1, updatelist,
  wherecondition: string): integer;
var
  i1,c1,t1:integer;
  updatefields:TjanSQLFields;
  outputfieldcount:integer;
  sqloutput:TjanSQLOutput;

  function matchwhere(arecord:integer):boolean;
  begin
    FMatchrecordSet:=t1;
    recordsets[t1].matchrecord:=arecord;
    if wherecondition<>'' then begin
      result:=query.Parser.evaluate;
    end
    else
      result:=true;
  end;

  function parseUpdateList:boolean;
  // format userid=10, username='Jan verhoeven' etc
  var
    LL,pp,fii:integer;
    sline,stoken:string;
  begin
    result:=false;
    sline:=trim(updatelist);
    LL:=0;
    repeat
      pp:=posstr('=',sline);
      if pp=0 then exit;
      stoken:=trim(copy(sline,1,pp-1));
      sline:=trim(copy(sline,pp+1,maxint));
      if sline='' then exit;
      inc(LL);
      setlength(updatefields,LL);
      updatefields[LL-1].FieldName:=stoken;

      fii:=recordsets[t1].FieldNames.IndexOf(stoken);
      if fii=-1 then begin
        err('UPDATE: can not find field '+stoken); //soner moved here
        exit;
      end;
      updatefields[LL-1].FieldIndex:=fii;
      if sline[1]='''' then begin // text value
        pp:=posstr('''',sline,2);
        if pp=0 then exit;
        stoken:=copy(sline,2,pp-2);
        updatefields[LL-1].FieldValue:=stoken;
        sline:=trim(copy(sline,pp+1,maxint));
        if sline='' then
          pp:=0
        else begin
          if sline[1]<>',' then exit;
          system.Delete(sline,1,1);
        end;
      end
      else begin // not text value
        pp:=posstr(',',sline);
        if pp=0 then
          updatefields[LL-1].FieldValue:=trim(sline)
        else begin
          stoken:=trim(copy(sline,1,pp-1));
          updatefields[LL-1].FieldValue:=stoken;
          sline:=copy(sline,pp+1,maxint);
        end;
      end;
    until pp=0;
    result:=true;
  end;

  procedure UpdateMatch(arecord:integer);
  var
    ii,LL:integer;
  begin
    LL:=length(updatefields);
    if LL=0 then exit;
    for ii:=0 to LL-1 do
      recordsets[t1].records[arecord].fields[updatefields[ii].FieldIndex].value:=updatefields[ii].FieldValue;
  end;

  
  function setoutputfields:boolean;
  var
    ii,cc,fii:integer;
    ofld:TjanSQLCalcField;
    ppa:integer;
    sfield,prefield:string;
  begin
    result:=false;
    split(updatelist,gen);
    cc:=gen.count;
    outputfieldcount:=cc;
    sqloutput:=TjanSQLOutput.create;
    for ii:=0 to cc-1 do begin
      ofld:=sqloutput.AddField;
      ofld.Calculator.onGetVariable:=GetVariable;
      sfield:=gen[ii];
      ppa:=pos('=',sfield);
      if ppa=0 then exit;
      prefield:=copy(sfield,ppa+1,maxint);
      ofld.name:=trim(copy(sfield,1,ppa-1));
      fii:=recordsets[t1].IndexOfField(ofld.name);
      if fii=-1 then exit;
      ofld.FieldIndex:=fii;
      try
        ofld.expression:=trim(prefield);
      except
        exit;
      end;
    end;
    result:=true;
  end;

  // JV 26-03-2002
  procedure updateresult(arecord:integer);
  var
    ii,cc,fii:integer;
    ss:string;
    v:variant;
  begin
    cc:=sqloutput.FieldCount;
    FMatchrecordSet:=t1;
    recordsets[t1].matchrecord:=arecord;
    for ii:=0 to cc-1 do begin
       fii:=sqloutput.fields[ii].FieldIndex;
       v:=sqloutput.Fields[ii].value;
       ss:=v;
       recordsets[t1].records[arecord].fields[fii].value:=ss;
    end;
  end;


begin
  result:=0;
  if tablename1='' then begin
    err('UPDATE: missing tablename'); //soner moved here
    exit;
  end;
  if updatelist='' then begin
    err('UPDATE: missing update fields'); //soner moved here
    exit;
  end;
  t1:=IndexOfTable(tablename1);
  if t1=-1 then begin
    err('UPDATE: cannot find table '+tablename1); //soner moved here
    exit;
  end;
  // table is open;
  //soner has no effect: err('UPDATE: can not parse updatelist');
  // JV 26-Mar-2002
  //soner moved: err('SELECT dev: can not set output fields');
  if not setoutputfields then begin
    sqloutput.free;
    err('SELECT dev: can not set output fields');
    exit;
  end;

  c1:=recordsets[t1].recordcount;
  if (c1=0) then begin
    sqloutput.free;
    result:=-1;
    exit;
  end;
  FMatchrecordSet:=t1;
  if wherecondition<>'' then begin
    query.Parser.Expression:=wherecondition;
  end;

  for i1:=0 to c1-1 do
    if matchwhere(i1) then
      UpdateResult(i1); // Jv 26-Mar-2002
  sqloutput.free;
  result:=-1;
  recordsets[t1].modified:=true;
end;

// save all modified persistent files to disk
function TjanSQL.Commit(query:TjanSQLQuery): integer;
var
  i,c:integer;
  fn:string;
begin
  result:=0;
  c:=recordsetcount;
  if c=0 then begin
    result:=-1;
    exit;
  end;
  for i:=1 to c do
    if (recordsets[i].persistent) and (recordsets[i].modified) then begin
      {fn:=Fcatalog+PathDelim+recordsets[i].name+'.txt';}
      fn:=Fcatalog+PathDelim+recordsets[i].name+'.csv'; //Changed by Zlatko Matić, 26.12.2013.
      if not fileexists(fn) then exit;
      recordsets[i].SaveToFile(fn);
      recordsets[i].modified:=false;
    end;
  result:=-1;
end;

function TjanSQL.getRecordSetCount: integer;
begin
  result:=Frecordsets.Count;
end;

function TjanSQL.AddTableColumn(tablename, column, value: string): integer;
var
  t1:integer;
begin
  result:=0;
  t1:=indexoftable(tablename);
  if t1=-1 then exit;
  result:=recordsets[t1].AddField(column,value);
  if result<>0 then
    recordsets[t1].modified:=true;
end;

function TjanSQL.DropTableColumn(tablename, column: string): integer;
var
  t1:integer;
begin
  result:=0;
  t1:=indexoftable(tablename);
  if t1=0 then exit;
  result:=recordsets[t1].DeleteField(column);
  if result<>0 then
    recordsets[t1].modified:=true;
end;

// the main function that executes one or more sql statements seperated by a ;
function TjanSQL.SQLDirect(value: string): integer;
var
  i,c:integer;
  resultset:integer;
begin
  result:=0;
  FError:='';
  //soner moved: err('Empty SQL statement');
  if value='' then begin
    err('Empty SQL statement'); //soner moved here for performance
    exit;
  end;
  value:=trim(value);
  split(value,FSQL);
  c:=FSQL.count;
  if c=0 then exit;
  // remove any empty lines
  for i:=c-1 downto 0 do
    if trim(FSQL[i])='' then
      FSQL.Delete(i);
  c:=FSQL.count;
  if c=0 then exit;
  for i:=0 to c-1 do begin
    namespace.Clear;
    resultset:=ISQL(FSQL[i]);
    if resultset=0 then exit;
  end;
  result:=resultset;
  err('OK');
end;


function TjanSQL.SQLDirectStatement(query:TjanSQLQuery;value: string): integer;
var
  sline{,stoken}:string;
  tokenizer:TjanSQLTokenizer;
  b:boolean;
begin
  query.ClearTokenList;
  result:=0;
  sline:=trim(stringreplace(value,cr,' ',[rfreplaceall]));
  //soner moved:err('Empty SQL statement');
  if sline='' then begin
    err('Empty SQL statement'); //soner moved here
    exit;
  end;
  //moved: err('Could not tokenize: '+sline);
  tokenizer:=TjanSQLTokenizer.create;
  tokenizer.onSubExpression:=procSubExpression;
  try
    b:=Tokenizer.Tokenize(sline,query.Ftokens)
  finally
    tokenizer.free;
  end;
  if not b then begin
    err('Could not tokenize: '+sline); //soner moved here
    exit;
  end;
  //soner moved: err('No tokens');
  if query.Ftokens.Count=0 then begin
    err('No tokens'); //soner moved here
    exit;
  end;
  case query.tokens[0]._operator of
    tosqlSELECT: result:=SQLSelect(query,sline,'');
    tosqlASSIGN: result:=SQLAssign(query,sline);
    tosqlSAVETABLE: result:=SQLSaveTable(query,sline);
    tosqlRELEASETABLE: result:=SQLReleaseTable(query,sline);
    tosqlINSERT:
      begin
        if query.Ftokens.Count<5 then exit;
        if query.Tokens[3]._operator=tosqlselect then
          result:=SQLInsertSelect(query,sline)
        else
          result:=SQLInsert(query,sline);
      end;
    tosqlDELETE: result:=SQLDelete(query,sline);
    tosqlUPDATE: result:=SQLUpdate(query,sline);
    tosqlCREATE: result:=SQLCreate(query,sline);
    tosqlDROP:   result:=SQLDrop(query,sline);
    tosqlALTER:  result:=SQLAlter(query,sline);
    tosqlCOMMIT: result:=SQLCommit(query,sline);
    tosqlCONNECT:result:=SQLConnect(query,sline);
    tosqlROLLBACK: result:=SQLROLLBACK(query,sline);
  else
    err('Unknown SQL command');
  end;
end;


// ALTER TABLE ADD COLUMN columnname
// ALTER TABLE DROP COLUMN columnname
function TjanSQL.SQLAlter(query:TjanSQLQuery;aline: string): integer;
var
  tablename,column:string;
  p,t1,L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<6 then exit;
  p:=0;
  // check
  if (query.tokens[0]._operator<>tosqlAlter) or
    (query.tokens[1]._operator<>tosqlTABLE) or
    (query.tokens[4]._operator<>tosqlCOLUMN)
     then exit;
  // tablename
  tablename:=query.tokens[2].name;
  t1:=indexoftable(tablename);
  if t1=-1 then exit;
  // add or drop
  if query.tokens[3]._operator=tosqlADD then begin
    column:=query.tokens[5].name;
    if L>6 then
      result:=AddTableColumn(tablename,column,query.tokens[6].name)
    else
      result:=AddTableColumn(tablename,column,'')
  end
  else if query.tokens[3]._operator=tosqlDROP then begin
    column:=query.tokens[5].name;
    result:=DropTableColumn(tablename,column);
  end
  else
    exit;
end;

// syntax: COMMIT
function TjanSQL.SQLCommit(query:TjanSQLQuery;aline: string): integer;
var
  L:integer;
begin
  result:=-1;
  L:=query.FTokens.count;
  if L<>1 then exit;
  if query.Tokens[0]._operator<>tosqlCOMMIT then exit;
  result:=Commit(query);
end;

// syntax: CREATE TABLE tablename (column1[,columnN])
function TjanSQL.SQLCreate(query:TjanSQLQuery;aline: string): integer;
var
  tablename,fieldlist:string;
  p,L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<6 then exit;
  if (query.Tokens[0]._operator<>tosqlCREATE) or
     (query.Tokens[1]._operator<>tosqlTABLE)
     then exit;
  tablename:=query.tokens[2].name;
  if query.tokens[3].tokenkind<>tkOpen then exit;
  if query.tokens[L-1].tokenkind<>tkClose then exit;
  fieldlist:='';
  for p:=4 to L-2 do
    if query.tokens[p].name=',' then
      fieldlist:=fieldlist+';'
    else
      fieldlist:=fieldlist+query.tokens[p].name;
  result:=CreateTable(tablename,fieldlist);
end;

// syntax: DELETE FROM tablename WERE condition
function TjanSQL.SQLDelete(query:TjanSQLQuery;aline: string): integer;
var
  tablename,condition:string;
  p,L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  //rene: we may have no where clause
  //if L<7 then exit;
  if (query.Tokens[0]._operator<>tosqlDELETE) or
     (query.Tokens[1]._operator<>tosqlFROM)
     then exit;
  tablename:=query.tokens[2].name;
  condition := '';
  (*
  //note (rene)
  //this is not standard SQL.
  //no where clause is just delete all records
  if query.tokens[3]._operator<>tosqlWHERE then exit;
  for p:=4 to L-1 do
    condition:=condition+query.tokens[p].name;
  *)
  if (L>=6) and (query.tokens[3]._operator=tosqlWHERE) then
    begin
      for p:=4 to L-1 do
        condition:=condition+query.tokens[p].name;
    end
  else
    begin
      if L > 3 then //error, where expected
        begin
          err ('`WHERE` expected but `'+condition+query.tokens[3].name+'` found.');
          exit
        end
      else
        //hack here or hack DeleteFrom method, this is slower:
        condition := '1=1';
    end;
  result:=deletefrom(tablename,condition);
end;

// syntax DROP TABLE tablename
function TjanSQL.SQLDrop(query:TjanSQLQuery;aline: string): integer;
var
  tablename:string;
  L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<3 then exit;
  if (query.Tokens[0]._operator<>tosqlDROP) or
     (query.Tokens[1]._operator<>tosqlTABLE)
     then exit;
  tablename:=query.tokens[2].name;
  result:=DropTable(tablename);
end;

// syntax INSERT INTO tablename VALUES (value1,[value2])
// or: INSERT INTO tablename (column1[,columnN) VALUES (value1,[valueN])
function TjanSQL.SQLInsert(query:TjanSQLQuery;aline: string): integer;
var
  tablename:string;
  columns,values:string;
  p1,p2,L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<4 then exit;
  if (query.Tokens[0]._operator<>tosqlINSERT) or
     (query.Tokens[1]._operator<>tosqlINTO)
     then exit;
  tablename:=query.tokens[2].name;
  p1:=3;
  columns:='';
  if query.Tokens[p1].tokenkind=tkOpen then begin  // have columns
    inc(p1);
    p2:=p1;
    while (p2<L) and (query.tokens[p2].tokenkind<>tkClose) do
      inc(p2);
    if p2>=L then exit; // missing )
    if (p1+1)=p2 then exit; // no columns
    for p1:=p1 to p2-1 do
      if query.Tokens[p1].name=',' then
        columns:=columns+';'
      else
        columns:=columns+query.Tokens[p1].name;
    p1:=p2+1;
  end;

  if p1+2>=L then begin
    err('SQLInsert: missing VALUES'); //soner moved here
    exit;
  end;
  if query.Tokens[p1]._operator=tosqlVALUES then begin
    inc(p1);
    err('SQLInsert: missing ( after VALUES');
    if query.Tokens[p1].tokenkind<>tkOpen then begin
       //soner moved here
      exit;
    end;
    inc(p1);
    p2:=p1;
    while (p2<L) and (query.tokens[p2].tokenkind<>tkClose) do
      inc(p2);
    if p2>=L then  begin // missing )
      err('SQLInsert: missing ) after VALUES'); //soner moved here
      exit;
    end;
    if (p1+1)=p2 then begin // no values
      err('SQLInsert: no values after VALUES'); //soner moved here
      exit;
    end;
    for p1:=p1 to p2-1 do begin
      if query.tokens[p1]._operator=toAString then
        values:=values+''''+query.Tokens[p1].name+''''
      else
        values:=values+query.Tokens[p1].name;
    end;
  end
  else
    exit;
  result:=insertinto(tablename,columns,values);
end;

// syntax: SELECT fieldlist FROM tablename WHERE condition
// or: SELECT fieldlist FROM tablename
function TjanSQL.SQLSelect(query:TjanSQLQuery;aline,aname: string): integer;
var
  tablelist,fieldlist,condition,orderbylist:string;
  grouplist,having:string;
  ascending:boolean;
  p1,p2,L:integer;
  wfrom,wtill:integer;
  bracketopen:integer;
  alias:integer;
begin
  result:=0;
  grouplist:='';
  having:='';
  orderbylist:='';
  ascending:=true;
  L:=query.FTokens.count;
  if L<4 then begin
    err('SELECT: Need at least 4 token');//soner moved here
    exit;
  end;
  if (query.Tokens[0]._operator<>tosqlSELECT) then begin
    err('SELECT: missing SELECT'); //soner moved here
    exit;
  end;
  for p2:=1 to L-1 do
    if query.Tokens[p2]._operator=tosqlFROM then break;
  if query.Tokens[p2]._operator<>tosqlFROM then begin
    err('SELECT: missing FROM'); //soner moved here
    exit;
  end;
  // fieldlist
  if p2<2 then begin
    err('SELECT: missing selected field list'); //soner moved here
    exit;
  end;

// catch for any comma's in functions
  bracketopen:=0;
  for p1:=1 to p2-1 do begin
    case query.tokens[p1]._operator of
    toOpen:
      begin
        fieldlist:=fieldlist+'(';
        inc(bracketopen);
      end;
    toClose:
      begin
        fieldlist:=fieldlist+')';
        dec(bracketopen);
      end;
    toComma:
      begin
       if bracketopen=0 then
         fieldlist:=fieldlist+';'
       else
         fieldlist:=fieldlist+',';
      end;
    tosqlAS: fieldlist:=fieldlist+'|';
    else
      fieldlist:=fieldlist+query.Tokens[p1].name;
    end
  end;
  p1:=p2+1;
  if p1>=L then exit;

  // new
  alias:=0;
  while (p1<L) and (query.tokens[p1].tokenkind in [tkComma,tkOperand]) do begin
     if query.tokens[p1].tokenkind=tkComma then begin
       tablelist:=tablelist+';';
       alias:=0;
     end
     else begin
       inc(alias);
       if alias>=2 then
         tablelist:=tablelist+'|'+query.tokens[p1].name
       else
         tablelist:=tablelist+query.tokens[p1].name;
     end;
     inc(p1);
  end;
  // end new
  condition:='';
  wfrom:=0;
  if p1<L then begin
    if query.tokens[p1]._operator=tosqlWHERE then begin
      inc(p1);
      if (p1+1)>=L then begin
        err('SELECT: missing expression after WHERE'); //soner moved here
        exit;
      end;
      wfrom:=p1;
      while (p1<L) and (not(query.tokens[p1]._operator in [tosqlORDER,tosqlGROUP])) do begin
        if query.tokens[p1]._operator=toAstring then
          condition:=condition+''''+query.tokens[p1].name+''' '
        else
          condition:=condition+query.tokens[p1].name+' ';
        wtill:=p1;
        inc(p1);
      end;
    end;
    // check for GROUP BY clause
    if (p1<(L-1)) and (query.tokens[p1]._operator=tosqlGROUP) then begin
      inc(p1);
      while (p1<L) and (not(query.tokens[p1]._operator in [tosqlORDER,tosqlHAVING])) do begin
        grouplist:=grouplist+query.tokens[p1].name;
        inc(p1);
      end;
      grouplist:=stringreplace(grouplist,',',';',[rfreplaceall]);
    end;
    // check for HAVING clause
    if (p1<(L-1)) and (query.tokens[p1]._operator=tosqlHAVING) then begin
      inc(p1);
      while (p1<L) and (not(query.tokens[p1]._operator in [tosqlORDER])) do begin
        having:=having+query.tokens[p1].name;
        inc(p1);
      end;
    end;
    // check for ORDER BY clause
    if (p1<(L-1)) and (query.tokens[p1]._operator=tosqlORDER) then begin
      inc(p1);
      while (p1<L) do begin
        if query.tokens[p1]._operator=tosqlASC then begin
          orderbylist:=orderbylist+'+';
        end
        else if query.tokens[p1]._operator=tosqlDESC then
          orderbylist:=orderbylist+'-'
        else
          orderbylist:=orderbylist+query.tokens[p1].name;
        inc(p1);
      end;
      inc(p1);
      orderbylist:=stringreplace(orderbylist,',',';',[rfreplaceall]);
    end;
  end;
  if posstr(';',tablelist)>0 then
    result:=selectfromjoin(query,fieldlist,tablelist,condition,orderbylist,ascending,wfrom,wtill,grouplist,having,aname)
  else
    result:=selectfrom(query,tablelist,fieldlist,condition,orderbylist,ascending,wfrom,wtill,grouplist,having,aname);
end;

// syntax: UPDATE tablename SET field1=value1[,fieldN=valueN] WHERE condition
function TjanSQL.SQLUpdate(query:TjanSQLQuery;aline: string): integer;
var
  tablename,fieldlist,condition:string;
  columns{soner nu:,values}:string;
  p1,L:integer;
  bCondition:boolean;
  brackets:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<6 then exit;
  if (query.Tokens[0]._operator<>tosqlUPDATE) then exit;
  tablename:=query.tokens[1].name;
  if (query.Tokens[2]._operator<>tosqlSET) then exit;
  columns:='';
  // parse to WHERE
  p1:=3;
  bCondition:=true;
  // parse fieldlist
  // allow for commas in multiparamer functions
  brackets:=0;
  while (p1<L) and (query.Tokens[p1]._operator<>tosqlWHERE) do begin
    if query.tokens[p1].tokenkind=tkOpen then begin
      fieldlist:=fieldlist+'(';
      inc(brackets);
    end
    else if query.tokens[p1].tokenkind=tkClose then begin
      fieldlist:=fieldlist+')';
      dec(brackets);
    end
    else if query.tokens[p1].tokenkind=tkcomma then begin
      if brackets=0 then
        fieldlist:=fieldlist+';'
      else
        fieldlist:=fieldlist+','
    end
    else if query.tokens[p1]._operator=toAString then
      fieldlist:=fieldlist+''''+query.tokens[p1].name+''' '
    else
      fieldlist:=fieldlist+query.tokens[p1].name+' ';
    inc(p1);
  end;
  // parse condition
  condition:='';
  if (p1<L) and (query.Tokens[p1]._operator=tosqlWHERE) then begin
    inc(p1);
    while (p1<L) do begin
      if query.tokens[p1]._operator=toAString then
        condition:=condition+''''+query.tokens[p1].name+''' '
      else
        condition:=condition+query.tokens[p1].name+' ';
      inc(p1);
    end;
  end;
  result:=update(query,tablename,fieldlist,condition);
end;


function TjanSQL.SQLConnect(query:TjanSQLQuery;aline: string): integer;
var
  catalog:string;
  L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<2 then begin
    err('Expected 2 statement parts'); //soner moved here
    exit;
  end;
  if (query.Tokens[0]._operator<>tosqlCONNECT) then begin
    err('CONNECT TO expected'); //soner moved here
    exit;
  end;
  CATALOG:=query.tokens[1].name;
  result:=opencatalog(catalog);
end;

function TjanSQL.Error: string;
begin
  result:=FError;
end;


procedure TjanSQL.getvariable(sender: Tobject;const VariableName: string;
  var VariableValue: variant; var handled: boolean);
var
  index,p:integer;
  tablename,fieldname:string;
  arecordset,arecord:integer;
  anExId:integer;
begin
  p:=0;
  if not Fmatchinghaving then
    p:=pos('.',VariableName);
  if p>0 then begin
    tablename:=copy(VariableName,1,p-1);
    if not namespace.Hash(tablename,aRecordset,anExId) then exit;
    arecord:=recordsets[arecordset].matchrecord;
    fieldname:=copy(VariableName,p+1,maxint);
  end
  else begin  // select without join
    arecordset:=Fmatchrecordset;
    arecord:=recordsets[arecordset].matchrecord;
    fieldname:=VariableName;
  end;
  index:=recordsets[arecordset].IndexOfField(fieldname);
  if index<>-1 then begin
    VariableValue:=recordsets[arecordset].records[arecord].fields[index].value;
    handled:=true;
  end;
end;



procedure TjanSQL.Sort(arecordset,From, Count: Integer;orderby:array of TjanSQLSort);
  procedure   Sort( iL, iR : Integer ) ;
  var
  	L, R, M : Integer ;
  begin
  	repeat
          	L := iL ;
              	R := iR ;
              	M := ( L + R ) div 2 ;

              	repeat
                  	while Compare(arecordset, From + L, From + M ,orderby) < 0 do Inc(L) ;
                  	while Compare(arecordset, From + M, From + R ,orderby) < 0 do Dec(R) ;
                  	if L <= R then begin
                      		Swap(arecordset, From + L, From + R ) ;
                      		if M = L then
                          		M := R
                      		else if M = R then
                          		M := L ;
                      		Inc(L) ;
                      		Dec(R) ;
                  	end ;
              	until L > R ;

              	if ( R - iL ) > ( iR - L ) then begin {Sort left here}
                  	if L < iR then
                      		Sort( L, iR ) ;
                  	iR := R ;
              	end else begin
                  	if iL < R then
                      		Sort( iL, R ) ;
                  	iL := L ;
              	end ;
          until iL >= iR ;
  end ;
begin
  if Count > 1 then
  	Sort( 0, Count - 1 ) ;
end;

function TjanSQL.Compare(arecordset,i, j: Integer;orderby:array of TjanSQLSort): Integer;
var
  s1,s2:string;
  index:integer;
  arecord:integer;
  obi,obc:integer;

  function safefloat(atext:string):double;
  begin
    try
      result:=strtofloat(atext);
    except
      result:=0;
    end;
  end;

  function comparefloats(afloat1,afloat2:double):integer;
  begin
    if afloat1=afloat2 then
      result:=0
    else if afloat1>afloat2 then
      result:=1
    else
      result:=-1;
  end;
begin
  result:=0;
  arecord:=recordsets[arecordset].matchrecord;
  obc:=length(orderby);
  for obi:=0 to obc-1 do begin
    index:=orderby[obi].FieldIndex;
    s1:=recordsets[arecordset].records[i].fields[index].value;
    s2:=recordsets[arecordset].records[j].fields[index].value;
    if orderby[obi].SortAscending then begin
      if orderby[obi].SortNumeric then
        result:=comparefloats(safefloat(s1),safefloat(s2))
      else
        result:=ansicomparestr(s1,s2);
      if result<>0 then break;
    end
    else begin
      if orderby[obi].SortNumeric then
        result:=comparefloats(safefloat(s2),safefloat(s1))
      else
        result:=ansicomparestr(s2,s1);
      if result<>0 then break;
    end
  end;
end;

procedure TjanSQL.Swap(arecordset,i, j: Integer);
begin
  recordsets[arecordset].FRecords.Exchange(i,j);
end;

function TjanSQL.ReleaseRecordset(arecordset: integer): boolean;
var
  idx:integer;
begin
  result:=false;
  if arecordset<1 then exit;
  if arecordset>recordsetcount then exit;
  idx:=arecordset-1;  //
  FrecordSets.Delete(idx);
  result:=true;
end;

procedure TjanSQL.ClearQueries;
var
  i,c:Integer;
begin
  c:=FQueries.Count;
  if c=0 then exit;
  for i:=0 to c-1 do
    TjanSQLQuery(FQueries[i]).free;
  FQueries.clear;
end;

function TjanSQL.AddQuery: TjanSQLQuery;
begin
  result:=TjanSQLQuery.create;
  result.engine:=self;
  Fqueries.Add(result);
end;

function TjanSQL.DeleteQuery(query: TjanSQLQuery): boolean;
var
  idx:integer;
begin
  result:=false;
  idx:=FQueries.IndexOf(query);
  if idx<>-1 then begin
    TjanSQLQuery(FQueries[idx]).free;
    Fqueries.Delete(idx);
    result:=true;
  end;
end;

function TjanSQL.ISQL(value: string): integer;
var
  qry:TjanSQLQuery;
begin
  result:=0;
  qry:=AddQuery;
  qry.Parser.onGetVariable:=getvariable;
  try
    result:=SQLDirectStatement(qry,value);
  finally
    DeleteQuery(qry);
  end;
end;

procedure TjanSQL.procsubexpression(sender: Tobject;
  const subexpression: string; var subexpressionValue: variant;
  var handled: boolean);
var
  sqlresult:integer;

  function getresultlist:string;
  var
    rc,fc,arow:integer;
  begin
    result:='';
    rc:=RecordSets[sqlresult].recordcount;
    if rc=0 then exit;
    fc:=RecordSets[sqlresult].fieldcount;
    if fc=0 then exit;
    for arow:=0 to rc-1 do
      if result='' then
        result:='['+RecordSets[sqlresult].records[arow].fields[0].value
      else
        result:=result+']['+RecordSets[sqlresult].records[arow].fields[0].value;
    result:=result+']';
  end;
begin
  handled:=false;
  sqlresult:=SQLDirect(subexpression);
  if sqlresult>0 then begin
    subexpressionvalue:=getresultlist;
    ReleaseRecordset(sqlresult);
    handled:=true;
  end;
end;

procedure TjanSQL.GroupBy(arecordset: TjanRecordset; grouplist: string);
var
  grpidx:array of integer;
  i,fii:integer;
  g,groups:integer;
  r,rc,fc:integer;
  hash:TmwStringHashList;
  grouper:string;
  anId,anExId:integer;

  procedure resetgroup(arecord:integer);
  var
    ii:integer;
  begin
    for ii:=0 to fc-1 do
      case arecordset.FFieldFuncs[ii] of
      tosqlcount:
        begin
          arecordset.records[arecord].fields[ii].value:='1';
          arecordset.records[arecord].counter:=1;
        end;
      else
        begin
          arecordset.records[arecord].counter:=1;
        end;
      end;
  end;

  function forcefloat(atext:string):double;
  begin
    try
      result:=strtofloat(atext);
    except
      result:=0;
    end;
  end;

  procedure applygroup(arecord,torecord:integer);
  var
    ii,cc:integer;
    s1,s2:string;
    d1,d2,d3,sum,sum2,dmean:double;

  begin
    for ii:=0 to fc-1 do begin
      s1:=arecordset.records[arecord].fields[ii].value;
      s2:=arecordset.records[torecord].fields[ii].value;
      case arecordset.FFieldFuncs[ii] of
      tosqlcount:
        begin
          arecordset.records[torecord].fields[ii].value:=
            floattostr(forcefloat(s2)+1);
        end;
      tosqlMax:
        begin
          if forcefloat(s1)>forcefloat(s2) then
          arecordset.records[torecord].fields[ii].value:=s1;
        end;
      tosqlMin:
        begin
          if forcefloat(s1)<forcefloat(s2) then
          arecordset.records[torecord].fields[ii].value:=s1;
        end;
      tosqlsum:
        begin
          arecordset.records[torecord].fields[ii].value:=
            floattostr(forcefloat(s2)+forcefloat(s1));
        end;
      tosqlavg:
        begin
           cc:=arecordset.records[torecord].counter;
           d1:=forcefloat(s1);
           d2:=forcefloat(s2);
           d3:=(d2*cc+d1)/(cc+1);
           arecordset.records[torecord].fields[ii].value:=
             floattostr(d3);
           arecordset.records[torecord].counter:=cc+1;
        end;
      tosqlstddev:
        begin
           cc:=arecordset.records[torecord].counter;
           inc(cc);
           arecordset.records[torecord].counter:=cc;
           d1:=forcefloat(s1);  // from
           d2:=forcefloat(s2);  // to
           sum:=arecordset.records[torecord].fields[ii].sum+d1;
           arecordset.records[torecord].fields[ii].sum:=sum;
           sum2:=arecordset.records[torecord].fields[ii].sum2+d1*d1;
           arecordset.records[torecord].fields[ii].sum2:=sum2;
           dmean:=sum/cc;
           d3 := sqrt(Sum2/cc - dmean*dmean);
           arecordset.records[torecord].fields[ii].value:=
             floattostr(d3);
        end;
      end;
    end;
  end;

begin
  groups:=0;
  rc:=arecordset.recordcount;
  if rc=0 then exit;
  fc:=arecordset.fieldcount;
  if fc=0 then exit;
  // unmark all records
  for r:=0 to rc-1 do begin
    arecordset.records[r].mark:=false;
    arecordset.records[r].counter:=0;
  end;

  // no grouplist so only 1 record
  if grouplist='' then begin
    resetgroup(0);
    for r:=1 to rc-1 do begin
      applygroup(r,0);
      arecordset.records[r].mark:=true;
    end;
    for r:=rc-1 downto 0 do
      if arecordset.records[r].mark then
        arecordset.DeleteRecord(r);
    exit;
  end;
  split(grouplist,gen);
  groups:=gen.count;
  if groups<>0 then begin
    setlength(grpidx,groups);
    for i:=0 to groups-1 do begin
      fii:=arecordset.IndexOfField(gen[i]);
      if fii=-1 then exit;
      grpidx[i]:=fii;
    end;
  end;

  // unmark all records
  for r:=0 to rc-1 do begin
    arecordset.records[r].mark:=false;
    arecordset.records[r].counter:=0;
  end;
  try
    hash:=TmwStringHashList.create(tinyhash,HashSecondaryOne,HashCompare);
    for r:=0 to rc-1 do begin
      grouper:='';
      for g:=0 to groups-1 do
         grouper:=grouper+arecordset.records[r].fields[grpidx[g]].value+'|';
      if not hash.Hash(grouper,anId,anExId) then begin
      // add hash
        hash.AddString(grouper,r,0);
        resetgroup(r);
      end
      else begin
        applygroup(r,anId);
        arecordset.records[r].mark:=true;
      end;
    end;
  finally
    hash.free;
  end;
  for r:=rc-1 downto 0 do
    if arecordset.records[r].mark then
      arecordset.DeleteRecord(r);
end;


procedure TjanSQL.SortRecordSet(arecordset, From, Count: Integer;
  orderbylist: string; ascending: boolean);
var
  i,c,fii,p:integer;
  orderby:array of TjanSQLSort;
  fieldname:string;
begin
  split(orderbylist,gen);
  c:=gen.count;
  if c=0 then exit;
  setlength(orderby,c);
  for i:=0 to c-1 do begin
    orderby[i].SortAscending:=true;
    orderby[i].SortNumeric:=false;
    fieldname:=gen[i];
    p:=pos('#',fieldname);
    if p>0 then begin
      system.Delete(fieldname,p,1);
      orderby[i].SortNumeric:=true;
    end;
    p:=pos('-',fieldname);
    if p>0 then begin
      system.Delete(fieldname,p,1);
      orderby[i].SortAscending:=false;
    end;
    p:=pos('+',fieldname);
    if p>0 then begin
      system.Delete(fieldname,p,1);
    end;
    fii:=recordsets[arecordset].IndexOfField(fieldname);
    if fii=-1 then exit;
    orderby[i].FieldIndex:=fii;
  end;
  sort(arecordset,from,count,orderby);
end;

function TjanSQL.SQLInsertSelect(query: TjanSQLQuery;
  aline: string): integer;
var
  tablename:string;
  t1,t3,L:integer;
  i:integer;
  f,fii,fc,r,rc,newr:integer;

  function havematchingfields:boolean;
  var
    ii:integer;
  begin
    result:=true;
    for ii:=0 to fc-1 do
      if recordsets[t1].IndexOfField(recordsets[t3].fieldnames[ii])<>-1 then exit;
    result:=false;
  end;

begin
  result:=0;
  L:=query.FTokens.count;
  if L<4 then exit;
  tablename:=query.tokens[2].name;
  t1:=indexoftable(tablename);

  if t1=0 then begin
    err('INSERT INTO: can not find table '+tablename); //soner moved here
    exit;
  end;
  for i:=0 to 2 do begin
    query.Tokens[0].free;
    query.FTokens.Delete(0);
  end;
  t3:=SQLSelect(query,aline,'');
  rc:=recordsets[t3].recordcount;
  if rc=0 then begin
    err('No result records'); //soner moved here
    exit;
  end;
  fc:=recordsets[t3].fieldcount;
  if fc=0 then begin
    err('No result fields'); //soner moved here
    exit;
  end;
  if not havematchingfields then begin
    err('INSERT INTO..SELECT: no mathing fields'); //soner moved here
    exit;
  end;
  for r:=0 to rc-1 do begin
    newr:=recordsets[t1].addrecord;
    for f:=0 to fc-1 do begin
      fii:=recordsets[t1].indexoffield(recordsets[t3].fieldnames[f]);
      if fii<>-1 then
        recordsets[t1].records[newr].fields[fii].value:=recordsets[t3].records[r].fields[f].value;
    end;
  end;
  ReleaseRecordset(t3); // JV 25-mar-2002
  result:=-1;
end;


function TjanSQL.InCatalog(value: string): boolean;
var
  fn:string;
begin
  result:=true;
  {fn:=Fcatalog+PathDelim+value+'.txt';}
  fn:=Fcatalog+PathDelim+value+'.csv'; //Changed by Zlatko Matić, 26.12.2013.
  if fileexists(fn) then exit;
  result:=false;
end;

function TjanSQL.SQLAssign(query: TjanSQLQuery; aline: string): integer;
var
  tablename:string;
  L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<4 then begin
    err('SELECT: Need at least 4 token'); //soner moved here
    exit;
  end;
  tablename:=query.tokens[1].name;
  if (query.Tokens[2]._operator<>tosqlSELECT) then begin
    err('SELECT: missing SELECT'); //soner moved here
    exit;
  end;
  TToken(query.tokens[0]).free;
  TToken(query.tokens[1]).free;
  query.FTokens.Delete(0);
  query.FTokens.Delete(0);
  result:=SQLSelect(query,aline,tablename);
  if result>0 then
    result:=-1;
end;

function TjanSQL.SQLSaveTable(query: TjanSQLQuery; aline: string): integer;
var
  tablename:string;
  L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<2 then  begin
    err('SAVE TABLE: missing tablename'); //soner moved here
    exit;
  end;
  tablename:=query.tokens[1].name;
  result:=SaveTable(tablename);
end;

function TjanSQL.SaveTable(tablename: string): integer;
var
  fn:string;
  idx:integer;
begin
  result:=0;
  if tablename='' then  begin
    err('DROP TABLE: table name missing'); //soner moved here
    exit;
  end;
  idx:=FRecordSets.IndexOf(tablename);
  if idx=-1 then  begin
    err('SAVE TABLE: unknown table name '+tablename); //soner moved here
    exit;
  end;
  recordsets[idx+1].intermediate:=false;
  // force persistance
  recordsets[idx+1].persistent:=true;
  {fn:=Fcatalog+PathDelim+recordsets[idx+1].name+'.txt';}
  fn:=Fcatalog+PathDelim+recordsets[idx+1].name+'.csv';  //Changed by Zlatko Matić, 26.12.2013.
  recordsets[idx+1].SaveToFile(fn);
  recordsets[idx+1].modified:=false;
  result:=-1;
end;

function TjanSQL.SQLReleaseTable(query: TjanSQLQuery;
  aline: string): integer;
var
  tablename:string;
  L:integer;
begin
  result:=0;
  L:=query.FTokens.count;
  if L<2 then  begin
    err('SAVE TABLE: missing tablename'); //soner moved here
    exit;
  end;
  tablename:=query.tokens[1].name;
  result:=ReleaseTable(tablename);
end;

function TjanSQL.ReleaseTable(tablename: string): integer;
var
  idx:integer;
begin
  result:=0;
  if tablename='' then  begin
    err('RELEASE TABLE: table name missing'); //soner moved here
    exit;
  end;
  idx:=FRecordSets.IndexOf(tablename);
  if idx=-1 then  begin
    err('RELEASE TABLE: unknown table name '+tablename); //soner moved here
    exit;
  end;
  FRecordsets.delete(idx);
  result:=-1;
end;

function TjanSQL.RollBack(query: TjanSQLQuery): integer;
var
  i,c:integer;
  fn:string;
begin
  result:=0;
  c:=recordsetcount;
  if c=0 then begin
    result:=-1;
    exit;
  end;
  for i:=1 to c do
    if (recordsets[i].persistent) and (recordsets[i].modified) then begin
      {fn:=Fcatalog+PathDelim+recordsets[i].name+'.txt';}
      fn:=Fcatalog+PathDelim+recordsets[i].name+'.csv'; //Changed by Zlatko Matić, 26.12.2013.
      if not fileexists(fn) then
        continue;
      recordsets[i].LoadFromFile(fn);
      recordsets[i].modified:=false;
    end;
  result:=-1;
end;

function TjanSQL.SQLRollBack(query: TjanSQLQuery; aline: string): integer;
var
  L:integer;
begin
  result:=-1;
  L:=query.FTokens.count;
  if L<>1 then exit;
  if query.Tokens[0]._operator<>tosqlRollBack then exit;
  result:=RollBack(query);
end;

{ TjanRecordset }

function TjanRecordset.AddField(fieldname,value: string): integer;
var
  i,c:integer;
begin
  result:=0;
  if FFieldNames.IndexOf(fieldname)<>-1 then exit;
  FFieldNames.Append(fieldname);
  c:=Frecords.Count;
  if c<>0 then
    for i:=0 to c-1 do
      Records[i].AddField(value);
  result:=-1;
  modified:=true;  
end;

function TjanRecordSet.AddRecord: integer;
var
  i,c:integer;
begin
  result:= FRecords.Add(Tjanrecord.create);
  c:=FieldNames.count;
  if c=0 then exit;
  for i:=1 to c do
   records[result].AddField('');
  modified:=true;
end;


procedure TjanRecordset.Clear;
begin
  FfieldNames.Clear;
  FRecords.Clear;
end;

constructor TjanRecordset.create;
begin
  FFieldNames:=TStringList.Create;
  FRecords:=TjanRecordList.Create;
end;

function TjanRecordset.DeleteField(index: variant): integer;
var
  fi,i,c:integer;
begin
  result:=0;
  if vartype(index)=system.varstring then begin
    fi:=FFieldNames.IndexOf(index);
    if fi=-1 then exit;
  end
  else
    fi:=index;
  if (fi<0) or (fi>=FFieldNames.Count) then exit;
  c:=recordcount;
  result:=-1;
  FFieldNames.Delete(fi);
  if c=0 then exit;
  for i:=0 to c-1 do
    records[i].DeleteField(fi);
  modified:=true;
end;

function TjanRecordSet.DeleteRecord(index: integer): boolean;
begin
  result:=false;
  if (index<0) or (index>=Frecords.count) then exit;
  Frecords.delete(index);
  modified:=true;
end;

destructor TjanRecordset.destroy;
begin
  FFieldNames.Free;
  Frecords.Free;
  inherited;
end;

function TjanRecordSet.FindFieldValue(fieldindex: integer;
  fieldvalue: string): integer;
var
  i,c:integer;
begin
  result:=-1;
  c:=recordcount;
  if c=0 then exit;
  for i:=0 to c-1 do begin
    if records[i].fields[fieldindex].value=fieldvalue then begin
      result:=i;
      exit;
    end;
  end;
end;

function TjanRecordset.getfieldvalue(index: variant): string;
var
  fi:integer;
  s:string;
  rec:TjanRecord;
begin
  result:='';
  if FRecordCursor=-1 then exit;
  if vartype(index)=varstring then begin
    s:=index;
    fi:=FFieldNames.IndexOf(s);
    if fi=-1 then exit;
  end
  else
    fi:=index;
  rec:=TjanRecord(FRecords.items[FRecordcursor]);
  result:=rec.fields[fi].value;
end;

function TjanRecordset.getrecord(index: integer): TjanRecord;
begin
  result:=nil;
  if FRecords.Count=0 then exit;
  result:=TjanRecord(FRecords[index]);
end;

function TjanRecordset.getrecordcount: integer;
begin
  result:=FRecords.Count;
end;

function TjanRecordSet.IndexOfField(fieldname: string): integer;
begin
  result:=FFieldNames.IndexOf(fieldname);
end;

function TjanRecordset.LoadFromFile(filename: string): boolean;
var
  gen:TStringList;
  i,c:integer;
  rec:TjanRecord;
begin
  result:=false;
  if not fileexists(filename) then exit;
  Clear;
  try
    gen:=Tstringlist.Create;
    gen.LoadFromFile(filename);
    c:=gen.count;
    if c<>0 then begin
      split(gen[0],FFieldnames);
      if c>1 then
        for i:=1 to c-1 do begin
          rec:=Tjanrecord.create;
          rec.row:=gen[i];
          Frecords.Add(rec);
        end;
      result:=true;
    end;
  finally
    gen.free;
  end;
end;

function TjanRecordset.SaveToFile(filename: string): boolean;
var
  gen:TStringList;
  i,c:integer;

begin
  try
    gen:=TStringList.Create;
    gen.append(join(FFieldNames));
    c:=RecordCount;
    if c<>0 then
      for i:=0 to c-1 do
        gen.append(Records[i].row);
    gen.SaveToFile(filename);
    Result:=true; //soner added
  finally
    gen.free;
  end;
end;

procedure TjanRecordset.setfieldvalue(index: variant; const Value: string);
var
  fi:integer;
  s:string;
  rec:TjanRecord;
begin
  if FRecordCursor=-1 then exit;
  if vartype(index)=varstring then begin
    s:=index;
    fi:=FFieldNames.IndexOf(s);
    if fi=-1 then exit;
  end
  else
    fi:=index;
  rec:=TjanRecord(FRecords.items[FRecordcursor]);
  rec.fields[fi].value:=value;
  modified:=true;  
end;

procedure TjanRecordset.Setname(const Value: string);
begin
  Fname := Value;
end;

procedure TjanRecordset.Setpersistent(const Value: boolean);
begin
  Fpersistent := Value;
end;


procedure TjanRecordSet.Setmodified(const Value: boolean);
begin
  Fmodified := Value;
end;

function TjanRecordSet.getfieldcount: integer;
begin
  result:=fieldnames.Count;
end;


procedure TjanRecordSet.Setmatchrecord(const Value: integer);
begin
  Fmatchrecord := Value;
end;

function TjanRecordSet.getLongFieldList: string;
var
  i,c:integer;
begin
  result:='';
  c:=FFieldNames.Count;
  if c=0 then exit;
  for i:=0 to c-1 do
    if result='' then
      result:=name+'.'+FFieldNames[i]
    else
      result:=result+';'+name+'.'+FFieldNames[i];
end;

function TjanRecordSet.getShortFieldList: string;
var
  i,c:integer;
begin
  result:='';
  c:=FFieldNames.Count;
  if c=0 then exit;
  for i:=0 to c-1 do
    if result='' then
      result:=FFieldNames[i]
    else
      result:=result+';'+FFieldNames[i];
end;

procedure TjanRecordSet.Setalias(const Value: string);
begin
  Falias := Value;
end;

procedure TjanRecordSet.Setintermediate(const Value: boolean);
begin
  Fintermediate := Value;
end;

{ TjanRecord }

procedure TjanRecord.AddField(value: string);
var
  f:TjanSQLRecordField;
begin
  f:=TjanSQLRecordField.create;
  f.value:=value;
  FFields.Add(f);

end;

procedure TjanRecord.ClearFields;
var
  i,c:integer;
begin
  c:=FFields.Count;
  if c=0 then exit;
  for i:=0 to c-1 do
    TjanSQLRecordField(FFields[i]).free;
  FFields.Clear;
end;

constructor TjanRecord.create;
begin
  FFields:=TList.Create;
end;

function TjanRecord.DeleteField(index: integer): boolean;
begin
  result:=false;
  if (index<0) or (index>=FFields.count) then exit;
  TjanSQLRecordField(FFields[index]).free;
  FFields.Delete(index);
  result:=true;
end;

destructor TjanRecord.destroy;
begin
  ClearFields;
  FFields.free;
  inherited;
end;

function TjanRecord.getfield(index: integer): TjanSQLRecordField;
begin
  result:=nil;
  if (index<>-1) and (index<FFields.count) then
    result:=TjanSQLRecordField(FFields[index])
  else
    raise exception.create('fieldcount:'+inttostr(FFields.count));

end;

function TjanRecord.getrow: string;

  function validformat (value: String): String;
  var qn: boolean;
  begin
    qn := false;
    if pos (PathDelim, value)>0 then
      begin
        while (pos ('\\', value)>0) do
          value := StringReplace (value, '\\', PathDelim, [rfReplaceAll]);
        value := StringReplace (value, PathDelim, '\\', [rfReplaceAll]);
      end;
    if pos (#13, value)>0 then
      value := StringReplace (value, #13, '\n', [rfReplaceAll]);
    if pos (#10, value)>0 then
      value := StringReplace (value, #10, '\l', [rfReplaceAll]);
    if pos (#9, value)>0 then
      value := StringReplace (value, #9, '\t', [rfReplaceAll]);
    if pos (#0, value)>0 then
      value := StringReplace (value, #0, '\0', [rfReplaceAll]);
    if pos (';', value)>0 then
      //quotesneeded
      qn := true;
    if pos ('''', value)>0 then
      qn := true;
    if pos ('"', value)>0 then
      begin
        value := StringReplace (value, '"', '\"', [rfReplaceAll]);
        qn := true;
      end;
    if qn then
      value := '"'+value+'"';
    result := value;
  end;

var
  i:integer;
begin
  result:='';
  for i:=0 to FFields.count-1 do
   if i = 0 then                                                                   //Dak_Alpha
     result:=validformat(TjanSQLRecordField(FFields[i]).value)
   else
     result:=result+';'+validformat(TjanSQLRecordField(FFields[i]).value);

end;


procedure TjanRecord.Setcounter(const Value: integer);
begin
  Fcounter := Value;
end;

procedure TjanRecord.setfield(index: integer; const Value: string);
begin
  if (index<>-1) and (index<FFields.count) then
    TjanSQLRecordField(FFields[index]).value:=value;

end;

procedure TjanRecord.Setmark(const Value: boolean);
begin
  Fmark := Value;
end;

procedure TjanRecord.setrow(const Value: string);
  function StripQuotes (value: String): String;
  begin
    Result := value;
    //exit;
    if (length(value)>=2) and
       (
       ((value[1]='"') and (value[length(value)]='"')) or                          //Dak_Alpha
       ((value[1]='''') and (value[length(value)]='''')) or                        //Dak_Alpha
       ((value[1]='`') and (value[length(value)]='`'))                             //Dak_Alpha
       ) then
      value := copy (value, 2, length(value)-2);
    Result := value;
  end;
var
 i,c:integer;
 lis:TStringlist;
begin
  ClearFields;
  try
    lis:=TStringList.create;
    split(value,lis);
    c:=lis.count;
    for i:=0 to c-1 do
      AddField(StripQuotes(lis[i]));
  finally
    lis.free;
  end;
end;


{ TjanRecordList }

procedure TjanRecordList.Clear;
var
  i,c:integer;
begin
  c:=count;
  if c<>0 then
    for i:=0 to c-1 do
      TjanRecord(self.items[i]).free;
  inherited;
end;


procedure TjanRecordList.delete(index: integer);
begin
  TjanRecord(items[index]).free;
  inherited;

end;

destructor TjanRecordList.destroy;
begin
  Clear;
  inherited;
end;


{ TjanRecordSetList }

procedure TjanRecordSetList.delete(index: integer);
begin
  TjanRecordSet(objects[index]).free;
  inherited;
end;

destructor TjanRecordSetList.destroy;
var
  i,c:integer;
begin
  c:=self.Count;
  if c>0 then
   for i:=0 to c-1 do
     TjanRecordSet(objects[i]).free;
  inherited;
end;


{ TjanSQLQuery }

procedure TjanSQLQuery.ClearTokenList;
var
  i,c:Integer;
begin
  c:=FTokens.Count;
  if c=0 then exit;
  for i:=0 to c-1 do
    TToken(Ftokens[i]).free;
  FTokens.clear;
end;

constructor TjanSQLQuery.create;
begin
  FTokens:=TList.create;
  FParser:=TjanSQLExpression2.create;
end;

destructor TjanSQLQuery.destroy;
begin
  ClearTokenList;
  FTokens.free;
  FParser.free;
  inherited;
end;

function TjanSQLQuery.getParser: TjanSQLExpression2;
begin
  result:=FParser;
end;

function TjanSQLQuery.GetToken(index: integer): TToken;
begin
  result:=TToken(Ftokens[index]);
end;

procedure TjanSQLQuery.SetEngine(const Value: TjanSQL);
begin
  FEngine := Value;
end;

{ TjanSQLCalcField }

constructor TjanSQLCalcField.create;
begin
  FCalc:=TjanSQLExpression2.create;
end;

destructor TjanSQLCalcField.destroy;
begin
  FCalc.free;
  inherited;

end;

function TjanSQLCalcField.getValue: variant;
begin
  result:=FCalc.Evaluate;
end;

procedure TjanSQLCalcField.Setexpression(const Value: string);
begin
  Fexpression := Value;
  FCalc.Expression:=value;
end;

procedure TjanSQLCalcField.SetFieldIndex(const Value: integer);
begin
  FFieldIndex := Value;
end;

procedure TjanSQLCalcField.Setname(const Value: string);
begin
  Fname := Value;
end;


{ TjanSQLOutput }

function TjanSQLOutput.AddField: TjanSQLCalcField;
begin
  result:=TjanSQLCalcField.create;
  FFields.Add(result);
end;

procedure TjanSQLOutput.ClearFields;
var
  i,c:integer;
begin
  c:=FFields.count;
  if c=0 then exit;
  for i:=0 to c-1 do
    TjanSQLCalcField(FFields[i]).free;
  FFields.clear;
end;

constructor TjanSQLOutput.create;
begin
  FFields:=TList.create;
end;

destructor TjanSQLOutput.destroy;
begin
  ClearFields;
  FFields.free;
  inherited;
end;

function TjanSQLOutput.getField(index: integer): TjanSQLCalcField;
begin
  result:=nil;
  if (index<0) or (index>=FFields.count) then exit;
  result:=TjanSQLCalcField(FFields[index]);
end;

function TjanSQLOutput.getFieldCount: integer;
begin
  result:=FFields.count;
end;

function TjanSQLOutput.getFieldNames: string;
var
  i,c:integer;
begin
  result:='';
  c:=FFields.Count;
  if c=0 then exit;
  for i:=0 to c-1 do
    if result='' then
      result:=Fields[i].name
    else
      result:=result+';'+Fields[i].name;
end;


{ TjanSQLRecordField }

procedure TjanSQLRecordField.Setcount(const Value: integer);
begin
  Fcount := Value;
end;

procedure TjanSQLRecordField.Setsum(const Value: double);
begin
  Fsum := Value;
end;

procedure TjanSQLRecordField.Setsum2(const Value: double);
begin
  Fsum2 := Value;
end;

procedure TjanSQLRecordField.Setvalue(const Value: variant);
begin
  Fvalue := Value;
end;

end.
