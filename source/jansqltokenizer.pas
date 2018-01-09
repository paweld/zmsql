{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at
http://www.mozilla.org/NPL/NPL-1_1Final.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: janSQLTokenizer.pas, released March 24, 2002.

The Initial Developer of the Original Code is Jan Verhoeven
(jan1.verhoeven@wxs.nl or http://jansfreeware.com).
Portions created by Jan Verhoeven are Copyright (C) 2002 Jan Verhoeven.
All Rights Reserved.

Contributor(s):
               - Zlatko Matić (matalab@gmail.com)
___________________.

Last Modified: 16.08.2011
Current Version: 1.2

Notes: This is a SQL oriented tokenizer.

Known Issues:


History:
  1.2 16.08.2011 (by Zlatko Matić)
      - added tosqlSELECTDISTINCT, tosqlINNERJOIN, tosqlLEFTOUTERJOIN, tosqlRIGHTOUTERJOIN,
      tosqlFULLOUTERJOIN, tosqlCROSSJOIN, tosqlON, tosqlUSING
  1.1 25-mar-2002
      - TRUNC alias for FIX function
      - added FORMAT function
      - added DATE constant
      - added TIME constant
      - added YEAR function
      - added MONTH function
      - added DAY function
      - added DATEADD function
      - added DATEDIFF function
      - added EASTER function
      - added WEEKNUMBER function
      - added ISNUMERIC function      
      - added ISDATE function
  1.0 24-mar-2002 : original release

-----------------------------------------------------------------------------}

{$ifdef fpc}
   {$mode delphi} {$H+}
{$endif}


unit janSQLTokenizer;

interface

uses
  {$IFDEF UNIX} clocale, cwstring,{$ENDIF}
  Classes,SysUtils,janSQLStrings{soner ,dialogs};

const
  delimiters=['+','-','*','/',' ','(',')','=','>','<'];
  numberchars=['0'..'9','.'];
  identchars=['a'..'z','A'..'Z','0'..'9','.','_'];
  alphachars=['a'..'z','A'..'Z'];

type

  TSubExpressionEvent=procedure(sender:Tobject;const subexpression:string;var subexpressionValue:variant;var handled:boolean) of object;

  TTokenKind=(tkKeyword,tkOperator, tkOperand, tkOpen, tkClose,
    tkComma,tkHash);


  TTokenOperator=(toNone,toAString,toNumber,toVariable,
     toComma,toOpen,toClose,toHash,
     tosqlCount, tosqlSum, tosqlAvg, tosqlMAX, tosqlMIN, tosqlStdDev,
     toEq,toNe,toGt,toGe,toLt,toLe,
     toLOJ, //To be used for lef outer join. Added by Zlatko Matić, 16.08.2011
     toROJ, //To be used for right outer join. Added by Zlatko Matić, 16.08.2011
     toAdd,toSubtract,toMultiply,toDivide,
     toAnd,toOr,toNot,toLike,
     tosqlALTER,tosqlTABLE,tosqlCOLUMN,
     tosqlADD,tosqlDROP,tosqlCOMMIT,tosqlCREATE,
     tosqlDELETE,tosqlFROM,tosqlWHERE,
     tosqlINSERT,tosqlINTO,tosqlVALUES,
     tosqlSELECT,tosqlAS,tosqlORDER,tosqlUPDATE,
     tosqlSELECTDISTINCT,  //Added by Zlatko Matić, 16.08.2011
     tosqlINNERJOIN, tosqlLEFTOUTERJOIN, tosqlRIGHTOUTERJOIN, tosqlFULLOUTERJOIN, tosqlCROSSJOIN, //Added by Zlatko Matić, 16.08.2011
     tosqlON, tosqlUSING,  //Added by Zlatko Matić, 16.08.2011
     tosqlSET,tosqlCONNECT, tosqlASSIGN,
     tosqlSAVETABLE, tosqlRELEASETABLE,
     tosqlGROUP, tosqlASC, tosqlDESC, tosqlHAVING,
     tosqlIN,
     toLOWER,toUPPER,toTRIM,toSoundex,
     toSin, toCos, toSqr, toSqrt,
     toAsNumber,toLeft, toRight, toMid,
     tosubstr_after, tosubstr_before,
     toFormat,
     toDateAdd,
     toYear, toMonth, toDay, toEaster, toWeekNumber,
     toLen, toFix, toCeil, toFloor,
     toIsNumeric, toIsDate,
     toReplace, tosqlROLLBACK);



  TToken=class(TObject)
  private
    Fname: string;
    Ftokenkind: TTokenKind;
    Foperator: TTokenOperator;
    Fvalue: variant;
    Flevel: integer;
    Fexpression: string;
    procedure Setname(const Value: string);
    procedure Setoperator(const Value: TTokenOperator);
    procedure Settokenkind(const Value: TTokenKind);
    procedure Setvalue(const Value: variant);
    procedure Setlevel(const Value: integer);
    procedure Setexpression(const Value: string);
  public
    function copy:TToken;
    property name:string read Fname write Setname;
    property value:variant read Fvalue write Setvalue;
    property tokenkind:TTokenKind read Ftokenkind write Settokenkind;
    property _operator: TTokenOperator read Foperator write Setoperator;
    property level:integer read Flevel write Setlevel;
    property expression:string read Fexpression write Setexpression;
  end;

  TjanSQLTokenizer=class(TObject)
  private
    FSource:string;
    FList:TList;
    idx: integer; // scan index
    SL:integer; // source length
    FToken:string;
    FTokenKind:TTokenKind;
    FTokenValue:variant;
    FTokenOperator:TTokenOperator;
    FTokenLevel:integer;
    FTokenExpression:string;
    FonSubExpression: TSubExpressionEvent;
    procedure AddToken(list:TList);
    function GetToken: boolean;
    function IsKeyWord(value: string): boolean;
    function IsFunction(value: string): boolean;
    function LookAhead(var index:integer):string;
    function getTokenCount: integer;
    function getsubExpression:boolean;
    procedure SetonSubExpression(const Value: TSubExpressionEvent);
  public
    function Tokenize(source:string;list:TList):boolean;
    property TokenCount:integer read getTokenCount;
    property onSubExpression:TSubExpressionEvent read FonSubExpression write SetonSubExpression;
  end;


implementation

const
  cr = chr(13)+chr(10);


{ TjanSQLTokenizer }

function TjanSQLTokenizer.Tokenize(source: string; list: TList): boolean;
begin
  result:=true;
  FSource:=source;
  idx:=1;
  SL:=length(source);
  while getToken do AddToken(list);
end;



procedure TjanSQLTokenizer.AddToken(list:TList);
var
  tok:TToken;
begin
  tok:=TToken.Create;
  tok.name:=FToken;
  tok.tokenkind:=FTokenKind;
  tok.value:=FTokenValue;
  tok._operator:=FTokenOperator;
  tok.level:=FtokenLevel;
  tok.expression:=FTokenExpression;
  List.Add(tok);
end;


function TjanSQLTokenizer.GetToken: boolean;
var
  bot:char;
  tmpToken: String;

  function sqldatestring:string;
  var
    ayear,amonth,aday:word;
  begin
    decodedate(now,ayear,amonth,aday);
    result:=format('%.4d',[ayear])+'-'+format('%.2d',[amonth])+'-'+format('%.2d',[aday])
  end;

  function sqltimestring:string;
  var
    ahour,amin,asec,amsec:word;
  begin
    decodetime(time,ahour,amin,asec,amsec);
    result:=format('%.2d',[ahour])+':'+format('%.2d',[amin])+':'+format('%.2d',[asec]);
  end;

begin
  result:=false;
  FToken:='';
  tmpToken := '';
  while (idx<=SL) and (FSource[idx]=' ') do inc(idx);
  if idx>SL then exit;
  bot:=FSource[idx]; // begin of token
  case bot of         //// edgarrod71@gmail.com  incorporated CASE instead of IFs
    '''': begin  // string
          inc(idx);
          while (idx<=SL) and (FSource[idx]<>'''' ) do begin
            FToken:=FToken+Fsource[idx];
            inc(idx);
          end;
          if idx>SL then exit;
          inc(idx);
          FTokenValue:=FToken;
          FTokenKind:=tkOperand;
          FTokenOperator:=toAString;
          result:=true;
      end;
    ',': begin
          FToken:=FToken+Fsource[idx];
          inc(idx);
          FTokenValue:=FToken;
          FTokenKind:=tkComma;
          FTokenOperator:=toComma;
          result:=true;
      end;
    '#': begin
          FToken:=FToken+Fsource[idx];
          inc(idx);
          FTokenValue:=FToken;
          FTokenKind:=tkHash;
          FTokenOperator:=toHash;
          result:=true;
      end;
    'A'..'Z',
    'a'..'z': begin  // identifier
            while (idx<=SL) and (FSource[idx] in identchars) do begin
              FToken:=FToken+Fsource[idx];
              inc(idx);
            end;
            tmpToken := lowercase(FToken);
            if isKeyword(Ftoken) then begin
              result:=true;
            end
            else if tmpToken='or' then begin
                FTokenKind:=tkOperator;
                FTokenLevel:=0;
                FTokenOperator:=toOr;
            end
            else if tmpToken='and' then begin
                FTokenKind:=tkOperator;
                FTokenLevel:=0;
                FTokenOperator:=toAnd;
            end
            else if tmpToken='pi' then begin
                FTokenKind:=tkOperand;
                FTokenValue:=pi;
                FTokenOperator:=toNumber;
            end
            else if tmpToken='date' then begin
                FTokenKind:=tkOperand;
                FTokenValue:=sqldatestring;
                FTokenOperator:=toAString;
            end
            else if tmpToken='time' then begin
                FTokenKind:=tkOperand;
                FTokenValue:=sqltimestring;
                FTokenOperator:=toAString;
            end
            else if ISFunction(tmpToken) then begin
            end
            else begin
                FTokenKind:=tkOperand;
                FTokenOperator:=toVariable;
            end;
            result:=true;
      end;
    '0'..'9': begin // number
            while (idx<=SL) and (FSource[idx] in numberchars) do begin
              FToken:=FToken+Fsource[idx];
              inc(idx);
            end;
            FTokenKind:=tkOperand;
            try
              FTokenValue:=strtofloat(FToken);
              FTokenOperator:=toNumber;
            except
              exit;
            end;
            result:=true;
        end;
    '(': begin
            FToken:='(';
            FTokenKind:=tkOpen;
            FTokenOperator:=toOpen;
            FtokenLevel:=1;
            inc(idx);
            result:=true;
         end;
    ')': begin
            FToken:=')';
            FTokenKind:=tkClose;
            FTokenOperator:=toClose;
            FtokenLevel:=1;
            inc(idx);
            result:=true;
        end;
    '+','-',
    '*','/',
    ' ','=',
    '>','<': begin   //// delimiters
            FToken:=FToken+Fsource[idx];
            inc(idx);
            FTokenKind:=tkOperator;
            case bot of
            '=': begin  //Modified by Zlatko Matić, 16.08.2011
                      if FSource[idx]='*' then begin
                        FToken:=FToken+FSource[idx];
                        inc(idx);
                        FTokenOperator:=toROJ; //to be used for right outer join
                        FTokenLevel:=3; //to check this level!
                      end
                      else begin
                        FTokenOperator:=toEq;
                        FTokenLevel:=3;
                      end
                 end;
            '+': begin  FTokenOperator:=toAdd;
                        FTokenLevel:=4;
                 end;
            '-': begin  FTokenOperator:=toSubtract;
                        FTokenLevel:=3;
                 end;
            '*': begin  //Modified by Zlatko Matić, 16.08.2011
                      if FSource[idx]='=' then begin
                        FToken:=FToken+FSource[idx];
                        inc(idx);
                        FTokenOperator:=toLOJ; //to be used for left outer join
                        FTokenLevel:=3;  //to check this level!
                      end
                      else begin
                        FTokenOperator:=toMultiply;
                        FTokenLevel:=6;
                      end
                 end;
            '/': begin  FTokenOperator:=toDivide;
                        FtokenLevel:=5;
                 end;
            '>': begin
                   if idx>SL then exit;
                   FTokenLevel:=3;
                   if FSource[idx]='=' then begin
                     FToken:=FToken+Fsource[idx];
                     inc(idx);
                     FTokenOperator:=toGe;
                   end
                   else
                     FTokenOperator:=toGt
                 end;
            '<': begin
                   if idx > SL then exit;
                   FTokenLevel:=3;
                   if FSource[idx] = '=' then begin
                     FToken:=FToken+Fsource[idx];
                     inc(idx);
                     FTokenOperator:=toLe;
                   end
                   else if FSource[idx] = '>' then begin
                     FToken:=FToken+Fsource[idx];
                     inc(idx);
                     FTokenOperator:=toNe;
                   end
                   else
                     FTokenOperator:=toLt;
                 end;
            end;
            result:=true;
        end;
  else
    exit;
  end;
end;

function TjanSQLTokenizer.IsFunction(value: string): boolean;
var
  vValue: string;
begin
  result:=true;     //// edgarrod71@gmail.com simplified the function, more readable and shrinked bytes on the executable, not so much, but it counts..
  vValue := lowercase(value);
  if vValue='sin' then
    FTokenOperator:=tosin
  else if vValue='cos' then
    FTokenOperator:=tocos
  else if vValue='sqr' then
    FTokenOperator:=tosqr
  else if vValue='sqrt' then
    FTokenOperator:=tosqrt
  else if vValue='easter' then
    FTokenOperator:=toEaster
  else if value='weeknumber' then
    FTokenOperator:=toWeekNumber
  else if value='year' then
    FTokenOperator:=toyear
  else if value='month' then
    FTokenOperator:=tomonth
  else if value='day' then
    FTokenOperator:=today
  else if value='soundex' then
    FTokenOperator:=toSoundex
  else if value='lower' then
    FTokenOperator:=toLOWER
  else if value='upper' then
    FTokenOperator:=toUPPER
  else if value='trim' then
    FTokenOperator:=toTRIM
  else if value='in' then begin
    FTokenOperator:=tosqlIN;
    result:=boolean(getsubexpression);
  end
  else if value='not' then
    FTokenOperator:=toNot
  else if value='like' then
    FTokenOperator:=toLike
  else if value='asnumber' then
    FTokenOperator:=toAsNumber
  else if value='dateadd' then
    FTokenOperator:=todateadd
  else if value='left' then
    FTokenOperator:=toleft
  else if value='right' then
    FTokenOperator:=toRight
  else if value='mid' then
    FTokenOperator:=toMid
  else if value='substr_after' then
    FTokenOperator:=tosubstr_after
  else if value='substr_before' then
    FTokenOperator:=tosubstr_before
  else if value='format' then
    FTokenOperator:=toFormat
  else if value='length' then
    FTokenOperator:=toLen
  else if (value='fix') or (value='trunc') then
    FTokenOperator:=toFix
  else if value='ceil' then
    FTokenOperator:=toCeil
  else if value='floor' then
    FTokenOperator:=toFloor
  else if value='isnumeric' then
        FTokenOperator:=toIsNumeric
  else if value='isdate' then
        FTokenOperator:=toIsDate
  else if value='replace' then
        FTokenOperator:=toReplace
  else
        result := false;

  if result then begin                //// simplifies it. edgarrod71@gmail.com
    FtokenKind:=tkOperator;
    FtokenLevel:=7;
  end;
end;

function TjanSQLTokenizer.getTokenCount: integer;
begin
  result:=FList.count;
end;

function TjanSQLTokenizer.IsKeyWord(value: string): boolean;
var
  tmp:string;
  i:integer;
begin
  result:=false;
  tmp:=uppercase(value);
  if tmp='SELECT' then begin //Modified by Zlatko Matić, 16.08.2011
      //Added by Zlatko Matić, 16.08.2011
      if uppercase(lookahead(i))='DISTINCT' then begin
        FTokenOperator:=tosqlSELECTDISTINCT;
        result:=true;
        idx:=i;
      end
    else begin
      FTokenOperator:=tosqlSELECT;
      result:=true;
    end
  end
  else if tmp='AS' then begin
    FTokenOperator:=tosqlAS;
    result:=true;
  end
  else if tmp='SAVE' then begin
    if uppercase(lookahead(i))<>'TABLE' then exit;
    FTokenOperator:=tosqlSAVETABLE;
    result:=true;
    idx:=i;
  end
  else if tmp='RELEASE' then begin
    if uppercase(lookahead(i))<>'TABLE' then exit;
    FTokenOperator:=tosqlRELEASETABLE;
    result:=true;
    idx:=i;
  end
  else if tmp='ASSIGN' then begin
    if uppercase(lookahead(i))<>'TO' then exit;
    FTokenOperator:=tosqlASSIGN;
    result:=true;
    idx:=i;
  end
  else if tmp='UPDATE' then begin
    FTokenOperator:=tosqlUPDATE;
    result:=true;
  end
  else if tmp='INSERT' then begin
    FTokenOperator:=tosqlINSERT;
    result:=true;
  end
  else if tmp='INTO' then begin
    FTokenOperator:=tosqlINTO;
    result:=true;
  end
  else if tmp='DELETE' then begin
    FTokenOperator:=tosqlDELETE;
    result:=true;
  end
  else if tmp='CONNECT' then begin
    if uppercase(lookahead(i))<>'TO' then exit;
    FTokenOperator:=tosqlCONNECT;
    result:=true;
    idx:=i;
  end
  else if tmp='COMMIT' then begin
    FTokenOperator:=tosqlCOMMIT;
    result:=true;
  end
  else if tmp='ROLLBACK' then begin
    FTokenOperator:=tosqlROLLBACK;
    result:=true;
  end
  else if tmp='FROM' then begin
    FTokenOperator:=tosqlFROM;
    result:=true;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='LEFT' then begin
    if ((uppercase(lookahead(i))<>'JOIN') and (uppercase(lookahead(i))<>'OUTER')) then exit;
    if (uppercase(lookahead(i))='OUTER') then begin
      idx:=i;
      if (uppercase(lookahead(i))<>'JOIN') then exit;
      if (uppercase(lookahead(i))='JOIN') then begin
        FTokenOperator:=tosqlLEFTOUTERJOIN;
        result:=true;
        idx:=i;
      end;
    end
    else if (uppercase(lookahead(i))='JOIN') then begin
      FTokenOperator:=tosqlLEFTOUTERJOIN;
      result:=true;
      idx:=i;
    end;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='RIGHT' then begin
    if ((uppercase(lookahead(i))<>'JOIN') and (uppercase(lookahead(i))<>'OUTER')) then exit;
    if (uppercase(lookahead(i))='OUTER') then begin
      idx:=i;
      if (uppercase(lookahead(i))<>'JOIN') then exit;
      if (uppercase(lookahead(i))='JOIN') then begin
        FTokenOperator:=tosqlRIGHTOUTERJOIN;
        result:=true;
        idx:=i;
      end;
    end
    else if (uppercase(lookahead(i))='JOIN') then begin
      FTokenOperator:=tosqlRIGHTOUTERJOIN;
      result:=true;
      idx:=i;
    end;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='FULL' then begin
    if ((uppercase(lookahead(i))<>'JOIN') and (uppercase(lookahead(i))<>'OUTER')) then exit;
    if (uppercase(lookahead(i))='OUTER') then begin
      idx:=i;
      if (uppercase(lookahead(i))<>'JOIN') then exit;
      if (uppercase(lookahead(i))='JOIN') then begin
        FTokenOperator:=tosqlFULLOUTERJOIN;
        result:=true;
        idx:=i;
      end;
    end
    else if (uppercase(lookahead(i))='JOIN') then begin
      FTokenOperator:=tosqlFULLOUTERJOIN;
      result:=true;
      idx:=i;
    end;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='INNER' then begin
    if (uppercase(lookahead(i))<>'JOIN') then exit;
    if (uppercase(lookahead(i))='JOIN') then begin
      FTokenOperator:=tosqlINNERJOIN;
      result:=true;
      idx:=i;
    end;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='CROSS' then begin
    if (uppercase(lookahead(i))<>'JOIN') then exit;
    if (uppercase(lookahead(i))='JOIN') then begin
      FTokenOperator:=tosqlCROSSJOIN;
      result:=true;
      idx:=i;
    end;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='JOIN' then begin
    FTokenOperator:=tosqlINNERJOIN;
    result:=true;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='ON' then begin
    FTokenOperator:=tosqlON;
    result:=true;
  end
  //Added by Zlatko Matić, 16.08.2011
  else if tmp='USING' then begin
    FTokenOperator:=tosqlUSING;
    result:=true;
  end
  else if tmp='WHERE' then begin
    FTokenOperator:=tosqlWHERE;
    result:=true;
  end
  else if tmp='ORDER' then begin
    if uppercase(lookahead(i))<>'BY' then exit;
    FTokenOperator:=tosqlORDER;
    result:=true;
    idx:=i;
  end
  else if tmp='ASC' then begin
    FTokenOperator:=tosqlASC;
    result:=true;
  end
  else if tmp='DESC' then begin
    FTokenOperator:=tosqlDESC;
    result:=true;
  end
  else if tmp='SET' then begin
    FTokenOperator:=tosqlSET;
    result:=true;
  end
  else if tmp='VALUES' then begin
    FTokenOperator:=tosqlVALUES;
    result:=true;
  end
  else if tmp='CREATE' then begin
    FTokenOperator:=tosqlCREATE;
    result:=true;
  end
  else if tmp='TABLE' then begin
    FTokenOperator:=tosqlTABLE;
    result:=true;
  end
  else if tmp='DROP' then begin
    FTokenOperator:=tosqlDROP;
    result:=true;
  end
  else if tmp='ALTER' then begin
    FTokenOperator:=tosqlALTER;
    result:=true;
  end
  else if tmp='ADD' then begin
    FTokenOperator:=tosqlADD;
    result:=true;
  end
  else if tmp='COLUMN' then begin
    FTokenOperator:=tosqlCOLUMN;
    result:=true;
  end
  else if tmp='GROUP' then begin
    if uppercase(lookahead(i))<>'BY' then exit;
    FTokenOperator:=tosqlgroup;
    result:=true;
    idx:=i;
  end
  else if tmp='HAVING' then begin
    FTokenOperator:=tosqlHAVING;
    result:=true;
  end;

  if result then begin
    FtokenKind:=tkKeyword;
    FtokenLevel:=0;
  end;
end;

function TjanSQLTokenizer.getsubExpression: boolean;
var
  tmp:string;
  b:boolean;
  i,c,L:integer;
  tokenizer:TjanSQLTokenizer;
  sublist:TList;
  handled:boolean;
  subvalue:variant;
  brackets:integer;

  procedure clearsublist;
  var
    ii,cc:integer;
  begin
    cc:=sublist.count;
    if cc<>0 then
      for ii:=0 to cc-1 do
        TToken(sublist[ii]).free;
    sublist.clear;
  end;
begin
  result:=False;
  while (idx<=SL) and (FSource[idx]=' ') do inc(idx);
  if idx>SL then exit;
  if FSource[idx]<>'(' then exit;
  inc(idx);
  brackets:=1; // keep track of open/close brackets
  while (idx<=SL) do begin
    if FSource[idx]='(' then
      inc(brackets)
    else if FSource[idx]=')' then begin
      dec(brackets);
      if (brackets=0) then break;
    end
    else
      tmp:=tmp+FSource[idx];
    inc(idx);
  end;
  if idx>SL then exit;
  inc(idx);
  tmp:=trim(tmp);
  if postext('select ',tmp)=1 then begin
    if assigned(onSubExpression) then begin
      onSubExpression(self,tmp,subvalue,handled);
      if handled then begin
        FtokenExpression:=subvalue;
        result:=true;
      end;
    end;
    exit;
  end;
  try
    sublist:=TList.create;
    tokenizer:=TjanSQLTokenizer.create;
    b:=tokenizer.Tokenize(tmp,sublist);
  finally
    tokenizer.free;
  end;
  if not b then begin
    clearsublist;
    sublist.free;
    exit;
  end;
  c:=sublist.Count;
  if c>0 then begin
    tmp:='[';
    for i:=0 to c-1 do begin
      if Ttoken(sublist[i]).tokenkind=tkComma then
        tmp:=tmp+']['
      else
        tmp:=tmp+TToken(sublist[i]).name;
    end;
    tmp:=tmp+']';
  end;
  FtokenExpression:=tmp;
  clearsublist;
  sublist.free;
  result:=true;
end;

procedure TjanSQLTokenizer.SetonSubExpression(
  const Value: TSubExpressionEvent);
begin
  FonSubExpression := Value;
end;
// some sql clauses consist of 2 wordes
// eg GROUP BY
function TjanSQLTokenizer.LookAhead(var index:integer): string;
var
  i:integer;
  tmp:string;
begin
  result:='';
  i:=idx;
  //skip spaces
  while (i<=SL) and (FSource[i]=' ') do inc(i);
  if i>SL then exit;
  // only alpha
  if not (Fsource[i] in alphachars) then exit;
  while (i<=SL) and (Fsource[i] in alphachars) do begin
    tmp:=tmp+FSource[i];
    inc(i);
  end;
  if (i>SL) then
    result:=tmp
  else if Fsource[i]=' ' then
    result:=tmp;
  index:=i;
end;

{ TToken }

function TToken.copy: TToken;
begin
  result:=TToken.Create;
  result.name:=name;
  result.value:=value;
  result.tokenkind:=tokenkind;
  result._operator:=_operator;
  result.level:=level;
  result.expression:=expression;
end;

procedure TToken.Setexpression(const Value: string);
begin
  Fexpression := Value;
end;

procedure TToken.Setlevel(const Value: integer);
begin
  Flevel := Value;
end;

procedure TToken.Setname(const Value: string);
begin
  Fname := Value;
end;

procedure TToken.Setoperator(const Value: TTokenOperator);
begin
  Foperator := Value;
end;

procedure TToken.Settokenkind(const Value: TTokenKind);
begin
  Ftokenkind := Value;
end;

procedure TToken.Setvalue(const Value: variant);
begin
  Fvalue := Value;
end;




end.
