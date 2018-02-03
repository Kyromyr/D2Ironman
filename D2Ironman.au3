#RequireAdmin
#include <Array.au3>
#include <GuiEdit.au3>
#include <HotKey.au3>
#include <HotKeyInput.au3>
#include <Misc.au3>
#include <NomadMemory.au3>
#include <WinAPI.au3>

#include <AutoItConstants.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <MemoryConstants.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <StaticConstants.au3>
#include <TabConstants.au3>
#include <WindowsConstants.au3>

#pragma compile(Icon, Assets/icon.ico)
#pragma compile(FileDescription, Diablo II Ironman Anti-Cheat Helper)
#pragma compile(ProductName, D2Ironman)
#pragma compile(ProductVersion, 0.1a)
#pragma compile(FileVersion, 0.1a)
#pragma compile(Comments, 03.02.2018)
#pragma compile(UPX, True) ;compression
#pragma compile(inputboxres, True)
;#pragma compile(ExecLevel, requireAdministrator)
;#pragma compile(Compatibility, win7)
;#pragma compile(x64, True)
;#pragma compile(Out, D2Ironman.exe)
;#pragma compile(LegalCopyright, Legal stuff here)
;#pragma compile(LegalTrademarks, '"Trademark something, and some text in "quotes" and stuff')

if (not _Singleton("D2Ironman-Singleton")) then
	exit
endif

if (not IsAdmin()) then
	MsgBox($MB_ICONERROR, "D2Ironman", "Admin rights needed!")
	exit
endif

Opt("MustDeclareVars", 1)
Opt("GUICloseOnESC", 0)
Opt("GUIOnEventMode", 1)

DefineGlobals()

OnAutoItExitRegister("_Exit")

CreateGUI()
Main()

#Region Main
func Main()
	local $hTimerUpdateDelay = TimerInit()
	
	while 1
		Sleep(20)
		
		if (TimerDiff($hTimerUpdateDelay) > 2000) then
			$hTimerUpdateDelay = TimerInit()
			
			UpdateHandle()
			
			if (IsIngame()) then
				InjectFunctions()

				if ($g_iGheedX) then
					GheedCheck()
				else
					GheedUpdatePosition()
				endif
			else
				$g_iGheedX = 0
				$g_iGheedY = 0
			endif
		endif
	wend
endfunc

func _Exit()
	OnAutoItExitUnRegister("_Exit")
	GUIDelete()
	_CloseHandle()
	_LogSave()
	exit
endfunc

func _CloseHandle()
	if ($g_ahD2Handle) then
		_MemoryClose($g_ahD2Handle)
		$g_ahD2Handle = 0
		$g_iD2pid = 0
	endif
endfunc

func UpdateHandle()
	local $hWnd = WinGetHandle("[CLASS:Diablo II]")
	local $iPID = WinGetProcess($hWnd)
	
	if ($iPID == -1) then return _CloseHandle()
	if ($iPID == $g_iD2pid) then return

	_CloseHandle()
	$g_iUpdateFailCounter += 1
	$g_ahD2Handle = _MemoryOpen($iPID)
	if (@error) then return _Debug("UpdateHandle", "Couldn't open Diablo II memory handle.")
	
	if (not UpdateDllHandles()) then
		_CloseHandle()
		return _Debug("UpdateHandle", "Couldn't update dll handles.")
	endif
	
	if (not InjectFunctions()) then
		_CloseHandle()
		return _Debug("UpdateHandle", "Couldn't inject functions.")
	endif

	$g_iUpdateFailCounter = 0
	$g_iD2pid = $iPID
	$g_pD2sgpt = _MemoryRead($g_hD2Common + 0x99E1C, $g_ahD2Handle)
endfunc

func IsIngame()
	if (not $g_iD2pid) then return False
	return _MemoryRead($g_hD2Client + 0x11BBFC, $g_ahD2Handle) <> 0
endfunc

func _Debug($sFuncName, $sMessage, $iError = @error, $iExtended = @extended)
	_Log($sFuncName, $sMessage, $iError, $iExtended)
	PrintString($sMessage, $ePrintRed)
endfunc

func _Log($sFuncName, $sMessage, $iError = @error, $iExtended = @extended)
	$g_sLog &= StringFormat("[%s] %s (error: %s; extended: %s)%s", $sFuncName, $sMessage, $iError, $iExtended, @CRLF)
	
	if ($g_iUpdateFailCounter >= 10) then
		MsgBox($MB_ICONERROR, "D2Ironman", "Failed too many times in a row. Check log for details. Closing D2Ironman...", 0, $g_hGUI)
		exit
	endif
endfunc

func _LogSave()
	if ($g_sLog <> "") then
		local $hFile = FileOpen("D2Ironman-log.txt", $FO_OVERWRITE)
		FileWrite($hFile, $g_sLog)
		FileFlush($hFile)
		FileClose($hFile)
	endif
endfunc
#EndRegion

#Region Checks
func GheedUpdatePosition()
	if (not IsIngame()) then return
	
	local $pPlayer = _MemoryRead($g_hD2Client + 0x11BBFC, $g_ahD2Handle)
	local $pAct = _MemoryRead($pPlayer + 0x1C, $g_ahD2Handle)
	if (not $pAct) then return
	
	local $dwAct = _MemoryRead($pAct + 0x14, $g_ahD2Handle)
	if ($dwAct <> 0) then return
	
	local $pRoom1 = _MemoryRead($pAct + 0x10, $g_ahD2Handle)
	local $pRoom2, $pPresetUnit, $dwTxtFileNo, $dwType
	
	while $pRoom1
		$pRoom2 = _MemoryRead($pRoom1 + 0x10, $g_ahD2Handle)
		$pPresetUnit = _MemoryRead($pRoom2 + 0x5C, $g_ahD2Handle)
		while $pPresetUnit
			$dwType	= _MemoryRead($pPresetUnit + 0x14, $g_ahD2Handle)
			$dwTxtFileNo = _MemoryRead($pPresetUnit + 0x04, $g_ahD2Handle)
			if ($dwType == 1 and $dwTxtFileNo == 147) then
				local $iRoomX = _MemoryRead($pRoom1 + 0x4C, $g_ahD2Handle)
				local $iRoomY = _MemoryRead($pRoom1 + 0x50, $g_ahD2Handle)
				
				$g_iGheedX = $iRoomX + _MemoryRead($pPresetUnit + 0x08, $g_ahD2Handle)
				$g_iGheedY = $iRoomY + _MemoryRead($pPresetUnit + 0x18, $g_ahD2Handle)
				return
			endif
			$pPresetUnit = _MemoryRead($pPresetUnit + 0x0C, $g_ahD2Handle)
		wend
		$pRoom1 = _MemoryRead($pRoom1 + 0x7C, $g_ahD2Handle)
	wend
endfunc

func GheedDistance($iX, $iY)
	return Floor(Sqrt( ($iX - $g_iGheedX)*($iX - $g_iGheedX) + ($iY - $g_iGheedY)*($iY - $g_iGheedY) ))
endfunc

func GheedCheck()
	if (not $g_iGheedX) then return
	
	local $pPlayer = _MemoryRead($g_hD2Client + 0x11BBFC, $g_ahD2Handle)
	
	local $pRoom1, $pRoom2
	local $iUnitID, $iLevelID, $iPlayerX, $iPlayerY, $iDist, $sPlayerName
	local $pUnit, $pPath, $pLevel, $pPlayerData
	
	local $aiCheckedPlayers[8] = [0]
	
	for $i = 0 to 7
		$pUnit = _MemoryRead($g_hD2Client + 0x11B800 + 4*$i, $g_ahD2Handle)
		if ($pUnit and $pUnit <> $pPlayer) then
			$iUnitID = _MemoryRead($pUnit + 0x0C, $g_ahD2Handle)
			$pPath = _MemoryRead($pUnit + 0x2C, $g_ahD2Handle)
			$iPlayerX = _MemoryRead($pPath + 0x02, $g_ahD2Handle, "word")
			$iPlayerY = _MemoryRead($pPath + 0x06, $g_ahD2Handle, "word")
			
			$pRoom1 = _MemoryRead($pPath + 0x1C, $g_ahD2Handle)
			$pRoom2 = _MemoryRead($pRoom1 + 0x10, $g_ahD2Handle)
			$pLevel = _MemoryRead($pRoom2 + 0x58, $g_ahD2Handle)
			$iLevelID = _MemoryRead($pLevel + 0x1D0, $g_ahD2Handle)
			
			$iDist = GheedDistance($iPlayerX, $iPlayerY)
			if ($iLevelID == 1 and $iDist <= 20) then
				$pPlayerData = _MemoryRead($pUnit + 0x14, $g_ahD2Handle)
				$sPlayerName = _MemoryRead($pPlayerData + 0x00, $g_ahD2Handle, "char[16]")
				PrintString(StringFormat("%s is too close to Gheed!", $sPlayerName), $ePrintRed)
			endif
			
			$aiCheckedPlayers[0] += 1
			$aiCheckedPlayers[$aiCheckedPlayers[0]] = $iUnitID
		endif
	next
	
	local $iMe = _MemoryRead($pPlayer + 0x0C, $g_ahD2Handle)
	local $iMePartyID = -1, $iPartyID = -1
	
	local $pRosterUnit = _MemoryRead($g_hD2Client + 0x11BC14, $g_ahD2Handle)
	local $bCheck

	while $pRosterUnit
		$iUnitID = _MemoryRead($pRosterUnit + 0x10, $g_ahD2Handle)
		$iPartyID = _MemoryRead($pRosterUnit + 0x22, $g_ahD2Handle, "word")
		$bCheck = True
		
		for $i = 1 to $aiCheckedPlayers[0]
			if ($iUnitID == $aiCheckedPlayers[$i]) then $bCheck = False
		next

		if ($iUnitID == $iMe) then
			$iMePartyID = $iPartyID
		elseif ($bCheck and $iMePartyID <> -1 and $iMePartyID == $iPartyID) then				
			$iLevelID = _MemoryRead($pRosterUnit + 0x24, $g_ahD2Handle)
			$iPlayerX = _MemoryRead($pRosterUnit + 0x28, $g_ahD2Handle)
			$iPlayerY = _MemoryRead($pRosterUnit + 0x2C, $g_ahD2Handle)
			
			$iDist = GheedDistance($iPlayerX, $iPlayerY)
			if ($iLevelID == 1 and $iDist <= 20) then
				$sPlayerName = _MemoryRead($pRosterUnit + 0x00, $g_ahD2Handle, "char[16]")
				PrintString(StringFormat("%s is too close to Gheed!", $sPlayerName), $ePrintRed)
			endif
		endif
		
		$pRosterUnit = _MemoryRead($pRosterUnit + 0x80, $g_ahD2Handle)
	wend
endfunc

#EndRegion

#Region GUI
func CreateGUI()
	local $sTitle = not @Compiled ? "Ironman Test" : StringFormat("D2Ironman%s %s - [%s]", @AutoItX64 ? "-64" : "", FileGetVersion(@AutoItExe, "FileVersion"), FileGetVersion(@AutoItExe, "Comments"))
	
	global $g_hGUI = GUICreate($sTitle, 400, 300)
	GUISetFont(9 / _GetDPI()[2], 0, 0, "Courier New")
	GUISetOnEvent($GUI_EVENT_CLOSE, "_Exit")

	GUISetState(@SW_SHOW)
endfunc

Func _GetDPI()
    Local $avRet[3]
    Local $iDPI, $iDPIRat, $hWnd = 0
    Local $hDC = DllCall("user32.dll", "long", "GetDC", "long", $hWnd)
    Local $aResult = DllCall("gdi32.dll", "long", "GetDeviceCaps", "long", $hDC[0], "long", 90)
    DllCall("user32.dll", "long", "ReleaseDC", "long", $hWnd, "long", $hDC)
    $iDPI = $aResult[0]

    Select
        Case $iDPI = 0
            $iDPI = 96
            $iDPIRat = 94
        Case $iDPI < 84
            $iDPIRat = $iDPI / 105
        Case $iDPI < 121
            $iDPIRat = $iDPI / 96
        Case $iDPI < 145
            $iDPIRat = $iDPI / 95
        Case Else
            $iDPIRat = $iDPI / 94
    EndSelect
	
    $avRet[0] = 2
    $avRet[1] = $iDPI
    $avRet[2] = $iDPIRat

    Return $avRet
EndFunc   ;==>_GetDPI
#EndRegion

#Region Injection
func RemoteThread($pFunc, $iVar = 0) ; $var is in EBX register
	local $aResult = DllCall($g_ahD2Handle[0], "ptr", "CreateRemoteThread", "ptr", $g_ahD2Handle[1], "ptr", 0, "uint", 0, "ptr", $pFunc, "ptr", $iVar, "dword", 0, "ptr", 0)
	local $hThread = $aResult[0]
	if ($hThread == 0) then return _Debug("RemoteThread", "Couldn't create remote thread.")
	
	_WinAPI_WaitForSingleObject($hThread)
	
	local $tDummy = DllStructCreate("dword")
	DllCall($g_ahD2Handle[0], "bool", "GetExitCodeThread", "handle", $hThread, "ptr", DllStructGetPtr($tDummy))
	local $iRet = Dec(Hex(DllStructGetData($tDummy, 1)))
	
	_WinAPI_CloseHandle($hThread)
	return $iRet
endfunc

func SwapEndian($pAddress)
	return StringFormat("%08s", StringLeft(Hex(Binary($pAddress)), 8))
endfunc

func PrintString($sString, $iColor = $ePrintWhite)
	if (not IsIngame()) then return
	if (not WriteWString($sString)) then return _Log("PrintString", "Failed to write string.")
	
	RemoteThread($g_pD2InjectPrint, $iColor)
	if (@error) then return _Log("PrintString", "Failed to create remote thread.")
	
	return True
endfunc

func WriteString($sString)
	if (not IsIngame()) then return _Log("WriteString", "Not ingame.")
	
	_MemoryWrite($g_pD2InjectString, $g_ahD2Handle, $sString, StringFormat("char[%s]", StringLen($sString) + 1))
	if (@error) then return _Log("WriteString", "Failed to write string.")
	
	return True
endfunc
	
func WriteWString($sString)
	if (not IsIngame()) then return _Log("WriteWString", "Not ingame.")
	
	_MemoryWrite($g_pD2InjectString, $g_ahD2Handle, $sString, StringFormat("wchar[%s]", StringLen($sString) + 1))
	if (@error) then return _Log("WriteWString", "Failed to write string.")
	
	return True
endfunc

#cs
D2Client.dll+CDE00 - 53                    - push ebx
D2Client.dll+CDE01 - 68 *                  - push D2Client.dll+CDE50
D2Client.dll+CDE06 - 31 C0                 - xor eax,eax
D2Client.dll+CDE08 - E8 *                  - call D2Client.dll+7D850
D2Client.dll+CDE0D - C3                    - ret 
#ce

func InjectCode($pWhere, $sCode)
	_MemoryWrite($pWhere, $g_ahD2Handle, $sCode, StringFormat("byte[%s]", StringLen($sCode)/2 - 1))
	
	local $iConfirm = _MemoryRead($pWhere, $g_ahD2Handle)
	return Hex($iConfirm, 8) == Hex(Binary(Int(StringLeft($sCode, 10))))
endfunc

func InjectFunctions()
	local $iPrintOffset = ($g_hD2Client + 0x7D850) - ($g_hD2Client + 0xCDE0D)
	local $sWrite = "0x5368" & SwapEndian($g_pD2InjectString) & "31C0E8" & SwapEndian($iPrintOffset) & "C3"
	local $bPrint = InjectCode($g_pD2InjectPrint, $sWrite)

	return $bPrint
endfunc

func UpdateDllHandles()
	local $pLoadLibraryA = _WinAPI_GetProcAddress(_WinAPI_GetModuleHandle("kernel32.dll"), "LoadLibraryA")
	if (not $pLoadLibraryA) then return _Debug("UpdateDllHandles", "Couldn't retrieve LoadLibraryA address.")
	
	local $pAllocAddress = _MemVirtualAllocEx($g_ahD2Handle[1], 0, 0x100, BitOR($MEM_COMMIT, $MEM_RESERVE), $PAGE_EXECUTE_READWRITE)
	if (@error) then return _Debug("UpdateDllHandles", "Failed to allocate memory.")

	local $iDLLs = UBound($g_asDLL)
	local $hDLLHandle[$iDLLs]
	local $bFailed = False
	
	for $i = 0 to $iDLLs - 1
		_MemoryWrite($pAllocAddress, $g_ahD2Handle, $g_asDLL[$i], StringFormat("char[%s]", StringLen($g_asDLL[$i]) + 1))
		$hDLLHandle[$i] = RemoteThread($pLoadLibraryA, $pAllocAddress)
		if ($hDLLHandle[$i] == 0) then $bFailed = True
	next
	
	$g_hD2Client = $hDLLHandle[0]
	$g_hD2Common = $hDLLHandle[1]
	
	local $pD2Inject = $g_hD2Client + 0xCDE00
	$g_pD2InjectPrint = $pD2Inject + 0x0
	$g_pD2InjectString = $pD2Inject + 0x20
	
	$g_pD2sgpt = _MemoryRead($g_hD2Common + 0x99E1C, $g_ahD2Handle)

	_MemVirtualFreeEx($g_ahD2Handle[1], $pAllocAddress, 0x100, $MEM_RELEASE)
	if (@error) then return _Debug("UpdateDllHandles", "Failed to free memory.")
	if ($bFailed) then return _Debug("UpdateDllHandles", "Couldn't retrieve dll addresses.")
	
	return True
endfunc
#EndRegion

#Region Global Variables
func DefineGlobals()
	global $g_sLog = ""

	global enum $ePrintWhite, $ePrintRed, $ePrintLime, $ePrintBlue, $ePrintGold, $ePrintGrey, $ePrintBlack, $ePrintUnk, $ePrintOrange, $ePrintYellow, $ePrintGreen, $ePrintPurple

	global $g_asDLL[] = ["D2Client.dll", "D2Common.dll"]
	global $g_hD2Client, $g_hD2Common
	global $g_ahD2Handle
	
	global $g_iD2pid, $g_iUpdateFailCounter

	global $g_pD2sgpt, $g_pD2InjectPrint, $g_pD2InjectString
	
	global $g_iGheedX, $g_iGheedY
endfunc
#EndRegion
