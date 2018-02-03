IF EXIST D2Ironman.exe (
	Del D2Ironman.exe /Q
)
REM IF EXIST D2Ironman-64.exe (
REM 	Del D2Ironman-64.exe /Q
REM )
"Assets/Aut2Exe.exe" /in D2Ironman.au3 /out D2Ironman.exe /icon "Assets/icon.ico" /x86
REM "Assets/Aut2Exe.exe" /in D2Ironman.au3 /out D2Ironman-64.exe /icon "Assets/icon.ico" /x64