import os
import sys
import datetime
import tempfile
import navicmd


def is_ignored_file(fn):
	return False


def is_ignored_dir(fn):
	ignored_words = [
		'.svn',
		'.git',
	]
	if not os.path.isdir(fn):
		return False
	return any(os.path.basename(fn) == x for x in ignored_words)


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


def main():
	if len(sys.argv) == 3:
		dest = sys.argv[1]
		scite_handle = sys.argv[2]
	else:
		dest = sys.argv[0]
		scite_handle = '0'

	root = os.path.dirname(os.path.abspath(dest))
	print 'Dump files, root: "%s"' % (root)
	fntmp = os.path.join(tempfile.gettempdir(), 'NaviData_files.txt')
	with open(fntmp, 'w') as f:
		lasttime = datetime.datetime.now()
		print 'Files:', dump_files(root, f)
		print 'Time: ', datetime.datetime.now() - lasttime

	navicmd.navicmd(fntmp, 'scite:%s' % scite_handle)


if __name__ == '__main__':
	main()
