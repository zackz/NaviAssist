import os
import sys
import datetime
import navicmd

def is_ignored_file(fn):
    ignore_list = ['.pyc', '.obj']
    for one in ignore_list:
        if fn.lower().endswith(one):
            return True
    return False

def is_ignored_dir(fn):
    ignore_list = ['.svn', 'CVS']
    for one in ignore_list:
        if os.path.basename(fn) == one:
            return True
    return False

def dump_files(dest, root, fout):
    files = []
    dirs = []
    for one in os.listdir(dest):
        one = os.path.join(dest, one)
        if os.path.isfile(one):
            if not is_ignored_file(one):
                files.append(one)
        elif not is_ignored_dir(one):
            dirs.append(one)

    count = 0
    files.sort(key=lambda x: x.lower())
    for one in files:
        line = '%s###%s###%s\n' % (os.path.basename(one),
                                   one.replace(root, '.'),
                                   'open:%s' % (one.replace('\\', '\\\\')))
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
    with open('hhk.txt', 'w') as f:
        lasttime = datetime.datetime.now()
        print 'Files:', dump_files(root, root, f)
        print 'Time: ', datetime.datetime.now() - lasttime

    navicmd.navicmd(os.path.abspath('hhk.txt'),
                    'scite:%s' % scite_handle,
                    r'C:\PRJ\AutoScript\NaviAssist\NaviAssist.au3')

