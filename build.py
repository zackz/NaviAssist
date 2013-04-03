import os
import re
import sys
import _winreg
import zipfile


def get_package_name(src):
	# Get version number. (Global Const $VERSION = "0.1.2")
	with open(src) as f:
		ver = re.findall(r'\$VERSION\s*=\s*"(.*?)"', f.read(), re.I)[0]

	# Exe name
	out = src + '-%s.exe' % ver
	if src.lower().endswith('.au3'):
		out = src[:-4] + '-%s' % ver
	return out


def makeexe(src):
	print
	print 'Deprecated! Use autoit.exe to run script instead of compiling executable file.'
	print

	# Get path of Aut2exe.exe
	key = _winreg.OpenKey(_winreg.HKEY_LOCAL_MACHINE, r'SOFTWARE\AutoIt v3\AutoIt')
	path_autoit = _winreg.QueryValueEx(key, 'InstallDir')[0]
	_winreg.CloseKey(key)
	path_aut2exe = os.path.join(path_autoit, r'Aut2Exe\Aut2exe.exe')

	# Exe file name
	out = get_package_name(src) + '.exe'

	# Compile
	print 'Compiling %s ......' % src
	print 'Aut2Exe', path_aut2exe
	print 'IN     ', src
	print 'OUT    ', out
	os.system('"%s" /in %s /out %s /nopack' % (path_aut2exe, src, out))
	return out


def makedll():
	# TODO: Edit it..
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
	out = get_package_name('NaviAssist.au3') + '.zip'
	print 'Package %s ......' % out
	with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as f:
		if os.path.isfile(fnexe):
			f.write(fnexe)
		else:
			f.write('NaviAssist.au3')
			f.write('cfgmgr.au3')
		if os.path.isfile(fndll):
			f.write(fndll)
		f.write('NaviAssist.sample.ini', 'NaviAssist.ini')
		f.write(r'extensions\NaviData_AutoIt3.chm.txt')
		f.write(r'extensions\NaviData_python272.chm.txt')
		f.write(r'extensions\NaviData_python272.txt')
		f.write(r'extensions\navicmd.py')


def main():
	# Prefer to run au3 script
	PACKAGE_EXECUTABLE_FILE = False

	if PACKAGE_EXECUTABLE_FILE:
		fnexe = makeexe('NaviAssist.au3')
	else:
		fnexe = ''
	fndll = makedll()
	package(fnexe, fndll)


if __name__ == '__main__':
	main()
