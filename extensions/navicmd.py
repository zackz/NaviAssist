"""Some functions helping to call/send navi command."""

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
        ctypes.windll.user32.GetWindowTextA(next, ctypes.byref(strbuf),
                                            ctypes.sizeof(strbuf))
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
    sp = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          startupinfo=startupinfo, shell=True)
    return sp.communicate(input)

def navicmd_msg(navidata, navicmd):
    """Send cmd message to existing NaviAssist window"""
    handle = find_naviassist()
    if handle <> 0:
        send_copydata(handle, '%s###%s' % (navidata, navicmd))
    else:
        raise Exception("Can't find NaviAssist window!")

def navicmd(navidata, navicmd, navipath):
    """Run navi cmd, try send message first"""
    try:
        navicmd_msg(navidata, navicmd)
    except Exception as e:
        print 'Error call send_cmd:', str(e)
        if os.path.exists(navipath):
            if not navidata:
                navidata = '""'
            cmd = '"%s" %s %s' % (navipath, navidata, navicmd)
            print 'Try to run NaviAssist with command line...'
            print cmd
            runcmd('"%s" %s %s' % (navipath, navidata, navicmd))
        else:
            print 'Error path:', navipath

def get_naviassist_path():
    """Try to get path of NaviAssist.exe

    Assume that NaviAssist-(version).exe wasn't renamed, and located in parent
    path of extensions.
    """
    path_current = os.path.dirname(os.path.abspath(sys.argv[0]))
    path_parent = os.path.abspath(os.path.join(path_current, '..'))
    files = os.listdir(path_parent)
    name_pattern = re.compile(r'NaviAssist-(\d+)\.(\d+)\.(\d+)\.exe', re.I)
    naviassist_files = filter(lambda x: name_pattern.match(x), files)
    if not naviassist_files:
        return ''
    naviassist_files_sorted = sorted(
        naviassist_files,
        key=lambda x: map(int, name_pattern.match(x).groups()[1:]),
        reverse=True)
    return os.path.join(path_parent, naviassist_files_sorted[0])

if __name__ == '__main__':
    navicmd('', 'winlist', get_naviassist_path())

