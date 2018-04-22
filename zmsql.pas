{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit zmsql;

{$warn 5023 off : no warning about unused units}
interface

uses
  AllzmsqlRegister, ZMBufDataset, ZMConnection, ZMQueryDataSet, 
  ZMReferentialKey, ZMBufDataset_parser, QBDBFrm2, QBuilder, QBDirFrm, 
  QBAbout, QBLnkFrm, QBDBFrm, QBEZmsql, ZMQueryBuilder, janSQL, 
  janSQLExpression2, janSQLStrings, janSQLTokenizer, mwStringHashList, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('AllzmsqlRegister', @AllzmsqlRegister.Register);
end;

initialization
  RegisterPackage('zmsql', @Register);
end.
