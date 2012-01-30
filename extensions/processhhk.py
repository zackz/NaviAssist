"""Dump data in *.hhk which extracted from chm by 7-Zip

1. Use 7-Zip or other tools extract all data in chm
2. Check *.hhk whether simlar to python272.chm or AutoIt.chm.  If so use
   PythonProcessor or AutoItProcessor to process hhk file.
3. Otherwise derive HHKProcessorBase, and override method parse_object and
   process_4to3 to write particularly processor.

NaviData.txt
Each key takes full line.  key/catalog/data don't include ','.  All lines
sorted by catalog and key.
key,catalog,data
key,catalog,data
......

HHKProcessorBase
  |--PythonProcessor
  |--AutoItProcessor

"""

import re
import os
import datetime
import collections
import xml.etree.ElementTree 

class HHKProcessorBase:
    """Dump data in *.hhk which extracted from chm by 7-Zip
    
    Override method parse_object and process_4to3 to write particularly
    processor.
    """

    def parse_object(self, ele, prefix):
        """Parse object data, return (lastkey, [[key, prefix, name, local], ...])
        
        <OBJECT type="text/sitemap">
        <param name="Keyword" value="!=">
        <param name="See Also" value="!=">
        </OBJECT>
        """
        raise NotImplementedError

    def process_4to3(self, dat):
        """Transfer chm data to NaviAssist data
        
        [[key, prefix, name, local], ...] --> [(key, catalog, data), ...]
        """
        raise NotImplementedError

    def parse_element(self, ele, prefix='', lastkey=''):
        """Parse xml element, return (lastkey, [[key, prefix, name, local], ...])
        
        Keyword arguments:
        ele     -- a xml.etree.ElementTree.Element to be parsed
        prefix  -- from parant level's key
        lastkey -- last object's key for next 'ul' element
        """
        result = []
        if ele.tag.lower() == 'ul':
            if prefix and lastkey:
                prefix = prefix + '>' + lastkey 
            else:
                prefix = prefix + lastkey
            lk = ''  # current lastkey
            for one in ele:
                lk, res = self.parse_element(one, prefix, lk)
                result.extend(res)
                res = re.match(r'(.*?)\s*\([^\(]+?\)', lk)
                if res:
                    lk = res.expand(r'\1')
            return (lastkey, result)
        elif ele.tag.lower() == 'object':
            return self.parse_object(ele, prefix)
        else:
            raise Exception('Unknown tag "%s"' % ele.tag)

    def parse_hhk(self, fn):
        """Parse the hhk file"""
        with open(fn) as f:
            txt = f.read()
        # Remove useless tags
        txt = re.sub(r'<!.*?>', '', txt, flags=re.M|re.S|re.I)
        txt = re.sub(r'<meta.*?>', '', txt, flags=re.M|re.S|re.I)
        txt = re.sub(r'</?html>|</?head>|</?body>|<li>', '', txt,
                     flags=re.M|re.S|re.I)
        # <...> --> <... />
        txt = re.sub(r'<(param.*?)>', r'<\1 />', txt,
                     flags=re.M|re.S|re.I)
        root = xml.etree.ElementTree.XML(txt)
        # [[key, prefix, name, local], ...]
        return self.parse_element(root)[1]

    def process(self, outputname, fns):
        """Process hhk files and output to file
        
        Keyword arguments:
        outputname -- generated output name is outputname.%Y%m%d%H%M%S.txt
        fns        -- [(hhk file, relative path), ...]
        """
        # [[key, prefix, name, local], ...]
        dat = []
        print '-', outputname
        for fn, rdir in fns:
            items = self.parse_hhk(fn)
            print '- hhk: %s, rdir: %s, items: %d' % (fn, rdir, len(items))
            if rdir:
                for i in range(len(items)):
                    items[i][3] = rdir + '/' + items[i][3]
            dat.extend(items)

        # [[key, prefix, name, local], ...] --> [(key, catalog, data), ...]
        result = self.process_4to3(dat)
        HHKProcessorBase.show_catalog(result)

        # Output to file
        fnout = datetime.datetime.now().strftime(
            outputname + '.%Y%m%d%H%M%S.txt')
        print 'Result:   ', fnout
        with open(fnout, 'w') as fout:
            for one in result:
                fout.write('%s###%s###%s\n' % tuple(one))

    @staticmethod
    def show_localdict(localdict, dup):
        print 'locals:', len(localdict)
        for k in localdict:
            if len(localdict[k]) < dup:
                continue
            print '-', len(localdict[k]), k
            for i in localdict[k]:
                print i

    @staticmethod
    def show_catalog(dat):
        counter = collections.Counter()
        counter.update([x[1] for x in dat])
        catalogs = counter.most_common()
        print 'Catalogs: ', len(catalogs), catalogs[:5], '...'


class PythonProcessor(HHKProcessorBase):
    """Parse python272.hhk from python272.chm in python272
    
    python272.hhk
    
    <LI> <OBJECT type="text/sitemap">
        <param name="Keyword" value="!=">
        <param name="See Also" value="!=">
    </OBJECT>
    <UL> <LI> <OBJECT type="text/sitemap">
        <param name="Keyword" value="operator">
        <param name="Local" value="library/stdtypes.html#index-1927">
    </OBJECT>
    </UL>
    
    <LI> <OBJECT type="text/sitemap">
        <param name="Keyword" value="%">
        <param name="See Also" value="%">
    </OBJECT>
    <UL> <LI> <OBJECT type="text/sitemap">
        <param name="Keyword" value="operator">
        <param name="Local" value="library/stdtypes.html#index-1933">
    </OBJECT>
    </UL>
    """

    def parse_object(self, ele, prefix):
        result = []
        key = name = local = ''
        for one in ele:
            k = one.get('name').lower()
            v = one.get('value')
            if k == 'keyword':
                key = v
            elif k == 'name':
                name = v
            elif k == 'local':
                local = v
            elif k == 'see also':
                pass
            else:
                raise Exception('Unknown param "%s", "%s"' % (k, v))
            if key and name and local:
                result.append([key, prefix, name, local])
                name = local = ''
        if local:
            result.append([key, prefix, name, local])
        assert key
        return (key, result)

    def process_4to3(self, dat):
        # Count key and prefix
        counter = collections.Counter()
        counter.update([x[0] for x in dat])
        counter.update([x[1] for x in dat])
        print 'Counter:  ', counter.most_common(5)

        # Local dict for checking duplication
        localdict = collections.defaultdict(list)
        for one in dat:
            localdict[one[3]].append(one)
        #~ HHKProcessorBase.show_localdict(localdict, 20)

        # [[key, prefix, name, local], ...]
        # Remove duplicated items, and make all items count(key) < count(prefix)
        result = []  # [(key, catalog, data), ...]
        for k in localdict:
            localdat = localdict[k]
            for key, prefix, name, local in localdat:
                try:
                    index = localdat.index([prefix, key, name, local])
                    if counter[key] < counter[prefix]:
                        result.append([key, prefix, name, local])
                except ValueError:
                    result.append([key, prefix, name, local])
        print 'Lines new:', len(result)

        # Split and adjust catalog
        result2 = []  # [(key, catalog, data), ...]
        for key, prefix, name, local in result:
            if name:
                name = ' ' + name
            if not prefix:
                res = re.match(r'(.*?)\s*(\([^\(]+?\))', key)
                if res:
                    result2.append((res.group(1) + name, res.group(2), local))
                else:
                    result2.append((key + name, '', local))
            else:
                res = re.match(r'\(.*\)', key)
                if res:
                    result2.append((prefix + name, key, local))
                else:
                    result2.append((key + name, prefix, local))

        # Put catalog "(module)" before others
        keyfunc = lambda x: (x[1] != '(module)', x[1], x[0], x[2])
        return sorted(result2, key=keyfunc)


class AutoItProcessor(HHKProcessorBase):
    """Parse AutoIt3.chm and UDFs3.chm from AutoIt3.3.8
    
    UDFs3 Index.hhk
    
    <LI> <OBJECT type="text/sitemap">
       <param name="Name" value="_ArrayBinarySearch">
       <param name="Local" value="html/libfunctions/_ArrayBinarySearch.htm">
       </OBJECT>
    <LI> <OBJECT type="text/sitemap">
       <param name="Name" value="_ArrayCombinations">
       <param name="Local" value="html/libfunctions/_ArrayCombinations.htm">
       </OBJECT>
    <LI> <OBJECT type="text/sitemap">
       <param name="Name" value="_ArrayConcatenate">
       <param name="Local" value="html/libfunctions/_ArrayConcatenate.htm">
       </OBJECT>
    """

    def parse_object(self, ele, prefix):
        result = []
        name = local = ''
        for one in ele:
            k = one.get('name').lower()
            v = one.get('value')
            if k == 'name':
                name = v
            elif k == 'local':
                local = v
            else:
                raise Exception('Unknown param "%s", "%s"' % (k, v))
            if name and local:
                result.append([name, prefix, '', local])
                name = local = ''
        assert not name and not local
        return (name, result)

    def process_4to3(self, dat):
        result = []
        for a, b, c, d in dat:
            assert not c
            result.append([a, os.path.dirname(d), d])
        return sorted(result, key=lambda x: (x[1], x[0], x[2]))


if __name__ == '__main__':
    
    fns = [
        (r'python272\python272.hhk', 'python272'),
        ]
    PythonProcessor().process('NaviData_python272.chm', fns)
    
    fns = [
        (r'python272\python272.hhk', 'http://docs.python.org'),
        ]
    PythonProcessor().process('NaviData_python272', fns)

    fns = [
        (r'AutoIt3\AutoIt3 Index.hhk', 'AutoIt3'),
        (r'UDFs3\UDFs3 Index.hhk', 'UDFs3'),
        ]
    AutoItProcessor().process('NaviData_AutoIt3.chm', fns)




