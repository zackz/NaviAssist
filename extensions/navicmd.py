"""Functions helping to call/send navi command."""

import os
import sys
import re
import ctypes
import subprocess
import _subprocess


def find_naviassist():
	"""Find handle of NaviAssist window"""
	next = 0
	while True:
		next = ctypes.windll.user32.FindWindowExA(0, next, 'AutoIt v3 GUI', 0)
		if next == 0:
			return 0
		strbuf = ctypes.create_string_buffer(256)
		ctypes.windll.user32.GetWindowTextA(
			next, ctypes.byref(strbuf), ctypes.sizeof(strbuf))
		str = ctypes.string_at(strbuf)
		if str.lower().startswith('naviassist'):
			return next


def send_copydata(handle, str):
	"""Send WM_COPYDATA"""
	class COPYDATASTRUCT(ctypes.Structure):
		_fields_ = [
			('dwData', ctypes.c_void_p),
			('cbData', ctypes.c_int),
			('lpData', ctypes.c_char_p),
		]
	copydata = COPYDATASTRUCT(0, len(str), str)
	ctypes.windll.user32.SendMessageA(handle, 0x004A, 0, ctypes.byref(copydata))


def runcmd(cmd, input=None):
	"""Run cmd with hiding console window"""
	startupinfo = subprocess.STARTUPINFO()
	startupinfo.dwFlags = _subprocess.STARTF_USESHOWWINDOW
	startupinfo.wShowWindow = _subprocess.SW_HIDE
	sp = subprocess.Popen(
		cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
		stderr=subprocess.PIPE, startupinfo=startupinfo, shell=True)
	return sp.communicate(input)


def navicmd_msg(navidata, navicmd):
	"""Send cmd message to existing NaviAssist window"""
	handle = find_naviassist()
	if handle != 0:
		send_copydata(handle, '%s###%s' % (navidata, navicmd))
	else:
		raise Exception("Can't find NaviAssist window! Run NaviAssist first.")


def navicmd(navidata, navicmd, show_error=True):
	"""Run navi cmd, try send message first"""
	try:
		navicmd_msg(navidata, navicmd)
	except Exception as e:
		if show_error:
			ctypes.windll.user32.MessageBoxA(
				0, str(e), 'NaviAssist - navicmd.py', 0x00000040L)


if __name__ == '__main__':
	navicmd('', 'winlist')
