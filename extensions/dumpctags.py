import os
import sys
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

def dump_ctags(destfile, fout):
    cmd = r'ctags58\ctags -x "%s"' % (destfile)
    print cmd

    results = navicmd.runcmd(cmd)[0]
    results = results.replace('enum constant', 'enum')  # for java

    content = []
    for line in results.splitlines():
        # Avoid space in path
        line2 = line.replace(destfile, 'token_destfile')
        ctx = line2.split(None, 4)
        content.append(ctx)
    content.sort(key=lambda x: (name_dict[x[1]][1], x[2]))

    for ctx in content:
        line = '%s###%s###%s\n' % (ctx[4],
                                   '%-10s L:%4s' % (ctx[1], ctx[2]),
                                   'goto:%s' % (ctx[2]))
        fout.write(line)

if __name__ == '__main__':
    dest = sys.argv[1] if len(sys.argv) >= 2 else sys.argv[0]
    scite_handle = sys.argv[2] if len(sys.argv) >= 3 else '0'

    dest = os.path.abspath(dest)
    print 'Dump ctags, file: "%s"' % (dest)
    fn = os.path.join(tempfile.gettempdir(), 'NaviData_ctags.txt')
    with open(fn, 'w') as f:
        lasttime = datetime.datetime.now()
        dump_ctags(dest, f)
        print 'Time: ', datetime.datetime.now() - lasttime

    navicmd.navicmd(fn, 'scite:%s' % scite_handle,
                    r'C:\PRJ\AutoScript\NaviAssist\NaviAssist.au3')


