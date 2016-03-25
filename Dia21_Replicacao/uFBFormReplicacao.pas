unit uFBFormReplicacao;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait,
  Vcl.StdCtrls, Data.DB, FireDAC.Comp.Client, Vcl.ExtCtrls, Vcl.ComCtrls,
  Vcl.Buttons, FireDAC.Phys.FBDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteDef, FireDAC.Phys.IBDef, FireDAC.Comp.UI, FireDAC.Phys.IB,
  FireDAC.Phys.SQLite, FireDAC.Phys.IBBase, FireDAC.Phys.FB,
  FireDAC.Comp.ScriptCommands, FireDAC.Stan.Util, FireDAC.Comp.Script;

const
  CR = #13;
type



  TFDReplicacao = class
  private
    FConn:TFDConnection;
    procedure CreateRepl_Table;
    procedure ExecSql(texto: string);
    function CreateGidPublisher(tab: string): boolean;
    function CriarGID(tab:string):boolean;
    function existsColumn(tab, coluna: string): boolean;
    public
      procedure LerColunas(aConn:TFDConnection; aTabela:string; aItems:TStrings);
      procedure LerTabelas(aConn:TFDConnection;aItems:TStrings)  ;
      procedure CriarPublisher(aConn:TFDConnection; aTabela:string);
      procedure CriarSubscriptor(aConn:TFDConnection; aTabela:string);
  end;


  TForm41 = class(TForm)
    FConnOrigem: TFDConnection;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    Label1: TLabel;
    ComboBox1: TComboBox;
    Panel1: TPanel;
    Panel2: TPanel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    FDManager1: TFDManager;
    SpeedButton3: TSpeedButton;
    Label2: TLabel;
    ComboBox2: TComboBox;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    FDPhysIBDriverLink1: TFDPhysIBDriverLink;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    ListBox1: TListBox;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    Label3: TLabel;
    ComboBox3: TComboBox;
    SpeedButton6: TSpeedButton;
    Label4: TLabel;
    ComboBox4: TComboBox;
    SpeedButton7: TSpeedButton;
    ListBox2: TListBox;
    FConnDestino: TFDConnection;
    SpeedButton8: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
    procedure SpeedButton3Click(Sender: TObject);
    procedure SpeedButton4Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SpeedButton5Click(Sender: TObject);
    procedure SpeedButton6Click(Sender: TObject);
    procedure SpeedButton7Click(Sender: TObject);
    procedure SpeedButton8Click(Sender: TObject);
  private
    { Private declarations }
    FReplicacao:TFDReplicacao;
  public
    { Public declarations }
    procedure moveTab(const value:integer);
  end;

var
  Form41: TForm41;

implementation

{$R *.dfm}

procedure TForm41.FormCreate(Sender: TObject);
var it:IFDStanConnectionDef;
    i:integer;
begin
   FReplicacao:=TFDReplicacao.create;
   ComboBox1.Items.Clear;
    for i:=0 to FDManager1.ConnectionDefs.Count-1 do
    begin
        it := FDManager1.ConnectionDefs.Items[i];
        if it.Params.values['DriverID'] = 'FB' then
        begin
          ComboBox1.Items.Add(it.Name);
          comboBox3.Items.Add(it.Name);
        end;
    end;
    comboBox1.ItemIndex := 0;
    ComboBox3.ItemIndex := 0;
    PageControl1.ActivePageIndex := 0;
end;

procedure TForm41.FormDestroy(Sender: TObject);
begin
  FReplicacao.Free;
end;

procedure TForm41.moveTab(const value: integer);
var r:integer;
begin
    r := PageControl1.ActivePageIndex + value;
    if r>=PageControl1.PageCount then
       r := PageControl1.PageCount -1;
    if r<0 then
       r := 0;
    PageControl1.ActivePageIndex := r;
end;

procedure TFDReplicacao.LerTabelas(aConn:TFDConnection;aItems:TStrings)  ;
var
  lst: TStringList;
begin
  AItems.Clear;
  lst := TStringList.Create;
  try
    AConn.GetTableNames('', '', '', lst);
    AItems.Assign(lst);
  finally
    lst.Free;
  end;
end;


procedure TFDReplicacao.CreateRepl_Table;
begin
    ExecSQL('create table Repl_Itens ' +
      '( tabela varchar(128), ' +
      '  gid varchar(38), ' +
      '  tipo char(1), ' +
      '  data date, id numeric(15,0) ' +
      ');');
    ExecSQL('alter table Repl_Itens add Session_id numeric(15,0);');
    ExecSQL('create index repl_itensID on repl_itens(id); ');
    ExecSQL('create index repl_itensData on repl_itens(data); ');
    ExecSQL('create index repl_itensgid on repl_itens(gid); ');
    ExecSQL('create index repl_itenstabela on repl_itens(tabela); ');
    ExecSQL('CREATE SEQUENCE REPL_ITENS_GEN_ID;');

    ExecSQL(
      'CREATE OR ALTER TRIGGER REPL_ITENS_ID FOR REPL_ITENS ' + CR +
      'ACTIVE BEFORE INSERT POSITION 0 ' + CR +
      'AS ' + CR +
      'begin /* Replicacao Storeware */ ' + CR +
      '  new.id = gen_id(REPL_ITENS_GEN_ID,1); ' + CR +
      '  new.data = cast(''now'' as date); ' + CR +
      'end ');
end;



function TFDReplicacao.existsColumn(tab, coluna: string): boolean;
var lst:TStringList;
begin
  lst:=TStringList.create;
  try
    FConn.GetFieldNames('','',tab,'',lst);
    result := lst.IndexOf(uppercase(coluna))>=0;
  finally
    lst.free;
  end;
end;

function TFDReplicacao.CreateGidPublisher(tab: string): boolean;
begin
  result := false;
  tab := uppercase(tab);

    if not existsColumn(tab, 'GID') then
    begin
      ExecSQL('alter table ' + tab + ' add GID varchar(38);');
      ExecSQL('create index ' + tab + 'GID on ' + tab + '(gid); ');
    end;

    ExecSQL(
      'CREATE OR ALTER TRIGGER REPL_' + tab + '_REG FOR ' + tab + ' ' + CR +
      'ACTIVE AFTER INSERT OR UPDATE OR DELETE POSITION 0 ' + CR +
      'AS ' + CR +
      'begin ' + CR +
      '  /* Replicacao Storeware */ ' + CR +
      '  if (coalesce(rdb$get_context(''USER_TRANSACTION'', ''Modulo''),''BD'')<>''PDVSYNC'') then ' + CR +
      '  begin ' + CR +
      '  in autonomous transaction do ' + CR +
      '  begin ' + CR +
      '   if (inserting) then ' + CR +
      '     insert into repl_itens ( tabela,gid,tipo) ' + CR +
      '            values(' + QuotedStr(tab) + ',new.gid,''I''); ' + CR +

      '   if (updating) then ' + CR +
      '     insert into repl_itens ( tabela,gid,tipo) ' + CR +
      '            values(' + QuotedStr(tab) + ',new.gid,''U''); ' + CR +

      '   if (deleting) then ' + CR +
      '     insert into repl_itens ( tabela,gid,tipo) ' + CR +
      '            values(' + QuotedStr(tab) + ',old.gid,''D''); ' + CR +
      '  end ' + CR +
      '  end ' + CR +

      'end ');//+
    result := true;
end;


function TFDReplicacao.CriarGID(tab: string): boolean;
begin
    if not existsColumn(tab, 'GID') then
    begin
      ExecSQL('alter table ' + tab + ' add GID varchar(38);');
      ExecSQL('create index ' + tab + 'GID on ' + tab + '(gid); ');
    end;

end;

procedure TFDReplicacao.CriarPublisher(aConn: TFDConnection; aTabela: string);
begin
    FConn := aConn;
    CreateRepl_Table; // criar a tabela de controle de eventos
    CreateGidPublisher(aTabela);

end;

procedure TFDReplicacao.CriarSubscriptor(aConn: TFDConnection; aTabela: string);
begin
    FConn := aConn;
    CriarGID(aTabela);
end;

procedure TFDReplicacao.ExecSql(texto:string);
var scp:TFDScript;
    txt:TStringList;
begin
    txt:=TStringList.create;
    try
      txt.Text := texto;
    scp:=TFDScript.Create(nil);
    try
      scp.Connection := FConn;
      scp.ExecuteScript(txt);
    finally
      scp.Free;
    end;
    finally
       txt.Free;
    end;
end;

procedure TFDReplicacao.LerColunas(aConn:TFDConnection; aTabela:string; aItems:TStrings);
var
  lst: TStringList;
begin
  if aTabela <> '' then
  begin
    lst := TStringList.create;
    try
      aConn.GetFieldNames('', '', aTabela, '', lst);
      AItems.Assign(lst);
    finally
      lst.Free;
    end;
  end;
end;

procedure TForm41.SpeedButton1Click(Sender: TObject);
begin
    moveTab(1);
end;

procedure TForm41.SpeedButton2Click(Sender: TObject);
begin
   moveTab(-1);
end;

procedure TForm41.SpeedButton3Click(Sender: TObject);
begin
  FConnOrigem.ConnectionDefName := comboBox1.Text;
  FReplicacao.LerTabelas(FConnOrigem,ComboBox2.Items);
  ComboBox2.Enabled := true;
  ComboBox2.ItemIndex := 0;
end;

procedure TForm41.SpeedButton4Click(Sender: TObject);
begin
  FReplicacao.LerColunas(FConnOrigem,ComboBox2.Text,ListBox1.Items);
  ComboBox4.Text := ComboBox2.Text;
end;

procedure TForm41.SpeedButton5Click(Sender: TObject);
begin
   // gerar
   if ComboBox2.text<>'' then
      FReplicacao.CriarPublisher(FConnOrigem,ComboBox2.text);
end;

procedure TForm41.SpeedButton6Click(Sender: TObject);
begin
  FConnDestino.ConnectionDefName := comboBox3.Text;
  FReplicacao.LerTabelas(FConnDestino,ComboBox4.Items);
  ComboBox4.Enabled := false;
end;

procedure TForm41.SpeedButton7Click(Sender: TObject);
begin
  FReplicacao.LerColunas(FConnDestino,ComboBox4.Text,ListBox2.Items);
end;

procedure TForm41.SpeedButton8Click(Sender: TObject);
begin
   if ComboBox1.Text = ComboBox3.text then
      raise exception.Create('O banco de origem e destino n�o podem ser o mesmo');

   if ComboBox4.text<>'' then
      FReplicacao.CriarSubscriptor(FConnDestino,ComboBox4.text);

end;

end.
