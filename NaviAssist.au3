#include <Math.au3>
#Include <Misc.au3>
#include <File.au3>
#include <Array.au3>
#include <Process.au3>
#include <WinAPI.au3>
#include <Timers.au3>
#include <Constants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <GuiEdit.au3>
#include <GuiListView.au3>
#include <ListViewConstants.au3>

#include <cfgmgr.au3>

Global Const $NAME = "NaviAssist"
Global Const $VERSION = "0.3.0"
Global Const $MAIN_TITLE = $NAME & " " & $VERSION
Global Const $PATH_INI = @ScriptDir & "\" & "NaviAssist.ini"
Global Const $PATH_DLL = @ScriptDir & "\" & "NaviAssist.dll"
Global Const $SECTION_NAME = "PROPERTIES"
Global Const $TITLE_FIREFOX = "[CLASS:MozillaWindowClass]"
Global Const $NAVI_MAX = 30
Global Const $INVALID_DLL = -1

Global Const $CFGKEY_WIDTH = "WIDTH"
Global Const $CFGKEY_HEIGHT = "HEIGHT"
Global Const $CFGKEY_COLUMN_WIDTH = "COLUMN_WIDTH"
Global Const $CFGKEY_NEWFF_CMD = "NEWFF_CMD" ; for firefox/firefoxsend
Global Const $CFGKEY_DEBUG_BITS = "DEBUG_BITS"
Global Const $CFGKEY_MAX_LIST_COUNT = "MAX_LIST_COUNT"
Global Const $CFGKEY_NAVI_DATA = "DATA"
Global Const $CFGKEY_NAVI_HOTKEY = "HOTKEY"
Global Const $CFGKEY_NAVI_CMD = "CMD"

Global Const $CFGCONST_FIREFOX = "FIREFOX" ; mozrepl
Global Const $CFGCONST_FIREFOXSEND = "FIREFOXSEND" ; send key
Global Const $CFGCONST_WINLIST = "WINLIST"
Global Const $CFGCONST_SCITE = "SCITE"
Global Const $CFGCONST_CMD = "CMD"
Global Const $CFGCONST_CMDHIDE = "CMDHIDE"

; http://msdn.microsoft.com/en-us/library/windows/desktop/dd375731%28v=vs.85%29.aspx
Global Const $VK_RETURN = 0x0D
Global Const $VK_H = 0x48
Global Const $VK_J = 0x4A
Global Const $VK_K = 0x4B
Global Const $VK_L = 0x4C
Global Const $VK_M = 0x4D
Global Const $VK_ESCAPE = 0x1B
;~ Global Const $VK_PRIOR = 0x21 ; Already defined in Constants.au3
;~ Global Const $VK_NEXT = 0x22  ; Already defined in Constants.au3

Global $g_hGUI
Global $g_idListView
Global $g_hListView
Global $g_idEdit
Global $g_hEdit
Global $g_wEditProcOld
Global $g_wListProcOld
Global $g_wListProcHandlePtr
Global $g_idTrayQuit
Global $g_iListMargin
Global $g_iLastTouchTime = 0
Global $g_iLastSizeTime = 0
Global $g_hOwnedFF
Global $g_bAutoQuit = False
Global $g_bCommandLine = False
Global $g_bLeaving = False
Global $g_bitsDebugOutput ; 0: no output, 1: console, 2: OutputDebugString

; $g_NaviData[0], length, $NAVI_MAX + 1
; $g_NaviData[N], navi defined in cfg
; $g_NaviData[$NAVI_MAX], navi from command line
Global $g_NaviData[$NAVI_MAX + 2]
Global $g_NaviCurrent
Global $g_NaviTmp_Data
Global $g_NaviTmp_CMD
Global $g_NaviDLL

main()

Func main()
	; Only one instance running except started with command line.
	If $CmdLine[0] = 0 And _Singleton($NAME, 1) = 0 Then
		WinSetState($MAIN_TITLE, "", @SW_SHOW)
		WinActivate($MAIN_TITLE)
		Exit
	EndIf

	Opt("MustDeclareVars", 1)
	Opt("TrayMenuMode", 1)
	Opt("TrayIconDebug", 0)
	Opt("TrayOnEventMode", 1)
	Opt("WinWaitDelay", 0)
	GUIRegisterMsg($WM_COMMAND, "WM_COMMAND")
	GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
	GUIRegisterMsg($WM_COPYDATA, "WM_COPYDATA")
	GUIRegisterMsg($WM_SIZE, "WM_SIZE")

	TCPStartup()
	InitCFG()
	InitDLL()
	ReadAllData()
	InitTray()
	MainDlg()

	If $g_NaviDLL <> $INVALID_DLL Then
		DllClose($g_NaviDLL)
	EndIf
	TCPShutdown()

	; Write back cfg
	CFGCachedWriteBack(False)

	dbg("Leaving...")
EndFunc

Func InitDLL()
	$g_NaviDLL = DllOpen($PATH_DLL)
	dbg("InitDLL()", $PATH_DLL, $g_NaviDLL)
	If $g_NaviDLL <> $INVALID_DLL Then
		DllCall($g_NaviDLL, "none", "SetDBGBits", "DWORD", $g_bitsDebugOutput)
		If @error <> 0 Then dbg("Error DllCall SetDBGBits", @error)
	EndIf
EndFunc

Func InitCFG()
	Local $t = _Timer_Init()
	CFGInitData($PATH_INI, $SECTION_NAME)

	; General
	If CFGKeyIndex($CFGKEY_NEWFF_CMD) < 0 Then
		Local $pathFirefox = "C:\Program Files\Mozilla Firefox\firefox.exe"
		If Not FileExists($pathFirefox) Then
			$pathFirefox = "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
		EndIf
		CFGSetDefault($CFGKEY_NEWFF_CMD, $pathFirefox)
	EndIf
	CFGSetDefault($CFGKEY_WIDTH, 600)
	CFGSetDefault($CFGKEY_HEIGHT, 300)
	CFGSetDefault($CFGKEY_COLUMN_WIDTH, 62) ; Column 1: 62%, Column 2: 38%
	CFGSetDefault($CFGKEY_MAX_LIST_COUNT, 100)
	$g_bitsDebugOutput = CFGSetDefault($CFGKEY_DEBUG_BITS, "0")
	dbg("InitCFG - 1 Time:", _Timer_Diff($t))

	; Default navi
	If Not IsNaviKeyExist(1) Then
		; Default one
		CFGSetDefault(GetNaviKey(1, $CFGKEY_NAVI_DATA), "")
		CFGSetDefault(GetNaviKey(1, $CFGKEY_NAVI_HOTKEY), "!{F2}")
		CFGSetDefault(GetNaviKey(1, $CFGKEY_NAVI_CMD), $CFGCONST_WINLIST)
	EndIf

	; Navi
	$g_NaviData[0] = $NAVI_MAX + 1
	If $CmdLine[0] = 2 Then
		; Command line, redirect index $NAVI_MAX to command line, see GetNaviValue
		; And no hotkey/tray in command line mode
		$g_NaviCurrent = $NAVI_MAX
		$g_NaviTmp_Data = $CmdLine[1]
		$g_NaviTmp_CMD = $CmdLine[2]
		$g_bAutoQuit = True
		$g_bCommandLine = True
		dbg("Command line", $CmdLine[0], $CmdLineRaw)
	Else
		dbg("Unknown command line", $CmdLine[0], $CmdLineRaw)
		$g_bCommandLine = False
	EndIf
	If Not $g_bCommandLine Then
		; Load navis defined in cfg
		For $i = 1 To $NAVI_MAX
			If Not IsNaviKeyExist($i) Then ContinueLoop
			HotKeySet(GetNaviValue($i, $CFGKEY_NAVI_HOTKEY), "HotKey_Navi")
			$g_NaviCurrent = $i
		Next
	EndIf
	dbg("InitCFG - 2 Time:", _Timer_Diff($t))
EndFunc

Func GetNaviKey($index, $key)
	Return "Navi" & $index & "_" & $key
EndFunc

Func GetNaviValue($index, $key)
	If $index = $NAVI_MAX Then
		If $key = $CFGKEY_NAVI_DATA Then
			Return $g_NaviTmp_Data
		ElseIf $key = $CFGKEY_NAVI_HOTKEY Then
			Return ""
		ElseIf $key = $CFGKEY_NAVI_CMD Then
			Return $g_NaviTmp_CMD
		EndIf
	Else
		Return CFGGet(GetNaviKey($index, $key))
	EndIf
EndFunc

Func IsNaviKeyExist($index)
	If $index = $NAVI_MAX Then Return Not Not $g_NaviTmp_CMD
	Local $value = GetNaviValue($index, $CFGKEY_NAVI_HOTKEY)
	Return Not Not $value
EndFunc

Func UseNaviDLL($index)
	Return $g_NaviDLL <> $INVALID_DLL And GetNaviValue($index, $CFGKEY_NAVI_CMD) <> $CFGCONST_WINLIST
EndFunc

Func ReadAllData()
	If $g_bCommandLine Then
		$g_NaviData[$NAVI_MAX] = ReadData($NAVI_MAX)
	Else
		For $i = 1 To $g_NaviData[0]
			$g_NaviData[$i] = ReadData($i)
		Next
	EndIf
EndFunc

Func ReadData($index)
	Local $t = _Timer_Init()
	If Not IsNaviKeyExist($index) Then Return
	Local $sNaviDataFile = GetNaviValue($index, $CFGKEY_NAVI_DATA)
	Local $ret
	If UseNaviDLL($index) Then
		Local $r = DllCall($g_NaviDLL, "DWORD", "ReadData", "DWORD", $index, "str", $sNaviDataFile)
		If @error <> 0 Then dbg("Error DllCall ReadData", @error)
		Local $tmp[1][1] = [[$r[0]]]
		$ret = $tmp
	Else
		; Line: "key###catalog###data"
		Local $sFileContent = FileRead($sNaviDataFile)
		Local $splitedLines = StringSplit($sFileContent, @CRLF, 3)
		Local $data[UBound($splitedLines) + 1][3]
		Local $n = 1
		For $line In $splitedLines
			If Not $line Then ContinueLoop
			Local $tmp = StringSplit($line, "###", 3)
			If UBound($tmp) <> 3 Then
				dbg("Error line?", $sNaviDataFile, $n, '"' & $line & '"')
				ContinueLoop
			EndIf
			$data[$n][0] = $tmp[0]
			$data[$n][1] = $tmp[1]
			$data[$n][2] = $tmp[2]
			$n = $n + 1
		Next
		$data[0][0] = $n - 1
		$ret = $data
	EndIf
	dbg($index, "Navi:", $sNaviDataFile, "Lines:", $ret[0][0])
	dbg("Time:", _Timer_Diff($t))
	Return $ret
EndFunc

Func NaviSwitchData($index)
	$g_NaviCurrent = $index
	If GetNaviValue($g_NaviCurrent, $CFGKEY_NAVI_CMD) = $CFGCONST_WINLIST Then
		; Winlist
		Local $data = GetNaviValue($g_NaviCurrent, $CFGKEY_NAVI_DATA)
		dbg("Winlist, data:", $data)
		Local $av
		if $data Then
			$av = WinList($data)
		Else
			$av = WinList()
		EndIf
		Local $list[$av[0][0] + 1][3]
		Local $n = 1
		For $i = 1 To $av[0][0]
			If BitAND(WinGetState($av[$i][1]), 2) And StringLen($av[$i][0]) <> 0 Then
				$list[$n][0] = $av[$i][0]
				$list[$n][1] = _WinAPI_GetClassName($av[$i][1])
				$list[$n][2] = $av[$i][1]
				$n = $n + 1
			EndIf
		Next
		$list[0][0] = $n - 1
		; Sort by catalog
		_ArraySort($list, 0, 1, $list[0][0], 1)
		$g_NaviData[$g_NaviCurrent] = $list
	EndIf
EndFunc

Func NaviActivate($index)
	Local $t = _Timer_Init()
	If $g_NaviCurrent <> $index Or $index = $NAVI_MAX Then
		ClearFilter()
	Else
		TouchKey()
	EndIf
	NaviSwitchData($index)
	dbg("NaviActivate(), Index:", $index, "Time:", _Timer_Diff($t))
	WinSetState($g_hGUI, "", @SW_SHOW)
	WinActivate($g_hGUI)
	ControlFocus("", "", $g_idEdit)
	dbg("NaviActivate(), Time:", _Timer_Diff($t))
EndFunc

Func HotKey_Navi()
	Local $new = 1
	For $i = 1 To $g_NaviData[0]
		If @HotKeyPressed == GetNaviValue($i, $CFGKEY_NAVI_HOTKEY) Then
			$new = $i
			ExitLoop
		EndIf
	Next
	NaviActivate($new)
EndFunc

Func InitTray()
	$g_idTrayQuit = TrayCreateItem("Quit")
	TrayItemSetOnEvent(-1, "Tray_EventHandler")
EndFunc

Func Tray_EventHandler()
	dbg("Tray_EventHandler()", @TRAY_ID)
	Switch @TRAY_ID
		Case $g_idTrayQuit
			$g_bLeaving = True
			WinClose($g_hGUI)
	EndSwitch
EndFunc

Func MainDlg()
	Local $t = _Timer_Init()

	; Dialog
	$g_hGUI = GUICreate("hello", Default, Default, Default, Default, $WS_MAXIMIZEBOX + $WS_SIZEBOX)
	Local $aiGUISize = WinGetClientSize($g_hGUI)

	; Edit
	$g_idEdit = GUICtrlCreateEdit("", 0, 0, $aiGUISize[0], 20, $ES_WANTRETURN)
	$g_hEdit = GUICtrlGetHandle($g_idEdit)
	GUICtrlSetResizing($g_idEdit, $GUI_DOCKTOP + $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

	; List
	Local $style = BitOR($LVS_SHOWSELALWAYS, $LVS_SINGLESEL, $LVS_NOCOLUMNHEADER) ; , $LVS_NOSCROLL)
	$g_idListView = GUICtrlCreateListView("", 0, 20, $aiGUISize[0], $aiGUISize[1] - 20, $style)
	$g_hListView = GUICtrlGetHandle($g_idListView)
	GUICtrlSetResizing($g_idListView, $GUI_DOCKBORDERS)
	$style = BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT, $WS_EX_CLIENTEDGE, $LVS_EX_BORDERSELECT)
	_GUICtrlListView_SetExtendedListViewStyle($g_hListView, $style)
	_GUICtrlListView_SetBkColor($g_hListView, $CLR_MONEYGREEN)
	_GUICtrlListView_SetTextColor($g_hListView, $CLR_BLACK)
	_GUICtrlListView_SetTextBkColor($g_hListView, $CLR_MONEYGREEN)
	_GUICtrlListView_SetOutlineColor($g_hListView, $CLR_BLACK)
	_GUICtrlListView_AddColumn($g_hListView, "key")
	_GUICtrlListView_AddColumn($g_hListView, "category")
	Local $posGUI = WinGetPos($g_hGUI)
	Local $posList = WinGetPos($g_hListView)
	$g_iListMargin = $posGUI[2] - $posList[2]

	; winproc
	Local $wEditProcHandle = DllCallbackRegister("EditWindowProc", "int", "hwnd;uint;wparam;lparam")
	$g_wEditProcOld = _WinAPI_SetWindowLong($g_hEdit, $GWL_WNDPROC, DllCallbackGetPtr($wEditProcHandle))
	Local $wListProcHandle = DllCallbackRegister("ListWindowProc", "int", "hwnd;uint;wparam;lparam")
	$g_wListProcHandlePtr = DllCallbackGetPtr($wListProcHandle)
	$g_wListProcOld = _WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $g_wListProcHandlePtr)

	; Show dialog
	WinMove($g_hGUI, "", Default, Default, CFGGetInt($CFGKEY_WIDTH), CFGGet($CFGKEY_HEIGHT))
	AdjustListColumn()
	NaviActivate($g_NaviCurrent)
	ListUpdate('')
	GUISetState(@SW_SHOW, $g_hGUI)
	Local $idTimer = _Timer_SetTimer($g_hGUI, 50, "Timer_Refresh")

	dbg("Main loop start...", _Timer_Diff($t))
	While 1
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE
				If $g_bLeaving Then ExitLoop
				Local $ret = MsgBox(1, $NAME, "Close " & $NAME & "?")
				If $ret = 1 Then
					ExitLoop
				EndIf
		EndSwitch
	WEnd

	_Timer_KillTimer($g_hGUI, $idTimer)
	_WinAPI_SetWindowLong($g_hEdit, $GWL_WNDPROC, $g_wEditProcOld)
	DllCallbackFree($wEditProcHandle)
	_WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $g_wListProcOld)
	DllCallbackFree($wListProcHandle)
	GUIDelete($g_hGUI)
EndFunc   ;==>MainDlg

Func WM_COMMAND($hWnd, $msg, $wParam, $lParam)
    Local $nNotifyCode = BitShift($wParam, 16)
    Local $nID = BitAND($wParam, 0xffff)
    Local $hCtrl = $lParam
    Switch $nID
        Case $g_idEdit
            Switch $nNotifyCode
                Case $EN_CHANGE
					TouchKey()
            EndSwitch
    EndSwitch
    Return $GUI_RUNDEFMSG
EndFunc  ;==>WM_COMMAND

Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	Local $hWndFrom, $iIDFrom, $iCode, $tNMHDR, $tInfo
	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	$iIDFrom = DllStructGetData($tNMHDR, "IDFrom")
	$iCode = DllStructGetData($tNMHDR, "Code")
	Switch $hWndFrom
		Case $g_hListView
			Switch $iCode
				; Sent by a list-view control when the user clicks an item with
				; the left mouse button
				Case $NM_DBLCLK
					$tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
					Local $index = DllStructGetData($tInfo, "Index")
					If $index >= 0 Then
						dbg("$NM_DBLCLK", $index)
						Enter()
					EndIf
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc

Func WM_COPYDATA($hWnd, $iMsg, $iwParam, $ilParam)
	dbg("WM_COPYDATA", $hWnd, $iMsg, $iwParam, $ilParam)
	Local $structCOPYDATA = DllStructCreate("Ptr;DWord;Ptr", $ilParam)
	Local $len = DllStructGetData($structCOPYDATA, 2)
	Local $structCMD = DllStructCreate("Char[" & $len & "]", DllStructGetData($structCOPYDATA, 3))
	Local $data = DllStructGetData($structCMD, 1)
	dbg("WM_COPYDATA", $data, $len)
	Local $splited = StringSplit($data, "###", 1)
	if $splited[0] = 2 Then
		$g_NaviTmp_Data = $splited[1]
		$g_NaviTmp_CMD = $splited[2]
		$g_NaviData[$NAVI_MAX] = ReadData($NAVI_MAX)
		NaviActivate($NAVI_MAX)
	Else
		dbg("WM_COPYDATA, Error CMD")
	EndIf
	Return True
EndFunc

Func AdjustListColumn()
	; List control hadn't updated yet when WM_SIZE sent, then WinGetClientSize
	; returned old size of list control. So calculate width of list by width
	; of main dialog.
	Local $len = CFGGet($CFGKEY_WIDTH) - $g_iListMargin - 23
	Local $percentage = CFGGetInt($CFGKEY_COLUMN_WIDTH)
	_GUICtrlListView_SetColumnWidth($g_hListView, 0, $len * $percentage / 100)
	_GUICtrlListView_SetColumnWidth($g_hListView, 1, $len * (100 - $percentage) / 100)
EndFunc

Func WM_SIZE($hWndGUI, $MsgID, $wParam, $lParam)
	If $hWndGUI <> $g_hGUI Then Return $GUI_RUNDEFMSG
	Local $pos = WinGetPos($g_hGUI)
	If CFGGetInt($CFGKEY_WIDTH) <> $pos[2] Then
		CFGSet($CFGKEY_WIDTH, $pos[2])
		; Same crash as the one in PuTTYAssist. It seems that scroll message isn't working well
		; with customized winproc in win7 and WM_SIZE. So use original winproc before sending list
		; message.
		_WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $g_wListProcOld)
		; Here is another trick. Scroll message seems sent latter after '_GUICtrlListView_SetColumnWidth'.
		; Can't set winproc back followed '_GUICtrlListView_SetColumnWidth', because scroll message
		; sent later is conflict with winproc just set back. So postpone writeback to 'Timer_Refresh'
		$g_iLastSizeTime = _Timer_Init()
		AdjustListColumn()
	EndIf
	If CFGGetInt($CFGKEY_HEIGHT) <> $pos[3] Then
		CFGSet($CFGKEY_HEIGHT, $pos[3])
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc

Func EditWindowProc($hWnd, $Msg, $wParam, $lParam)
	Switch $hWnd
		Case $g_hEdit
			Switch $Msg
				Case $WM_GETDLGCODE
					Switch $wParam
						Case $VK_RETURN
							dbg("Enter key is pressed")
							Enter()
							Return 0
					EndSwitch
				Case $WM_SYSCHAR
					If Func_SysChar($wParam) Then Return 0
				Case $WM_KEYDOWN
					If Func_KeyDown($wParam) Then Return 0
				Case $WM_CHAR
					If $wParam = 127 Then
						; CTRL+BACKSPACE
						ClearFilter()
						Return 0
					EndIf
				Case $WM_MOUSEWHEEL
					Return _SendMessage($g_hListView, $Msg, $wParam, $lParam)
			EndSwitch
	EndSwitch
	Return _WinAPI_CallWindowProc($g_wEditProcOld, $hWnd, $Msg, $wParam, $lParam)
EndFunc

Func ListWindowProc($hWnd, $Msg, $wParam, $lParam)
	; http://www.autoitscript.com/forum/topic/83621-trapping-nm-return-in-a-listview-via-wm-notify/
	Switch $hWnd
		Case $g_hListView
			Switch $Msg
				Case $WM_GETDLGCODE
					Switch $wParam
						Case $VK_RETURN
							dbg("Enter key is pressed")
							Enter()
							Return 0
					EndSwitch
					; Not working well, can't process ESC or TAB
					; Try to accept ALT+[X] keys...
; http://msdn.microsoft.com/en-us/library/windows/desktop/ms645425%28v=vs.85%29.aspx
					; DLGC_WANTALLKEYS
					; 0x0004
					; All keyboard input.
;~ 					return BitOR(0x0004, _WinAPI_CallWindowProc($g_wListProcOld, _
;~ 						$hWnd, $Msg, $wParam, $lParam))
				Case $WM_SYSCHAR
					If Func_SysChar($wParam) Then Return 0
				Case $WM_KEYDOWN
					If Func_KeyDown($wParam) Then Return 0
					If Func_FunctionKey($wParam) Then Return 0
			EndSwitch
	EndSwitch
	Return _WinAPI_CallWindowProc($g_wListProcOld, $hWnd, $Msg, $wParam, $lParam)
EndFunc

Func Func_SysChar($wParam)
	; Return True to avoid beep, ALT+[X]
	; Function keys, H/J/K/L/M
	Local $vk = 0
	Switch Chr($wParam)
		Case "j"
			$vk = $VK_J
		Case "k"
			$vk = $VK_K
		Case "h"
			$vk = $VK_H
		Case "l"
			$vk = $VK_L
		Case "m"
			$vk = $VK_M
	EndSwitch
	If $vk <> 0 And Func_FunctionKey($vk) Then
		Return True
	EndIf
	; ALT+[N]
	If 0x30 <= $wParam And $wParam <= 0x39 Then
		Local $offset = $wParam - 0x31
		If $offset < 0 Then $offset = 10 ; ALT+0
		Local $aHit = _GUICtrlListView_HitTest($g_hListView, 3, 3)
		If $aHit[0] >= 0 Then
			dbg("Hit:", $aHit[0], "Offset:", $offset)
			Local $newIndex = $aHit[0] + $offset
			If $newIndex < _GUICtrlListView_GetItemCount($g_hListView) Then
				ListSelectItem($newIndex)
				Enter()
				Return True
			EndIf
		EndIf
		Return False
	EndIf
	; Other function keys
	Switch $wParam
		Case 8
			; ALT+BACKSPACE
			ClearFilter()
			Return True
		Case 122
			; ALT+Z
			ListUpdate(GUICtrlRead($g_idEdit), True)
			Return True
		Case 120
			; ALT+X
			ClearFilter()
			Return True
	EndSwitch
	Return False
EndFunc

Func Func_KeyDown($wParam)
	; PageUp & PageDown
	If $wParam = $VK_PRIOR Or $wParam = $VK_NEXT Then
		_WinAPI_CallWindowProc($g_wListProcOld, $g_hListView, $WM_KEYDOWN, $wParam, 0)
		Return True
	EndIf
	; Up & Down
	If $wParam = $VK_UP Then
		Func_FunctionKey($VK_K)
	EndIf
	If $wParam = $VK_DOWN Then
		Func_FunctionKey($VK_J)
	EndIf
	; Escape
	If $wParam = $VK_ESCAPE Then
		WinSetState($g_hGUI, "", @SW_HIDE)
		Return True
	EndIf
	Return False
EndFunc

Func Func_FunctionKey($vk)
	Local $next = -1
	Local $index = _GUICtrlListView_GetNextItem($g_hListView)
	Local $len = _GUICtrlListView_GetItemCount($g_hListView)
	Switch $vk
		Case $VK_J
			$next = Mod($index + 1 + $len, $len)
		Case $VK_K
			$next = Mod($index - 1 + $len, $len)
		Case $VK_H
			$next = 0
		Case $VK_L
			$next = $len - 1
		Case $VK_M
			$next = Int(($len - 1) / 2)
	EndSwitch
	If $next >= 0 Then
		ListSelectItem($next)
		_GUICtrlListView_EnsureVisible($g_hListView, $next)
		Return True
	EndIf
	Return False
EndFunc

Func TouchKey()
	$g_iLastTouchTime = _Timer_Init()
EndFunc

Func ClearFilter()
	WinSetTitle($g_hEdit, "", "")
	TouchKey()
EndFunc

Func NewFirefox()
	Local $var = WinList($TITLE_FIREFOX)
	Run(CFGGet($CFGKEY_NEWFF_CMD), "", @SW_HIDE)
	For $i = 1 To 50
		Local $var2 = WinList($TITLE_FIREFOX)
		If $var[0][0] < $var2[0][0] Then ExitLoop
		Sleep(100)
		dbg("NewFirefox(), try to get new FF window's handle", $i)
	Next
	dbg("WinList, Old", $var[0][0], "New", $var2[0][0])
	For $i = 1 To $var2[0][0]
		Local $found = False
		For $j = 1 To $var[0][0]
			If $var2[$i][1] = $var[$j][1] Then
				$found = True
				ExitLoop
			EndIf
		Next
		If Not $found Then
			Local $handle = $var2[$i][1]
			WinWaitActive($handle, "", 1000)
			Return $handle
		EndIf
	Next
	Return 0
EndFunc

Func Enter_GetURL($c2)
	; $c2("local") --> url
	Local $left6 = StringLeft($c2, 6)
	If $left6 = "http:/" Or $left6 = "https:" Or $left6 = "ftp://" Then
		Return $c2
	Else
		Local $navipath = _PathFull(GetNaviValue($g_NaviCurrent, $CFGKEY_NAVI_DATA))
		Local $szDrive, $szDir, $szFName, $szExt
		_PathSplit($navipath, $szDrive, $szDir, $szFName, $szExt)
		Local $url = "file:///" & $szDrive & $szDir & $c2
		$url = StringReplace($url, "\", "/")
		Return $url
	EndIf
EndFunc

Func Enter_Firefox_send($url)
	; Indepandent one. Use this if not installed MozRepl.
	; And besides firefox, lots browsers support ALT+D
	dbg("Enter_Firefox_send($url)", $url)
	Opt("SendKeyDelay", 0)
	Send("!d")
	Send($url, 1) ; raw
	Send("{ENTER}")
EndFunc

Func Enter_Firefox($url)
	; MozRepl
	; https://github.com/bard/mozrepl/wiki
	; https://developer.mozilla.org/en/XUL/Method/loadURI
	dbg("Enter_Firefox($url)", $url)
	Local $cmd = 'gBrowser.loadURI("' & $url & '")'
	dbg("CMD   ", $cmd)
	Local $socket = TCPConnect("127.0.0.1", 4242)
	dbg("SOCKET", $socket)
	If $socket = -1 Then
		dbg('Error TCPConnect("127.0.0.1", 4242)')
		Return
	EndIf
	; Receive welcome message, not so accurate but works
	; TODO: check completed welcome messgae
	Local $len = 0
	While $len < 300
		Local $recv = TCPRecv($socket, 1024)
		$len = $len + StringLen($recv)
		dbg("RECV  ", $recv, "TOTAL", $len)
		Sleep(50)
	WEnd
	Local $n = TCPSend($socket, StringToBinary($cmd & @CRLF, 4))
	dbg("SEND  ", $n)
	Sleep(200)
	TCPCloseSocket($socket)
EndFunc

Func Enter_SciTE($hSciTE, $sCMD)
	; SciTE Director Interface
	; http://www.scintilla.org/SciTEDirector.html
	; http://msdn.microsoft.com/en-us/library/windows/desktop/ms649011%28v=vs.85%29.aspx
	dbg("Enter_SciTE($hSciTE, $sCMD)", $hSciTE, $sCMD)
	Local $structCMD = DllStructCreate("Char[" & StringLen($sCMD) & "]")
	DllStructSetData($structCMD, 1, $sCMD)
	Local $structCOPYDATA = DllStructCreate("Ptr;DWord;Ptr")
	DllStructSetData($structCOPYDATA, 1, 0)
	DllStructSetData($structCOPYDATA, 2, StringLen($sCMD))
	DllStructSetData($structCOPYDATA, 3, DllStructGetPtr($structCMD))
	_SendMessage($hSciTE, $WM_COPYDATA, 0, DllStructGetPtr($structCOPYDATA))
EndFunc

Func Enter_CMD($cmd, $c2, $show)
	Local $newcmd = StringReplace($cmd, "%s", $c2)
	dbg("Enter_CMD:", StringReplace($cmd, "%s", $c2))
	If $show Then
		Run(StringReplace($cmd, "%s", $c2), @ScriptDir)
	Else
		Run(StringReplace($cmd, "%s", $c2), @ScriptDir, @SW_HIDE)
	EndIf
EndFunc

Func Enter()
	Local $index = _GUICtrlListView_GetNextItem($g_hListView)
	If $index < 0 Then Return
	Local $key, $catalog, $data

	If UseNaviDLL($g_NaviCurrent) Then
		Local $stKey = DllStructCreate("char[1024]")
		Local $stCatalog = DllStructCreate("char[1024]")
		Local $stData = DllStructCreate("char[10240]")
		Local $r = DllCall($g_NaviDLL, "none", "GetSelected", "DWORD", $g_NaviCurrent, _
			"HWND", $g_hListView, "ptr", DllStructGetPtr($stKey), _
			"ptr", DllStructGetPtr($stCatalog), "ptr", DllStructGetPtr($stData))
		If @error <> 0 Then	dbg("Error DllCall GetSelected", @error)
		$key = DllStructGetData($stKey, 1)
		$catalog = DllStructGetData($stCatalog, 1)
		$data = DllStructGetData($stData, 1)
	Else
		Local $lines = $g_NaviData[$g_NaviCurrent]
		Local $iLine = -1
		Local $c0 = _GUICtrlListView_GetItemText($g_hListView, $index, 0)
		Local $c1 = _GUICtrlListView_GetItemText($g_hListView, $index, 1)
		For $i = 1 To $lines[0][0]
			If $c0 == $lines[$i][0] And $c1 == $lines[$i][1] Then
				$iLine = $i
				ExitLoop
			EndIf
		Next
		dbg("Enter() Line index:", $iLine)
		If $iLine <= 0 Then Return
		$key = $lines[$iLine][0]
		$catalog = $lines[$iLine][1]
		$data = $lines[$iLine][2]
	EndIf

	Local $cmd = GetNaviValue($g_NaviCurrent, $CFGKEY_NAVI_CMD)
	dbg("Enter() Data:", $key, $catalog, $data)
	dbg("Enter() $cmd:", $cmd)
	Local $splitedCMD = StringSplit($cmd, ":")
	Local $cmdRight = $cmd
	If $splitedCMD[0] > 1 Then
		$cmdRight = StringMid($cmd, StringLen($splitedCMD[1]) + 2)
	EndIf
	dbg("Enter() splited:", $splitedCMD[0], "Right:", $cmdRight)
	If $cmd = $CFGCONST_FIREFOX Or $cmd = $CFGCONST_FIREFOXSEND Then
		; Get actived browser window
		If Not $g_hOwnedFF Or Not WinExists($g_hOwnedFF) Then
			$g_hOwnedFF = NewFirefox()
			dbg("Got new FF handle", $g_hOwnedFF)
		Else
			WinActivate($g_hOwnedFF)
		EndIf
		; Open url with firefox
		Local $url = Enter_GetURL($data)
		If $cmd = $CFGCONST_FIREFOX Then
			Enter_Firefox($url)
		Else
			Enter_Firefox_send($url)
		EndIf
	ElseIf $cmd = $CFGCONST_WINLIST Then
		WinActivate($data)
	ElseIf $splitedCMD[1] = $CFGCONST_SCITE Then
		Enter_SciTE(Int($splitedCMD[2]), $data)
	ElseIf $splitedCMD[1] = $CFGCONST_CMD Then
		Enter_CMD($cmdRight, $data, True)
	ElseIf $splitedCMD[1] = $CFGCONST_CMDHIDE Then
		Enter_CMD($cmdRight, $data, False)
	Else
		dbg("Unknown CMD!")
	EndIf
	If $g_bAutoQuit Then
		$g_bLeaving = True
		WinClose($g_hGUI)
	Else
		; Auto hide
		WinSetState($g_hGUI, "", @SW_HIDE)
	EndIf
EndFunc

Func Timer_Refresh($hWnd, $Msg, $iIDTimer, $dwTime)
	If $g_iLastTouchTime <> 0 And _Timer_Diff($g_iLastTouchTime) > 200 Then
		$g_iLastTouchTime = 0
		ListUpdate(GUICtrlRead($g_idEdit))
	EndIf
	If $g_iLastSizeTime <> 0 And _Timer_Diff($g_iLastSizeTime) > 200 Then
		$g_iLastSizeTime = 0
		_WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $g_wListProcHandlePtr)
	EndIf
	CFGCachedWriteBack()
EndFunc

Func ListUpdate($sFilter, $showall = False)
	Local $t = _Timer_Init()
	Local $proc = _WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $g_wListProcOld)

	; List count viewed in listview
	Local $maxcount = CFGGet($CFGKEY_MAX_LIST_COUNT)
	Local $lines = $g_NaviData[$g_NaviCurrent]
	If $showall Then $maxcount = $lines[0][0]
	; Already checked items
	Local $i

	; List
	If UseNaviDLL($g_NaviCurrent) Then
		dbg("DWORD", $g_NaviCurrent, "HWND", $g_hListView)
		Local $r = DllCall($g_NaviDLL, "DWORD", "UpdateList", "DWORD", $g_NaviCurrent, _
			"HWND", $g_hListView, "str", $sFilter, "DWORD", $maxcount)
		If @error <> 0 Then dbg("Error DllCall UpdateList", @error)
		$i = $r[0]
		ListSelectItem(0)
	Else
		_GUICtrlListView_BeginUpdate($g_hListView)
		_GUICtrlListView_DeleteAllItems($g_hListView)
		Local $more = False
		Local $aItems[$maxcount][2]
		Local $aItemsParam[$maxcount]
		Local $index = 0
		For $i = 1 To $lines[0][0]
			If Not $sFilter Or StringInStr($lines[$i][0], $sFilter, 2) Or _
					StringInStr($lines[$i][1], $sFilter, 2) Then
				$aItems[$index][0] = $lines[$i][0]
				$aItems[$index][1] = $lines[$i][1]
				$aItemsParam[$index] = $i
				$index = $index + 1
				If $index >= $maxcount Then
					$more = True
					ExitLoop
				EndIf
			EndIf
		Next
		If $index > 0 Then
			ReDim $aItems[$index][2]
			_GUICtrlListView_AddArray($g_hListView, $aItems)
		EndIf
		ListSelectItem(0)
		_GUICtrlListView_EndUpdate($g_hListView)
	EndIf
	dbg("ListUpdate - 2 Time:", _Timer_Diff($t))

	; Title
	Local $count = _GUICtrlListView_GetItemCount($g_hListView)
	Local $prefix = $MAIN_TITLE
	dbg($count, $i, $lines[0][0])
	If $count Then
		If $i >= $lines[0][0] Then
			WinSetTitle($g_hGUI, "", $prefix & ' - "' & $sFilter & '" ' & $count)
		Else
			Local $notshown = $lines[0][0] - $i
			WinSetTitle($g_hGUI, "", $prefix & ' - "' & $sFilter & '" ' & _
				$count & '/' & $notshown & ' - press Alt+Z to show all items')
		EndIf
	Else
		WinSetTitle($g_hGUI, "", $prefix)
	EndIf

	_WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $proc)
	dbg("ListUpdate - 3 Time:", _Timer_Diff($t), $sFilter)
EndFunc

Func ListSelectItem($iItem)
	Local $iState = $LVIS_FOCUSED + $LVIS_SELECTED
	_GUICtrlListView_SetItemState($g_hListView, $iItem, $iState, $iState)
EndFunc

Func dbg($v1="", $v2="", $v3="", $v4="", $v5="")
	If $g_bitsDebugOutput = 0 Then Return
	Local $msg = $v1 & " " & $v2 & " " & $v3 & " " & $v4 & " " & $v5 & @CRLF
	If BitAND($g_bitsDebugOutput, 1) Then
		ConsoleWrite($msg)
	EndIf
	If BitAND($g_bitsDebugOutput, 2) Then
		DllCall("kernel32.dll", "none", "OutputDebugString", "str", $msg)
	EndIf
EndFunc

Func GetProcessMainWindow($pid)
	Local $wlist = WinList()
	For $i = 1 To $wlist[0][0]
		Local $handle = $wlist[$i][1]
		If $pid <> WinGetProcess($handle) Then ContinueLoop
		If _WinAPI_GetParent($handle) <> 0 Then ContinueLoop
		If BitAND(_WinAPI_GetWindowLong($handle, $GWL_STYLE), $WS_VISIBLE) = 0 Then
			ContinueLoop
		EndIf
		Return $handle
	Next
	Return 0
EndFunc
