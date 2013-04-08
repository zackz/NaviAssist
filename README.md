Navigator Assist
================

Navigator Assist is a handy tool for quickly finding and navigating stuff.
NaviAssist is another small apps as PuTTYAssist, which had wroten for myself
and friends prefer to use keyboard instead of mouse. And NaviAssist is
inspired by [Visual Assist X](http://www.wholetomato.com/)

Getting Started
---------------

* Install [AutoIt(3.3.8+)](http://www.autoitscript.com/site/autoit/downloads/)
  * Or get `AutoIt.exe` and `Include` directory. Clean and minimized, it's preferred way to
run NaviAssist.
  * Or compile excutable file using `build.py`.
* Run NaviAssist.au3, it'll create a default configure same as NaviAssist.sample.ini.
It includes two sample navigator:
  * **Winlist**, navigate to all top windows. (Shortcut: `ALT + F7`)
  * **python doc**, navigate to [Python v2 documentation](http://docs.python.org/2/).
(Shortcut: `ALT + F8`)
* Recommend to install [Python](http://python.org/download/). Some
scripts and extensions are written in python.

Samples
-------

Show all top-level windows, and bring selected window to top.

```ini
Navi1_DATA=
Navi1_HOTKEY=!{F7}
Navi1_CMD=Winlist
```

Show python272 keywords, and open python document with default browser.

```ini
Navi2_DATA=extensions\NaviData_python272.txt
Navi2_HOTKEY=!{F8}
Navi2_CMD=CMDHIDE:cmd.exe /c start %s
```

Same as previous one, but use recommended way to open url. (Firefox and MozRepl
are required)

```ini
Navi5_DATA=extensions\NaviData_python272.chm.txt
Navi5_HOTKEY=!{F2}
Navi5_CMD=FIREFOX
```

Another sample: [Use NaviAssist to enhance PuTTYAssist](https://github.com/zackz/NaviAssist/wiki/Use-NaviAssist-to-enhance-PuTTYAssist)

Settings
--------

### General settings

Height and width of NaviAssist

```ini
WIDTH=600
HEIGHT=300
```

Firefox path is required by command `FIREFOX` and `FIREFOXSEND` used to run a new browser.
NEWFF_CMD can be any browser supported `ALT + D` if just use command `FIREFOXSEND`.

```ini
NEWFF_CMD="C:\Program Files\Mozilla Firefox\firefox.exe"
```

Navigator key starts with `Navi[N]_` (1 <= N < 100)

```ini
Navi1_DATA=
Navi1_HOTKEY=!{F7}
Navi1_CMD=Winlist
```

* `Navi[N]_DATA`, a txt file has lines like `key##category##data`.

A sample navidata file, NaviData_python272.txt

```
AL###(module)###http://docs.python.org/library/al.html#module-AL
BaseHTTPServer###(module)###http://docs.python.org/library/basehttpserver.html#module-BaseHTTPServer
Bastion###(module)###http://docs.python.org/library/bastion.html#module-Bastion
...
```

* `Navi[N]_HOTKEY`, a key combination for Navi[N]: `! is ALT`, `+ is SHIFT`, `^ is CTRL`,
`# is WINKEY`, and [more...](http://www.autoitscript.com/autoit3/docs/functions/Send.htm)

* `Navi[N]_CMD`, do operation after found items.

<table width="100%">
  <tr>
    <th>Navi[N]_CMD</th><th>Description</th>
  </tr>
  <tr>
    <td>WINLIST</td>
    <td>A demo one. Show all top-level windows, and all data is automatically generated.<br>
Navi[N]_DATA is optional, which is a restricted title for searching windows.<br>
For example use "Navi1_DATA=[CLASS:PuTTY]" to search all PuTTY windows.
<a href="http://www.autoitscript.com/autoit3/docs/intro/windowsadvanced.htm">More info about it.</a>
    </td>
  </tr>
  <tr>
    <td>FIREFOX</td>
    <td>Recommended url opener. Require Firefox and
    <a href="https://github.com/bard/mozrepl/wiki/">MozRepl</a> extension.</td>
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
; A shortcut manager
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
Navi3_CMD=SCITE
</pre>
    </td>
  </tr>
</table>

### Extenstions

* **navicmd.py**, a python script for dynamically calling NaviAssist
* CHM document
  * **NaviData_python272.txt**, python272 documents point to
[Python v2 documentation](http://docs.python.org/2/)
  * **NaviData_python272.chm.txt**, python272 documents point to local unpacked chm data
  * **NaviData_AutoIt3.chm.txt**, autoit documents point to local unpacked chm data
* SciTE
  * **dumpfiles**, a extenstion for SciTE - dump files in current file path
  * **dumpctags**, a extenstion for SciTE - dump ctags parsed result of current file
