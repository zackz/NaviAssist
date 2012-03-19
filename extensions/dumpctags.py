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

    content = []  # [[name, type, lineno, token_destfile, code], ...]
    for line in results.splitlines():
        # Avoid space in path
        line2 = line.replace(destfile, 'token_destfile')
        ctx = line2.split(None, 4)
        content.append(ctx)
    content.sort(key=lambda x: (int(name_dict[x[1]][1]), int(x[2])))

    output.write('] %s\n' % destfile)
    for ctx in content:
        if ctx[1].lower() in ('namespace', 'variable', 'macro'):
            continue
        line = '%-5s  %-3s %s' % (ctx[2] + ':', ctx[1][0].upper(), ctx[4])
        output.write('%-200s###%s\n' % (line, ctx[0]))
        line = '%s###%s###%s\n' % (ctx[4], ctx[1], 'goto:%s' % (ctx[2]))
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

    navicmd.navicmd(fn, 'scite:%s' % scite_handle,
                    r'C:\PRJ\AutoScript\NaviAssist\NaviAssist.au3')

    output.seek(0, os.SEEK_SET)
    print output.read()

