import os
import sys
import StringIO
import datetime
import tempfile
import navicmd

name_dict = {
    'namespace':     ['n', 10],
    'macro':         ['d', 20],
    'enumerator':    ['e', 25],
    'enum':          ['g', 25],
    'externvar':     ['x', 30],
    'class':         ['c', 50],
    'member':        ['m', 50],
    'prototype':     ['p', 50],
    'struct':        ['s', 50],
    'typedef':       ['t', 50],
    'union':         ['u', 50],
    'variable':      ['v', 50],
    'local':         ['l', 70],
    'function':      ['f', 100],

    # java
    'package':       ['p', 10],
    'enumconstant':  ['e', 50],
    'field':         ['f', 50],
    'interface':     ['i', 50],
    'method':        ['m', 50],
    }

def dump_ctags(destfile, navidata, output):
    ctags = os.path.join(os.path.dirname(sys.argv[0]), r'ctags58\ctags')
    cmd = '"%s" -x "%s"' % (ctags, destfile)

    results = navicmd.runcmd(cmd)[0]
    results = results.replace('enum constant', 'enum')  # for java

    # Get contents
    # [[name, type, lineno, token_destfile, code], ...]
    content = []
    for line in results.splitlines():
        # Avoid space in path
        line2 = line.replace(destfile, 'token_destfile')
        dat = line2.split(None, 4)
        if dat[1] not in ['namespace', 'variable', 'macro']:
            content.append(dat)

    # Output, sorted by name_dict
    output.write('] %s\n' % destfile)
    for dat in sorted(content, key=lambda x: (int(name_dict[x[1]][1]), int(x[2]))):
        line = '%-5s  %-3s %s' % (dat[2] + ':', dat[1][0].upper(), dat[4])
        output.write('%-200s###%s\n' % (line, dat[0]))

    # Navidata, sorted by name
    for dat in sorted(content, key=lambda x: x[0].lower()):
        if dat[1] in ('function', ):
            col2 = dat[0]
        else:
            col2 = '%s [%s]' % (dat[0], dat[1])
        line = '%s###%s###%s\n' % (dat[4], col2, 'goto:%s' % (dat[2]))
        navidata.write(line)

if __name__ == '__main__':
    dest = sys.argv[1] if len(sys.argv) >= 2 else sys.argv[0]
    scite_handle = sys.argv[2] if len(sys.argv) >= 3 else '0'

    dest = os.path.abspath(dest)
    print 'Dump ctags, file: "%s"' % (dest)
    fn = os.path.join(tempfile.gettempdir(), 'NaviData_ctags.txt')
    output = StringIO.StringIO()
    lasttime = datetime.datetime.now()
    with open(fn, 'w') as f:
        dump_ctags(dest, f, output)
    print 'Time: ', datetime.datetime.now() - lasttime

    navicmd.navicmd(fn, 'scite:%s' % scite_handle, navicmd.get_naviassist_path())

    output.seek(0, os.SEEK_SET)
    print output.read()

