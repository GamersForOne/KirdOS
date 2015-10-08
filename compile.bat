@echo off
:: Build script for KirdOS
echo Build script for Windows
echo .
:start_demo_q
:: Ask if we should compile the full version or just the demo
set /P demo_a=Do you want the demo (Y/N)?
CALL :UpCase demo_a
IF "%demo_a%"="Y" GOTO :CompileDemo
IF "%demo_a%"="YES" GOTO :CompileDemo
IF "%demo_a%"="N" GOTO :CompileFull
IF "%demo_a%"="NO" GOTO :CompileFull
:: Invalid Answer, try again
echo Invalid answer
goto start_demo_q
:CompileFull
echo .
echo .
echo Press any key to assembly KirdOS Full Version...
pause
echo Assembling bootloader...
cd src\bootloader
nasm -O0 -f bin -o boot.bin boot.asm
cd ..

echo Assembling KirdOS kernel...
nasm -O0 -f bin -o krnldr.sys kernel.asm

echo Assembling programs...
cd programs
	for %%i in (*.asm) do nasm -O0 -f bin %%i
	for %%i in (*.bin) do del %%i
	for %%i in (*.) do ren %%i %%i.bin
cd ..

echo Adding bootsector to disk...
cd bootloader
	partcopy boot.bin 0 200 -f0 0
cd ..

echo Deleting previous files on floppy
	for %%i in (A:\*.*) do del %%i
echo Done.

echo Copying kernel and applications to disk image...
copy krnldr.sys a:\
copy programs\*.bin a:\
cd ..

echo Done!
pause
GOTO:EOF

:CompileDemo
echo .
echo .
echo Press any key to assemble KirdOS Demo...
pause
echo Assembling bootloader...
cd src\bootloader
nasm -O0 -f bin -o boot.bin boot.asm
cd ..

echo Assembling KirdOS Demo kernel...
nasm -O0 -f bin -o krnldr.sys kernel_demo.asm

echo Assembling demo programs...
cd programs_demo
	for %%i in (*.asm) do nasm -O0 -f bin %%i
	for %%i in (*.bin) do del %%i
	for %%i in (*.) do ren %%i %%i.bin
cd ..

echo Adding bootsector to disk...
cd bootloader
	partcopy boot.bin 0 200 -f0 0
cd ..

echo Deleting previous files on floppy
	for %%i in (A:\*.*) do del %%i
echo Done.

echo Copying kernel and applications to disk image...
copy krnldr.sys a:\
copy programs_demo\*.bin a:\
cd ..

echo Done!
pause
GOTO:EOF

:LoCase
:: Subroutine to convert a variable VALUE to all lower case.
:: The argument for this subroutine is the variable NAME.
SET %~1=!%1:A=a!
SET %~1=!%1:B=b!
SET %~1=!%1:C=c!
SET %~1=!%1:D=d!
SET %~1=!%1:E=e!
SET %~1=!%1:F=f!
SET %~1=!%1:G=g!
SET %~1=!%1:H=h!
SET %~1=!%1:I=i!
SET %~1=!%1:J=j!
SET %~1=!%1:K=k!
SET %~1=!%1:L=l!
SET %~1=!%1:M=m!
SET %~1=!%1:N=n!
SET %~1=!%1:O=o!
SET %~1=!%1:P=p!
SET %~1=!%1:Q=q!
SET %~1=!%1:R=r!
SET %~1=!%1:S=s!
SET %~1=!%1:T=t!
SET %~1=!%1:U=u!
SET %~1=!%1:V=v!
SET %~1=!%1:W=w!
SET %~1=!%1:X=x!
SET %~1=!%1:Y=y!
SET %~1=!%1:Z=z!
GOTO:EOF

:UpCase
:: Subroutine to convert a variable VALUE to all upper case.
:: The argument for this subroutine is the variable NAME.
SET %~1=!%1:a=A!
SET %~1=!%1:b=B!
SET %~1=!%1:c=C!
SET %~1=!%1:d=D!
SET %~1=!%1:e=E!
SET %~1=!%1:f=F!
SET %~1=!%1:g=G!
SET %~1=!%1:h=H!
SET %~1=!%1:i=I!
SET %~1=!%1:j=J!
SET %~1=!%1:k=K!
SET %~1=!%1:l=L!
SET %~1=!%1:m=M!
SET %~1=!%1:n=N!
SET %~1=!%1:o=O!
SET %~1=!%1:p=P!
SET %~1=!%1:q=Q!
SET %~1=!%1:r=R!
SET %~1=!%1:s=S!
SET %~1=!%1:t=T!
SET %~1=!%1:u=U!
SET %~1=!%1:v=V!
SET %~1=!%1:w=W!
SET %~1=!%1:x=X!
SET %~1=!%1:y=Y!
SET %~1=!%1:z=Z!
GOTO:EOF