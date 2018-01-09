unit Unit1; 

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  DbCtrls, DBGrids, ZMConnection, ZMQueryDataSet, db;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    ComboBox1: TComboBox;
    Datasource1: TDatasource;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    Label1: TLabel;
    ZMConnection1: TZMConnection;
    ZMQueryDataSet1: TZMQueryDataSet;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  Form1: TForm1; 

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
var
  db: String;
begin
  db := ZMQueryDataset1.ZMConnection.DatabasePath + ZMQueryDataset1.TableName + '.csv';
  ShowMessage('Data is going to be loaded from: '+ db);
  ZMQueryDataset1.LoadFromTable;
end;

procedure TForm1.Button2Click(Sender: TObject);
var
  vOriginalTableName:string;
  vOrigDelim: TFieldDelimiter;
begin
  try
    vOriginalTableName:=ZMQueryDataset1.TableName;
    vOrigDelim := ZMQueryDataset1.FieldDelimiter;
    ZMQueryDataset1.TableName:='Test';
    ZMQueryDataset1.FieldDelimiter := TFieldDelimiter(Combobox1.ItemIndex);
    ShowMessage('Dataset is going to be saved to: '+
       ZMQueryDataset1.ZMConnection.DatabasePath +
       ZMQueryDataset1.TableName+'.csv');
    ZMQueryDataset1.SaveToTable(FormatSettings.DecimalSeparator);
  finally
    ZMQueryDataset1.FieldDelimiter := vOrigDelim;
    ZMQueryDataset1.TableName:=vOriginalTableName;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ZMConnection1.DatabasePath := '..\data\';
end;

end.

