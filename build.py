import os
import re
import sys
import _winreg
import zipfile

def compile(src):
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

def package(fn):
    out = fn[:-4] + '.zip'
    print 'Package %s ......' % out
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zip:
        zip.write(fn)
        zip.write('NaviAssist.sample.ini', 'NaviAssist.ini')
        zip.write(r'extensions\NaviData_AutoIt3.chm.txt')
        zip.write(r'extensions\NaviData_python272.chm.txt')
        zip.write(r'extensions\NaviData_python272.txt')

if __name__ == '__main__':
    fn = compile('NaviAssist.au3')
    package(fn)

		  	