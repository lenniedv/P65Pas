{Unidad que agrega campos necesarios a la clase TCompilerBase, para la generación de
código con el PIC16F.}
unit GenCodBas_PIC16;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, XpresBas, XpresElementsPIC, XpresTypesPIC, CPUCore, P6502utils,
  CompBase, ParserDirec, Globales, CompOperands, MisUtils, LCLType, LCLProc;
const
  STACK_SIZE = 8;      //tamaño de pila para subrutinas en el PIC
  MAX_REGS_AUX_BYTE = 6;   //cantidad máxima de registros a usar
  MAX_REGS_AUX_BIT = 4;    //cantidad máxima de registros bit a usar
  MAX_REGS_STACK_BYTE = 8; //cantidad máxima de registros a usar en la pila
  MAX_REGS_STACK_BIT = 4;  //cantidad máxima de registros a usar en la pila

type
  {Información sobre los saltos con la instrucción kIF_TRUE}
  TIfInfo = record
    igoto  : integer;   //Address where is GOTO
  end;
  { TGenCodBas }
  TGenCodBas = class(TParserDirecBase)
  private
    linRep : string;   //línea para generar de reporte
    posFlash: Integer;
    procedure ClearDeviceError;
    procedure CompileProcBody(fun: TxpEleFun);
    function DeviceError: string;
    function GenCodBasCallCurrRAM(): integer;
    procedure GenCodLoadToA(Op: TOperand);
    procedure GenCodLoadToX(Op: TOperand);
    procedure GenCodLoadToY(Op: TOperand);
    procedure GenCodPicReqStartCodeGen;
    procedure GenCodPicReqStopCodeGen;
    procedure ProcByteUsed(offs: word; regPtr: TCPURamCellPtr);
    function ReturnAttribIn(typ: TxpEleType; const Op: TOperand; offs: integer
      ): boolean;
    procedure SetSharedUnused;
    procedure SetSharedUsed;
    procedure word_ClearItems(const OpPtr: pointer);
  protected
    //Work register (RT)
    A      : TPicRegister;     //Registro Interno.
    //System variables used as registers
    H   : TxpEleVar;  //To load the high byte of words.
    E      : TxpEleVar;  //To load the high word of dwords.
    U      : TxpEleVar;  //To load the high word of dwords.
    IX     : TxpEleVar;  //To index operands
    procedure PutLabel(lbl: string); inline;
    procedure PutTopComm(cmt: string; replace: boolean = true); inline;
    procedure PutComm(cmt: string); inline;
    procedure PutFwdComm(cmt: string); inline;
    function ReportRAMusage: string;
    function ValidateByteRange(n: integer): boolean;
    function ValidateWordRange(n: integer): boolean;
    function ValidateDWordRange(n: Int64): boolean;
  protected
    procedure ResetRAM;
    procedure StartCodeSub(fun: TxpEleFun);
    procedure EndCodeSub;
    procedure FunctCall(fun: TxpEleFunBase; out AddrUndef: boolean);
    procedure FunctParam(fun: TxpEleFunBase);
    procedure GenerateROBdetComment;
    procedure GenerateROUdetComment;
  protected  //Variables temporales
    {Estas variables temporales, se crean como forma de acceder a campos de una variable
     como varbyte.bit o varword.low. Se almacenan en "varFields" y se eliminan al final}
    varFields: TxpEleVars;  //Contenedor
    function CreateTmpVar(nam: string; eleTyp: TxpEleType): TxpEleVar;
    {Estas variables se usan para operaciones en el generador de código.
     No se almacenan en "varFields". Así se definió al principio, pero podrían también
     almacenarse, asumiendo que no importe crear variables dinámicas.}
    function NewTmpVarWord(rL, rH: TPicRegister): TxpEleVar;
  protected  //Rutinas de gestión de memoria para registros
    function GetAuxRegisterByte: TPicRegister;
  protected  //Memory manage routines for variables
    procedure AssignRAM(out addr: word; regName: string; shared: boolean);  //Asigna a una dirección física
    function CreateRegisterByte(RegType: TPicRegType): TPicRegister;
    procedure WriteVaLueToRAM(add: word; typ: TxpEleType; const value: TConsValue);
    procedure CreateVarInRAM(xVar: TxpEleVar; shared: boolean = false);
    procedure CreateValueInCode(typ: TxpEleType; const value: TConsValue; out startAddr: integer);
  protected  //Métodos para fijar el resultado
    //Métodos básicos
    procedure SetResultNull;
    procedure SetResultConst(typ: TxpEleType);
    procedure SetResultVariab(rVar: TxpEleVar; logic: TLogicType = logNormal);
    procedure SetResultExpres(typ: TxpEleType; ChkRTState: boolean = true);
    procedure SetResultVarRef(rVarBase: TxpEleVar; xtyp: TxpEleType);
    procedure SetResultVarConRef(rVarBase: TxpEleVar; consAddr: integer; xtyp: TxpEleType);
    procedure SetResultExpRef(typ: TxpEleType; ChkRTState: boolean = true);
    //Fija el resultado de ROB como constante.
    procedure SetROBResultConst_bool(valBool: Boolean);
    procedure SetROBResultConst_byte(valByte: integer);
    procedure SetROBResultConst_char(valByte: integer);
    procedure SetROBResultConst_word(valWord: integer);
    //Fija el resultado de ROB como variable
    procedure SetROBResultVariab(rVar: TxpEleVar; logic: TLogicType = logNormal);
    //Fija el resultado de ROB como expresión
    {El parámetro "Opt", es más que nada para asegurar que solo se use con Operaciones
     binarias.}
    procedure SetROBResultExpres_bool(Opt: TxpOperation; logic: TLogicType = logNormal);
    procedure SetROBResultExpres_byte(Opt: TxpOperation);
    procedure SetROBResultExpres_char(Opt: TxpOperation);
    procedure SetROBResultExpres_word(Opt: TxpOperation);
    //Fija el resultado de ROU
    procedure SetROUResultConst_bool(valBool: boolean);
    procedure SetROUResultConst_byte(valByte: integer);
    procedure SetROUResultVariab(rVar: TxpEleVar; logic: TLogicType = logNormal);
    procedure SetROUResultVarRef(rVarBase: TxpEleVar; xtyp: TxpEleType);
    procedure SetROUResultExpres_bool(logic: TLogicType);
    procedure SetROUResultExpres_byte;
    procedure SetROUResultExpRef(typ: TxpEleType);
    //Adicionales
    procedure ChangeResultCharToByte;
  protected  //Instrucciones
    function _PC: word;
    function _CLOCK: integer;
    procedure _LABEL_post(igot: integer);
    procedure _LABEL_pre(out curAddr: integer);
    //Instrucciones simples
    procedure _ADCi(const k: word);  //immidiate
    procedure _ADC(const addr: integer);  //Absolute/Zeropage
    procedure _ANDi(const k: word);
    procedure _AND(const addr: integer);
    procedure _ASL(const f: word);
    procedure _ASLa;
    procedure _LSR(const f: word);
    procedure _LSRa;
    procedure _JMP(const ad: word);
    procedure _JMP_post(out igot: integer);
    procedure _JSR(const ad: word);
    procedure _BEQ(const ad: ShortInt);
    procedure _BEQ_post(out ibranch: integer);
    procedure _BNE(const ad: ShortInt);
    procedure _BNE_pre(curAddr: integer);
    procedure _BNE_post(out ibranch: integer);
    procedure _BCC(const ad: ShortInt);
    procedure _BCC_post(out ibranch: integer);
    procedure _BCS(const ad: ShortInt);
    procedure _BCS_post(out ibranch: integer);

    procedure _BPL(const ad: ShortInt);
    procedure _BPL_pre(curAddr: integer);
    procedure _BPL_post(out ibranch: integer);

    procedure _CLC;
    procedure _CMPi(const k: word);  //immidiate
    procedure _CMP(const addr: integer);  //Absolute/Zeropage
    procedure _DEX;
    procedure _DEY;
    procedure _DEC(const addr: integer);
    procedure _EORi(const k: word);
    procedure _EOR(const addr: integer);
    procedure _INC(const addr: integer);
    procedure _INX;
    procedure _INY;
    procedure _LDAi(const k: word);
    procedure _LDA(const addr: integer);
    procedure _LDXi(const k: word);
    procedure _LDX(const addr: integer);
    procedure _LDYi(const k: word);
    procedure _LDY(const addr: integer);
    procedure _NOP;
    procedure _ORAi(const k: word);
    procedure _ORA(const addr: integer);
    procedure _PHA; inline;
    procedure _PHP; inline;
    procedure _PLA; inline;
    procedure _PLP; inline;
    procedure _ROL(const addr: integer);
    procedure _RORa;  //Acumulator
    procedure _ROR(const addr: integer);  //Absolute/Zeropage
    procedure _RTS;
    procedure _RTI;
    procedure _SEC;
    procedure _SED;
    procedure _SBCi(const k: word);   //SBC Immediate
    procedure _SBC(const addr: integer);  //SBC Absolute/Zeropage
    procedure _STA(addr: integer);          //STX Absolute/Zeropage
    procedure _STX(const addr: integer);  //STX Absolute/Zeropage
    procedure _STY(const addr: integer);  //STY Absolute/Zeropage
    procedure _TAX;
    procedure _TAY;
    procedure _TYA;
    procedure _TXA;
    procedure IF_TRUE(OpRes: TOperandPtr; out info: TIfInfo);
    procedure IF_FALSE(OpRes: TOperandPtr; out info: TIfInfo);
    procedure IF_END(const info: TIfInfo);
  protected  //Funciones de tipos
    //////////////// Tipo Byte /////////////
    procedure byte_LoadToRT(const OpPtr: pointer);
    procedure byte_DefineRegisters;
    procedure byte_SaveToStk;
    //////////////// Tipo Word /////////////
    procedure word_LoadToRT(const OpPtr: pointer);
    procedure word_DefineRegisters;
    procedure word_SaveToStk;
    procedure word_Low(const OpPtr: pointer);
    procedure word_High(const OpPtr: pointer);
  public     //Acceso a campos del CPU
    function PICName: string; override;
    function RAMmax: integer; override;
  public     //Inicialización
    pic        : TP6502;       //Objeto PIC de la serie 16.
    procedure StartRegs;
    function CompilerName: string; override;
    procedure CompileIF;
    procedure CompileWHILE;
    procedure CompileREPEAT;
    procedure CompileFOR;
    constructor Create; override;
    destructor Destroy; override;
  end;

  procedure SetLanguage;
implementation
var
  TXT_SAVE_W, TXT_SAVE_Z, TXT_SAVE_H, MSG_NO_ENOU_RAM, MSG_VER_CMP_EXP,
  MSG_STACK_OVERF, MSG_NOT_IMPLEM, ER_VARIAB_EXPEC, ER_ONL_BYT_WORD,
  ER_ASIG_EXPECT
  : string;

procedure SetLanguage;
begin
  ParserDirec.SetLanguage;
  {$I ..\language\tra_GenCodBas.pas}
end;
{ TGenCodPic }
procedure TGenCodBas.ProcByteUsed(offs: word; regPtr: TCPURamCellPtr);
begin
  linRep := linRep + regPtr^.name +
            ' DB ' + '$' + IntToHex(offs, 3) + LineEnding;
end;
function TGenCodBas.ReturnAttribIn(typ: TxpEleType; const Op: TOperand; offs: integer): boolean;
{Return a temp variable at the specified address.}
var
  tmpVar: TxpEleVar;
begin
  if Op.Sto = stVariab then begin
    tmpVar := CreateTmpVar('?', typ);   //Create temporal variable
    tmpVar.addr := Op.addr + offs;  //Set Address
    res.SetAsVariab(tmpVar);
    exit(true);
  end else begin
    GenError('Cannot access to field of this expression.');
    exit(false);
  end;
end;
procedure TGenCodBas.SetSharedUnused;
begin
  pic.SetSharedUnused;
end;
procedure TGenCodBas.SetSharedUsed;
begin
  pic.SetSharedUsed;
end;
procedure TGenCodBas.word_ClearItems(const OpPtr: pointer);
begin

end;
procedure TGenCodBas.PutLabel(lbl: string);
{Agrega uan etiqueta antes de la instrucción. Se recomienda incluir solo el nombre de
la etiqueta, sin ":", ni comentarios, porque este campo se usará para desensamblar.}
begin
  pic.addTopLabel(lbl);  //agrega línea al código ensmblador
end;
procedure TGenCodBas.PutTopComm(cmt: string; replace: boolean = true);
//Agrega comentario al inicio de la posición de memoria
begin
  pic.addTopComm(cmt, replace);  //agrega línea al código ensmblador
end;
procedure TGenCodBas.PutComm(cmt: string);
//Agrega comentario lateral al código. Se llama después de poner la instrucción.
begin
  pic.addSideComm(cmt, true);  //agrega línea al código ensmblador
end;
procedure TGenCodBas.PutFwdComm(cmt: string);
//Agrega comentario lateral al código. Se llama antes de poner la instrucción.
begin
  pic.addSideComm(cmt, false);  //agrega línea al código ensmblador
end;
function TGenCodBas.ReportRAMusage: string;
{Genera un reporte de uso de la memoria RAM}
begin
  linRep := '';
  pic.ExploreUsed(@ProcByteUsed);
  Result := linRep;
end;
function TGenCodBas.ValidateByteRange(n: integer): boolean;
//Verifica que un valor entero, se pueda convertir a byte. Si no, devuelve FALSE.
begin
  if (n>=0) and (n<256) then
     exit(true)
  else begin
    GenError('Numeric value exceeds a byte range.');
    exit(false);
  end;
end;
function TGenCodBas.ValidateWordRange(n: integer): boolean;
//Verifica que un valor entero, se pueda convertir a byte. Si no, devuelve FALSE.
begin
  if (n>=0) and (n<65536) then
     exit(true)
  else begin
    GenError('Numeric value exceeds a word range.');
    exit(false);
  end;
end;
function TGenCodBas.ValidateDWordRange(n: Int64): boolean;
begin
  if (n>=0) and (n<$100000000) then
     exit(true)
  else begin
    GenError('Numeric value exceeds a dword range.');
    exit(false);
  end;
end;
procedure TGenCodBas.GenerateROBdetComment;
{Genera un comentario detallado en el código ASM. Válido solo para
Rutinas de Operación binaria, que es cuando está definido operType, p1, y p2.}
begin
  if incDetComm then begin
    PutTopComm('      ;Oper(' + p1^.StoOpChr + ':' + p1^.Typ.name + ',' +
                                p2^.StoOpChr + ':' + p2^.Typ.name + ')', false);
  end;
end;
procedure TGenCodBas.GenerateROUdetComment;
{Genera un comentario detallado en el código ASM. Válido solo para
Rutinas de Operación unaria, que es cuando está definido operType, y p1.}
begin
  if incDetComm then begin
    PutTopComm('      ;Oper(' + p1^.StoOpChr + ':' + p1^.Typ.name + ')', false);
  end;
end;
//Rutinas de gestión de memoria de bajo nivel
function TGenCodBas.CreateTmpVar(nam: string; eleTyp: TxpEleType): TxpEleVar;
{Crea una variable temporal agregándola al contenedor varFields, que es
limpiado al iniciar la compilación. Notar que la variable temporal creada, no tiene
RAM asiganda.}
var
  tmpVar: TxpEleVar;
begin
  tmpVar:= TxpEleVar.Create;
  tmpVar.name := nam;
  tmpVar.typ := eleTyp;
  tmpVar.adicPar.hasAdic := decNone;
  tmpVar.adicPar.hasInit := false;
  tmpVar.IsTmp := true;   //Para que se pueda luego identificar.
  varFields.Add(tmpVar);  //Agrega
  Result := tmpVar;
end;
function TGenCodBas.NewTmpVarWord(rL, rH: TPicRegister): TxpEleVar;
{Crea una variable temporal Word, con las direcciones de los registros indicados, y
devuelve la referencia. La variable se crea sin asignación de memoria.}
begin
  Result := TxpEleVar.Create;
  Result.typ := typWord;
  Result.addr := rL.addr;  //asigna direcciones
end;
//Variables temporales
//Rutinas de Gestión de memoria
function TGenCodBas.GetAuxRegisterByte: TPicRegister;
{Devuelve la dirección de un registro de trabajo libre. Si no encuentra alguno, lo crea.
 Si hay algún error, llama a GenError() y devuelve NIL}
var
  reg: TPicRegister;
  regName: String;
begin
  //Busca en los registros creados
  {Notar que no se incluye en la búsqueda a los registros de trabajo. Esto es por un
  tema de orden, si bien podría ser factible, permitir usar algún registro de trabajo no
  usado, como registro auxiliar.}
  for reg in listRegAux do begin
    //Se supone que todos los registros auxiliares, estarán siempre asignados
    if (reg.typ = prtAuxReg) and not reg.used then begin
      reg.used := true;
      exit(reg);
    end;
  end;
  //No encontró ninguno libre, crea uno en memoria
  reg := CreateRegisterByte(prtAuxReg);
  if reg = nil then exit(nil);  //hubo error
  regName := 'aux'+IntToSTr(listRegAux.Count);
  AssignRAM(reg.addr, regName, false);   //Asigna memoria. Puede generar error.
  if HayError then exit;
  reg.assigned := true;  //Tiene memoria asiganda
  reg.used := true;  //marca como usado
  Result := reg;   //Devuelve la referencia
end;
//Memory manage routines for variables
function TGenCodBas.CreateRegisterByte(RegType: TPicRegType): TPicRegister;
{Crea una nueva entrada para registro en listRegAux[], pero no le asigna memoria.
 Si encuentra error, devuelve NIL. Este debería ser el único punto de entrada
para agregar un nuevo registro a listRegAux.}
var
  reg: TPicRegister;
begin
  //Agrega un nuevo objeto TPicRegister a la lista;
  reg := TPicRegister.Create;  //Crea objeto
  reg.typ := RegType;    //asigna tipo
  listRegAux.Add(reg);   //agrega a lista
  if listRegAux.Count > MAX_REGS_AUX_BYTE then begin
    //Se asume que se desbordó la memoria evaluando a alguna expresión
    GenError(MSG_VER_CMP_EXP);
    exit(nil);
  end;
  Result := reg;   //devuelve referencia
end;
procedure TGenCodBas.AssignRAM(out addr: word; regName: string; shared: boolean);
//Asocia a una dirección física de la memoria para ser usada como variable.
//Si encuentra error, devuelve el mensaje de error en "MsjError"
begin
  {Esta dirección física, la mantendrá este registro hasta el final de la compilación
  y en teoría, hasta el final de la ejecución de programa en el PIC.}
  if not pic.GetFreeByte(addr) then begin
    GenError(MSG_NO_ENOU_RAM);
    exit;
  end;
  pic.ram[addr].used := ruData;
  if shared then begin
    pic.ram[addr].shared := true;  //Marca como compartido
  end;
  inc(pic.iRam);  //Pasa al siguiente byte.
  pic.SetNameRAM(addr, regName);  //pone nombre a registro
end;
procedure TGenCodBas.WriteVaLueToRAM(add: word; typ: TxpEleType;
  const value: TConsValue);
//Write a constant value, of any type, to a some position in the RAM.
var
  i: Integer;
begin
  if typ = typByte then begin
    pic.ram[add].value := value.ValInt and $ff;
  end else if typ = typChar then begin
    pic.ram[add].value := value.ValInt and $ff;
  end else if typ = typBool then begin
    if value.ValBool then pic.ram[add].value := 1
    else pic.ram[add].value := 0;
  end else if typ = typWord then begin
    pic.ram[add].value := value.ValInt and $ff;
    pic.ram[add+1].value := (value.ValInt >> 8) and $ff;
  end else if typ.catType = tctArray then begin
    //Composite type
    for i:=0 to high(value.items) do begin
      WriteVaLueToRAM(add, typ.itmType, value.items[i]);  //Recursion
      inc(add, typ.itmType.size);
    end;
  end else if typ.catType = tctPointer then begin
    //Pointer are as words
    pic.ram[add].value := value.ValInt and $ff;
    pic.ram[add+1].value := (value.ValInt >> 8) and $ff;
  end else begin
    GenError(MSG_NOT_IMPLEM);
  end;
end;
procedure TGenCodBas.CreateVarInRAM(xVar: TxpEleVar; shared: boolean = false);
{Rutina para asignar espacio físico a una variable. La variable, es creada en memoria
en la posición actual que indica iRam
con los parámetros que posea en ese momento. Si está definida como ABSOLUTE, se le
creará en la posicón indicada. }
var
  varName: String;
  nbytes: integer;
  typ: TxpEleType;
  startAdd: word;
  i: integer;
  outOfProgram: Boolean;
begin
  varName := xVar.name;
  typ := xVar.typ;
  //Find the memory address where to place the variable
//  pic.freeStart := pic.iRam;    //Start in the current RAM
  pic.freeStart := self.GeneralORG;  //Find at the current program block.
  nbytes := typ.size;
  if xVar.adicPar.hasAdic = decAbsol then begin
    startAdd := xVar.adicPar.absAddr;
  end else begin
    if not pic.GetFreeBytes(nbytes, startAdd) then begin
      GenError(MSG_NO_ENOU_RAM);
      exit;
    end;
  end;
  xVar.addr:=startAdd;  //Set address
//  if pic.dataAddr1=-1 then begin
//    //The variable has been mapped in the current RAM
//    inc(pic.iRam, nbytes);  //Move pointer.
//  end;
  //Detect if variable location is out of the code block.
  if FirstPass then begin
    //In first pass, variables are located in a default position, so it's not secure
    //to validate.
    outOfProgram := false;  //Only checks for down
  end else begin
    //We assume absolute variables are out of code to protect from initialization
    {The problem is in the *.PRG format we use for output, doesn't allow to specify
    separates blocks of memory to fill. For example if we have specified an address like
    $FFFF, and the program start at $0000, all the RAM must be included in *.PRG.}
    outOfProgram := (xVar.adicPar.hasAdic = decAbsol) or
                    (pic.dataAddr1<>-1);  //This means the variable has been placed in the primary data address.
  end;
  //Mark as used.
  if outOfProgram then begin
    //Out of the program block, mark as "ruAbsData", in order to not be considered
    //to generate the PRG file.
    for i:=startAdd to startAdd+nbytes-1 do begin
      pic.ram[i].used := ruAbsData;
      if shared then begin
        pic.ram[i].shared := true;  //Marca como compartido
      end;
    end;
  end else begin
    //In the program block
    for i:=startAdd to startAdd+nbytes-1 do begin
      pic.ram[i].used := ruData;
      if shared then begin
        pic.ram[i].shared := true;  //Marca como compartido
      end;
    end;
  end;
  //Set name to that position
  pic.SetNameRAM(startAdd, xVar.name);   //Name at the first byte
  //Set initial value.
  if xVar.adicPar.hasInit then begin
    if outOfProgram then begin  //Only allowed in the program block
      GenError('Cannot initialize absolute variable "%s" in this location.', [varName]);
    end;
    //Here, we need to know the type
    WriteVaLueToRAM(startAdd, typ, xVar.adicPar.iniVal);
    if HayError then  exit;
  end;
  if typ.OnGlobalDef<>nil then typ.OnGlobalDef(varName, '');
end;
procedure TGenCodBas.CreateValueInCode(typ: TxpEleType;
  const value: TConsValue; out startAddr: integer);
{Write a constant value in RAM, in the current code section, adding the correspondent JMP
instruction. Returns in "startAddr", the address where start the value.}
var
  j1, i: integer;
  nbytes: SmallInt;
begin
  nbytes := typ.size;
  _JMP_post(j1);   //Salto hasta después del espacio de variables
  startAddr := pic.iRam;
  WriteVaLueToRAM(pic.iRam, typ, value);
  for i:=pic.iRam to pic.iRam+nbytes-1 do begin
    pic.ram[i].used := ruData;
  end;
  inc(pic.iRam, nBytes);  //Move pointer.
_LABEL_post(j1);   //Termina de codificar el salto
end;
//Métodos para fijar el resultado
procedure TGenCodBas.SetResultNull;
{Fija el resultado como NULL.}
begin
  res.SetAsNull;
  BooleanFromC:=0;   //para limpiar el estado
  BooleanFromZ:=0;
  AcumStatInZ := true;
  res.logic := logNormal;
end;
procedure TGenCodBas.SetResultConst(typ: TxpEleType);
{Fija los parámetros del resultado de una subexpresion. Este método se debe ejcutar,
siempre antes de evaluar cada subexpresión.}
begin
  res.SetAsConst(typ);
  BooleanFromC:=0;   //para limpiar el estado
  BooleanFromZ:=0;
  AcumStatInZ := true;
  {Se asume que no se necesita invertir la lógica, en una constante (booleana o bit), ya
  que en este caso, tenemos control pleno de su valor}
  res.logic := logNormal;
end;
procedure TGenCodBas.SetResultVariab(rVar: TxpEleVar; logic: TLogicType);
{Fija los parámetros del resultado de una subexpresion. Este método se debe ejcutar,
siempre antes de evaluar cada subexpresión.}
begin
  res.SetAsVariab(rVar);
  BooleanFromC:=0;   //para limpiar el estado
  BooleanFromZ:=0;
  AcumStatInZ := true;
  //"Inverted" solo tiene sentido, para los tipos bit y boolean
  res.logic := logic;
end;
procedure TGenCodBas.SetResultExpres(typ: TxpEleType; ChkRTState: boolean = true);
{Fija los parámetros del resultado de una subexpresion (en "res"). Este método se debe
ejecutar, siempre antes de evaluar cada subexpresión. Más exactamente, antes de generar
código para ña subexpresión, porque esta rutina puede generar su propio código.}
begin
  if ChkRTState then begin
    //Se pide verificar si se están suando los RT, para salvarlos en la pila.
    if RTstate<>nil then begin
      //Si se usan RT en la operación anterior. Hay que salvar en pila
      RTstate.SaveToStk;  //Se guardan por tipo
    end else begin
      //No se usan. Están libres
    end;
  end;
  //Fija como expresión
  res.SetAsExpres(typ);
  //Limpia el estado. Esto es útil que se haga antes de generar el código para una operación
  BooleanFromC:=0;
  BooleanFromZ:=0;
  AcumStatInZ := true;
  //Actualiza el estado de los registros de trabajo.
  RTstate := typ;
end;
procedure TGenCodBas.SetResultVarRef(rVarBase: TxpEleVar; xtyp: TxpEleType);
begin
  res.SetAsVarRef(rVarBase, xtyp);
  BooleanFromC:=0;   //para limpiar el estado
  BooleanFromZ:=0;
  AcumStatInZ := true;
  //No se usa "Inverted" en este almacenamiento
  res.logic := logNormal;
end;
procedure TGenCodBas.SetResultVarConRef(rVarBase: TxpEleVar; consAddr: integer;
  xtyp: TxpEleType);
begin
  res.SetAsVarConRef(rVarBase, consAddr, xtyp);
  BooleanFromC:=0;   //para limpiar el estado
  BooleanFromZ:=0;
  AcumStatInZ := true;
  //No se usa "Inverted" en este almacenamiento
  res.logic := logNormal;
end;
procedure TGenCodBas.SetResultExpRef(typ: TxpEleType; ChkRTState: boolean = true);
begin
  if ChkRTState then begin
    //Se pide verificar si se están suando los RT, para salvarlos en la pila.
    if RTstate<>nil then begin
      //Si se usan RT en la operación anterior. Hay que salvar en pila
      RTstate.SaveToStk;  //Se guardan por tipo
    end else begin
      //No se usan. Están libres
    end;
  end;
  res.SetAsExpRef(typ);
  BooleanFromC:=0;   //para limpiar el estado
  BooleanFromZ:=0;
  AcumStatInZ := true;
  //No se usa "Inverted" en este almacenamiento
  res.logic := logNormal;
end;
//Fija el resultado de ROP como constante
procedure TGenCodBas.SetROBResultConst_bool(valBool: Boolean);
begin
  GenerateROBdetComment;
  SetResultConst(typBool);
  res.valBool := valBool;
end;
procedure TGenCodBas.SetROBResultConst_byte(valByte: integer);
begin
  GenerateROBdetComment;
  if not ValidateByteRange(valByte) then
    exit;  //Error de rango
  SetResultConst(typByte);
  res.valInt := valByte;
end;
procedure TGenCodBas.SetROBResultConst_char(valByte: integer);
begin
  GenerateROBdetComment;
  SetResultConst(typChar);
  res.valInt := valByte;
end;
procedure TGenCodBas.SetROBResultConst_word(valWord: integer);
begin
  GenerateROBdetComment;
  if not ValidateWordRange(valWord) then
    exit;  //Error de rango
  SetResultConst(typWord);
  res.valInt := valWord;
end;
//Fija el resultado de ROP como variable
procedure TGenCodBas.SetROBResultVariab(rVar: TxpEleVar; logic: TLogicType);
begin
  GenerateROBdetComment;
  SetResultVariab(rVar, logic);
end;
//Fija el resultado de ROP como expresión
procedure TGenCodBas.SetROBResultExpres_bool(Opt: TxpOperation;
  logic: TLogicType);
{Define el resultado como una expresión de tipo Boolean, y se asegura de reservar el
registro Z, para devolver la salida. Debe llamarse cuando se tienen los operandos de
la oepración en p1^y p2^, porque toma información de allí.}
begin
  GenerateROBdetComment;
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) or (p2^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpres(typBool, false);  //actualiza "RTstate"
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpres(typBool);  //actualiza "RTstate"
  end;
  //Fija la lógica
  res.logic := logic;
end;
procedure TGenCodBas.SetROBResultExpres_byte(Opt: TxpOperation);
{Define el resultado como una expresión de tipo Byte, y se asegura de reservar el
registro A, para devolver la salida. Debe llamarse cuando se tienen los operandos de
la oepración en p1^y p2^, porque toma información de allí.}
begin
  GenerateROBdetComment;
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) or (p2^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpres(typByte, false);  //actualiza "RTstate"
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpres(typByte);  //actualiza "RTstate"
  end;
end;
procedure TGenCodBas.SetROBResultExpres_char(Opt: TxpOperation);
{Define el resultado como una expresión de tipo Char, y se asegura de reservar el
registro A, para devolver la salida. Debe llamarse cuando se tienen los operandos de
la oepración en p1^y p2^, porque toma información de allí.}
begin
  GenerateROBdetComment;
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) or (p2^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpres(typChar, false);  //actualiza "RTstate"
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpres(typChar);  //actualiza "RTstate"
  end;
end;
procedure TGenCodBas.SetROBResultExpres_word(Opt: TxpOperation);
{Define el resultado como una expresión de tipo Word, y se asegura de reservar los
registros H,A, para devolver la salida.}
begin
  GenerateROBdetComment;
  typWord.DefineRegister;  //
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) or (p2^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpres(typWord, false);
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpres(typWord);
  end;
end;
//Fija el resultado de ROU
procedure TGenCodBas.SetROUResultConst_bool(valBool: boolean);
begin
  GenerateROUdetComment;
  //if not ValidateBoolRange(valByte) then
  //  exit;  //Error de rango
  SetResultConst(typBool);
  res.valBool := valBool;
end;
procedure TGenCodBas.SetROUResultConst_byte(valByte: integer);
begin
  GenerateROUdetComment;
  if not ValidateByteRange(valByte) then
    exit;  //Error de rango
  SetResultConst(typByte);
  res.valInt := valByte;
end;
procedure TGenCodBas.SetROUResultVariab(rVar: TxpEleVar; logic: TLogicType);
begin
  GenerateROUdetComment;
  SetResultVariab(rVar, logic);
end;
procedure TGenCodBas.SetROUResultVarRef(rVarBase: TxpEleVar; xtyp: TxpEleType);
{Fija el resultado como una referencia de tipo stVarRef}
begin
  GenerateROUdetComment;
  SetResultVarRef(rVarBase, xtyp);
end;
procedure TGenCodBas.SetROUResultExpres_bool(logic: TLogicType);
begin
  GenerateROUdetComment;
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpres(typBool, false);  //actualiza "RTstate"
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpres(typBool);  //actualiza "RTstate"
  end;
  //Fija la lógica
  res.logic := logic;
end;
procedure TGenCodBas.SetROUResultExpres_byte;
{Define el resultado como una expresión de tipo Byte, y se asegura de reservar el
registro A, para devolver la salida. Se debe usar solo para operaciones unarias.}
begin
  GenerateROUdetComment;
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpres(typByte, false);  //actualiza "RTstate"
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpres(typByte);  //actualiza "RTstate"
  end;
end;
procedure TGenCodBas.SetROUResultExpRef(typ: TxpEleType);
{Define el resultado como una expresión stExpRef, protegiendo los RT si es necesario.
Se debe usar solo para operaciones unarias.}
begin
  GenerateROUdetComment;
  //Se van a usar los RT. Verificar si los RT están ocupadoa
  if (p1^.Sto = stExpres) then begin
    //Alguno de los operandos de la operación actual, está usando algún RT
    SetResultExpRef(typ, false);  //actualiza "RTstate"
  end else begin
    {Los RT no están siendo usados, por la operación actual.
     Pero pueden estar ocupados por la operación anterior (Ver doc. técnica).}
    SetResultExpRef(typ);  //actualiza "RTstate"
  end;
end;
//Adicionales
procedure TGenCodBas.ChangeResultCharToByte;
begin

end;
//Rutinas que facilitan la codifición de instrucciones
function TGenCodBas._PC: word; inline;
{Devuelve la dirección actual en Flash}
begin
  Result := pic.iRam;
end;
function TGenCodBas._CLOCK: integer; inline;
{Devuelve la frecuencia de reloj del PIC}
begin
  Result := pic.frequen;
end;
procedure TGenCodBas._LABEL_post(igot: integer);
{Finish a previous JMP_lbl, BNE_post, BEQ_post, or BCC_post instruction.}
begin
  if pic.ram[igot].value = 0 then begin
    //Es salto absoluto
    pic.ram[igot].value   := lo(_PC);
    pic.ram[igot+1].value := hi(_PC);
  end else begin
    //Es salto relativo
    if _PC > igot then begin
      //Salto hacia adelante
      pic.ram[igot].value := _PC - igot-1;
    end else begin
      //Salto hacia atrás
      pic.ram[igot].value := 256 + (_PC - igot);
    end;
  end;
end;
procedure TGenCodBas._LABEL_pre(out curAddr: integer);
{Set a label for a later jump BNE_pre, BEQ_pre or BCC_pre instruction.}
begin
  curAddr := pic.iRam;
end;
//Instrucciones simples
procedure TGenCodBas._ADCi(const k: word);
begin
  pic.codAsm(i_ADC, aImmediat, k);
end;
procedure TGenCodBas._ADC(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_ADC, aZeroPage, addr);
  end else begin
    pic.codAsm(i_ADC, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._ANDi(const k: word);
begin
  pic.codAsm(i_AND, aImmediat, k);
end;
procedure TGenCodBas._AND(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_AND, aZeroPage, addr);
  end else begin
    pic.codAsm(i_AND, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._ASL(const f: word);  //ASL Absolute/Zeropage
begin
  if f<256 then begin
    pic.codAsm(i_ASL, aZeroPage, f);
  end else begin
    pic.codAsm(i_ASL, aAbsolute, f);
  end;
end;
procedure TGenCodBas._ASLa;
begin
  pic.codAsm(i_ASL, aAcumulat, 0);
end;
procedure TGenCodBas._LSR(const f: word);  //LSR Absolute/Zeropage
begin
  if f<256 then begin
    pic.codAsm(i_LSR, aZeroPage, f);
  end else begin
    pic.codAsm(i_LSR, aAbsolute, f);
  end;
end;
procedure TGenCodBas._LSRa;
begin
  pic.codAsm(i_LSR, aAcumulat, 0);
end;
procedure TGenCodBas._JMP(const ad: word);
begin
  pic.codAsm(i_JMP, aAbsolute, ad);  //pone salto indefinido
end;
procedure TGenCodBas._JMP_post(out igot: integer);
{Escribe una instrucción GOTO, pero sin precisar el destino aún. Devuelve la dirección
 donde se escribe el GOTO, para poder completarla posteriormente.
}
begin
  igot := pic.iRam+1;  //guarda posición de instrucción de salto
  pic.codAsm(i_JMP, aAbsolute, 0);  //1 en Offset indica que se completará con salto absoluto
end;
procedure TGenCodBas._JSR(const ad: word);
begin
  pic.codAsm(i_JSR, aAbsolute, ad);  //1 en Offset indica que se completará con salto absoluto
end;
procedure TGenCodBas._BEQ(const ad: ShortInt);
begin
  if ad>=0 then begin
    pic.codAsm(i_BEQ, aRelative, ad);
  end else begin
    pic.codAsm(i_BEQ, aRelative, 256+ad);
  end;
end;
procedure TGenCodBas._BEQ_post(out ibranch: integer);
begin
  ibranch := pic.iRam+1;  //guarda posición del offset de salto
  pic.codAsm(i_BEQ, aRelative, 1);  //1 en Offset indica que se completará con salto relativo
end;
procedure TGenCodBas._BNE(const ad: ShortInt);
begin
  if ad>=0 then begin
    pic.codAsm(i_BNE, aRelative, ad);
  end else begin
    pic.codAsm(i_BNE, aRelative, 256+ad);
  end;
end;
procedure TGenCodBas._BNE_post(out ibranch: integer);
begin
  ibranch := pic.iRam+1;  //guarda posición del offset de salto
  pic.codAsm(i_BNE, aRelative, 1);  //1 en Offset indica que se completará con salto relativo
end;
procedure TGenCodBas._BNE_pre(curAddr: integer);
begin
  pic.codAsm(i_BNE, aRelative, (curAddr - pic.iRam-2) and $ff);
end;
procedure TGenCodBas._BCC(const ad: ShortInt);
begin
  if ad>=0 then begin
    pic.codAsm(i_BCC, aRelative, ad);
  end else begin
    pic.codAsm(i_BCC, aRelative, 256+ad);
  end;
end;
procedure TGenCodBas._BCC_post(out ibranch: integer);
begin
  ibranch := pic.iRam+1;  //guarda posición del offset de salto
  pic.codAsm(i_BCC, aRelative, 1);  //1 en Offset indica que se completará con salto relativo
end;
procedure TGenCodBas._BCS(const ad: ShortInt);
begin
  if ad>=0 then begin
    pic.codAsm(i_BCS, aRelative, ad);
  end else begin
    pic.codAsm(i_BCS, aRelative, 256+ad);
  end;
end;
procedure TGenCodBas._BCS_post(out ibranch: integer);
begin
  ibranch := pic.iRam+1;  //guarda posición del offset de salto
  pic.codAsm(i_BCS, aRelative, 1);  //1 en Offset indica que se completará con salto relativo
end;
procedure TGenCodBas._BPL(const ad: ShortInt);
begin
  if ad>=0 then begin
    pic.codAsm(i_BPL, aRelative, ad);
  end else begin
    pic.codAsm(i_BPL, aRelative, 256+ad);
  end;
end;
procedure TGenCodBas._BPL_pre(curAddr: integer);
begin
  pic.codAsm(i_BPL, aRelative, (curAddr - pic.iRam-2) and $ff);
end;
procedure TGenCodBas._BPL_post(out ibranch: integer);
begin
  ibranch := pic.iRam+1;  //guarda posición del offset de salto
  pic.codAsm(i_BPL, aRelative, 1);  //1 en Offset indica que se completará con salto relativo
end;
procedure TGenCodBas._CLC;
begin
  pic.codAsm(i_CLC, aImplicit, 0);
end;
procedure TGenCodBas._CMPi(const k: word);
begin
  pic.codAsm(i_CMP, aImmediat, k);
end;
procedure TGenCodBas._CMP(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_CMP, aZeroPage, addr);
  end else begin
    pic.codAsm(i_CMP, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._DEX;
begin
  pic.codAsm(i_DEX, aImplicit, 0);
end;
procedure TGenCodBas._DEY;
begin
  pic.codAsm(i_DEY, aImplicit, 0);
end;
procedure TGenCodBas._DEC(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_DEC, aZeroPage, addr);
  end else begin
    pic.codAsm(i_DEC, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._EOR(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_EOR, aZeroPage, addr);
  end else begin
    pic.codAsm(i_EOR, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._EORi(const k: word);
begin
  pic.codAsm(i_EOR, aImmediat, k);
end;
procedure TGenCodBas._INC(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_INC, aZeroPage, addr);
  end else begin
    pic.codAsm(i_INC, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._INX;
begin
  pic.codAsm(i_INX, aImplicit, 0);
end;
procedure TGenCodBas._INY;
begin
  pic.codAsm(i_INY, aImplicit, 0);
end;
procedure TGenCodBas._LDAi(const k: word);  //LDA Immediate
begin
  pic.codAsm(i_LDA, aImmediat, k);
end;
procedure TGenCodBas._LDA(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_LDA, aZeroPage, addr);
  end else begin
    pic.codAsm(i_LDA, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._LDXi(const k: word); inline;  //LDA Immediate
begin
  pic.codAsm(i_LDX, aImmediat, k);
end;
procedure TGenCodBas._LDX(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_LDX, aZeroPage, addr);
  end else begin
    pic.codAsm(i_LDX, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._LDYi(const k: word); inline;  //LDA Immediate
begin
  pic.codAsm(i_LDY, aImmediat, k);
end;
procedure TGenCodBas._LDY(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_LDY, aZeroPage, addr);
  end else begin
    pic.codAsm(i_LDY, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._NOP; inline;
begin
  pic.codAsm(i_NOP, aImplicit, 0);
end;
procedure TGenCodBas._ORAi(const k: word);
begin
  pic.codAsm(i_ORA, aImmediat, k);
end;
procedure TGenCodBas._ORA(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_ORA, aZeroPage, addr);
  end else begin
    pic.codAsm(i_ORA, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._PHA; inline;
begin
  pic.codAsm(i_PHA, aImplicit, 0);
end;
procedure TGenCodBas._PHP;
begin
  pic.codAsm(i_PHP, aImplicit, 0);
end;
procedure TGenCodBas._PLA;
begin
  pic.codAsm(i_PLA, aImplicit, 0);
end;
procedure TGenCodBas._PLP;
begin
  pic.codAsm(i_PLP, aImplicit, 0);
end;
procedure TGenCodBas._ROL(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_ROL, aZeroPage, addr);
  end else begin
    pic.codAsm(i_ROL, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._RORa;
begin
  pic.codAsm(i_ROR, aAcumulat, 0);
end;
procedure TGenCodBas._ROR(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_ROR, aZeroPage, addr);
  end else begin
    pic.codAsm(i_ROR, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._RTS; inline;
begin
  pic.codAsm(i_RTS, aImplicit, 0);
end;
procedure TGenCodBas._RTI; inline;
begin
  pic.codAsm(i_RTI, aImplicit, 0);
end;
procedure TGenCodBas._SEC; inline;
begin
  pic.codAsm(i_SEC, aImplicit, 0);
end;
procedure TGenCodBas._SED; inline;
begin
  pic.codAsm(i_SED, aImplicit, 0);
end;
procedure TGenCodBas._SBCi(const k: word); inline;  //SBC Immediate
begin
  pic.codAsm(i_SBC, aImmediat, k);
end;
procedure TGenCodBas._SBC(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_SBC, aZeroPage, addr);
  end else begin
    pic.codAsm(i_SBC, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._STA(addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_STA, aZeroPage, addr);
  end else begin
    pic.codAsm(i_STA, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._STX(const addr: integer);  //STA Absolute/Zeropage
begin
  if addr<256 then begin
    pic.codAsm(i_STX, aZeroPage, addr);
  end else begin
    pic.codAsm(i_STX, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._STY(const addr: integer);
begin
  if addr<256 then begin
    pic.codAsm(i_STY, aZeroPage, addr);
  end else begin
    pic.codAsm(i_STY, aAbsolute, addr);
  end;
end;
procedure TGenCodBas._TAX;
begin
  pic.codAsm(i_TAX, aImplicit, 0);
end;
procedure TGenCodBas._TAY;
begin
  pic.codAsm(i_TAY, aImplicit, 0);
end;
procedure TGenCodBas._TYA;
begin
  pic.codAsm(i_TYA, aImplicit, 0);
end;
procedure TGenCodBas._TXA;
begin
  pic.codAsm(i_TXA, aImplicit, 0);
end;
procedure TGenCodBas.IF_TRUE(OpRes: TOperandPtr; out info: TIfInfo);
{Conditional instruction. Test if last expression is TRUE. In this case, execute
the following block. The syntax is:

IF_TRUE(@OpRes, info)
<block of code>
IF_TRUE_END(info)

This instruction require to call to IF_TRUE_END() to define the End of the block.

The block of code can be one or more instructions. The instructions used in the jump
must be optimized, according to the length of the block.
}
begin
  if OpRes^.Sto = stVariab then begin
    //Result in variable
    if OpRes^.logic = logInverted then begin
      _LDA(OpRes^.rVar.addr);
      _BNE_post(info.igoto);
    end else begin
      _LDA(OpRes^.rVar.addr);
      _BEQ_post(info.igoto);
    end;
  end else if OpRes^.Sto = stExpres then begin
    {We first evaluate the case when it could be done an optimization}
    if BooleanFromC<>0 then begin
      //Expression result has been copied from C to A
      pic.iRam := BooleanFromC;   //Delete last instructions
      //Check C flag
      if OpRes^.logic = logInverted then begin
        _BCS_post(info.igoto);
      end else begin
        _BCC_post(info.igoto);
      end;
    end else if BooleanFromZ<>0 then begin
      //Expression result has been copied from Z to A
      pic.iRam := BooleanFromZ;   //Delete last instructions
      //Check Z flag
      if OpRes^.logic = logInverted then begin
        _BEQ_post(info.igoto);
      end else begin
        _BNE_post(info.igoto);
      end;
    end else begin
      {Cannot be (or should be) optimized }
      if AcumStatInZ then begin
        //Still we can use the optimizaction of testing Z flag
        if OpRes^.logic = logInverted then begin
          _BNE_post(info.igoto);
        end else begin
          _BEQ_post(info.igoto);
        end;
      end else begin
        //Operand value in A but not always in Z
        _TAX;  //To update Z
        if OpRes^.logic = logInverted then begin
          _BNE_post(info.igoto);
        end else begin
          _BEQ_post(info.igoto);
        end;
      end;
    end;
  end else begin
    genError('Expression storage not supported.');
  end;
end;
procedure TGenCodBas.IF_FALSE(OpRes: TOperandPtr; out info: TIfInfo);
//Negated version of IF_TRUE()
begin
  OpRes^.Invert;   //Change logic
  IF_TRUE(OpRes, info);
  OpRes^.Invert;   //Restore logic
end;
procedure TGenCodBas.IF_END(const info: TIfInfo);
{Define the End of the block, created with IF_TRUE().}
begin
  _LABEL_post(info.igoto);  //termina de codificar el salto
end;
function TGenCodBas.PICName: string;
begin
  Result := pic.Model;
end;
//////////////// Tipo Byte /////////////
procedure TGenCodBas.byte_LoadToRT(const OpPtr: pointer);
{Carga operando a registros de trabajo.}
var
  Op: ^TOperand;
begin
  Op := OpPtr;
  case Op^.Sto of  //el parámetro debe estar en "res"
  stConst : begin
    _LDAi(Op^.valInt);
  end;
  stVariab: begin
    _LDA(Op^.rVar.addr);
  end;
  stExpres: begin  //ya está en A
  end;
  stVarRef: begin
    ////Se tiene una variable puntero dereferenciada: x^
    //varPtr := Op^.rVar;  //Guarda referencia a la variable puntero
    ////Mueve a A
    //kMOVF(varPtr.adrByte0, toW);
    //kMOVWF(FSR);  //direcciona
    //kMOVF(INDF, toW);  //deje en A
  end;
  stExpRef: begin
//    //Es una expresión derefernciada (x+a)^.
//    {Se asume que el operando tiene su resultado en los RT. Si estuvieran en la pila
//    no se aplicaría.}
//    //Mueve a A
//    _MOVWF(FSR.addr);  //direcciona
//    _MOVF(0, toW);  //deje en A
  end;
  else
    //Almacenamiento no implementado
    GenError(MSG_NOT_IMPLEM);
  end;
end;
procedure TGenCodBas.byte_DefineRegisters;
begin
  //No es encesario, definir registros adicionales a A
end;
procedure TGenCodBas.byte_SaveToStk;
begin
  _PHA;
end;
//////////////// Tipo Word /////////////
procedure TGenCodBas.word_LoadToRT(const OpPtr: pointer);
{Carga el valor de una expresión a los registros de trabajo.}
var
  Op: ^TOperand;
begin
  Op := OpPtr;
  case Op^.Sto of  //el parámetro debe estar en "Op^"
  stConst : begin
    //byte alto
    _LDAi(Op^.HByte);
    _STA(H.addr);
    //byte bajo
    _LDAi(Op^.LByte);
  end;
  stVariab: begin
    _LDA(Op^.rVar.addr+1);
    _STA(H.addr);
    _LDA(Op^.rVar.addr);
  end;
  stExpres: begin  //se asume que ya está en (H,A)
  end;
  stVarRef: begin
    ////Se tiene una variable puntero dereferenciada: x^
    //varPtr := Op^.rVar;  //Guarda referencia a la variable puntero
    ////Mueve a A
    //kINCF(varPtr.adrByte0, toW);  //varPtr.addr+1 -> A  (byte alto)
    //_MOVWF(FSR.addr);  //direcciona byte alto
    //_MOVF(0, toW);  //deje en A
    //_MOVWF(H.addr);  //Guarda byte alto
    //_DECF(FSR.addr,toF);
    //_MOVF(0, toW);  //deje en A byte bajo
  end;
  stExpRef: begin
//    //Es una expresión desrefernciada (x+a)^.
//    {Se asume que el operando tiene su resultado en los RT. Si estuvieran en la pila
//    no se aplicaría.}
//    //Mueve a A
//    _MOVWF(FSR.addr);  //direcciona byte bajo
//    _INCF(FSR.addr,toF);  //apunta a byte alto
//    _MOVF(0, toW);  //deje en A
//    _MOVWF(H.addr);  //Guarda byte alto
//    _DECF(FSR.addr,toF);
//    _MOVF(0, toW);  //deje en A byte bajo
  end;
  else
    //Almacenamiento no implementado
    GenError(MSG_NOT_IMPLEM);
  end;
end;
procedure TGenCodBas.word_DefineRegisters;
begin
  //Changed from versión 0.7.1
  AddCallerTo(H);
end;
procedure TGenCodBas.word_SaveToStk;
begin
  //guarda A
  _PHA;
  //guarda H
  _LDA(H.addr);
  _PHA;
end;
procedure TGenCodBas.word_Low(const OpPtr: pointer);
{Acceso al byte de menor peso de un word.}
var
  xvar, tmpVar: TxpEleVar;
  Op: ^TOperand;
begin
  cIn.Next;  //Toma identificador de campo
  Op := OpPtr;
  case Op^.Sto of
  stVariab: begin
    xvar := Op^.rVar;
    //Se devuelve una variable, byte
    //Crea una variable temporal que representará al campo
    tmpVar := CreateTmpVar(xvar.name+'.L', typByte);   //crea variable temporal
    tmpVar.addr :=  xvar.addr;  //byte bajo
    res.SetAsVariab(tmpVar);
  end;
  stConst: begin
    //Se devuelve una constante bit
    res.SetAsConst(typByte);
    res.valInt := Op^.ValInt and $ff;
  end;
  else
    GenError('Syntax error.');
  end;
end;
procedure TGenCodBas.word_High(const OpPtr: pointer);
{Acceso al byte de mayor peso de un word.}
var
  xvar, tmpVar: TxpEleVar;
  Op: ^TOperand;
begin
  cIn.Next;  //Toma identificador de campo
  Op := OpPtr;
  case Op^.Sto of
  stVariab: begin
    xvar := Op^.rVar;
    //A byte type is returned
    //Temporal variable that will represent the field
    tmpVar := CreateTmpVar(xvar.name+'.H', typByte);
    tmpVar.addr := xvar.addrH;  //byte alto
    res.SetAsVariab(tmpVar);
  end;
  stConst: begin
    //Se devuelve una constante bit
    res.SetAsConst(typByte);
    res.valInt := (Op^.ValInt and $ff00)>>8;
  end;
  else
    GenError('Syntax error.');
  end;
end;
procedure TGenCodBas.GenCodPicReqStopCodeGen;
{Required Stop the Code generation}
begin
  posFlash := pic.iRam; //Probably not the best way.
end;
procedure TGenCodBas.GenCodPicReqStartCodeGen;
{Required Start the Code generation}
begin
  pic.iRam := posFlash; //Probably not the best way.
end;
function TGenCodBas.DeviceError: string;
begin
  exit (pic.MsjError);
end;
function TGenCodBas.GenCodBasCallCurrRAM(): integer;
begin
  exit(pic.iRam);
end;
//Inicialización
procedure TGenCodBas.StartRegs;
{Inicia los registros de trabajo en la lista.}
begin
  listRegAux.Clear;
  {Crea registros de trabajo adicionales H,E,U, para que estén definidos, pero aún no
  tienen asignados una posición en memoria.}
  //Puede salir con error
end;
procedure TGenCodBas.GenCodLoadToA(Op: TOperand);
begin
  if Op.Typ.IsByteSize then begin
    case Op.Sto. of
    stConst: begin
      _LDAi(Op.valInt and $ff);
    end;
    stVariab: begin
      _LDA(Op.rVar.addr);
    end;
    stExpres: begin
      //Already in A
    end
    else
      GenError('Cannot load this operand to register A.');
    end;
  end else begin
    GenError('Operand must be byte-size to fit in register A.');
  end;
end;
procedure TGenCodBas.GenCodLoadToX(Op: TOperand);
begin
  if Op.Typ.IsByteSize then begin
    case Op.Sto. of
    stConst: begin
      _LDXi(Op.valInt and $ff);
    end;
    stVariab: begin
      _LDX(Op.rVar.addr);
    end;
    stExpres: begin
      _TAX;
    end
    else
      GenError('Cannot load this operand to register X.');
    end;
  end else begin
    GenError('Operand must be byte-size to fit in register Y.');
  end;
end;
procedure TGenCodBas.GenCodLoadToY(Op: TOperand);
begin
  if Op.Typ.IsByteSize then begin
    case Op.Sto. of
    stConst: begin
      _LDYi(Op.valInt and $ff);
    end;
    stVariab: begin
      _LDY(Op.rVar.addr);
    end;
    stExpres: begin
      _TAY;
    end
    else
      GenError('Cannot load this operand to register Y.');
    end;
  end else begin
    GenError('Operand must be byte-size to fit in register Y.');
  end;
end;
function TGenCodBas.CompilerName: string;
begin
  Result := 'P65Pas Compiler'
end;
function TGenCodBas.RAMmax: integer;
begin
   Result := high(pic.ram);
end;
procedure TGenCodBas.StartCodeSub(fun: TxpEleFun);
{debe ser llamado para iniciar la codificación de una subrutina}
begin
//  iFlashTmp :=  pic.iFlash; //guarda puntero
//  pic.iFlash := curBloSub;  //empieza a codificar aquí
end;
procedure TGenCodBas.EndCodeSub;
{debe ser llamado al terminar la codificaión de una subrutina}
begin
//  curBloSub := pic.iFlash;  //indica siguiente posición libre
//  pic.iFlash := iFlashTmp;  //retorna puntero
end;
procedure TGenCodBas.FunctParam(fun: TxpEleFunBase);
{Rutina genérica, que se usa antes de leer los parámetros de una función.}
begin
  {Haya o no, parámetros se debe proceder como en cualquier expresión, asumiendo que
  vamos a devolver una expresión.}
  SetResultExpres(fun.typ);  //actualiza "RTstate"
end;
procedure TGenCodBas.FunctCall(fun: TxpEleFunBase; out AddrUndef: boolean);
{Rutina genérica para llamar a una función definida por el usuario.}
var
  xfun: TxpEleFun;
begin
  AddrUndef := false;
  if FirstPass then begin
    //In first Pass, definign calls is not really important.
    _JSR($0000);
  end else begin
    //In linking, it's supposed all functions are implemented
    if fun.idClass = eltFunc then begin
      xfun := TxpEleFun(fun);
    end else begin
      //Must be a declaration
      xfun := TxpEleFunDec(fun).implem;
    end;
    if xfun.linked then begin
      //We have a real address
      _JSR(xfun.adrr);  //It's a complete function
    end else begin
      //Function is not yet linked. We need to complete this call later.
      _JSR($0000);
      xfun.AddAddresPend(pic.iRam-2);
    end;
  end;
end;
procedure TGenCodBas.CompileIF;
{Compila una extructura IF}
var
  jEND_TRUE: integer;
  lbl1: TIfInfo;
begin
  if not GetExpressionBool then exit;
  if not CaptureStr('then') then exit; //toma "then"
  //Aquí debe estar el cuerpo del "if"
  case res.Sto of
  stConst: begin  //la condición es fija
    if res.valBool then begin
      //Es verdadero, siempre se ejecuta
      if not CompileNoConditionBody(true) then exit;
      //Compila los ELSIF que pudieran haber
      while cIn.tokL = 'elsif' do begin
        cIn.Next;   //toma "elsif"
        if not GetExpressionBool then exit;
        if not CaptureStr('then') then exit;  //toma "then"
        //Compila el cuerpo pero sin código
        if not CompileNoConditionBody(false) then exit;
      end;
      //Compila el ELSE final, si existe.
      if cIn.tokL = 'else' then begin
        //Hay bloque ELSE, pero no se ejecutará nunca
        cIn.Next;   //toma "else"
        if not CompileNoConditionBody(false) then exit;
        if not VerifyEND then exit;
      end else begin
        VerifyEND;
      end;
    end else begin
      //Es falso, nunca se ejecuta
      if not CompileNoConditionBody(false) then exit;
      if cIn.tokL = 'else' then begin
        //hay bloque ELSE, que sí se ejecutará
        cIn.Next;   //toma "else"
        if not CompileNoConditionBody(true) then exit;
        VerifyEND;
      end else if cIn.tokL = 'elsif' then begin
        cIn.Next;
        CompileIF;  //más fácil es la forma recursiva
        if HayError then exit;
        //No es necesario verificar el END final.
      end else begin
        VerifyEND;
      end;
    end;
  end;
  stVariab, stExpres:begin
    IF_TRUE(@res, lbl1);
//    Cod_JumpIfTrue;
//    _JMP_post(jFALSE);  //salto pendiente
    //Compila la parte THEN
    if not CompileConditionalBody then exit;
    //Verifica si sigue el ELSE
    if cIn.tokL = 'else' then begin
      //Es: IF ... THEN ... ELSE ... END
      cIn.Next;   //toma "else"
      _JMP_post(jEND_TRUE);  //llega por aquí si es TRUE
      IF_END( lbl1);
      if not CompileConditionalBody then exit;
      _LABEL_post(jEND_TRUE);   //termina de codificar el salto
      VerifyEND;   //puede salir con error
    end else if cIn.tokL = 'elsif' then begin
      //Es: IF ... THEN ... ELSIF ...
      cIn.Next;
      _JMP_post(jEND_TRUE);  //llega por aquí si es TRUE
      IF_END( lbl1);
      CompileIF;  //más fácil es la forma recursiva
      if HayError then exit;
      _LABEL_post(jEND_TRUE);   //termina de codificar el salto
      //No es necesario verificar el END final.
    end else begin
      //Es: IF ... THEN ... END. (Puede ser recursivo)
      IF_END( lbl1);
      VerifyEND;  //puede salir con error
    end;
  end;
  end;
end;
procedure TGenCodBas.CompileREPEAT;
{Compila uan extructura WHILE}
var
  l1: Word;
  info: TIfInfo;
begin
  l1 := _PC;        //guarda dirección de inicio
  CompileCurBlock;
  if HayError then exit;
  cIn.SkipWhites;
  if not CaptureStr('until') then exit; //toma "until"
  if not GetExpressionBool then exit;
  case res.Sto of
  stConst: begin  //la condición es fija
    if res.valBool then begin
      //lazo nulo
    end else begin
      //lazo infinito
      _JMP(l1);
    end;
  end;
  stVariab, stExpres: begin
    IF_FALSE(@res, info);   { TODO : Se debería optimizar. Hay un salto innecesario, útil solo para bloques largos. }
    _JMP(l1);
    IF_END(info)
    //sale cuando la condición es verdadera
  end;
  end;
end;
procedure TGenCodBas.CompileWHILE;
{Compila una extructura WHILE}
var
  l1: Word;
  info: TIfInfo;
begin
  l1 := _PC;        //guarda dirección de inicio
  if not GetExpressionBool then exit;  //Condición
  if not CaptureStr('do') then exit;  //toma "do"
  //Aquí debe estar el cuerpo del "while"
  case res.Sto of
  stConst: begin  //la condición es fija
    if res.valBool then begin
      //Lazo infinito
      if not CompileNoConditionBody(true) then exit;
      if not VerifyEND then exit;
      _JMP(l1);
    end else begin
      //Lazo nulo. Compila sin generar código.
      if not CompileNoConditionBody(false) then exit;
      if not VerifyEND then exit;
    end;
  end;
  stVariab, stExpres: begin
    IF_TRUE(@res, info);
    if not CompileConditionalBody then exit;
    _JMP(l1);
    IF_END(info);
    if not VerifyEND then exit;
  end;
  end;
end;
procedure TGenCodBas.CompileFOR;
{Compila uan extructura FOR}
var
  l1: Word;
  LABEL1: Integer;
  Op1, Op2: TOperand;
  opr1: TxpOperator;
  info: TIfInfo;
begin
  GetOperand(Op1, opmSetter);
  if Op1.Sto <> stVariab then begin
    GenError(ER_VARIAB_EXPEC);
    exit;
  end;
  if HayError then exit;
  if (Op1.Typ<>typByte) and (Op1.Typ<>typWord) then begin
    GenError(ER_ONL_BYT_WORD);
    exit;
  end;
  cIn.SkipWhites;
  opr1 := GetOperator(Op1);   //debe ser ":="
  if opr1 = nil then begin  //no sigue operador
    GenError(ER_ASIG_EXPECT);
    exit;  //termina ejecucion
  end;
  if opr1.txt <> ':=' then begin
    GenError(ER_ASIG_EXPECT);
    exit;
  end;
  Op2 := GetExpression(0);
  if HayError then exit;
  //Ya se tiene la asignación inicial
  Oper(Op1, opr1, Op2);   //codifica asignación
  if HayError then exit;
  if not CaptureStr('to') then exit;
  //Toma expresión Final
  res := GetExpression(0);
  if HayError then exit;
  cIn.SkipWhites;
  if not CaptureStr('do') then exit;  //toma "do"
  //Aquí debe estar el cuerpo del "for"
  if (res.Sto = stConst) or (res.Sto = stVariab) then begin
    //Es un for con valor final de tipo constante
    //Se podría optimizar, si el valor inicial es también constante
    l1 := _PC;        //guarda dirección de inicio
    //Codifica rutina de comparación, para salir
    OnExprStart();  //We need this to reset register
    opr1 := Op1.Typ.FindBinaryOperator('<=');  //Busca operador de comparación
    if opr1 = nullOper then begin
      GenError('Internal: No operator <= defined for %s.', [Op1.Typ.name]);
      exit;
    end;
    Op2 := res;   //Copia porque la operación Oper() modificará res
    Oper(Op1, opr1, Op2);   //verifica resultado
    IF_TRUE(@res, info);
    OnExprEnd(pexSTRUC);  //Close expresión
    if not CompileConditionalBody then exit;
    if not VerifyEND then exit;
    //Incrementa variable cursor
    if Op1.Typ = typByte then begin
      _INC(Op1.rVar.addr);
    end else if Op1.Typ = typWord then begin
      _INC(Op1.rVar.addr);
      _BNE_post(LABEL1);  //label
      _INC(Op1.rVar.addr+1);
_LABEL_post(LABEL1);
    end;
    _JMP(l1);  //repite el lazo
    //ya se tiene el destino del salto
    IF_END(info);   //termina de codificar el salto
  end else begin
    GenError('Last value must be Constant or Variable');
    exit;
  end;
end;
procedure TGenCodBas.CompileProcBody(fun: TxpEleFun);
{Compila el cuerpo de un procedimiento}
begin
  callStartCodeSub(fun);    //Inicia codificación de subrutina
  CompileInstruction;
  if HayError then exit;
  if fun.IsInterrupt then begin
    //Las interrupciones terminan así
    _RTI;
  end else begin
    //Para los procedimeintos, podemos terminar siempre con un RTS u optimizar,
    if OptRetProc then begin
      //Verifica es que ya se ha incluido exit().
      if fun.ObligatoryExit<>nil then begin
        //Ya tiene un exit() obligatorio y en el final (al menos eso se espera)
        //No es necesario incluir el RTS().
      end else begin
        //No hay un exit(), seguro
        _RTS();  //instrucción de salida
      end;
    end else begin
      _RTS();  //instrucción de salida
    end;
  end;
  callEndCodeSub;  //termina codificación
  //Calcula tamaño
  fun.srcSize := pic.iRam - fun.adrr;
end;

procedure TGenCodBas.ClearDeviceError;
begin
  pic.MsjError := '';
end;

procedure TGenCodBas.ResetRAM;
{Reset the device RAM memory, and set the pointer iRam to start writing at the
beggining of the RAM.}
begin
  pic.iRam := 0;  //Ubica puntero al inicio.
  pic.ClearMemRAM;  //Pone las celdas como no usadas y elimina nombres.
  StartRegs;        //Limpia registros de trabajo, auxiliares, y de pila.
  if pic.hasDataAdrr = -1 then begin
    //No primary data address has been specified
    pic.dataAddr1 := pic.hasDataAdrr;  //Set start address
  end else begin
    //Has been specified a primary Data Address
    pic.dataAddr1 := pic.hasDataAdrr;  //Set start address
  end;
end;
constructor TGenCodBas.Create;
begin
  inherited Create;
  ID := 16;  //Identifica al compilador PIC16
  devicesPath := patDevices16;
  OnReqStartCodeGen:=@GenCodPicReqStartCodeGen;
  OnReqStopCodeGen:=@GenCodPicReqStopCodeGen;
  pic := TP6502.Create;
  picCore := pic;   //Referencia picCore
  //Crea lista de variables temporales
  varFields    := TxpEleVars.Create(true);
  //Inicializa contenedores
  listRegAux   := TPicRegister_list.Create(true);
  {Crea registro de trabajo A. El registro A, es el registro interno del PIC, y no
  necesita un mapeo en RAM. Solo se le crea aquí, para poder usar su propiedad "used"}
  A := TPicRegister.Create;
  A.assigned := false;   //se le marca así, para que no se intente usar



  //Implement calls to Code Generator
  callCurrRAM         := @GenCodBasCallCurrRAM;
  callResetRAM        := @ResetRAM;
  callCreateVarInRAM  := @CreateVarInRAM;
  callSetSharedUnused := @SetSharedUnused;
  callSetSharedUsed   := @SetSharedUsed;
  callReturnAttribIn  := @ReturnAttribIn;
  callDeviceError     := @DeviceError;
  callClearDeviceError:= @ClearDeviceError;
  callCompileProcBody := @CompileProcBody;
  callFunctParam      := @FunctParam;
  callFunctCall       := @FunctCall;
  callStartCodeSub    := @StartCodeSub;
  callEndCodeSub      := @EndCodeSub;

  callCompileIF       := @CompileIF;;
  callCompileWHILE    := @CompileWHILE;
  callCompileREPEAT   := @CompileREPEAT;
  callCompileFOR      := @CompileFOR;
  callLoadToA         := @GenCodLoadToA;
  callLoadToX         := @GenCodLoadToX;
  callLoadToY         := @GenCodLoadToY;
end;
destructor TGenCodBas.Destroy;
begin
  A.Destroy;
  listRegAux.Destroy;
  varFields.Destroy;
  pic.Destroy;
  inherited Destroy;
end;

end.

