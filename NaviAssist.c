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

DWORD NAVIAPI ReadData(DWORD nIndex, LPCSTR fn)
{
	FILE * f;
	struct _stat st;
	int n;

	// Read all file data into g_NaviData[nIndex].pData
	ClearNaviData(nIndex);
	f = fopen(fn, "r");
	if (!f || _stat(fn, &st) != 0)
	{
		dbg("Error file? %s, %d", fn, f);
		return 0;
	}
	g_NaviData[nIndex].pData = malloc(st.st_size + 1);
	n = fread(g_NaviData[nIndex].pData, 1, st.st_size, f);
	g_NaviData[nIndex].pData[n] = 0;
	fclose(f);

	// Count lines
	char * pStart;
	char * pNext;
	n = 0;
	for (pStart = g_NaviData[nIndex].pData; *pStart; pStart++)
		if (*pStart == '\n')
			n++;

	// Split data and make lines
	const char szSep[] = "###";
	const int nSep = strlen(szSep);
	char * p1;
	char * p2;
	g_NaviData[nIndex].pLines = (LINEDATA *)malloc(n * sizeof(LINEDATA));
	n = 0;
	pStart = g_NaviData[nIndex].pData;
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
		p2 = p1 ? strstr(p1 + 1, szSep) : NULL;
		if (!p2)
		{
			dbg("Error line? %s", pStart);
			continue;
		}
		memset(p1, 0, nSep);
		memset(p2, 0, nSep);
		(g_NaviData[nIndex].pLines + n)->pKey = pStart;
		(g_NaviData[nIndex].pLines + n)->pCatalog = p1 + nSep;
		(g_NaviData[nIndex].pLines + n)->pData = p2 + nSep;
		n++;
	}
	g_NaviData[nIndex].nLinesCount = n;
	return n;
}

DWORD NAVIAPI UpdateList(DWORD nIndex, HWND hList,
	LPCSTR pszFilter, DWORD nMaxCount)
{
	SendMessage(hList, WM_SETREDRAW, FALSE, 0);
	ListView_DeleteAllItems(hList);

	char bufFilter[200];
	strncpy(bufFilter, pszFilter, sizeof(bufFilter) - 1);
	bufFilter[sizeof(bufFilter) - 1] = 0;
	strlwr(bufFilter);

	LVITEM item;
	char buf[2000];
	char * p1;
	char * p2;
	int i;
	int nNewItem;
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
		p1 = buf;
		strlwr(p1);
		p2 = buf + (pLine->pCatalog - pLine->pKey);
		strlwr(p2);
		if (bufFilter[0] == 0 || strstr(p1, bufFilter) || strstr(p2, bufFilter))
		{
			item.mask = LVIF_TEXT | LVIF_PARAM;
			item.iItem = i;
			item.iSubItem = 0;
			item.pszText = pLine->pKey;
			item.lParam = i;
			nNewItem = ListView_InsertItem(hList, &item);
			ListView_SetItemText(hList, nNewItem, 1, pLine->pCatalog);
			if (--nMaxCount == 0)
				break;
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

