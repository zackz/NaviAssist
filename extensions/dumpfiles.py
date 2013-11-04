"""Dump files

dumpfiles.py <dest> <scite_handle>
	Call navicmd with scite command

dumpfiles.py <dest>
	Output to NaviData_files.txt

dumpfiles.py
	Just test output
"""

import os
import sys
import datetime
import tempfile
import navicmd


def is_ignored_file(fn):
	_, ext = os.path.splitext(fn)
	if ext.lower() in ['.pyo', '.pyc', '.obj']:
		return True
	return False


def is_ignored_dir(fn):
	return os.path.basename(fn) in ['.svn', '.git']


def dump_files(dest, fout, file_filter=is_ignored_file, dir_filter=is_ignored_dir):
	count = 0
	for a, b, c in os.walk(dest, True):
		for n in sorted(c):
			fn = os.path.join(a, n)
			if file_filter(fn):
				continue
			line = '%s###%s###%s\n' % (
				fn.replace(dest, '.'), n, 'open:' + fn.replace('\\', '\\\\'))
			fout.write(line)
			count += 1
		for one in filter(lambda x: dir_filter(os.path.join(a, x)), b):
			b.remove(one)
		b.sort()
	return count


def find_project_root(dest):
	fn = os.path.join(os.path.dirname(sys.argv[0]), 'dumpfiles.project.txt')
	if not os.path.isfile(fn):
		return dest
	with open(fn) as f:
		txt = f.read()

	f_ = lambda x: os.path.abspath(os.path.normcase(x))
	for one in txt.splitlines():
		one = one.strip()
		if not os.path.isdir(one):
			continue
		if f_(dest).startswith(f_(one) + '\\'):
			return one
	return dest


def main():
	scite_handle = None
	fntmp = os.path.join(tempfile.gettempdir(), 'NaviData_files.txt')

	if len(sys.argv) > 1:
		dest = sys.argv[1]
		if os.path.isfile(dest):
			dest = os.path.dirname(dest)
	else:
		dest = os.path.dirname(os.path.abspath(sys.argv[0]))
	if len(sys.argv) == 3:
		dest = find_project_root(dest)
		scite_handle = sys.argv[2]
	elif len(sys.argv) == 2:
		fntmp = 'NaviData_files.txt'

	print 'Dump files, root: "%s"' % (dest)
	with open(fntmp, 'w') as f:
		lasttime = datetime.datetime.now()
		print 'Files:', dump_files(dest, f)
		print 'Time: ', datetime.datetime.now() - lasttime
		if len(sys.argv) ==  1:
			print
			print '\n'.join(open(fntmp).read().splitlines()[:10])

	if scite_handle:
		navicmd.navicmd(fntmp, 'scite:%s' % scite_handle)


if __name__ == '__main__':
	main()
