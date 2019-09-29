{"Hello World" P65Pas program.}
program Hello;
uses X16;
begin
  CLRSCR;
  Locate(20, 40);
  ChrOUT('H');
  ChrOUT('E');
  ChrOUT('L');
  ChrOUT('L');
  ChrOUT('O');
  
  asm RTS end 
end.
