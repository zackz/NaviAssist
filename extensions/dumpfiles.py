import os
import sys
import datetime
import tempfile
import navicmd

def is_ignored_file(fn):
    return False

def is_ignored_dir(fn):
    return False

def dump_files(dest, root, fout):
    if not dest.endswith('\\'):
        dest += '\\'
    files = []
    dirs = []
    for one in os.listdir(dest):
        fullpath = dest + one
        if os.path.isfile(fullpath):
            if not is_ignored_file(fullpath):
                files.append(one)
        elif not is_ignored_dir(fullpath):
            dirs.append(fullpath)

    count = 0
    files.sort(key=lambda x: x.lower())
    path_catalog = dest.replace(root, '.')
    path_data = dest.replace('\\', '\\\\')
    for one in files:
        line = '%s###%s###%s\n' % (one, path_catalog + one, 'open:' + path_data + one)
        fout.write(line)
        count += 1

    dirs.sort(key=lambda x: x.lower())
    for one in dirs:
        count += dump_files(one, root, fout)
    return count

if __name__ == '__main__':
    dest = sys.argv[1] if len(sys.argv) >= 2 else sys.argv[0]
    scite_handle = sys.argv[2] if len(sys.argv) >= 3 else '0'

    root = os.path.dirname(os.path.abspath(dest))
    print 'Dump files, root: "%s"' % (root)
    fn = os.path.join(tempfile.gettempdir(), 'NaviData_files.txt')
    with open(fn, 'w') as f:
        lasttime = datetime.datetime.now()
        print 'Files:', dump_files(root, root, f)
        print 'Time: ', datetime.datetime.now() - lasttime

    navicmd.navicmd(fn, 'scite:%s' % scite_handle,
                    r'C:\PRJ\AutoScript\NaviAssist\NaviAssist.au3')

