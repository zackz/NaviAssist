Navigator Assist
================

Navigator Assist is a handy tool for quickly finding and navigating stuff.
NaviAssist is another small apps as PuTTYAssist, which wroten for myself
and friends prefer to use keyboard instead of mouse. And NaviAssist is
inspired by [Visual Assist X](http://www.wholetomato.com/)

Getting Started
---------------

* [Download](https://github.com/zackz/NaviAssist/downloads) latest zip file.
It includes two sample navigator:
  * **Winlist**, navigate to all top windows
  * **python doc**, navigate to [Python v2.7.2 documentation](http://docs.python.org)
* If you installed [AutoIt(3.3.8)](http://www.autoitscript.com/site/autoit/downloads/)
  * Run NaviAssist.au3 directly
  * Or compile your own excutable file
* Recommend to install [Python](http://python.org/download/releases/2.7.2/). Some
scripts and extensions are written in python.

Samples
-------

Show all top-level windows, and bring selected window to top

```ini
Navi1_DATA=
Navi1_HOTKEY=!{F7}
Navi1_CMD=Winlist
```

Show python272 keywords, and open python document with default browser

```ini
Navi2_DATA=extensions\NaviData_python272.txt
Navi2_HOTKEY=!{F8}
Navi2_CMD=CMDHIDE:cmd.exe /c start %s
```

Same as previous one, but use recommended way to open url. (Firefox and MozRepl
are required)

```ini
Navi2_DATA=extensions\NaviData_python272.txt
Navi2_HOTKEY=!{F8}
Navi2_CMD=FIREFOX
NEWFF_CMD="C:\Program Files\Mozilla Firefox\firefox.exe"
```

Settings
--------

### General settings

Height and width of NaviAssist

```ini
WIDTH=600
HEIGHT=300
```

Firefox path required by command `FIREFOX` and `FIREFOXSEND` used to run a new browser.
NEWFF_CMD can be any browser supported `ALT + D` if just use command `FIREFOXSEND`

```ini
NEWFF_CMD="C:\Program Files\Mozilla Firefox\firefox.exe"
```

Navigator key starts with `Navi[N]_` (1 <= N < 100)

```ini
Navi1_DATA=
Navi1_HOTKEY=!{F7}
Navi1_CMD=Winlist
```

* `Navi[N]_DATA`, a txt file has lines like `key##category##data`

A sample navidata file, NaviData_python272.txt

```
AL###(module)###http://docs.python.org/library/al.html#module-AL
BaseHTTPServer###(module)###http://docs.python.org/library/basehttpserver.html#module-BaseHTTPServer
Bastion###(module)###http://docs.python.org/library/bastion.html#module-Bastion
...
```

* `Navi[N]_HOTKEY`, a key combination for Navi[N]: `! is ALT`, `+ is SHIFT`, `^ is CTRL`,
`# is WINKEY`, and [more...](http://www.autoitscript.com/autoit3/docs/functions/Send.htm)

* `Navi[N]_CMD`, triggered operation after found items

<table>
  <tr>
    <th>Navi[N]_CMD</th><th>Description</th>
  </tr>
  <tr>
    <td>WINLIST</td>
    <td>A demo one. Navi[N]_DATA is not required. All data is automatically generated
    which includes all top-level windows.</td>
  </tr>
  <tr>
    <td>FIREFOX</td>
    <td>Recommended url opener. Require Firefox and MozRepl extension.</td>
  </tr>
  <tr>
    <td>FIREFOXSEND</td>
    <td>Send key sequence to firefox. Not only for firefox.</td>
  </tr>
  <tr>
    <td>CMD</td>
    <td>Run command (replace "%s" with "data")
<pre>
; NavaData.txt
notepad##editor##C:\Windows\System32\notepad.exe
ie##browser##C:\Program Files (x86)\Internet Explorer\iexplore.exe
firefox##browser##C:\Program Files\Mozilla Firefox\firefox.exe
; A link manager
Navi1_DATA=NaviData.txt
Navi1_HOTKEY=!{F7}
Navi1_CMD=CMD:%s
</pre>
    </td>
  </tr>
  <tr>
    <td>CMDHIDE</td>
    <td>Same as CMD except hiding windows.
<pre>
; Another way to open url
Navi2_DATA=extensions\NaviData_python272.txt
Navi2_HOTKEY=!{F8}
Navi2_CMD=CMDHIDE:cmd.exe /c start %s
</pre>
    </td>
  </tr>
  <tr>
    <td>SCITE</td>
    <td>Use <a href="http://www.scintilla.org/SciTEDirector.html">SciTE director interface</a>
    to send command to SciTE
<pre>
; Open files use SciTE. See dumpfiles.py and dumpctags.py
Navi3_DATA=extensions\some_file_list.txt
Navi3_HOTKEY=!{F9}
Navi3_CMD=SCITE:open:%s
</pre>
    </td>
  </tr>
</table>

### Extenstions

* **navicmd.py**, a python script for dynamically calling NaviAssist
* **dumpfiles**, a extenstion for SciTE - dump files in current file path
* **dumpctags**, a extenstion for SciTE - dump ctags parsed result of current file

History
-------

* 0.2.2 Optimizations about parsing file and updating listview (NaviAssist.dll).
* 0.2.1 Optimizations about command line mode and temporary navi (navicmd.py).
Add two extension scripts - dumpfiles and dumpctags.
* 0.2.0 Basic functions and GUI, several command processors:
Winlist/MozRepl/Scite. Sample ini and extensions include dumped python272
and AutoIt CHM files.
