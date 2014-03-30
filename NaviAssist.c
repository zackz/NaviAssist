/*
NaviAssist.dll is an optional part of NaviAssist, which is for improving
user experience. In NaviAssist.c rewrote time-consuming parts from
NaviAssist.au3. NaviAssist.dll holds data read from navidata files and
fills them into list directly.

Use MinGW to compile this file:
gcc -shared -o NaviAssist.dll NaviAssist.c -Wl,--kill-at

Exported functions:
void  NAVIAPI SetDBGBits(DWORD bits);
DWORD NAVIAPI ReadData(DWORD nIndex, LPCSTR fn);
DWORD NAVIAPI UpdateList(DWORD nIndex, HWND hList,
	LPCSTR pszFilter, DWORD nMaxCount);
void  NAVIAPI GetSelected(DWORD nIndex, HWND hList,
	BYTE * pRetKey, BYTE * pRetCatalog, BYTE * pRetData);
*/

#include <stdio.h>
#include <sys/stat.h>
#include <windows.h>
#include <commctrl.h>

#define NAVIAPI __stdcall __declspec(dllexport)

typedef struct tagLINEDATA
{
	char * pKey;
	char * pCatalog;
	char * pData;
} LINEDATA;

typedef struct tagNAVIDATA
{
	char *     pData;
	LINEDATA * pLines;
	int        nLinesCount;
} NAVIDATA;

NAVIDATA g_NaviData[100];
DWORD g_dwDebugBits = 0;  // 0: no output, 1: console, 2: OutputDebugString


void dbg(LPCSTR szFormat, ...)
{
	if (g_dwDebugBits == 0)
		return;

	char buf[1024];
	va_list args;
	va_start(args, szFormat);
	_vsnprintf(buf, sizeof(buf), szFormat, args);
	va_end(args);
	buf[sizeof(buf) - 1] = 0;

	if (g_dwDebugBits & 1)
		printf("%s\n", buf);
	if (g_dwDebugBits & 2)
		OutputDebugString(buf);
}

void ClearNaviData(DWORD nIndex)
{
	free(g_NaviData[nIndex].pData);
	free(g_NaviData[nIndex].pLines);
	g_NaviData[nIndex].pData = NULL;
	g_NaviData[nIndex].pLines = NULL;
	g_NaviData[nIndex].nLinesCount = 0;
}

void BuildNaviData(NAVIDATA * pNaviData, char * pData, const char * szSep)
{
	pNaviData->pData = pData;

	// Count lines
	char * pStart = NULL;
	char * pNext = NULL;
	int n = 1;
	for (pStart = pNaviData->pData; *pStart; pStart++)
		if (*pStart == '\n')
			n++;

	// Split data and make lines
	const int nSep = strlen(szSep);
	char * p1 = NULL;
	char * p2 = NULL;
	pNaviData->pLines = (LINEDATA *)malloc(n * sizeof(LINEDATA));
	n = 0;
	pStart = pNaviData->pData;
	for (; pStart; pStart = pNext ? pNext + 1 : NULL)
	{
		pNext = strchr(pStart, '\n');
		if (pNext)
			*pNext = 0;
		while (*pStart == ' ' || *pStart == '\t')
			pStart++;
		if (*pStart == 0 || *pStart == ';')
			continue;  // Empty line or comment ';'
		p1 = strstr(pStart, szSep);
		p2 = p1 ? strstr(p1 + nSep, szSep) : NULL;
		if (!p2)
		{
			dbg("Error line? %s", pStart);
			continue;
		}
		memset(p1, 0, nSep);
		memset(p2, 0, nSep);
		(pNaviData->pLines + n)->pKey = pStart;
		(pNaviData->pLines + n)->pCatalog = p1 + nSep;
		(pNaviData->pLines + n)->pData = p2 + nSep;
		n++;
	}
	pNaviData->nLinesCount = n;
}

DWORD NAVIAPI ReadData(DWORD nIndex, LPCSTR fn)
{
	FILE * f;
	struct _stat st;
	char * buffer = NULL;
	int n;

	ClearNaviData(nIndex);
	f = fopen(fn, "r");
	if (!f || _stat(fn, &st) != 0)
	{
		dbg("Error file? %s, %d", fn, f);
		return 0;
	}
	buffer = malloc(st.st_size + 1);
	n = fread(buffer, 1, st.st_size, f);
	buffer[n] = 0;
	fclose(f);

	BuildNaviData(g_NaviData + nIndex, buffer, "###");
	return g_NaviData[nIndex].nLinesCount;
}

BOOL IsMatched(LPCSTR pszFilter, char * filters[], int fcnt)
{
	// Match all filters
	int i;
	for (i = 0; i < fcnt; i++)
	{
		if (!strstr(pszFilter, filters[i]))
			return FALSE;
	}
	return TRUE;
}

DWORD NAVIAPI UpdateList(DWORD nIndex, HWND hList,
	LPCSTR pszFilter, DWORD nMaxCount)
{
	SendMessage(hList, WM_SETREDRAW, FALSE, 0);
	ListView_DeleteAllItems(hList);

	// Get filters splited by " "
	char bufFilter[200];
	char * p;
	char * filters[sizeof(bufFilter)];  // Never greater then bufFilter's length.
	int fcnt;
	strncpy(bufFilter, pszFilter, sizeof(bufFilter));
	bufFilter[sizeof(bufFilter) - 1] = 0;
	strlwr(bufFilter);
	for (p = bufFilter, fcnt = 0; *p; fcnt++)
	{
		while (*p == ' ')
			*p++ = 0;
		if (!*p)
			break;
		filters[fcnt] = p;
		while (*p && *p != ' ')
			*p++;
	}

	// Update list with filters
	LVITEM item;
	char buf[2000];
	int nItem = 0;
	int i, j;
	for (i = 0; i < g_NaviData[nIndex].nLinesCount; i++)
	{
		const LINEDATA * pLine = g_NaviData[nIndex].pLines + i;
		if (pLine->pData - pLine->pKey > sizeof(buf))
		{
			dbg("Key or catalog is too long, skipped...");
			dbg(pLine->pKey);
			dbg(pLine->pCatalog);
			continue;
		}
		memcpy(buf, pLine->pKey, pLine->pData - pLine->pKey);
		for (j = 0; j < pLine->pData - pLine->pKey - 1; j++)
		{
			if (buf[j] == 0)
				buf[j] = ' ';  // Connect c1 & c2 to one string
		}
		strlwr(buf);
		if (fcnt == 0 || IsMatched(buf, filters, fcnt))
		{
			char tmp[] = "*";
			item.mask = LVIF_TEXT | LVIF_PARAM;
			item.iItem = i;
			item.iSubItem = 0;
			tmp[0] = (nItem < 9) ? ('0' + nItem + 1) : 0;
			item.pszText = tmp;
			item.lParam = i;
			ListView_InsertItem(hList, &item);
			ListView_SetItemText(hList, nItem, 1, pLine->pKey);
			ListView_SetItemText(hList, nItem, 2, pLine->pCatalog);
			nItem++;
			if (--nMaxCount == 0)
			{
				i++;
				break;
			}
		}
	}
	SendMessage(hList, WM_SETREDRAW, TRUE, 0);
	return i;
}

void NAVIAPI GetSelected(DWORD nIndex, HWND hList,
	BYTE * pRetKey, BYTE * pRetCatalog, BYTE * pRetData)
{
	*pRetKey = *pRetCatalog = *pRetData = 0;
	int nItem = ListView_GetNextItem(hList, -1, LVNI_SELECTED);
	if (nItem < 0)
		return;

	LVITEM item;
	item.mask = LVIF_PARAM;
	item.iItem = nItem;
	if (ListView_GetItem(hList, &item))
	{
		const LINEDATA * pLine = g_NaviData[nIndex].pLines + item.lParam;
		strcpy(pRetKey, pLine->pKey);
		strcpy(pRetCatalog, pLine->pCatalog);
		strcpy(pRetData, pLine->pData);
	}
}

void NAVIAPI SetDBGBits(DWORD bits)
{
	g_dwDebugBits = bits;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
	int i;
	switch(fdwReason)
	{
		case DLL_PROCESS_ATTACH:
			memset(g_NaviData, 0, sizeof(g_NaviData));
			break;
		case DLL_PROCESS_DETACH:
			for (i = 0; i < sizeof(g_NaviData) / sizeof(g_NaviData[0]); i++)
				ClearNaviData(i);
			break;
	}
	return TRUE;
}
