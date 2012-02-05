import os
import re
import sys
import _winreg
import zipfile

def makeexe(src):
    # Get path of Aut2exe.exe
    key = _winreg.OpenKey(_winreg.HKEY_LOCAL_MACHINE, r'SOFTWARE\AutoIt v3\AutoIt')
    path_autoit = _winreg.QueryValueEx(key, 'InstallDir')[0]
    _winreg.CloseKey(key)
    path_aut2exe = os.path.join(path_autoit, r'Aut2Exe\Aut2exe.exe')

    # Get version number. (Global Const $VERSION = "0.1.2")
    with open(src) as f:
        ver = re.findall(r'\$VERSION\s*=\s*"(.*?)"', f.read(), re.I)[0]

    # Exe name
    out = src + '-%s.exe' % ver
    if src.lower().endswith('.au3'):
        out = src[:-4] + '-%s.exe' % ver
        
    # Compile
    print 'Compiling %s ......' % src
    print 'Aut2Exe', path_aut2exe
    print 'IN     ', src
    print 'OUT    ', out
    os.system('"%s" /in %s /out %s' % (path_aut2exe, src, out))
    return out

def makedll():
    PATH_MINGW = r'C:\MinGW'
    if os.path.isfile(os.path.join(PATH_MINGW, r'bin\gcc.exe')):
        print 'Compiling NaviAssist.dll ......'
        envpath = os.getenv('path')
        os.putenv('path', envpath + ';' + os.path.join(PATH_MINGW, 'bin'))
        os.system('gcc -shared -o NaviAssist.dll NaviAssist.c -Wl,--kill-at')
        return 'NaviAssist.dll'
    else:
        print "Can't find MinGW in", PATH_MINGW
        return ''

def package(fnexe, fndll):
    out = fnexe[:-4] + '.zip'
    print 'Package %s ......' % out
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as f:
        f.write(fnexe)
        if os.path.isfile(fndll):
            f.write(fndll)
        f.write('NaviAssist.sample.ini', 'NaviAssist.ini')
        f.write(r'extensions\NaviData_AutoIt3.chm.txt')
        f.write(r'extensions\NaviData_python272.chm.txt')
        f.write(r'extensions\NaviData_python272.txt')
        f.write(r'extensions\navicmd.py')

if __name__ == '__main__':
    fnexe = makeexe('NaviAssist.au3')
    fndll = makedll()
    package(fnexe, fndll)

		  	