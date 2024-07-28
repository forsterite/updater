#pragma TextEncoding="UTF-8"
#pragma rtGlobals=3
#pragma version=5.06
#pragma IgorVersion=8
#pragma IndependentModule=Updater
#include <Resize Controls>

// Updater headers
static constant kProjectID=8197 // the project node on IgorExchange
static strconstant ksShortTitle="Updater" // the project short title on IgorExchange

// *********************************************************************
// Use this software at your own risk. Installing and updating projects
// requires that this software downloads from the web, and overwrites
// files on your computer. No warranty is offered against error or
// vulnerability to exploitation of this software or of third-party
// (web) services.

// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
// DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
// PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
// TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.
// *********************************************************************

// This file should be saved in the Igor Procedures folder (look in the
// Help menu for "Show Igor Pro User Files").

// Look in the Misc menu for "IgorExchange Projects..." to open a control
// panel that allows you to browse and install user-contributed packages.

// Options are configurable via the settings button in the control panel.
// Setting the check frequency determines how frequently Updater should
// check for new releases. Checking is done in the background by
// downloading release pages from Wavemetrics.com. If the option to check
// IPFs for new releases is checked, the user procedures folder is
// searched for updater-compliant projects, and the current release
// version is checked against the file version number.

// If you use the control panel to update projects, it's best to set
// the setting for Text Editing like this:
// Look in the Misc menu for Miscellaneus Settings, then select Text
// Editing -> External Editor and check Reload Automatically -> As Soon
// as Modification is Detected.

// If you're developing a package and want to make sure that it's
// compatible with IgorExchange installer:

// It's a good idea to compress (zip) your project file(s) before
// uploading a project release. This is recommended even for single-file
// projects.

// Make sure that the version number fields are filled out correctly,
// and, if your project includes a procedure file, that the version
// number matches that of your file. If your file version is 1.03, set
// the patch version to 03, NOT 3! Updater uses the Major and Patch
// version fields to identify new releases. If you do not fill in at
// least the major version field, your project can be neither installed
// nor updated via the updater control panel.

// Be aware that the version number and location of installed files are
// recorded in the install log on the user's computer at the time of
// installation. If files are moved or replaced by the user this will
// interfere with the updating function of the installer.

// Design your project so that files do not have to be moved into other
// locations after installation. You can provide an itx script as part of
// your package if you need Igor to create shortcuts for XOPs, help
// files, etc. Please include one of the following lines (starting with
// X) in your itx file to identify it as a script to be run after
// installation:

// X // Updater Script
// X // Updater Script for Macintosh
// X // Updater Script for Windows

// note that if you use a script to create aliases and the user
// subsequently uninstalls the project, the aliases will not be cleaned
// up and an error will likely occur. ITX files are moved to the install
// location just like any other file, and moving or deleting an itx file
// will cause the project status to become incomplete.

// If you change the structure of your zip archive between releases,
// Updater may refuse to install the new version as an update. The user
// can still choose to uninstall the old version and then install the new
// version in the install tab.

// ---------------- Command line options ---------------------------------

// Updater#Install("archull")
// Installs archull project in location chosen by user

// Updater#Install("https://www.wavemetrics.com/project-releases/7399")
// same as above

// Updater#Install("archull;baselines;", path=SpecialDirPath("Igor Pro User Files",0,0,0)+"User Procedures:")
// Installs archull and baselines projects in specified location

// updater#InstallFile(fileName) function for use in itx scripts

// ----------------------- Details ----------------------------------

// An install log and cache file are saved in the User Procedures folder.
// When projects are installed using the IgorExchange installer, details
// of the installation are recorded in the install log. Moving or deleting
// the install log or any of the installed files will interfere with the
// update-checking functions.

// I'm grateful to Jim Prouty and Jeff Weimer, both of whom have made
// suggestions and tested development versions of this project. Please
// let me know about any new bugs you find.

// Required igor version is not accessible for recent project releases.
// In older releases this information was encoded in the version string,
// but that's not currently enforced. Updater requires Igor Pro 8+, so
// projects requiring Igor 9+ may become problematic in the future.

// feedback? ideas? send me a note: https: www.wavemetrics.com/user/tony

constant kNumProjects = 270 // provides a rough idea of the minimum number of user-contributed projects that can be found at wavemetrics.com
constant kRemoveSuffix = 1 // if a single file is downloaded that has a name that looks like it has
 								// a suffix added to make the file unique, remove that suffix.
strconstant ksIgnoreFilesList = ".DS_Store;Install Updater.itx;" // list of files that shouldn't be copied, wildcards okay
strconstant ksIgnoreFoldersList = "__MACOSX;" // list of folders that shouldn't be copied, wildcards okay
strconstant ksBackupLocation = "Desktop" // set the value of dirIDStr for SpecialDirPath here
strconstant ksDownloadLocation = "Temporary" // displayHelpTopic "SpecialDirPath" for details
strconstant ksLogPath = "User Procedures:IgorExchange Installer:" // path to location for log files, starting from User Files
strconstant ksHistoryFile = "History.txt" // Installation and update activity is recorded in this file
strconstant ksCacheFile = "Cache.txt" // file used as cache for information parsed from IgorExchange web pages
strconstant ksLogFile = "Install.log" // file used to record details of each installed project

strconstant ksProjectsDimLabelsList = "projectID;ProjectCacheDate;name;author;published;views;type;userNum;;;"
strconstant ksUpdatesDimLabelsList = "projectID;name;status;local;remote;system;releaseDate;installPath;releaseURL;releaseIgorVersion;installDate;filesInfo;releaseInfo;lastUpdate;;"

// location for a failsafe file, can be used to restore updater if the IgorExchange website format is changed
strconstant ksGitHub = "https://raw.githubusercontent.com/forsterite/updater/main/Updater.ipf"

// User-configurable settings are accessible from the control panel: Misc -> IgorExchange Projects...

//#define testing
//#define debug

menu "Misc"
	"-"
	"IgorExchange Projects", /Q, updater#makeInstallerPanel()
	"-"
end

// ------------------------------------------------------------------
// ***  Hook and related functions for initiating periodic checks ***

static function IgorStartOrNewHook(string igorApplicationNameStr)
	variable startTicks = ticks + 60*2 // start in 2 seconds - plenty of time to allow an experiment to be opened
	CtrlNamedBackground BGUpdaterDelayedStartDL, Proc=updater#StartDownloadThreadForHook, start=startTicks
	ExperimentModified 0 // this will allow an experiment to be loaded by double-clicking
	return 0
end

// if we always open Igor by double-clicking an experiment file, this
// will enable checking update status in a preemptive thread
static function AfterFileOpenHook(refNum, fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr, fileKind)
	variable refNum, fileKind
	string fileNameStr, pathNameStr, fileTypeStr, fileCreatorStr
	
	if (fileKind == 1 || fileKind == 2)
		CtrlNamedBackground BGUpdaterStartDL, Proc=updater#StartDownloadThreadForHook, start
	endif
	return 0
end

// runs in BG at startup
function StartDownloadThreadForHook(STRUCT WMBackgroundStruct &s)
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	if ( (datetime-prefs.lastCheck) < prefs.frequency)
		#ifdef debug
		Print "StartDownloadThreadForHook() completed without starting preemptive thread"
		#endif
		return 1 // Getting here should be fast!
	endif
	
	int options = 1 + 2 // projects list and updates list based on installation log
	if (!(prefs.options & 4))
		options += 4 // updates for files not in install log
	endif
	
	StartPreemptiveDownload(options, "")
	return 1
end

// start preemptive download and cooperative bg task
// options:
//  bit 0: projects list - get info from index pages
//  bit 1: installed projects - get info from release pages
//  bit 2: ipfs in user procs (default is all installed projects)
//  bit 3: ipfs open in experiment
function StartPreemptiveDownload(int options, string projectID, [variable pagenum])
	
	#ifdef THREADING_DISABLED
	return 1
	#endif
		
	#ifdef debug
	Print "StartPreemptiveDownload() started"
	if (ParamIsDefault(pagenum)==0)
		Print "Pagenum", pagenum
	endif
	#endif
	
	// create an input folder for preemptive task
	KillDataFolder/Z root:InstallerBG
	NewDataFolder/O root:InstallerBG
	NewDataFolder/O root:InstallerBG:dfrIn
	DFREF dfrIn = root:InstallerBG:dfrIn
	
	// remove empty lines from log file - not sure why it should happen,
	// but older versions of updater may have caused this
	LogCleanup(projects=0)
	
	// get a list of projects from the log file and save the projectIDs in a text wave
	string ProjectsList = ""
	if (options & 2)
		if (strlen(projectID))
			ProjectsList = projectID
		else
			ProjectsList = ListOfProjectsFromInstallLog()
		endif
	endif
	wave/T w_InstalledProjectIDs = ListToTextWave(ProjectsList,";")
	int numInstalled = DimSize(w_InstalledProjectIDs, 0)
	Make/N=(numInstalled) dfrIn:w_InstalledVersions /wave=w_InstalledVersions
	if (numInstalled)
		w_InstalledVersions = str2num(LogGetVersion(w_InstalledProjectIDs))
	endif
	
	// get a list of project IDs and version numbers for procedure files
	// in user procedures folder. this is a bit slow.
	if (options&12 && strlen(projectID))
		wave w_UserProjects = ProjectWave(projectID)
	elseif (options & 4)
		wave w_UserProjects = UserProcsProjectsWave()
	elseif (options & 8)
		wave w_UserProjects = ExperimentProcsProjectsWave()
	else
		Make/free/N=(0,2) w_UserProjects
	endif
	// w_UserProjects is a 2D numeric wave with project IDs in the first column
	// and current versions in second column
	int numNotInstalled = DimSize(w_UserProjects, 0)
	
	if (numNotInstalled > 0)
		Redimension/N=(numInstalled+numNotInstalled) w_InstalledProjectIDs, w_InstalledVersions
		w_InstalledProjectIDs[numInstalled, Inf] = num2istr(w_UserProjects[p-numInstalled][0])
		w_InstalledVersions[numInstalled, Inf] = w_UserProjects[p-numInstalled][1]
	endif
	
	RemoveDuplicates(w_InstalledProjectIDs, wrefs={w_InstalledVersions})
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	// put a list of projects from the log file and the timeout prefs setting
	// into preemptive task input queue
	MoveWave w_InstalledProjectIDs dfrIn:w_InstalledProjectIDs
	variable/G dfrIn:v_timeout = prefs.pagetimeout
	variable/G dfrIn:v_options = options
	string/G   dfrIn:s_project = projectID
	variable/G dfrIn:v_pagenum = ParamIsDefault(pagenum) ? -1 : pagenum
		
	WAVEClear w_InstalledProjectIDs, w_InstalledVersions
	DFREF dfrIn = $""
			
	variable/G root:InstallerBG:threadGroupID
	NVAR threadGroupID = root:InstallerBG:threadGroupID
	threadGroupID = ThreadGroupCreate(1)
	
	#ifndef THREADING_DISABLED
	ThreadStart threadGroupID, 0, PreemptiveDownloader()
	ThreadGroupPutDF threadGroupID, root:InstallerBG:dfrIn
	#endif
	
	// preemptive thread is now downloading
	#ifdef debug
	Print "PreemptiveDownloader thread started"
	#endif
		
	// okay to start if it's already running
	// start cooperative BG task to deal with downloads when they're done
	CtrlNamedBackground BGCheck, period=1*60, Proc=BackgroundCheck, start
	
	#ifdef debug
	Print "Cooperative BG task started with period 1s"
	#endif
	
	CtrlNamedBackground animation, period=30, Proc=AnimateButton
	CtrlNamedBackground animation, start
	
	return 1 // task doesn't repeat
end

// RemoveDuplicates(w, wrefs={w1}) removes duplicates from textwave w
// and corresponding points in waves referenced in wrefs
threadsafe function RemoveDuplicates(wave/T w, [wave/Z/wave wrefs])
	int i, j
	for (i=numpnts(w)-1;i>=0;i-=1)
		FindValue/TEXT=w[i] w
		if (V_value>-1 && V_value<i)
			DeletePoints i, 1, w
			if (WaveExists(wrefs))
				for (j=0;j<numpnts(wrefs);j+=1)
					DeletePoints i, 1, wrefs[j]
				endfor
			endif
		endif
	endfor
	return numpnts(w)
end

// runs in its own thread, downloads and parses the web pages needed to
// check for new releases of installed projects and to create an up-to-
// date list of projects for the IgorExchange Installer panel projects
// tab
threadsafe function PreemptiveDownloader()
	DFREF dfrIn = ThreadGroupGetDFR(0, Inf) // waits here for dfr
	if ( DataFolderRefStatus(dfrIn) == 0 )
		return -1	 // Thread is being killed
	endif
	
	NVAR timeout = dfrIn:v_timeout
	NVAR options = dfrIn:v_options
	NVAR pagenum = dfrIn:v_pagenum
	SVAR projectID = dfrIn:s_project
	wave/T w_InstalledProjectIDs = dfrIn:w_InstalledProjectIDs
	wave w_InstalledVersions = dfrIn:w_InstalledVersions
	
	// create output folder
	NewDataFolder/S resultsDF
	Make/T/N=(DimSize(w_InstalledProjectIDs, 0)) w_InstalledProjectsDL
	
	// save some text from project web pages in w_InstalledProjectsDL
	// each point of w_InstalledProjectsDL will be filled with a list
	if (numpnts(w_InstalledProjectsDL))
		w_InstalledProjectsDL = DownloadStringlistFromProjectPage(w_InstalledProjectIDs[p], timeout)
	endif
	
	// put the local version info into output queue
	MoveWave w_InstalledVersions :w_InstalledVersions
	
	// reload the projects list
	if (options & 1)
		if (pagenum >=0)
			wave/T w_AllProjectsDL = DownloadProjectsList(timeout, projectID, page=pagenum)
		else
			wave/T w_AllProjectsDL = DownloadProjectsList(timeout, projectID)
		endif
		Duplicate w_AllProjectsDL :w_AllProjectsDL
	else
		Make/T/N=0 :w_AllProjectsDL
	endif
	
	// copy the input settings to the output folder in case we are downloading sequentially
	variable/G :v_pagenum = pagenum
	string/G   :s_project = projectID
	variable/G :v_options = options
	variable/G :v_timeout = timeout
	
	// check the version version of updater in the GitHub repository
	variable/G :GitVer /N=GitVer
	string/G   :strAlert /N=strAlert
	
	variable gv
	string alrt
	[gv, alrt] = GetGitHubVersion(timeout)
	GitVer = gv
	strAlert = alrt
	
	NVAR/Z GitVer = $"" // not strictly required,
	SVAR/Z strAlert = $""
	// but good to clear all references to objects in the output data folder
		
	// ThreadGroupPutDF requires that no waves in the data folder be referenced
	WAVEClear w_InstalledProjectsDL, w_InstalledProjectIDs, w_AllProjectsDL, w_InstalledVersions
	ThreadGroupPutDF 0, : // Send output data folder to output queue
	KillDataFolder dfrIn
	
	#ifdef debug
	Print "PreemptiveDownloader() finished"
	#endif
	return 0
end

// returns a 1D wave containing project info from WM index pages
// Each point contains a stringlist:
// projectID;ProjectCacheDate;title;author;published;views;type;userNum;
threadsafe function/WAVE DownloadProjectsList(variable timeout, string ProjectList, [int page])
	Make/free/T/N=(0) AllProjectsWave
	
	int pageNum, projectNum, pStart, pEnd, selStart, selEnd
	string baseURL = "", projectsURL = "", url = ""
	string projectID = "", strName = "", strUserNum = "", strAuthor = "", strProjectURL = ""
	string strType = "", strPublished = "", strViews = ""
	string strLine = ""
	string strDate = num2istr(datetime)
	
	baseURL = "https://www.wavemetrics.com"
	projectsURL = "/projects?os_compatibility=All&project_type=All&field_supported_version_target_id=All&page="
	
	int startPage = ParamIsDefault(page) ? 0 : page
	int maxPage = ParamIsDefault(page) ? 49 : page
	
	// loop through listPages
	for (pageNum=startPage;pageNum<=maxPage;pageNum+=1)
		sprintf url "%s%s%d", baseURL, projectsURL, pageNum

		URLRequest/time=(timeout)/Z url=url
		if (V_flag)
			return AllProjectsWave
		endif

		pStart = strsearch(S_serverResponse, "<section class=\"Project-teaser-wrapper\">", 0, 2)
		if (pStart == -1)
			break // no more projects
		endif
		pEnd = 0
		
		// loop through projects on listPage
		for (projectNum=0;projectNum<50;projectNum+=1)
			pStart = strsearch(S_serverResponse, "<section class=\"Project-teaser-wrapper\">", pEnd, 2)
			pEnd = strsearch(S_serverResponse, "<div class=\"Project-teaser-footer\">", pStart, 2)
			if (pEnd==-1 || pStart==-1)
				break // no more projects on this listPage
			endif
			
			selStart = strsearch(S_serverResponse, "<a class=\"user-profile-compact-wrapper\" href=\"/user/", pEnd, 3)
			if (selStart < pStart)
				continue
			endif
			
			selStart += 52
			selEnd = strsearch(S_serverResponse, "\">", selStart, 0)
			strUserNum = S_serverResponse[selStart,selEnd-1]
			
			selStart = strsearch(S_serverResponse, "<span class=\"username-wrapper\">", selEnd, 2)
			selStart += 31
			selEnd = strsearch(S_serverResponse, "</span>", selStart, 2)
			strAuthor = S_serverResponse[selStart,selEnd-1]
					
			selStart = strsearch(S_serverResponse, "<a href=\"", selEnd, 2)
			selStart += 9
			selEnd = strsearch(S_serverResponse, "\"><h2>", selStart, 2)
			strProjectURL = baseURL + S_serverResponse[selStart,selEnd-1]
			
			selStart = selEnd + 6
			selEnd = strsearch(S_serverResponse, "</h2></a>", selStart, 2)
			strName = S_serverResponse[selStart,selEnd-1]
			
			if (strlen(strName) == 0)
				continue
			endif
			
			// clean up project names that contain certain encoded characters
			strName = RemoveHTMLEncoding(strName)
			
			projectID = ParseFilePath(0, strProjectURL, "/", 1, 0)
			
			if (strlen(ProjectList) && FindListItem(projectID, ProjectList)==-1)
				continue
			endif
			
			// search for other non-essential parameters
			
			// project types
			selEnd = pStart
			strType = ""
			do
				selStart = strsearch(S_serverResponse, "/taxonomy/", selEnd, 2)
				selStart = strsearch(S_serverResponse, ">", selStart, 0)
				selEnd = strsearch(S_serverResponse, "<", selStart, 0)
				if (selStart<pStart || selEnd>pEnd || selEnd<1 )
					break
				endif
				strType += S_serverResponse[selStart+1,selEnd-1] + ","
			while (1)
			
			// date
			selStart = strsearch(S_serverResponse, "<span>", pEnd, 2)
			selEnd = strsearch(S_serverResponse, "</span>", pEnd, 2)
			if (selStart>0 && selEnd>0 && selEnd<(pEnd+80))
				strPublished = ParsePublishDate(S_serverResponse[selStart+6,selEnd-1])
			endif
			
			// views
			selEnd = strsearch(S_serverResponse, " views</span>", pEnd, 2)
			selStart = strsearch(S_serverResponse, "<span>", selEnd, 3)
			if (selStart>pEnd && selEnd<(pEnd+150))
				strViews = S_serverResponse[selStart+6,selEnd-1]
			else
				selEnd = strsearch(S_serverResponse, " view</span>", pEnd, 2)
				selStart = strsearch(S_serverResponse, "<span>", selEnd, 3)
				if (selStart>pEnd && selEnd<(pEnd+150))
					strViews = S_serverResponse[selStart+6,selEnd-1]
				endif
			endif

			sprintf strLine, "%s;%s;%s;%s;%s;%s;%s;%s;", projectID, strDate, strName, strAuthor, strPublished, strViews, strType, strUserNum
			if (ItemsInList(strLine) != 8)
				continue // an extra semicolon would corrupt the cache
			endif
			AllProjectsWave[numpnts(AllProjectsWave)] = {strLine}
			
		endfor	 // next project
	endfor	 // next page
	return AllProjectsWave
end

// cooperative BG task to deal with downloads when they're done
function BackgroundCheck(STRUCT WMBackgroundStruct &s)
	
	int debugging = 0
	#ifdef debug
	debugging = 1
	#endif
	
	if (debugging)
		printf "%s BackgroundCheck: ", time()
	endif

	NVAR threadGroupID = root:InstallerBG:threadGroupID
	DFREF dfr = ThreadGroupGetDFR(threadGroupID, 0) // Get free data folder from output queue
	if ( DataFolderRefStatus(dfr) == 0 )
		if (debugging)
			Print "preemptive task still running"
		endif
		return 0 // task repeats in main thread until folder is ready
	endif
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	wave/T/SDFR=dfr w_InstalledProjectsDL, w_AllProjectsDL
	wave w_InstalledVersions = dfr:w_InstalledVersions
	
	CachePutWave(w_AllProjectsDL, 0)
	CachePutWave(w_InstalledProjectsDL, 1)
	
	// check status of each project
	variable remote
	int i
	int numProjects = DimSize(w_InstalledProjectsDL, 0)
	int UpdateAvailable = 0, notInstalled = 0, checkGit = 1
	string fileStatus, projectID, strList
	
	int gui = WinType("InstallerPanel") == 7
		
//	ReleaseCacheDate;shortTitle;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;
	
	if ((!gui) || debugging)
		
		for (i=0;i<numProjects;i+=1)
			strList = w_InstalledProjectsDL[i]
			if (strlen(strList) == 0)
				continue
			endif
			projectID = StringFromList(0, strList)
			fileStatus = GetInstallStatus(projectID)
			if (strlen(fileStatus) && cmpstr(fileStatus, "complete"))
				// installed but not complete
				continue
			endif
			remote = str2num(StringFromList(3, strList)) //NumberByKey("remote", keyList)
			
			if ((w_InstalledVersions[i] + 1e-5) < remote) // small increment corrects for single precision floating point representation
				string strName = StringFromList(2, strList)
				string cmd = ""
				sprintf cmd, "New project release found: %s %0.2f\r", strName, remote
				WriteToHistory(cmd, prefs, 0)
				UpdateAvailable += 1
				if (strlen(fileStatus) == 0)
					notInstalled += 1
				endif
				// if the new release is not compatible with current Igor version
				// we will not find out until an update is attempted.
				
				// this is not ideal, and will become a problem when Igor 9+
				// versions are released for projects that have an Igor 8
				// compatible version.
			endif
		endfor
	endif
	
	variable tstatus = ThreadGroupRelease(threadGroupID)
	if (tstatus == -2)
		Print "Updater thread would not quit normally, had to force kill it. Restart Igor."
	endif
	KillVariables threadGroupID
	
	KillDataFolder/Z root:InstallerBG:
	
	NVAR/SDFR=dfr GitVer = GitVer
	SVAR/SDFR=dfr strAlert = strAlert
	if (debugging)
		Print "Updater version =", GetThisVersion()
		Print "GitHub version =", GitVer
		Print "Alert =", strAlert
	endif
	
	// if alert string has been set, trigger an emergency repair
	if (strlen(strAlert) && GitVer > GetThisVersion())
		CtrlNamedBackground animation, stop
		DoAlert 0, strAlert
		RepairUpdater()
		return 0
	endif
	
	if (!gui)
		
		if (UpdateAvailable==1 && GrepString(strName, "Updater$"))
			if (GetThisVersion() >= remote)
				LogSyncWithProjectFile("8197")
				UpdateAvailable = 0 // this may prevent us from fixing a file with version higher than current release version
			endif
		endif
			
		if (UpdateAvailable)
			DoAlert 1, "An IgorExchange Project update is available.\rDo you want to view updates?"
			if (v_flag == 1)
				// kill control panel before setting panel options in prefs
				KillWindow/Z InstallerPanel
				
				LoadPrefs(prefs)
				prefs.paneloptions = prefs.paneloptions | 1 // set tab to 1
				
				if (notInstalled == UpdateAvailable) // none of updated projects are in install log
					prefs.paneloptions = prefs.paneloptions | 4 // select user procs folder in popup
				endif
				
				SavePackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
				MakeInstallerPanel()	// use the data we stashed in the cache to create panel
				SetWindow InstallerPanel UserData(GitVer) = num2str(GitVer)
				checkGit = 0 // don't check github version if user will try to update via panel
			endif
		endif
		
		if (checkGit && GitVer>GetThisVersion())
			DoAlert 1, "It looks like Updater may need to be repaired or updated\r\rDo you want to update to version " + num2str(GitVer) + "?"
			if (v_flag == 1) // yes
				RepairUpdater(silently=2)
			endif
		endif
	endif
			
	SVAR PID = dfr:s_project
	
	if (gui)
		ControlInfo/W=InstallerPanel tabs
		if (v_value == 0)
			ReloadProjectsList(forced=1) // force load from cache
		else
			ReloadUpdatesList(2) // force reload of local file
		endif
		UpdateListboxWave(fGetStub())
		SelectProject(PID)
	endif
	
	NVAR/SDFR=dfr pagenum = v_pagenum
	NVAR/SDFR=dfr options = v_options
	
	if (pagenum>=0 && DimSize(w_AllProjectsDL, 0))
		StartPreemptiveDownload(options, "", pagenum=pagenum+1)
		return 0
	endif
	
	// check that we have not just refreshed one project
	if (strlen(PID) == 0)
		LoadPrefs(prefs)
		prefs.lastCheck = datetime
		SavePackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
	endif
		
	CtrlNamedBackground animation, stop
	
	if (debugging)
		Print "preemptive task complete, number of updates available =", UpdateAvailable
	endif
	
	return 1 // bg task doesn't repeat
end

// --------------------------------------------------------------
// *** package preferences ***

// define some constants for saving preferences for this package
strconstant ksPackageName = "Updater"
strconstant ksPrefsFileName = "UpdaterPrefs.bin"
constant kPrefsVersion = 100

structure PackagePrefs
	uint32 version      // 4 bytes, structure version
	uint32 frequency    // 4 bytes
	uint16 pagetimeout  // 2 bytes
	uint16 filetimeout  // 2 bytes
	uchar  options		 // 1 byte, 8 bits to set
	uchar  paneloptions // 1 byte
	uchar  dateFormat   // 1 byte, deprecated
	uchar  tab          // 1 byte to record active tab
	STRUCT Rect win     // window position and size, 8 bytes
	uint32 lastCheck    // 4 bytes
	                    // 28 bytes used
	uint32 reserved[121]	// 484 bytes reserved for future use
endstructure // 512 bytes

// set prefs structure to default values
function PrefsSetDefault(STRUCT PackagePrefs &prefs)
	prefs.version      = kPrefsVersion
	prefs.frequency    = 604800 // weekly
	prefs.pagetimeout  = 6
	prefs.filetimeout  = 15
	prefs.options      = 0 // bit 0 save backups, 1 print to history, 2 limit release check to installed files
	prefs.paneloptions = 0 // bit 0: tab, bit 1: bigger panel, bit 2: select user proc folder in popup menu
	prefs.dateformat   = 0 // deprecated
	prefs.tab          = 0 // for now we're using bit 0 of prefs.paneloptions for tab.
	prefs.win.left     = 20
	prefs.win.top      = 20
	prefs.win.right    = 20 + 520
	prefs.win.bottom   = 20 + 355
	prefs.lastCheck    = 0 // last check time, rounded to seconds
	int i
	for (i=0;i<(121);i+=1)
		prefs.reserved[i] = 0
	endfor
end

function LoadPrefs(STRUCT PackagePrefs &prefs)
	LoadPackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
	if (V_flag!=0 || V_bytesRead==0 || prefs.version!=kPrefsVersion)
		PrefsSetDefault(prefs)
	endif
end

// Not used by Igor versions >= 9
function GetScreenHeight()
	string strInfo = StringByKey("SCREEN1", IgorInfo(0))
	variable rectPos = strsearch(strInfo, "RECT=", 0)
	strInfo = strInfo[rectPos+5, strlen(strInfo)-1]
	variable scrnLeft, scrnTop, scrnRight, scrnBottom
	sscanf strInfo, "%d,%d,%d,%d", scrnLeft, scrnTop, scrnRight, scrnBottom
	return scrnBottom - scrnTop
end
	
function MakePrefsPanel([variable WL, variable WT])
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	KillWindow/Z UpdaterPrefsPanel
	
	GetWindow/Z InstallerPanel wsizeRM
	if (v_flag == 0)
		WL = ParamIsDefault(WL) ? V_right : WL
		WT = ParamIsDefault(WT) ? V_top : WT
	endif
	
	if (IgorVersion() < 9)
		variable sHeight = GetScreenHeight(), sMinHeight = 700
		if (prefs.paneloptions & 2)
			if (sHeight >= sMinHeight)
				Execute/Q/Z "SetIgorOption PanelResolution=?"
				NVAR vf = V_Flag
				variable oldResolution = vf
				Execute/Q/Z "SetIgorOption PanelResolution=96"
				// make a correction to window coordinates
				WL *= ScreenResolution/96; WT *= ScreenResolution/96
			else
				prefs.paneloptions -= 2
			endif
		endif
	endif
	
	variable frequencyPopMode
	switch (prefs.frequency)
		case 0:
			frequencyPopMode = 1 // always
			break
		case 86400:
			frequencyPopMode = 2 // daily
			break
		case 604800:
			frequencyPopMode = 3 // weekly
			break
		case 2592000:
			frequencyPopMode = 4 // monthly
			break
		default:
			frequencyPopMode = 5 // never
	endswitch
	
	NewPanel/K=1/N=UpdaterPrefsPanel/W=(WL,WT,WL+215,WT+345) as "Settings"
	ModifyPanel/W=UpdaterPrefsPanel, fixedSize=1, noEdit=1
	
	variable left = 15
	variable top = 10
	Button btnRepair,win=UpdaterPrefsPanel,pos={left,top},title="Repair Updater...",size={125,22},Proc=updater#PrefsButtonProc
	Button btnRepair,win=UpdaterPrefsPanel,help={"Repair uploader by downloading a fresh copy"}
	top += 30
	Button btnClearCache,win=UpdaterPrefsPanel,pos={left,top},title="Clear Cache",size={85,22},Proc=updater#PrefsButtonProc
	Button btnClearCache,win=UpdaterPrefsPanel,help={"Clear downloaded project release info from cache"}
	top += 30
	PopupMenu popFrequency,win=UpdaterPrefsPanel,pos={left,top},value="always*;daily;weekly;monthly;never;"
	PopupMenu popFrequency,win=UpdaterPrefsPanel,title="Check for Updates", mode=frequencyPopMode, fsize=12
	PopupMenu popFrequency,win=UpdaterPrefsPanel,help={"How frequently to check for updates for installed packages"}
	top += 25
	CheckBox checkInstalled,win=UpdaterPrefsPanel,pos={left,top},size={141.00,16.00},title="Include IPFs in Check"
	CheckBox checkInstalled,win=UpdaterPrefsPanel,fSize=12,value=!(prefs.options&4)
	CheckBox checkInstalled,win=UpdaterPrefsPanel,help={"Search user procedures for IPFs with update headers"}
	top += 25
	TitleBox titleFreq,win=UpdaterPrefsPanel,pos={left,top}, frame=0, fsize=10
	TitleBox titleFreq,win=UpdaterPrefsPanel,title="* Checking for updates more\rfrequently than weekly is not\rrecommended. 'Always' is for\rtesting only."
	top += 60
	TitleBox titleDL, pos={left,top},frame=0,win=UpdaterPrefsPanel,title="Timeout for Downloads (s):", fsize=12
	top += 20
	SetVariable setvarPage,win=UpdaterPrefsPanel,pos={left,top}, title="Web Pages", value=_NUM:prefs.pagetimeout
	SetVariable setvarPage,win=UpdaterPrefsPanel,size={95,20}, limits={1,25,0}, fsize=12
	SetVariable setvarPage,win=UpdaterPrefsPanel,help={"Sets timeout for URLrequest. Use larger value for slow connections."}
	SetVariable setvarFile,win=UpdaterPrefsPanel,pos={120,top}, title="Files", value=_NUM:prefs.filetimeout
	SetVariable setvarFile,win=UpdaterPrefsPanel,size={60,20}, limits={1,25,0}, fsize=12
	SetVariable setvarFile,win=UpdaterPrefsPanel,help={"Sets timeout for URLrequest. Use larger value for slow connections."}
	top += 30
	CheckBox checkBackups,win=UpdaterPrefsPanel,pos={left,top},size={141.00,16.00},title="Backup Files Replaced  \rDuring Install or Update"
													// maybe simply "Backup Files Before Replacing"
	CheckBox checkBackups,win=UpdaterPrefsPanel,fSize=12,value=prefs.options&1
	CheckBox checkBackups,win=UpdaterPrefsPanel,help={"Backup files to a folder on the desktop"}
	top += 35
	CheckBox checkHistory,win=UpdaterPrefsPanel,pos={left,top},size={141.00,16.00},title="Write to Experiment History"
	CheckBox checkHistory,win=UpdaterPrefsPanel,fSize=12,value=prefs.options&2
	CheckBox checkHistory,win=UpdaterPrefsPanel,help={"Mirror history file entries to experiment history"}
	top += 20
	CheckBox checkBigger,win=UpdaterPrefsPanel,pos={left,top},size={141.00,16.00},title="Bigger Panel (Igor 8)"
	CheckBox checkBigger,win=UpdaterPrefsPanel,fSize=12,value=prefs.paneloptions&2
	CheckBox checkBigger,win=UpdaterPrefsPanel,help={"Control panel size will be slightly increased"}
	CheckBox checkBigger,win=UpdaterPrefsPanel,disable=2*(sHeight<sMinHeight || IgorVersion()>=9)
	top += 25
	Button ButtonSave,win=UpdaterPrefsPanel,pos={15,top},size={100,22},title="Save Settings", valueColor=(65535,65535,65535), fColor=(0,0,65535), Proc=updater#PrefsButtonProc
	Button ButtonCancel,win=UpdaterPrefsPanel,pos={135,top},size={70,22},title="Cancel", Proc=updater#PrefsButtonProc
	
	SetWindow UpdaterPrefsPanel, hook(hEnter)=updater#hookPrefsPanel
	
	if (IgorVersion()<9 && prefs.paneloptions&2)
		// reset panel resolution
		Execute/Q/Z "SetIgorOption PanelResolution=" + num2istr(oldResolution)
	endif
end

function PrefsButtonProc(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	int redraw = 0
	string filepath = ""
	strswitch (s.ctrlName)
		case "BtnRepair":
			if (RepairUpdater())
				KillWindow/Z $s.win
			endif
			return 0
		case "BtnClearCache":
			return CacheClearAll()
		case "btnHistoryClear":
			DoAlert/T="Clear All History" 1, "Are you sure you want to clear the History log file?"
			if (v_flag == 1)
				filePath = GetInstallerFilePath(ksHistoryFile)
				int refnum
				Open/Z refnum as filePath
				if (V_flag == 0)
					variable version = GetProcVersion(FunctionPath(""))
					fprintf refnum, "Cache file created by IgorExchange Installer %0.2f\r\n", version
					Close refnum
					string str = ""
					sprintf str, "Cache file created by IgorExchange Installer %0.2f\r", version
					Notebook HistoryPanel#nbHistory selection={StartOfFile,EndOfFile}, text=str
				endif
			endif
			break
		case "btnHistoryShow":
			NewPath/O/Q tempPathIXI, ParseFilePath(1, GetInstallerFilePath(ksHistoryFile), ":", 1, 0)
			PathInfo/SHOW tempPathIXI
			KillPath/Z tempPathIXI
			break
		case "btnHistoryOpen":
			GetWindow $s.win wsizeRM
			filePath = GetInstallerFilePath(ksHistoryFile)
			OpenNotebook/Z/N=HistoryNotebook/W=(V_left,v_top,v_right,v_bottom) filePath
			Notebook HistoryNotebook, writeProtect=1
			KillWindow/Z $s.win
			break
		case "ButtonSave":
			// run PrefsSync, return value tells us whether updates need to be made
			redraw = PrefsSync()
		case "ButtonCancel": // cancel or save
			KillWindow/Z UpdaterPrefsPanel
			if (redraw)
				PrefsSaveWindowPosition(s.win)
				MakeInstallerPanel()
			endif
			UpdateListboxWave(fGetStub())
	endswitch
	return 0
end

// hook makes panel act as if save Button has focus
function hookPrefsPanel(STRUCT WMWinHookStruct &s)
	if (s.eventCode != 11) // keyboard
		return 0
	endif
	if (s.keycode==13 || s.keycode==3) // enter or return
		STRUCT WMButtonAction sb
		sb.ctrlName = "ButtonSave"
		sb.eventCode = 2
		PrefsButtonProc(sb)
		return 1
	endif
	return 0
end

function PrefsSync()
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)

	prefs.options = 0
	ControlInfo/W=UpdaterPrefsPanel checkBackups
	prefs.options += 1 * (v_value)
	ControlInfo/W=UpdaterPrefsPanel checkHistory
	prefs.options += 2 * (v_value)
	ControlInfo/W=UpdaterPrefsPanel checkInstalled
	prefs.options += 4 * (v_value == 0)
	
	ControlInfo/W=UpdaterPrefsPanel checkBigger
	int redrawPanel = 0
	if (v_flag == 2)
		redrawPanel = ((prefs.paneloptions&2) != (2*v_value))
		prefs.paneloptions = (prefs.paneloptions & ~2) | (2 * v_value)
	endif
	
	ControlInfo/W=UpdaterPrefsPanel setvarPage
	prefs.pagetimeout = v_value
	ControlInfo/W=UpdaterPrefsPanel setvarFile
	prefs.filetimeout = v_value
	
	ControlInfo/W=UpdaterPrefsPanel popFrequency
	switch (v_value)
		case 1:
			prefs.frequency = 0 // always
			break
		case 2:
			prefs.frequency = 86400 // daily
			break
		case 3:
			prefs.frequency = 604800 // weekly
			break
		case 4:
			prefs.frequency = 2592000 // monthly
			break
		default:
			prefs.frequency = Inf // actually, 2^32, ie never
	endswitch
		
	SavePackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
	
	return redrawPanel
end

// save window position and tab selection in package prefs
function PrefsSaveWindowPosition(string strWin)
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	// save window position
	GetWindow $strWin wsizeRM
	prefs.win.top    = v_top
	prefs.win.left   = v_left
	prefs.win.bottom = v_bottom
	prefs.win.right  = v_right
	
	ControlInfo/W=InstallerPanel tabs
	prefs.paneloptions = (prefs.paneloptions & ~1) | v_value
//	prefs.tab = v_value
	
	SavePackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
end

// ------------------ end of package preferences & related functions --------------------

function/DF SetupPackageFolder()

	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:Installer
	DFREF dfr = root:Packages:Installer
	wave/T/SDFR=dfr/Z ProjectsFullList, UpdatesFullList
	int numCols
	
	// create wave to hold names of all available projects
	if (WaveExists(ProjectsFullList) == 0)
		numCols = ItemsInList(ksProjectsDimLabelsList)
		Make/O/T/N=(0,numCols) dfr:ProjectsFullList /WAVE=ProjectsFullList, dfr:ProjectsMatchList /WAVE=ProjectsMatchList
	endif
	
	// create wave to hold names of projects that have updater compatibility
	if (WaveExists(UpdatesFullList) == 0)
		numCols = ItemsInList(ksUpdatesDimLabelsList)
		Make/O/T/N=(0,numCols) dfr:UpdatesFullList /WAVE=UpdatesFullList, dfr:UpdatesMatchList /WAVE=UpdatesMatchList
	endif
	
	ResetColumnLabels()
	
	Make/O/N=(1,4)/T dfr:ProjectsDisplayList /WAVE=ProjectsDisplayList, dfr:ProjectsHelpList /WAVE=ProjectsHelpList, dfr:ProjectsColTitles /WAVE=ProjectsColTitles
	ProjectsDisplayList = {{"retrieving list..."},{""},{""},{""}}
	ProjectsHelpList    = {{"waiting for download"},{""},{""},{""}}
	ProjectsColTitles   = {{"Project (right-click for web page)"},{"Author"},{"\JRRelease Date"},{"\JRViews"}}
	
	Make/O/N=(1,4)/T dfr:UpdatesDisplayList /WAVE=UpdatesDisplayList, dfr:UpdatesHelpList /WAVE=UpdatesHelpList, dfr:UpdatesColTitles /WAVE=UpdatesColTitles
	UpdatesDisplayList = {{"retrieving list..."},{""},{""},{""}}
	UpdatesHelpList    = {{"waiting for download"},{""},{""},{""}}
	UpdatesColTitles   = {{"Project (right-click for options)"},{"Status"},{"\JCLocal"},{"\JCRemote"}}
	
	if (strlen(LogGetVersion("8197")) == 0) // updater not in log
		string filePath = FunctionPath("") // path to this file
		string fileName = ParseFilePath(0, filePath, ":", 1, 0) // name of this file
		string strVersion = num2str(GetProcVersion(filePath)) // version of this procedure
		string installPath = ParseFilePath(1, filePath, ":", 1, 0) // location of this file
		LogUpdateProject(num2str(kProjectID), ksShortTitle, installPath, strVersion, fileName, num2istr(datetime))
	elseif (0)
		// check for wrong filepath
		//LogUpdateInstallPath(string projectID, string installPath)
	endif
	
	// maybe check status before doing this?
	LogSyncWithProjectFile("8197")
	
	return dfr
end

// Set column dimlabels for project and update waves during initialization.
// Also used to check that labels are correct, to maintain backward compatibility
// projectID: the identifying "node" number of a project
// name: short title if possible; status: update available, up to date, etc
//	local: version of installed project; remote: remote version
//	system: operating system compatibility; releaseDate: last release date
//	installPath: file path or install path; releaseURL: url for new release
//	releaseIgorVersion: can't retrieve this from web :(
//	installDate: set at time of installation (datetime)
//	filesInfo: a summary of installed files
//	releaseInfo: possibly abbreviated 'Release Notes' text
// lastUpdate: timestamp for last update applied by updater (datetime)
function ResetColumnLabels()
	DFREF dfr = root:Packages:Installer
	wave/T/SDFR=dfr/Z UpdatesFullList, UpdatesMatchList, ProjectsFullList, ProjectsMatchList
	
	if (WaveExists(ProjectsFullList))
		if (FindDimLabel(ProjectsFullList, 1, "userNum") == -2)
			SetDimLabels(ksProjectsDimLabelsList, 1, ProjectsFullList)
			SetDimLabels(ksProjectsDimLabelsList, 1, ProjectsMatchList)
		endif
	endif
	
	if (WaveExists(UpdatesFullList))
		if (FindDimLabel(UpdatesFullList, 1, "lastUpdate") == -2)
			SetDimLabels(ksUpdatesDimLabelsList, 1, UpdatesFullList)
			SetDimLabels(ksUpdatesDimLabelsList, 1, UpdatesMatchList)
		endif
	endif
end

threadsafe function SetDimLabels(string strList, int dim, wave w)
	int numLabels = ItemsInList(strList)
	int i
	if (numLabels != DimSize(w, dim))
		return 0
	endif
	for (i=0;i<numLabels;i+=1)
		SetDimLabel dim, i, $StringFromList(i, strList), w
	endfor
	return 1
end

// Download file from supplied url and replace original
// installPath is either path to file, or path to folder (installPath from log)
// If we're updating something from the install log, must supply shortTitle and localVersion
// Returns full path to replaced file
function/S UpdateFile(installPath, url, projectID, [shortTitle, localVersion, newVersion, silently])
	string installPath, url, projectID
	string shortTitle
	variable localversion, newVersion, silently
	
	silently = paramisdefault(silently) ? 0 : silently
				
	string cmd = "", filePath = "", fileExt = ""
	string fileName
	variable flagI
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	string backupPathStr = SelectString(prefs.options & 1, "", SpecialDirPath(ksBackupLocation,0,0,0))
	// this location must exist, a subfolder may be created
	
	string downloadFileName = ParseFilePath(0, url, "/", 1, 0)
	string downloadFileExt = ParseFilePath(4, url, "/", 0, 0)
	
	if (stringmatch(installPath[strlen(installPath)-1], ":"))
		// get the filePath from install log
		filePath = LogGetFilePath(projectID)
	else
		filePath = installPath
	endif
	
	installPath = ParseFilePath(1, filePath, ":", 1, 0)
	fileName = ParseFilePath(0, filePath, ":", 1, 0) // name of file to be updated
	fileExt = ParseFilePath(4, filePath, ":", 0, 0)
	
	if (cmpstr(fileExt, downloadFileExt))
		sprintf cmd, "Could not match file type at\r%s\rand %s\r", url, filePath
		WriteToHistory(cmd, prefs, 1)
		return ""
	endif
	
	if (ParamIsDefault(shortTitle))
		shortTitle = GetShortTitle(filePath)
		if (strlen(shortTitle) == 0) // use fileName
			shortTitle = ParseFilePath(3, filePath, ":", 0, 0)
		endif
	endif
	if (ParamIsDefault(localVersion))
		localVersion = GetProcVersion(filePath)
	endif
	
	// check with user before overwriting file
	if (!silently && isFile(filePath))
		cmd += "Do you want to replace " + fileName + " with\r"
		cmd += "the file from\r" + url + "?"
		DoAlert 1, cmd
		if (v_flag == 2)
			sprintf cmd, "Update for %s cancelled\r", shortTitle
			WriteToHistory(cmd, prefs, 0)
			return ""
		endif
	endif
	
	if (strlen(backupPathStr) && isFile(filePath)) // save a backup of the old procedure file
		// figure out full path to backup file
		string NewFileName = ""
		fileExt = selectstring (strlen(fileExt) > 0, "", "." + fileExt)

		sprintf NewFileName, "%s%g%s", ParseFilePath(3, fileName, ":", 0, 0), localVersion, fileExt
//		sprintf backupPathStr, "%s%s%g.%s", backupPathStr, ParseFilePath(3, fileName, ":", 0, 0), localVersion, ParseFilePath(4, fileName, ":", 0, 0)
		flagI = 0
		GetFileFolderInfo/Q/Z backupPathStr + NewFileName
		if (v_flag == 0) // file already exists in archive location
			NewFileName = UniqueFileName(backupPathStr, NewFileName, 0)
//			flagI = 2 // check before overwriting
		endif
		MoveFile/O/S="Archive current file"/I=(flagI)/Z filePath as backupPathStr + NewFileName
		if (v_flag == 0)
			sprintf cmd, "Saved copy of %s version %g to %s\r", shortTitle, localVersion, s_path
			WriteToHistory(cmd, prefs, 0)
		endif
	endif
	
	#ifdef testing
	variable refnum
	Open/R/D/F="ipf Files (*.ipf):.ipf;"/M="Looking for an ipf file..." refnum
	if (strlen(S_fileName) == 0)
		return ""
	endif
	url = "file:///" + ReplaceString(":", S_fileName, "/")
	#endif
	
	// check for different filename
	if (cmpstr(downloadFileName, fileName))
		// move the old file, if it exists
		string deletePath = CreateUniqueDir(SpecialDirPath("Temporary",0,0,0), shortTitle)
		MoveFile/O/I=0/Z filePath as deletePath + fileName
		// set the name for the new file
		fileName = downloadFileName
		filePath = installPath + fileName
	endif
	
	// download new file and overwrite any exisiting one
	URLRequest/time=(prefs.fileTimeout)/Z/O/FILE=filePath url=url
	if (V_flag)
		WriteToHistory("Could not download " + url, prefs, 1)
		return ""
	elseif (strlen(S_fileName) == 0)
		WriteToHistory("Could not write file to " + filePath, prefs, 1)
		return ""
	endif
	sprintf cmd "Downloaded %s\r", url
	WriteToHistory(cmd, prefs, 0)
	sprintf cmd, "Saved file to %s\r", S_fileName
	WriteToHistory(cmd, prefs, 0)
	
	if (ParamIsDefault(newVersion))
		newVersion = GetProcVersion(filePath)
	endif
	
	// write to install log
	LogUpdateProject(projectID, shortTitle, installPath, num2str(newVersion), fileName, num2istr(datetime))
	
	return S_fileName
end

// Update procedure and associated files with contents of zip file to be
// downloaded from url. If we're updating something from the install log,
// must supply all the optional parameters. In that case filePath is a
// path to install location, not to a file.
function/S UpdateZip(filePath, url, projectID, [shortTitle, localVersion, newVersion])
	string filePath, url, projectID, shortTitle
	variable localversion, newVersion
	
	string archivePathStr, archiveName, unzipPathStr, fileList, folderList, fileName
	string ipfName, packagePathStr, installPathStr
	string oldFiles = "", staleFiles = "", cmd = "", backupPathStr = ""
	string downloadPathStr = SpecialDirPath(ksDownloadLocation,0,0,0) + "TonyInstallerTemp:"
	int i
	
	if (ParamIsDefault(localVersion))
		localVersion = GetProcVersion(filePath)
	endif
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	if (prefs.options & 1)
		backupPathStr = SpecialDirPath(ksBackupLocation,0,0,0)
	endif
	
	if (cmpstr(filePath[strlen(filePath)-1], ":")) // we have path to a file
		ipfName = ParseFilePath(0, filePath, ":", 1, 0) // name of procedure file to be updated
		packagePathStr = ParseFilePath(1, filePath, ":", 1, 0) // path to folder containing procedure file
	else // path to folder
		ipfName = ""
		packagePathStr = filePath
		installPathStr = filePath
	endif
	
	if (ParamIsDefault(shortTitle)) // not a log file based update
		shortTitle = GetShortTitle(filePath)
		if (strlen(shortTitle) == 0) // use fileName
			shortTitle = ParseFilePath(3, filePath, ":", 0, 0)
		endif
	endif
	
	// create a temporary folder in the download location
	NewPath/C/O/Q tempPathIXI, downloadPathStr; KillPath/Z tempPathIXI
	
	#ifdef testing
	variable refnum
	Open/R/D/F="ZIP Files (*.zip):.zip;"/M="Looking for ZIP file..." refnum
	if (strlen(S_fileName) == 0)
		return ""
	endif
	url = "file:///" + ReplaceString(":", S_fileName, "/")
	#endif
	
	// download zip file to temporary location
	URLRequest/time=(prefs.fileTimeout)/Z/O/FILE=downloadPathStr+ParseFilePath(0, url,"/", 1, 0) url=url
	if (V_flag)
		WriteToHistory("Could not download " + url, prefs, 1)
		return ""
	elseif (strlen(S_fileName) == 0)
		WriteToHistory("Could not write file to " + filePath, prefs, 1)
		return ""
	endif
	
	archivePathStr = S_fileName // path to zip file
	archiveName = ParseFilePath(0, S_fileName, ":", 1, 0)
	sprintf cmd, "Downloaded new version of %s from %s\r", shortTitle, url
	WriteToHistory(cmd, prefs, 0)
	sprintf cmd, "Saved temporary file %s\r", archiveName
	WriteToHistory(cmd, prefs, 0)
	
	// create a temporary directory for the uncompressed files
	unzipPathStr = CreateUniqueDir(downloadPathStr, "Install")

	// inflate archive
	variable success = UnzipArchive(archivePathStr, unzipPathStr)
	if (success == 0)
		WriteToHistory("unzipArchive failed to inflate " + S_fileName, prefs, 1)
		return ""
	endif
	sprintf cmd, "Inflated %s to %s\r", archiveName, unzipPathStr
	WriteToHistory(cmd, prefs, 0)
	
	// get list of files and folders
	NewPath/O/Q unzipPath, unzipPathStr
	fileList = IndexedFile(unzipPath, -1, "????")
	folderList = IndexedDir(unzipPath, -1, 0)
	KillPath/Z unzipPath
		
	// ignore pesky __MACOSX folder, and other folders listed in ignoreFoldersList
	folderList = RemoveFromListWC(folderList, ksIgnoreFoldersList)
	fileList = RemoveFromListWC(fileList, ksIgnoreFilesList)
	
	// check number of files and folders at root of inflated archive
	variable numFiles = ItemsInList(fileList), numFolders = ItemsInList(folderList)

	// skip the following checks if we're using log file
	if (strlen(ipfname))
		// use FindFile to look for the file that replaces the target procedure file
		string unzippedIPFpathStr = FindFile(unzipPathStr, ipfName)
		if (strlen(unzippedIPFpathStr) == 0) // abort installation if we don't have the right file!
			sprintf cmd, "Could not find %s in %s\r", ipfName, archiveName
			WriteToHistory(cmd, prefs, 1)
			InstallerCleanup(downloadPathStr)
			return ""
		endif
			
		// figure out local path from unzipPathStr to replacement procedure file
		unzippedIPFpathStr = unzippedIPFpathStr[strlen(unzipPathStr),Inf]
		variable subfolders = ItemsInList(unzippedIPFpathStr, ":")-1
			
		if (subfolders > 0) // check that directory structure at destination matches that from archive
			if (stringmatch(filePath, "*" + unzippedIPFpathStr) == 0)
				// target directory doesn't match folder in archive
				sprintf cmd, "Could not match directory structure in %s to %s\r", archiveName, packagePathStr
				WriteToHistory(cmd, prefs, 1)
				InstallerCleanup(downloadPathStr)
				return ""
			endif
		endif
	
		// move up directory structure at destination
		installPathStr = ParseFilePath(1, filePath, ":", 1, 0) // path to folder containing file
		for (i=0;i<subfolders;i+=1)
			installPathStr = ParseFilePath(1, installPathStr, ":", 1, 0)
		endfor
		
	endif
	
	// test to find out which files will be overwritten
	fileList = MergeFolder(unzipPathStr, installPathStr, test=1, ignore=ksIgnoreFilesList)
	numFiles = ItemsInList(fileList)
	
	if (strlen(ipfname))
		oldFiles = fileList
	else
		oldFiles = LogGetFileList(projectID) // file list from log (if log exists)
	endif

	staleFiles = RemoveFromList(fileList, oldFiles, ";", 0) // files to be removed
	oldFiles = fileList // files to be overwritten
	if (strlen(staleFiles))
		oldFiles = AddListItem(RemoveEnding(staleFiles, ";"), oldFiles)
	endif
	variable numOldFiles = ItemsInList(oldFiles)
	
	// check with user before overwriting files
	if (numOldFiles)
		cmd = GenerateOverwriteAlertString(oldFiles, rootPath=installPathStr, del=1+2*(ItemsInList(staleFiles)>0))
		DoAlert 1, cmd
		if (v_flag == 2)
			sprintf cmd, "Update for %s cancelled\r", shortTitle
			WriteToHistory(cmd, prefs, 0)
			InstallerCleanup(downloadPathStr)
			return ""
		endif
	endif

	// create backup folder
	if (numOldFiles && strlen(backupPathStr))
		string folderName
		sprintf folderName, "%s_%0.2f", shortTitle, localVersion
		folderName = CleanupName(folderName,0) // making it Igor-legal should hopefully ensure the name is good for the OS
		sprintf backupPathStr, "%s%s:", backupPathStr, folderName
		NewPath/Q/C/O/Z tempPathIXI, backupPathStr; KillPath/Z tempPathIXI
		sprintf cmd, "Created backup folder %s\r", backupPathStr
		WriteToHistory(cmd, prefs, 0)
	endif
		
	if (strlen(staleFiles))
		// remove any files from previous install that won't be overwritten
		string deletePath
		if (strlen(backupPathStr))
			deletePath = backupPathStr
		else
			deletePath = CreateUniqueDir(SpecialDirPath("Temporary",0,0,0), shortTitle)
		endif
		MoveFiles(staleFiles, installPathStr, deletePath)
	endif
		
	// move files into user procedures folder
	fileList = MergeFolder(unzipPathStr, installPathStr, backupPathStr=backupPathStr, killSourceFolder=0, ignore=ksIgnoreFilesList)

	for (i=0;i<ItemsInList(fileList);i+=1)
		fileName = StringFromList(i, fileList) // this is full path to file
		sprintf cmd, "Moved %s to %s\r", ParseFilePath(0, fileName, ":", 1, 0), ParseFilePath(1, fileName, ":", 1, 0)
		WriteToHistory(cmd, prefs, 0)
	endfor
	InstallerCleanup(downloadPathStr)
		
	if (ParamIsDefault(newVersion)) // not a log-based update
		newVersion = GetProcVersion(filePath)
	endif
	
	sprintf cmd, "Update complete: %s version %g\r", shortTitle, newVersion
	WriteToHistory(cmd, prefs, 0)
		
	// write to install log
	LogUpdateProject(projectID, shortTitle, installPathStr, num2str(newVersion), fileList, num2istr(datetime))
	
	return fileList
end

function MoveFiles(string fileList, string fromPath, string toPath)
	string fileName, filePath, subPath, destinationPath
	int numFiles = ItemsInList(fileList)
	int i, j
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	string cmd = ""
	for (i=0;i<numFiles;i+=1)
		filePath = StringFromList(i, fileList)
		if (stringmatch(filePath, fromPath + "*") == 0)
			continue
		endif
		fileName = ParseFilePath(0, filePath, ":", 1, 0)
		subPath = ParseFilePath(1, filePath, ":", 1, 0)
		subPath = subPath[strlen(fromPath), Inf]
		destinationPath = toPath
		for (j=0;j<ItemsInList(subPath, ":");j+=1)
			destinationPath += StringFromList(j, subPath, ":") + ":"
			NewPath/C/O/Q/Z tempPathIXI, destinationPath // Igor eXchange Installer
		endfor
		MoveFile/O/Z filePath as destinationPath + fileName
		if (v_flag == 0)
			sprintf cmd, "Moved %s to %s\r", fileName, destinationPath
			WriteToHistory(cmd, prefs, 0)
		endif
	endfor
	KillPath/Z tempPathIXI
	return 1
end

function Update(string filePath, string url, string projectID)
	string fileType = ParseFilePath(4, url, ":", 0, 0)
	string fileList = ""
	if (stringmatch(fileType, "zip"))
		fileList = UpdateZip(filePath, url, projectID)
	elseif (stringmatch(fileType, "ipf"))
		fileList = UpdateFile(filePath, url, projectID)
	elseif (stringmatch(fileType, "xop"))
		// can only update xop if we have info from install log
	endif
	return (ItemsInList(fileList))
end

// this is for updates requested by IgorExchange Installer Panel
// for backward compatibility, filePath can be path to a file or to install location
function UpdateSelection()

	string projectID, installPath, url, shortTitle
	variable localVersion, newVersion
		
	DFREF dfr = root:Packages:Installer
	wave/SDFR=dfr/T UpdatesMatchList
	ControlInfo/W=InstallerPanel listboxUpdate
	
	string fileList = ""
	if (v_value>-1 && v_value<DimSize(UpdatesMatchList,0))
		SetPanelStatus("Updating " + UpdatesMatchList[v_value][%name])
		
		projectID = UpdatesMatchList[v_value][%projectID]
		localVersion = str2num(UpdatesMatchList[v_value][%local])
		newVersion = str2num(UpdatesMatchList[v_value][%remote])
		url = UpdatesMatchList[v_value][%releaseURL]
		shortTitle = UpdatesMatchList[v_value][%name]
		installPath = UpdatesMatchList[v_value][%installPath] // full path
		string fileType = ParseFilePath(4, url,":", 0, 0)
		
		if (stringmatch(fileType, "zip"))
			fileList = UpdateZip(installPath, url, projectID, shortTitle=shortTitle, localVersion=localVersion, newVersion=newVersion)
		else
			fileList = UpdateFile(installPath, url, projectID, shortTitle=shortTitle, localVersion=localVersion, newVersion=newVersion)
		endif
	
		if (strlen(fileList))
			ReloadUpdatesList(1)
			UpdateListboxWave(fGetStub())
			SetPanelStatus(shortTitle + " Update Complete")
		else
			SetPanelStatus("Selected: " + UpdatesMatchList[v_value][%name])
		endif
	endif
	
	return (strlen(fileList) > 0)
end

// delete temporary installation folder if required
function InstallerCleanup(string downloadPathStr)
	if (stringmatch(downloadPathStr, SpecialDirPath("Temporary",0,0,0) + "*"))
		return 0
	endif
	DeleteFolder/M="OK to delete temporary installation files?"/Z RemoveEnding(downloadPathStr,":")
	if (v_flag == 0)
		string cmd = ""
		sprintf cmd, "Deleted temporary folder %s\r", downloadPathStr
		STRUCT PackagePrefs prefs
		LoadPrefs(prefs)
		WriteToHistory(cmd, prefs, 0)
	endif
end

function/S GetProcWinFilePath(string strWin)
	GetWindow/Z $strWin file
	return StringFromList(1, S_value) + StringFromList(0, S_value)
end

function GetIgorVersion() // windows-safe
	string strIgorVersion = StringByKey("IGORFILEVERSION", IgorInfo(3))
	strIgorVersion = ReplaceString(".", strIgorVersion, "*", 0, 1)
	strIgorVersion = ReplaceString(".", strIgorVersion, "")
	strIgorVersion = ReplaceString("*", strIgorVersion, ".")
	return str2num(strIgorVersion)
end

// wrapper for GetFileFolderInfo
threadsafe function isFile(string filePath)
//	GetFileFolderInfo/Q/Z filePath
//	return V_isFile
	
	variable status, refnum
	Open/Z/R refnum as filePath
	if (v_flag == 0)
		status = 1
		Close refnum
	endif
	return status
end

// extract procedure version from file
threadsafe function GetProcVersion(string filePath)
	variable procVersion
	variable noVersion = 0
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E="(?i)^#pragma[\s]*version[\s]*="/LIST/Z filePath
	if (v_flag != 0)
		return noVersion
	endif
	s_value = LowerStr(TrimString(s_value, 1))
	sscanf s_value, "#pragma version = %f", procVersion
	return (V_flag!=1 || procVersion<=0) ? noVersion : procVersion
end

// non-threadsafe, but relatively fast
function GetThisVersion()

	variable procVersion
	// try the quick way
	#if exists("ProcedureVersion") == 3
	procVersion = ProcedureVersion("")
	if (procVersion)
		return procVersion
	endif
	#endif
	
	int maxLines = 30 // number of lines to search for version pragma
	int refNum, i
	string strHeader = ""
	string strLine = ""
	
	Open/R/Z refnum as FunctionPath("")
	if (refnum == 0)
		return 0
	endif
	for (i=0;i<maxLines;i+=1)
		FReadLine refNum, strLine
		strHeader += strLine
	endfor
	Close refnum
	wave/T ProcText = ListToTextWave(strHeader, "\r")
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E="(?i)^#pragma[\s]*version[\s]*="/LIST/Z ProcText
	if (v_flag != 0)
		return 0
	endif
	s_value = LowerStr(TrimString(s_value, 1))
	sscanf s_value, "#pragma version = %f", procVersion
	ProcVersion = (V_flag!=1 || ProcVersion<=0) ? 0 : ProcVersion

	return ProcVersion
end

// extract project ID from file and return as string
threadsafe function/S GetProjectIDString(string filePath)
	variable projectID = GetConstantFromFile("kProjectID", filePath)
	if (numtype(projectID) == 0)
		return num2istr(projectID)
	endif
end

threadsafe function/S GetPragmaString(string strPragma, string filePath)
	if (isFile(filePath) == 0)
		return ""
	endif
	string s_exp = "(?i)^#pragma[\s]*" + strPragma + "[\s]*="
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E=s_exp/LIST/Z filePath
	if (v_flag != 0)
		return ""
	endif
	string str = RemoveEnding(s_value, ";")
	variable vpos = strsearch(str, "=", 0)
	if (vpos == -1)
		return ""
	endif
	str = str[vpos+1,Inf]
	vpos = strsearch(str, "//", 0)
	if (vpos > 2)
		str = str[0,vpos-1]
	endif
	return TrimString(str, 1)
end

function GetPragmaVariable(string strPragma, string filePath)
	if (isFile(filePath) == 0)
		return NaN
	endif
	strpragma = LowerStr(strpragma)
	string s_exp = "(?i)^#pragma[\s]*" + strPragma + "[\s]*="
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E=s_exp/LIST/Z filePath
	if (v_flag != 0)
		return NaN
	endif
	variable result
	s_value = LowerStr(TrimString(s_value, 1))
	sscanf s_value, "#pragma " + strpragma + " = %g", result
	return v_flag ? result : NaN
end

// maybe better to use simply GetStringConstFromFile("ksShortTitle", filePath)
threadsafe function/S GetShortTitle(string filePath)
	variable selStart, selEnd
	string shortTitle = GetStringConstFromFile("ksShortTitle", filePath)
	if (strlen(shortTitle) == 0)
		shortTitle = GetStringConstFromFile("ksShortName", filePath) // for backward compatibility
	endif
	if (strlen(shortTitle) == 0)
		string S_Value = "" // workaround for Grep bug for Igor 8
		Grep/Q/E="(?i)#pragma[\s]*moduleName[\s]*="/LIST/Z filePath
	
		if (v_flag != 0)
			return ""
		endif
		
		if (strlen(s_value) == 0)
			Grep/Q/E="(?i)#pragma[\s]*IndependentModule[\s]*="/LIST/Z filePath
			if (v_flag != 0 || strlen(s_value) == 0)
				return ""
			endif
		endif
		s_value = RemoveEnding(s_value,";")
		selStart = strsearch(s_value, "=", 0) + 1
		selEnd = strsearch(s_value, "//", 0)
		selEnd = selEnd == -1 ? strlen(s_value)-1 : selEnd-1
		shortTitle = TrimString(s_value[selStart,selEnd])
	endif
	return shortTitle
end

// extract a static string constant from a procedure file by reading from disk
threadsafe function/S GetStringConstFromFile(string constantNameStr, string filePath)
	string s_exp = "", s_out = ""
	sprintf s_exp, "(?i)^[\s]*static[\s]*strconstant[\s]*%s[\s]*=", constantNameStr
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Z/Q/E=s_exp/LIST/Z filePath
	if (v_flag != 0)
		return ""
	endif
	variable start, stop
	start = strsearch(s_value, "\"", 0)
	stop = strsearch(s_value, "\"", start + 1)
	if (start<0 || stop<0)
		return ""
	endif
	return s_value[start+1,stop-1]
end

// extract a static constant from a procedure file by reading from disk
threadsafe function GetConstantFromFile(string strName, string filePath)
	if (isFile(filePath) == 0)
		return NaN
	endif
	string s_exp = "", s_out = ""
	sprintf s_exp, "(?i)^[\s]*static[\s]*constant[\s]*%s[\s]*=", strName
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E=s_exp/LIST/Z filePath
	if (v_flag != 0)
		return NaN
	endif
	variable start, stop
	start = strsearch(s_value, "=", 0)
	if (start<0)
		return NaN
	endif
	return str2num(s_value[start+1,Inf])
end

// strip trailing stuff in the output from winlist
function/S FileNameFromProcName(string str)
	SplitString/E=".*\.ipf" str // remove module names
	return RemoveEnding(s_value, ".ipf")
end

function/S CreateUniqueDir(string pathStr, string baseName)
	pathStr = ParseFilePath(2, pathStr, ":", 0, 0)
	GetFileFolderInfo/Q/Z pathStr
	if (v_isFolder == 0)
		return ""
	endif
	int i = 0
	string strOut = ""
	do
		sprintf strOut, "%s%s%d:", pathStr, baseName, i
		GetFileFolderInfo/Q/Z strOut
		i += 1
	while(V_Flag == 0)
	NewPath/C/O/Q tempPathIXI, strOut; KillPath/Z tempPathIXI
	if (v_flag == 0)
		return strOut
	endif
	return ""
end

// baseName should be legal fileName
// returns path to a nonexisting file with name basename or basename + numeral
function/S UniqueFileName(string pathStr, string baseName, int fullpath)
	pathStr = ParseFilePath(2, pathStr, ":", 0, 0)
	GetFileFolderInfo/Q/Z pathStr
	if (v_isFolder == 0)
		return ""
	endif
	GetFileFolderInfo/Q/Z pathStr + baseName
	if (v_flag)
		return selectstring(fullpath, baseName, pathStr + baseName)
	endif
	
	int i
	string NewFileName = ""	
	string ext = ParseFilePath(4, baseName, ":", 0, 0)
	int extlen = strlen(ext)
	if (strlen(ext))
		baseName = baseName[0, strlen(baseName)-extlen-2]
		ext = "." + ext
	endif
		
	for (i=0;i<1000;i+=1)
		sprintf NewFileName, "%s_%d%s", baseName, i, ext
		GetFileFolderInfo/Q/Z pathStr + NewFileName
		if (v_flag)
			break
		endif
	endfor
	
	return selectstring(fullpath, NewFileName, pathStr + NewFileName)
end

// returns listStr, purged of any items that match an item in ZapListStr.
// Wildcards okay! Case insensitive.
function/S RemoveFromListWC(string listStr, string zapListStr)
	string removeStr = ""
	int i
	for (i=ItemsInList(zapListStr)-1;i>=0;i-=1)
		removeStr += ListMatch(listStr, StringFromList(i, zapListStr))
	endfor
	return RemoveFromList(removeStr, listStr, ";", 0)
end

// Parse html in AllReleasesText to find releases.
function/WAVE ParseAllReleasesAsWave(string AllReleasesText)
	Make/T/Free/N=(0,8) w_releases
	variable selStart = -1, selEnd = -1, blockStart, blockEnd, selFound
	string projectName = "", releaseMajor = "", releaseMinor = "", releaseExtra = ""
	string url = "", platform = "", versionDate = "", requiredVersion = ""
	
	variable reqIgorVersion, releaseVersion
	
	int i = 0
	
	string strTitleStart = "<h1 class=\"page-title\" title=\""
	string strReleaseStart = "<div class=\"project-release-info\">"
	string strReleaseEnd = "<div class=\"project-release-footer\">"
	string strVersionStart = "\"field-paragraph-version\">"
	string strDateStart = "\"field-paragraph-version-date\"><time datetime=\""
	string strMajorStart = "\"field-paragraph-version-major\">"
	string strPatchStart = "\"field-paragraph-version-patch\">"
	string strExtraStart = "\"field-paragraph-version-extra\">"
	string strLinkStart = "\"field-paragraph-file\""
	string strWindows = "<span class=\"entity-reference\">Windows</span>"
	string strMac = "<span class=\"entity-reference\">Mac-"
		
	// locate project name
//	selStart = strsearch(AllReleasesText, "<h1 class=\"page-title\" title=\"Releases for ", blockStart, 2)
	
	selStart = strsearch(AllReleasesText, strTitleStart, blockStart, 2)
	selStart += strlen(strTitleStart)
	selEnd = strsearch(AllReleasesText, "\"", selStart, 2)
	if (selStart<strlen(strTitleStart) || selEnd>(selStart+150))
		return w_releases
	endif
	projectName = AllReleasesText[selStart, selEnd-1]

	do
		// find start and end of project release fields
		selStart = strsearch(AllReleasesText, strReleaseStart, selStart, 2)
		if (selStart == -1)
			break
		endif
		blockStart = selStart
		selEnd = strsearch(AllReleasesText, strReleaseEnd, selStart, 2)
		if (selEnd == -1)
			break
		endif
		blockEnd = selEnd
		
		// locate version info
		selStart = strsearch(AllReleasesText, strVersionStart, blockStart, 2)
		selStart += strlen(strVersionStart)
		selEnd = strsearch(AllReleasesText, "<", selStart, 2)
		if (selStart>blockStart && selEnd<blockEnd)
			requiredVersion = AllReleasesText[selStart, selEnd-1]
			sscanf (LowerStr(requiredVersion)), "igor.%f.x-%f", reqIgorVersion, releaseVersion
			if (V_flag == 2)
				requiredVersion = num2str(reqIgorVersion)
			else // version string doesn't have strict formatting from old IgorExchange site
				requiredVersion = "0"
				// no way to figure out required Igor version prior to download
			endif
		endif
				
		// locate version date
		selStart = strsearch(AllReleasesText, strDateStart, blockStart, 2)
		selStart += strlen(strDateStart)
		selEnd = strsearch(AllReleasesText, "\"", selStart, 2)
		if (selStart<blockStart || selEnd>blockEnd)
			break
		endif
		versionDate = num2istr(ISO8601toJulian(AllReleasesText[selStart, selEnd-1]))
		
		selStart = strsearch(AllReleasesText, strMajorStart, blockStart, 2)
		selStart += strlen(strMajorStart) // 32
		selEnd = strsearch(AllReleasesText, "<", selStart, 2)
		if (selStart<blockStart || selEnd>blockEnd)
			break
		endif
		releaseMajor = AllReleasesText[selStart, selEnd-1]
		
		selStart = strsearch(AllReleasesText, strPatchStart, blockStart, 2)
		selStart += strlen(strPatchStart) // 32
		selEnd = strsearch(AllReleasesText, "<", selStart, 2)
		if (selStart<blockStart || selEnd>blockEnd)
			releaseMinor = "0" // patch not found - field may be missing
		else
			releaseMinor = AllReleasesText[selStart, selEnd-1]
		endif
		
		selStart = strsearch(AllReleasesText, strExtraStart, blockStart, 2)
		selStart += strlen(strExtraStart) // 32
		selEnd = strsearch(AllReleasesText, "<", selStart, 2)
		if (selStart<blockStart || selEnd>blockEnd)
			releaseExtra = "" // field not present for this release
		else
			releaseExtra = AllReleasesText[selStart, selEnd-1]
		endif
		
		// find download link
		selStart = strsearch(AllReleasesText, strLinkStart, blockStart, 2)
		selStart = strsearch(AllReleasesText, "<a href=\"", selStart, 2)
		selStart += 9
		selEnd = strsearch(AllReleasesText, "\"", selStart, 2)
		if (selEnd<0 || selEnd>blockEnd)
			break
		endif
		url = AllReleasesText[selStart, selEnd-1]
				
		platform = ""
		selFound = strsearch(AllReleasesText, strWindows, blockStart, 2)
		if (selFound>blockStart && selFound<blockEnd)
			platform += "Windows;"
		endif
		selFound = strsearch(AllReleasesText, strMac, blockStart, 2)
		if (selFound>blockStart && selFound<blockEnd)
			platform += "Macintosh;"
		endif
		if (strlen(projectName)==0 || strlen(releaseMajor)==0 || strlen(releaseMinor)==0 ||strlen(url)==0)
			break
		endif
		w_releases[DimSize(w_releases,0)][] = {{projectName},{requiredVersion},{releaseMajor},{releaseMinor},{url},{platform},{versionDate},{releaseExtra}}
		selStart = blockEnd
		i += 1
	while (i < 1000)
	return w_releases
end
//{{projectName},{requiredVersion},{releaseMajor},{releaseMinor},{url},{platform},{versionDate},{releaseExtra}}



// NEW FOR VERSION 5.0: insert https://www.wavemetrics.com/ in URL

// Parse html in project web page to find releases. Returns a string list:
// projectID;ReleaseCacheDate;title;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;
threadsafe function/S ParseProjectPageAsList(string projectID, string WebPageText)
	
	string strDate = num2istr(datetime)
	string strLine = ""
		
	string name = "", releaseIgorVersion = "", releaseDate = "", remote = ""
	string releaseURL = "", system = "", releaseInfo = ""

	variable reqIgorVersion, releaseVersion
	string requiredVersion = "", releaseMajor = "", releaseMinor = "", releaseExtra = ""
	
	string strTitleStart = "<h1 class=\"page-title\" title=\""
	string strReleaseStart = "<div class=\"project-release-info\">"
	string strReleaseEnd = "<div class=\"project-release-footer\">"
	string strVersionStart = "\"field-paragraph-version\">"
	string strDateStart = "\"field-paragraph-version-date\"><time datetime=\""
	string strMajorStart = "\"field-paragraph-version-major\">"
	string strPatchStart = "\"field-paragraph-version-patch\">"
	string strExtraStart = "\"field-paragraph-version-extra\">"
	string strLinkStart = "\"field-paragraph-file\"><span"
	string strWindows = "<span class=\"entity-reference\">Windows"
	string strMac = "<span class=\"entity-reference\">Mac"
	string strNotesStart = "<span class=\"field-paragraph-full-html\">"
			
	// locate project name - required
	name = GetTextField(WebPageText, strTitleStart)
	if (isError(name) || strlen(name) > 200)
		return ""
	endif
	
	// find start and end of project release fields
	// set WebPageText to the release text
	WebPageText = GetTextField(WebPageText, strReleaseStart, strEnd = strReleaseEnd)
	if (isError(name))
		return ""
	endif
		
	// locate version info - may be missing
	releaseIgorVersion = GetTextField(WebPageText, strVersionStart)
	sscanf (LowerStr(releaseIgorVersion)), "igor.%f.x-%f", reqIgorVersion, releaseVersion
	if (V_flag == 2)
		releaseIgorVersion = num2str(reqIgorVersion)
	else // version string doesn't have strict formatting from old IgorExchange site
		releaseIgorVersion = "0"
		// no way to figure out required Igor version prior to download
	endif
	
	// locate version date
	releaseDate = GetTextField(WebPageText, strDateStart)
	if (!isError(releaseDate))
		releaseDate = num2istr(ISO8601toJulian(releaseDate))
	else
		releaseDate = ""
	endif
	
	// Major version number is required
	releaseMajor = GetTextField(WebPageText, strMajorStart)
	if (isError(releaseMajor))
		return ""
	endif
		
	releaseMinor = GetTextField(WebPageText, strPatchStart)
	if (isError(releaseMinor))
		releaseMinor = "0" // patch not found - field may be missing
	endif
	
	releaseExtra = GetTextField(WebPageText, strExtraStart)
	if (isError(releaseExtra))
		releaseExtra = ""
	endif
	
	// maybe it's safer to make a preemptive number conversion
	// in case the text field is badly formatted
	releaseVersion = str2num(releaseMajor + "." + releaseMinor)
	releaseExtra = SelectString( strlen(releaseExtra)>0, "", "-" + releaseExtra)
	sprintf remote, "%g%s", releaseVersion, releaseExtra
	remote = ReplaceString(":", remote, "-")
		
	// find download link
	releaseURL = GetTextField(WebPageText, strLinkStart, strEnd = "</span>")
	releaseURL = GetTextField(releaseURL, "<a href=\"")
	if (isError(releaseURL))
		return ""
	endif
	releaseURL = "https://www.wavemetrics.com" + releaseURL
				
	system = ""
	if (!isError(GetTextField(WebPageText, strWindows, strEnd = "<")))
		system += "Windows,"
	endif
	if (!isError(GetTextField(WebPageText, strMac, strEnd = "<")))
		system += "Macintosh,"
	endif
	
	releaseInfo = GetTextField(WebPageText, strNotesStart, strEnd = "</span>")
	if (isError(releaseInfo))
		releaseInfo = ""
	else
		releaseInfo = removeHTMLEncoding(releaseInfo)
		releaseInfo = ReplaceString("\r", releaseInfo, "")
		releaseInfo = ReplaceString("\n", releaseInfo, "")
		releaseInfo = ReplaceString(";", releaseInfo, "-")
		releaseInfo = ReplaceString(":", releaseInfo, "-")
		releaseInfo = RemoveEnding(releaseInfo, " ")
		if (strlen(releaseInfo)>300) // set a character limit for this field
			releaseInfo = releaseInfo[0,299] + "..."
		endif
	endif
			
	sprintf strLine, "%s;%s;%s;%s;%s;%s;%s;%s;%s;", projectID, strDate, name, remote, system, releaseDate, releaseURL, releaseIgorVersion, releaseInfo
	if (ItemsInList(strLine) != 9)
		return ""
	endif
	return strLine
end

threadsafe function ISO8601toSecs(string strISO8601)
	variable YY, MM, DD, hour, minute, second
	sscanf strISO8601, "%d-%d-%dT%d:%d:%g", YY, MM, DD, hour, minute, second
	return date2secs(YY, MM, DD) + second + minute * 60 + hour * 3600
end

threadsafe function ISO8601toJulian(string strISO8601)
	variable YY, MM, DD
	sscanf strISO8601, "%d-%d-%dT", YY, MM, DD
	return DateToJulian(YY, MM, DD)
end

threadsafe function isError(string str)
	return cmpstr(str, "error") == 0
end

threadsafe function/S GetTextField(string strHTML, string strStart, [string strEnd])
	if (ParamIsDefault(strEnd))
		if (cmpstr(strStart[strlen(strStart)-1], ">") == 0)
			strEnd = "<"
		else
			strEnd = "\""
		endif
	endif
	int selStart, selEnd
	selStart = strsearch(strHTML, strStart, 0, 2)
	if (selStart < 0)
		return "error"
	endif
	selStart += strlen(strStart)
	selEnd = strsearch(strHTML, strEnd, selStart, 2)
	if (selEnd < 0)
		return "error"
	endif
	return strHTML[selStart, selEnd-1]
end

// utility function, inflates a zip archive
// verbose=1 to print output from ExecuteScriptText
function UnzipArchive(string archivePathStr, string unzipPathStr, [int verbose])
	verbose = ParamIsDefault(verbose) ? 0 : verbose
	string validExtensions = "zip;" // set to "" to skip check
	string msg, unixCmd, cmd
		
	GetFileFolderInfo/Q/Z archivePathStr

	if (V_Flag || V_isFile==0)
		printf "Could not find file %s\r", archivePathStr
		return 0
	endif

	if (ItemsInList(validExtensions) && FindListItem(ParseFilePath(4, archivePathStr, ":", 0, 0), validExtensions, ";", 0, 0) == -1)
		printf "%s doesn't appear to be a zip archive\r", ParseFilePath(0, archivePathStr, ":", 1, 0)
		return 0
	endif
	
	if (strlen(unzipPathStr) == 0)
		unzipPathStr = SpecialDirPath("Desktop",0,0,0) + ParseFilePath(3, archivePathStr, ":", 0, 0)
		sprintf msg, "Unzip to %s:%s?", ParseFilePath(0, unzipPathStr, ":", 1, 1), ParseFilePath(0, unzipPathStr, ":", 1, 0)
		DoAlert 1, msg
		if (v_flag == 2)
			return 0
		endif
	else
		GetFileFolderInfo/Q/Z unzipPathStr
		if (V_Flag || V_isFolder==0)
			sprintf msg, "Could not find unzipPathStr folder\rCreate %s?", unzipPathStr
			DoAlert 1, msg
			if (v_flag == 2)
				return 0
			endif
		endif
	endif
	
	// make sure unzipPathStr folder exists - necessary for mac
	NewPath/C/O/Q acw_tmpPath, unzipPathStr
	KillPath/Z acw_tmpPath

	#ifdef WINDOWS
	// The following works with .Net 4.5, which is available in Windows 8 and up.
	// current versions of Windows with Powershell 5 can use the more succinct PS command
	// 'Expand-Archive -LiteralPath C:\archive.zip -DestinationPath C:\Dest'
	string strVersion = StringByKey("OSVERSION", IgorInfo(3))
	variable WinVersion = str2num(strVersion) // turns "10.1.2.3" into 10.1 and 6.23.111 into 6.2 (windows 8.0)
	if (WinVersion < 6.2)
		Print "unzipArchive requires Windows 8 or later"
		return 0
	endif

	archivePathStr = ParseFilePath(5, archivePathStr, "\\", 0, 0)
	unzipPathStr = ParseFilePath(5, unzipPathStr, "\\", 0, 0)
	cmd = "powershell.exe -nologo -noprofile -command \"& { Add-Type -A 'System.IO.Compression.FileSystem';"
	sprintf cmd "%s [IO.Compression.ZipFile]::ExtractToDirectory('%s', '%s'); }\"", cmd, archivePathStr, unzipPathStr
	#else // Mac
	sprintf unixCmd, "unzip '%s' -d '%s'", ParseFilePath(5, archivePathStr, "/", 0,0), ParseFilePath(5, unzipPathStr, "/", 0,0)
	sprintf cmd, "do shell script \"%s\"", unixCmd
	#endif
	
	ExecuteScriptText/B/UNQ/Z cmd
	if (verbose)
		Print S_value // output from executescripttext
	endif
	
	return (v_flag == 0)
end

// returns full path to alias if found, otherwise ""
function/S FindAlias(string folderPathStr, string targetPathStr)
	
	variable maxLevels = 5 // quit after recursion through this many sublevels
	variable folderLimit = 20 // quit after looking in this many folders.
	variable folderIndex, fileIndex, subfolderIndex, folderCount = 1, sublevels = 0
	string folderList

	if (strlen(folderPathStr)==0 || strlen(targetPathStr)==0)
		return ""
	endif
		
	Make/free/T/N=0 w_folders, w_subfolders
	w_folders = {folderPathStr}

	do
		for (folderIndex=0;folderIndex<numpnts(w_folders);folderIndex+=1)
			// check files at current level
			NewPath/O/Q/Z tempPathIXI, w_folders[folderIndex]
			fileindex = 0
			do
				GetFileFolderInfo/P=tempPathIXI/Q/Z IndexedFile(tempPathIXI, fileindex, "????")
				if (V_isFile == 0)
					break
				endif
				if (V_isAliasShortcut && stringmatch(S_aliasPath, targetPathStr))
					KillPath/Z tempPathIXI
					return s_path // set by getFileFolderInfo
				endif
				fileindex += 1
			while(1)
			// make a list of subfolders in current folder
			folderList = IndexedDir(tempPathIXI, -1, 0)
			for (subfolderIndex=0;subfolderIndex<ItemsInList(folderList);subfolderIndex+=1)
				w_subfolders[numpnts(w_subfolders)] = {w_folders[folderIndex] + StringFromList(subfolderIndex,folderList) + ":"}
				folderCount += 1
			endfor
		endfor
		Duplicate/T/O/free w_subfolders, w_folders
		Redimension/N=0 w_subfolders
		sublevels += 1
		
		if (numpnts(w_folders) == 0)
			break
		endif
		
		if (sublevels>maxLevels || (folderCount-folderIndex)>folderLimit)
			break
		endif
	while(1)
	KillPath/Z tempPathIXI
	return ""
end

// Search recursively for fileName within folder described by folderPathStr.
// Don't expect this to be quick.
// Returns path to file. Wildcards okay.
function/S FindFile(string folderPathStr, string fileName)
	
	variable maxLevels = 10 // quit after recursion through this many sublevels
	variable folderLimit = 5000 // quit after looking in this many folders.
	variable folderIndex, fileIndex, subfolderIndex, folderCount = 1, sublevels = 0
	string folderList, indexFileName

	if (strlen(folderPathStr) == 0)
		// it would be nice to default to the current save location, but I couldn't find a way to do that
		folderPathStr = SpecialDirPath("Documents", 0, 0, 0)
	endif
		
	Make/free/T/N=0 w_folders, w_subfolders
	w_folders = {folderPathStr}

	do
		for (folderIndex=0;folderIndex<numpnts(w_folders);folderIndex+=1)
			// check files at current level
			NewPath/O/Q/Z tempPathIXI, w_folders[folderIndex]

			fileindex = 0
			do
				indexFileName = IndexedFile(tempPathIXI, fileindex, "????")
				if (stringmatch(indexFileName, fileName))
					KillPath/Z tempPathIXI
					return w_folders[folderIndex] + indexFileName
				endif
				fileindex += 1
			while(strlen(indexFileName))
			// make a list of subfolders in current folder
			folderList = IndexedDir(tempPathIXI, -1, 0)
			for (subfolderIndex=0;subfolderIndex<ItemsInList(folderList);subfolderIndex+=1)
				w_subfolders[numpnts(w_subfolders)] = {w_folders[folderIndex] + StringFromList(subfolderIndex,folderList) + ":"}
				folderCount += 1
			endfor
		endfor
		Duplicate/T/O/free w_subfolders, w_folders
		Redimension/N=0 w_subfolders
		sublevels += 1
		
		if (numpnts(w_folders) == 0)
			break
		endif
		
		if (sublevels>maxLevels || (folderCount-folderIndex)>folderLimit)
			break
		endif

	while(1)
	KillPath/Z tempPathIXI
	return ""
end

// search recursively in folderPathStr for files matching fileName.
// returns list of complete paths to files
function/T RecursiveFileList(string folderPathStr, string fileName)
	
	variable maxLevels = 10 // quit after recursion through this many sublevels
	variable folderLimit = 1000 // quit after looking in this many folders
	variable folderIndex, fileIndex, subfolderIndex, folderCount = 1, sublevels = 0
	string folderList, indexFileName
	string fileList = ""

	if (strlen(folderPathStr) == 0)
		return ""
	endif
		
	Make/free/T/N=0 w_folders, w_subfolders
	w_folders = {folderPathStr}

	do
		for (folderIndex=0;folderIndex<numpnts(w_folders);folderIndex+=1)
			// check files at current level
			NewPath/O/Q/Z tempPathIXI, w_folders[folderIndex]

			fileIndex = 0
			do
				indexFileName = IndexedFile(tempPathIXI, fileindex, "????")
				if (stringmatch(indexFileName, fileName))
					fileList = AddListItem(w_folders[folderIndex] + indexFileName, fileList)
				endif
				fileIndex += 1
			while(strlen(indexFileName))
			// make a list of subfolders in current folder
			folderList = IndexedDir(tempPathIXI, -1, 0)
			for (subfolderIndex=0;subfolderIndex<ItemsInList(folderList);subfolderIndex+=1,folderCount+=1)
				w_subfolders[numpnts(w_subfolders)] = {w_folders[folderIndex] + StringFromList(subfolderIndex,folderList) + ":"}
			endfor
		endfor
		Duplicate/T/O/free w_subfolders, w_folders
		Redimension/N=0 w_subfolders
		sublevels += 1
		
		if (numpnts(w_folders) == 0)
			break
		endif
		
		if (((maxlevels && sublevels>maxLevels) || (folderLimit && (folderCount-folderIndex)>folderLimit)))
			break
		endif

	while(1)
	KillPath/Z tempPathIXI
	return fileList
end

// Merges folders like copyFolder on Windows, deletes source files
// Files in destination folder are overwritten by files from source
// Setting test=1 doesn't move anything but generates a list of files
// that would be overwritten
// ignore is a string list of names of files that should not be moved.
// includes a check for install scripts
function/S MergeFolder(source, destination, [killSourceFolder, backupPathStr, test, ignore])
	string source, destination
	int killSourceFolder, test
	string backupPathStr // must be no more than one sublevel below an existing folder
	string ignore // list of filenames that won't be moved
	
	killSourceFolder = ParamIsDefault(killSourceFolder) ? 1 : killSourceFolder
	test = ParamIsDefault(test) ? 0 : test
	backupPathStr = SelectString(ParamIsDefault(backupPathStr), backupPathStr, "")
	ignore = SelectString(ParamIsDefault(ignore), ignore, "")
	int backup = (strlen(backupPathStr)>0)
	
	// clean up paths
	source = ParseFilePath(2, source, ":", 0, 0)
	destination = ParseFilePath(2, destination, ":", 0, 0)
	if (backup)
		backupPathStr = ParseFilePath(2, backupPathStr, ":", 0, 0)
	endif
	
	// check that source and destination folders exist
	GetFileFolderInfo/Q/Z source
	variable sourceOK = V_isFolder
	GetFileFolderInfo/Q/Z destination
	if (sourceOK==0 || V_isFolder==0)
		return ""
	endif
	
	variable folderIndex, fileIndex, subfolderIndex, folderCount = 1, sublevels = 0
	string folderList, fileList, fileName
	string movedFileList = "", destFolderStr = "", subPathStr = ""
	
	Make/free/T/N=0 w_folders, w_subfolders
	w_folders = {source}
	do
		// step through folders at current sublevel
		for (folderIndex=0;folderIndex<numpnts(w_folders);folderIndex+=1)
			// figure out destination folder to match current source folder
			subPathStr = (w_folders[folderIndex])[strlen(source),strlen(w_folders[folderIndex])-1]
			destFolderStr = destination + subPathStr
			
			// make sure that folder exists at destination
			if (test == 0)
				NewPath/C/O/Q/Z tempPathIXI, destination + subPathStr
				if (backup)
					NewPath/C/O/Q/Z tempPathIXI, backupPathStr + subPathStr
				endif
			endif
					
			// get list of source files in indexth folder at current sublevel
			NewPath/O/Q/Z tempPathIXI, w_folders[folderIndex]
			fileList = IndexedFile(tempPathIXI, -1, "????")
			// remove files from list if they match an entry in ignorefileList
			fileList = RemoveFromListWC(fileList, ignore)
			// move files
			for (fileindex=0;fileIndex<ItemsInList(fileList);fileIndex+=1)
				fileName = StringFromList(fileindex, fileList)
				
				// check for install scripts
				if (CheckScript(w_folders[folderIndex] + fileName) == 1)
					continue
				endif
				
				if (test)
					GetFileFolderInfo/Q/Z destFolderStr + fileName
					if (v_flag==0 && v_isFile) // file is to be overwritten
						movedFileList = AddListItem(destFolderStr + fileName, movedfileList)
					endif
				else
					if (backup) // back up any files that are to be overwritten
						GetFileFolderInfo/Q/Z destFolderStr + fileName
						if (v_flag==0 && v_isFile) // file is to be overwritten
							//newPath/C/O/Q/Z tempPathIXI, backupPathStr + subPathStr; killpath/Z tempPathIXI
							MoveFile/Z/O destFolderStr + fileName as backupPathStr + subPathStr + fileName
						endif
					endif
					MoveFile/Z/O w_folders[folderIndex] + fileName as destFolderStr + fileName
					movedFileList = AddListItem(destFolderStr + fileName, movedfileList)
				endif
			endfor
			
			// make a list of subfolders in current folder
			folderList = IndexedDir(tempPathIXI, -1, 0)
			
			// remove folders that we don't want to copy
			folderList = RemoveFromListWC(folderList, ksIgnoreFoldersList)
			
			// add the list of folders to the subfolders wave
			for (subfolderIndex=0;subfolderIndex<ItemsInList(folderList);subfolderIndex+=1)
				w_subfolders[numpnts(w_subfolders)] = {w_folders[folderIndex] + StringFromList(subfolderIndex, folderList) + ":"}
				folderCount += 1
			endfor
		endfor
		// prepare for next sublevel iteration
		Duplicate/T/O/free w_subfolders, w_folders
		Redimension/N=0 w_subfolders
		sublevels += 1
	
		if (numpnts(w_folders) == 0)
			break
		endif

	while(1)
	KillPath/Z tempPathIXI
	
	if ((test == 0) && killSourceFolder)
		DeleteFolder/Z RemoveEnding(source, ":")
	endif
	
	return SortList(movedFileList)
end

// Merges folders like copyFolder on Windows
// Files in destination folder are overwritten by more recently modified
// files from source
// Setting test=1 doesn't move anything but generates a list of files
// that would be overwritten
// ignore is a string list of names of files that should not be moved.
function/S MirrorFolder(source, destination, [backupPathStr, test, ignore])
	string source, destination
	int test
	string backupPathStr // must be no more than one sublevel below an existing folder
	string ignore // list of filenames that won't be moved
	
	test = ParamIsDefault(test) ? 0 : test
	backupPathStr = SelectString(ParamIsDefault(backupPathStr), backupPathStr, "")
	ignore = SelectString(ParamIsDefault(ignore), ignore, "")
	int backup = (strlen(backupPathStr)>0)
	
	// clean up paths
	source = ParseFilePath(2, source, ":", 0, 0)
	destination = ParseFilePath(2, destination, ":", 0, 0)
	if (backup)
		backupPathStr = ParseFilePath(2, backupPathStr, ":", 0, 0)
	endif
	
	// check that source and destination folders exist
	GetFileFolderInfo/Q/Z source
	variable sourceOK = V_isFolder
	GetFileFolderInfo/Q/Z destination
	if (sourceOK==0 || V_isFolder==0)
		return ""
	endif
	
	variable folderIndex, fileIndex, subfolderIndex, folderCount = 1, sublevels = 0
	string folderList, fileList, fileName
	string movedFileList = "", destFolderStr = "", subPathStr = ""
	variable sourceMod
	int filefound
	
	Make/free/T/N=0 w_folders, w_subfolders
	w_folders = {source}
	do
		// step through folders at current sublevel
		for (folderIndex=0;folderIndex<numpnts(w_folders);folderIndex+=1)
			// figure out destination folder to match current source folder
			subPathStr = (w_folders[folderIndex])[strlen(source),strlen(w_folders[folderIndex])-1]
			destFolderStr = destination + subPathStr
			
			// make sure that folder exists at destination
			if (test == 0)
				NewPath/C/O/Q/Z tempPathIXI, destination + subPathStr
				if (backup)
					NewPath/C/O/Q/Z tempPathIXI, backupPathStr + subPathStr
				endif
			endif
					
			// get list of source files in indexth folder at current sublevel
			NewPath/O/Q/Z tempPathIXI, w_folders[folderIndex]
			fileList = IndexedFile(tempPathIXI, -1, "????")
			// remove files from list if they match an entry in ignorefileList
			fileList = RemoveFromListWC(fileList, ignore)
			// move files
			for (fileindex=0;fileIndex<ItemsInList(fileList);fileIndex+=1)
				fileName = StringFromList(fileindex, fileList)
				GetFileFolderInfo/Q/Z w_folders[folderIndex] + fileName
				sourceMod = V_modificationDate
				
				GetFileFolderInfo/Q/Z destFolderStr + fileName
				filefound = (v_flag == 0) && v_isFile
				sourceMod = filefound ? V_modificationDate < (sourceMod-10) : 1
			
				if (test)
					if (filefound && sourceMod) // file is to be overwritten
						movedFileList = AddListItem(destFolderStr + fileName, movedfileList)
					endif
				else
					if (backup) // back up any files that are to be overwritten
						if (filefound && sourceMod) // file is to be overwritten
							CopyFile/Z/O destFolderStr + fileName as backupPathStr + subPathStr + fileName
						endif
					endif
					if (sourceMod)
						CopyFile/Z/O w_folders[folderIndex] + fileName as destFolderStr + fileName
						movedFileList = AddListItem(destFolderStr + fileName, movedfileList)
					endif
				endif
			endfor
			
			// make a list of subfolders in current folder
			folderList = IndexedDir(tempPathIXI, -1, 0)
			
			// remove folders that we don't want to copy
			folderList = RemoveFromListWC(folderList, ksIgnoreFoldersList)
			
			// add the list of folders to the subfolders wave
			for (subfolderIndex=0;subfolderIndex<ItemsInList(folderList);subfolderIndex+=1)
				w_subfolders[numpnts(w_subfolders)] = {w_folders[folderIndex] + StringFromList(subfolderIndex, folderList) + ":"}
				folderCount += 1
			endfor
		endfor
		// prepare for next sublevel iteration
		Duplicate/T/O/free w_subfolders, w_folders
		Redimension/N=0 w_subfolders
		sublevels += 1
	
		if (numpnts(w_folders) == 0)
			break
		endif

	while(1)
	KillPath/Z tempPathIXI
		
	return SortList(movedFileList)
end

// ------------------------- Project Installer ---------------------

// Install() function is deprecated.

// install a user-contributed package hosted on Wavemetrics.com
// packageList is a list of project IDs.

// Looks for updaterscript.itx within package folder and executes if found.
// updaterscript.itx should create shortcuts for help files and XOPs as needed.
// Use updaterscriptWindows.itx or updaterscriptMacintosh.itx for OS specific installations.

// install("foo") installs IgorExchange project with long title foo in a
// location within the Igor User Files folder chosen by the user.

// install("foo;bar;", path=SpecialDirPath("Igor Pro User
// Files",0,0,0)+"User Procedures:") installs packages foo and bar in the
// User Procedures folder.

// install("foo;bar;", path="User Procedures") is an acceptable substitution.
// "User Procedures" is the only shortened alternative to a full path.

// if path is supplied for zip archive(s), subfolders may or may not
// not be created, depending on the structure of the archive.

function install(packageList, [path, gui])
	string packageList, path
	int gui
	
	// gui is not intended to be set when running from commandline
	gui = ParamIsDefault(gui) ? 0 : gui // default to gui=0: don't use DoAlert unless necessary
	path = SelectString(ParamIsDefault(path), path, "") // default to ""
	if (stringmatch(path, "User Procedures"))
		path = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "User Procedures:"
	elseif (stringmatch(path, "Igor Procedures"))
		path = SpecialDirPath("Igor Pro User Files", 0, 0, 0) + "Igor Procedures:"
	endif
	
	string url = "", cmd = "", projectName = "", projectID = ""
	int selStart, selEnd, i
	int nameIsURL = 0, successfulInstalls = 0
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	for (i=0;i<ItemsInList(packageList);i+=1)
		
		projectName = StringFromList(i, packageList)
		
		// projectName can be project ID, package long title, or filePath for a local install.
		if (isFile(projectName))
			successfulInstalls += InstallFile(projectName, path=path)
			continue
		endif
				
		int NameCol
		if (GrepString(projectName,"[^0-9]"))
			wave/Z/T ProjectsFullList = CacheGetProjectsWave()
			NameCol = FindDimLabel(ProjectsFullList, 1, "name")
			FindValue/TEXT=projectName/TXOP=4/RMD=[][NameCol] ProjectsFullList
			if (V_row > -1)
				projectID = ProjectsFullList[v_row][%projectID]
			else
				sprintf cmd, "Could not find project ID for %s\r", projectName
				WriteToHistory(cmd, prefs, 0)
				continue
			endif
		else
			projectID = projectName
		endif
		
		sprintf cmd, "Install started: %s", projectName
		WriteToHistory(cmd, prefs, 0)
		successfulInstalls += installProject(projectID, gui=gui, path=path)
	endfor
	return successfulInstalls
end

// url optionally supplies the file to be installed
// this can be used for local install
// must supply version with url!
function installProject(projectID, [gui, path, shortTitle, url, releaseVersion])
	string projectID
	int gui
	variable releaseVersion
	string path, shortTitle, url
	
	// gui is not intended to be set when running from commandline
	gui = ParamIsDefault(gui) ? 0 : gui
	// if we don't know the short title that's unfortunate
	string packageName = SelectString(ParamIsDefault(shortTitle), shortTitle, "project " + projectID)
	// packageName will be used until we get a better idea for shortTitle. projectName is the full title.
	shortTitle = SelectString(ParamIsDefault(shortTitle), shortTitle, "")
	path = SelectString(ParamIsDefault(path), path, "")
	url = SelectString(ParamIsDefault(url), url, "")
	releaseVersion = ParamIsDefault(releaseVersion) ? 0 : releaseVersion
	
	// where to save downloaded files - a temporary location
	string downloadPathStr = SpecialDirPath(ksDownloadlocation,0,0,0) + "TonyInstaller:"
		
	string projectName = "", cmd = ""
	string IncludeProcStr = "", packagePathStr = "", releaseExtra = "", backupPathStr = ""
	string fileList = "", fileName = "", fileExtension = "", destFileName = "", fileNameNoExt = ""
	variable releaseIgorVersion
	int selStart, selEnd, i
	int ListIndex = 0, success = 0, restricted = 0, isZip = 0
	
	variable currentIgorVersion = GetIgorVersion()
	string system = "your system"
	#ifdef WINDOWS
	system = "Windows"
	#endif
	#ifdef MACINTOSH
	system = "Macintosh"
	#endif
		
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
		
	backupPathStr = SelectString((prefs.options & 1), "", SpecialDirPath(ksBackupLocation,0,0,0))
	
	if (strlen(url) == 0)
				
		string ReleaseKeyList = DownloadKeylistFromProjectPage(projectID, prefs.pageTimeout)
		if (strlen(ReleaseKeyList) == 0) // download failed
			WriteToHistory("Could not load project page", prefs, gui)
			return 0
		endif
		
		// keys = "projectID;ReleaseCacheDate;name;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;"
		projectName = StringByKey("name", ReleaseKeyList)
		releaseIgorVersion = NumberByKey("releaseIgorVersion", ReleaseKeyList)
		releaseVersion = NumberByKey("remote", ReleaseKeyList)
		// shortTitle defaults to full name from web page
		shortTitle = StringByKey("name", ReleaseKeyList)
//		releaseExtra = StringByKey("?", ReleaseKeyList)

		if (currentIgorVersion < releaseIgorVersion)
			sprintf cmd, "%s %0.2f%s requires Igor Pro version >= %g\r", projectName, releaseVersion, releaseExtra, releaseIgorVersion
			WriteToHistory(cmd, prefs, gui)
		elseif (strlen(StringByKey("system", ReleaseKeyList)) && FindListItem(system, StringByKey("system", ReleaseKeyList), ",") == -1)
			sprintf cmd, "%s %0.2f%s not available for %s\r", projectName, releaseVersion, releaseExtra, system
			WriteToHistory(cmd, prefs, gui)
		else
			url = StringByKey("releaseURL", ReleaseKeyList)
		endif
		if (strlen(url) == 0)
			return 0
		endif
	endif

	// create the temporary folder
	NewPath/C/O/Q DLPathTemp, downloadPathStr; KillPath/Z DLPathTemp
	
	// download package
	if (gui)
		SetPanelStatus("Downloading " + url)
	endif
	URLRequest/time=(prefs.fileTimeout)/Z/O/FILE=downloadPathStr+ParseFilePath(0, url,"/", 1, 0) url=url
	if (V_flag)
		sprintf cmd, "Could not load %s\r", url
		WriteToHistory(cmd, prefs, gui)
		return 0
	endif
	fileName = S_fileName
	sprintf cmd, "Downloaded %s\r", url
	WriteToHistory(cmd, prefs, 0)
	sprintf cmd, "Saved temporary file %s\r", fileName
	WriteToHistory(cmd, prefs, 0)
	
	fileExtension = ParseFilePath(4, fileName, ":", 0, 0)
	isZip = stringmatch(fileExtension, "zip")
	
	if (isZip)
		//string archivePathStr = fileName // path to zip file
		string archiveName = ParseFilePath(0, fileName, ":", 1, 0)

		// create a temporary directory for the uncompressed files
		string unzipPathStr = CreateUniqueDir(downloadPathStr, "Install")

		// inflate archive
		success = UnzipArchive(fileName, unzipPathStr)
		if (success == 0)
			sprintf cmd, "unzipArchive failed to inflate %s\r", fileName
			WriteToHistory(cmd, prefs, 0)
			return 0
		endif
		sprintf cmd, "Inflated %s to %s\r", archiveName, unzipPathStr
		WriteToHistory(cmd, prefs, 0)
		fileList = RecursiveFileList(unzipPathStr, "*")
	else
		fileList = fileName
	endif
	
	if (strlen(GrepList(fileList,"((?i)(.ipf|.xop)$)")))
		restricted = 1
	endif
	
	// determine destination for file(s)
	if (strlen(path) == 0)
		packagePathStr = ChooseInstallLocation(projectName, restricted)
		if (strlen(packagePathStr) == 0)
			WriteToHistory("Install cancelled", prefs, 0)
			return 0
		endif
	else
		GetFileFolderInfo/Q/Z path
		if (v_flag!=0 || V_isFolder==0)
			sprintf cmd, "Install path not found: %s\r", path
			WriteToHistory(cmd, prefs, gui)
			return 0
		endif
		packagePathStr = path
	endif
			
	fileList = "" // keep a list of installed files

	// move files/folders to destination
	if (isZip)
		// test to find out which files will overwritten
		fileList = MergeFolder(unzipPathStr, packagePathStr, test=1, ignore=ksIgnoreFilesList)
		
		if (ItemsInList(fileList))
			cmd = GenerateOverwriteAlertString(filelist, rootPath=packagePathStr)
			DoAlert 1, cmd
			if (v_flag == 2)
				sprintf cmd, "Install cancelled for %s\r", packageName
				WriteToHistory(cmd, prefs, 0)
				InstallerCleanup(downloadPathStr)
				return 0
			endif

			if (strlen(backupPathStr))
				// create backup folder
				string folderName = CleanupName(projectName,0,30) // making it Igor-legal should hopefully ensure the name is good for the OS
				backupPathStr = CreateUniqueDir(backupPathStr, folderName)
				NewPath/Q/C/O/Z tempPathIXI, backupPathStr; KillPath/Z tempPathIXI
				sprintf cmd, "Created backup folder %s\r", backupPathStr
				WriteToHistory(cmd, prefs, 0)
			endif
		endif
			
		// move files into user procedures folder
		fileList = MergeFolder(unzipPathStr, packagePathStr, backupPathStr=backupPathStr, killSourceFolder=0, ignore=ksIgnoreFilesList)
		int numFiles = ItemsInList(fileList)
		for (i=0;i<numFiles;i+=1)
			fileName = StringFromList(i, fileList) // this is full path to file
			sprintf cmd, "Moved %s to %s\r", ParseFilePath(0, fileName, ":", 1, 0), ParseFilePath(1, fileName, ":", 1, 0)
			WriteToHistory(cmd, prefs, 0)
		endfor
		
	else // a single file
			
		// remove suffix if needed
		fileNameNoExt = ParseFilePath(3, fileName, ":", 0, 0) // fileName without extension
		if (kRemoveSuffix && GrepString(fileNameNoExt, "_[0-9]+$"))
			SplitString/E="(.*)_([0-9]+)$" fileNameNoExt, fileNameNoExt
		endif
		destFileName = fileNameNoExt + "." + fileExtension
		destFileName = RemoveHexEncoding(destFileName)
		
		GetFileFolderInfo/Q/Z packagePathStr + destFileName
		if (v_flag == 0) // already exists
			DoAlert 1, "overwrite " + destFileName + "?"
			if (v_flag == 2)
				return 0
			endif
			if (strlen(backupPathStr)) // backup the old file
				variable ver = GetProcVersion(packagePathStr + destFileName)
				string fileExt = ParseFilePath(4, destFileName, ":", 0, 0)
				string bupFile = ""
				fileExt = selectstring (strlen(fileExt) > 0, "", "." + fileExt)
				sprintf bupFile, "%s%g%s", ParseFilePath(3, fileName, ":", 0, 0), ver, fileExt			
				GetFileFolderInfo/Q/Z backupPathStr + bupFile
				if (v_flag == 0) // already exists
					bupFile = UniqueFileName(backupPathStr, bupFile, 0)
				endif
				MoveFile/Z 	packagePathStr + destFileName as backupPathStr + bupFile
				sprintf cmd, "Created backup file: %s\r", backupPathStr + bupFile
				WriteToHistory(cmd, prefs, 0)
			endif
		endif
		// install the new file
		MoveFile/O/Z fileName as packagePathStr + destFileName
		if (V_flag != 0)
			return 0
		endif
		fileList = packagePathStr + destFileName
		sprintf cmd, "Saved %s in %s\r", destFileName, packagePathStr
		WriteToHistory(cmd, prefs, 0)
	endif
	
	// figure out if we have a 'master' procedure file
	string IncludeProcPath = ""
	string ipfList = ListMatch(fileList, "*.ipf")
	int numIPFs = ItemsInList(ipfList)
	if (numIPFs == 1) // only one procedure file
		IncludeProcPath = StringFromList(0, ipfList)
		IncludeProcStr = ParseFilePath(3, IncludeProcPath, ":", 0, 0)
	elseif (numIPFs > 1)
		if (WhichListItem(packagePathStr + packageName + ".ipf", ipfList)!=-1)
			// package folder includes a procedure with project name
			IncludeProcPath = packagePathStr + packageName + ".ipf"
			IncludeProcStr = packageName
		elseif (WhichListItem(packagePathStr + ReplaceString(" ", packageName, "") + ".ipf", ipfList)!=-1)
			IncludeProcPath = packagePathStr + ReplaceString(" ", packageName, "") + ".ipf"
			IncludeProcStr = ReplaceString(" ", packageName, "")
		endif
	endif
	
	string ShortTitleFromFile = GetStringConstFromFile("ksShortTitle", IncludeProcPath)
	shortTitle = SelectString((strlen(ShortTitleFromFile)>0), shortTitle, ShortTitleFromFile)
		
	string msg = ""
	
	string pxpList = ListMatch(fileList, "*.pxp")
	
	// if there's an XOP in the package, don't try to open any procedure file
	string xopList = ListMatch(fileList, "*.xop")
	if (strlen(xopList))
		IncludeProcStr = ""
	endif	
	
	// problem: if package has mac and windows xops, but mac xop has
	// resource fork instead of extension, will offer to install an alias
	// for the windows xop!
	
	// such packages are unlikely to be 64-bit compatible anyway
	
//	// if only one xop in package offer to create alias
//	if(ItemsInList(xopList)==1)
//		fileName=StringFromList(0, xopList)
//		string ExtensionsPath=getIgorExtensionsPath()
//		// find out whether an alias already exists
//		variable aliasExists=(strlen(FindAlias(ExtensionsPath, fileName))>0)
//		variable isInExtensions=stringmatch(fileName, ExtensionsPath+"*")
//		if(!(aliasExists || isInExtensions))
//			sprintf msg, "Do you want to create an alias for\r%s\r)", ParseFilePath(0, fileName, ":", 1, 0)
//			msg+="in the Igor Extensions folder?"
//			DoAlert 1, msg
//			if(v_flag==1)
//				string aliasName=ParseFilePath(3, fileName, ":", 0, 0)+selectstring(isWin, " Alias", " Shortcut")
//				createAliasShortcut fileName as ExtensionsPath+aliasName
//				printf "Created %s in %s\r", aliasName, ExtensionsPath
//			endif
//		endif
//	endif

// solution is for developer to supply an itx script to create an alias for the correct xop.
// see the top of this file for more info about itx scripts.
		
	LogUpdateProject(projectID, shortTitle, packagePathStr, num2str(releaseVersion), fileList, num2istr(datetime))
	InstallerCleanup(downloadPathStr)
			
	// Look for and run itx-format installation script. Script will run
	// from within the package folder saved in location of user's
	// choice within Igor Pro User Files folder.
	
	// A comment at start of ITX identifies it unambiguously as an install script
	// like this: X // updater script
	
	// first grep all itx for X // updater script
	// then for X // updater script OS
	
	// fileList is list of full file paths
	
	string pathToScriptStr = ""
	string listOfITX = ListMatch(fileList, "*.itx")
	string ithITX = ""
	int numITX = ItemsInList(listOfITX)
	for (i=0;i<numITX;i++)
		ithITX = StringFromList(i, listOfITX)
		Grep/Z/Q/E="(?i)^X[\s]*//[\s]*Updater Script[\s]*$" ithITX
		if (V_value)
			pathToScriptStr = ithITX
			break
		endif
		Grep/Z/Q/E="(?i)^X[\s]*//[\s]*Updater Script[\s]*(for[\s]*)?" + system + "[\s]*$" ithITX
		if (V_value)
			pathToScriptStr = ithITX
			break
		endif
	endfor
	// note that script files will be left in the installation location.
	// deleting these files will change the project status to incomplete!
		
	// listMatch returns a list, and will always have separator at end
	pathToScriptStr = StringFromList(0, pathToScriptStr) // keep only the first item from the list, no trailing separator.
	string scriptFile = ParseFilePath(0, pathToScriptStr, ":", 1, 0)
	if (strlen(pathToScriptStr)) // script could do naughty things, so ask before allowing it to run
		sprintf msg, "Run installation script?\r%s was downloaded from %s", scriptFile, url
				
		DoAlert 1, msg
		if (v_flag == 1)
			sprintf cmd, "Loadwave/T \"%s\"", pathToScriptStr
			Execute cmd // will be printed to history
			WriteToHistory("Ran installation script: " + scriptFile, prefs, 0)
		endif
	endif
	
	if (!stringmatch(IncludeProcPath, SpecialDirPath("Igor Pro User Files",0,0,0) + "User Procedures:" + "*"))
		IncludeProcStr = ""
		if (stringmatch(IncludeProcPath, SpecialDirPath("Igor Pro User Files",0,0,0) + "Igor Procedures:" + "*"))
			DoAlert 0, "Restart Igor Pro to include the installed project:\r" + shortTitle
		endif
	endif
	
	if (strlen(IncludeProcStr)>0 && isLoaded(IncludeProcPath)==0)
		// 'master' procedure file is not loaded
		sprintf cmd "Do you want to include %s in the current experiment?", IncludeProcStr
		DoAlert 1, cmd
		if (v_flag == 1)
			// load the procedure
			sprintf cmd, "INSERTINCLUDE \"%s\"", IncludeProcStr
			Execute/P/Q/Z cmd
			Execute/P/Q/Z "COMPILEPROCEDURES "
			if (prefs.options & 2)
				printf "Included %s in current experiment\r", IncludeProcStr
			endif
		endif
	endif
	
	sprintf cmd, "Install complete: %s %g", shortTitle, releaseVersion
	WriteToHistory(cmd, prefs, 0)
	
	if (ItemsInList(pxpList)==1 && ItemsInList(xopList)==0)
		string strPXP = ParseFilePath(0, StringFromList(0, pxpList), ":", 1, 0)
		DoAlert 1, "do you want to open " + strPXP + " now?"
		if (v_flag == 1)
			Execute/P "LOADFILE " + StringFromList(0, pxpList)
		endif
	endif
	
// we do this in higher level function
//	#if IgorVersion() >= 9
//	Execute/P "RELOAD CHANGED PROCS "
//	Execute/P/Q/Z "COMPILEPROCEDURES "
//	#endif
	
	return 1
end

// returns 1 for a file indentified as a standalone install script
function CheckScript(string filePath)
	if (GrepString(filePath, "(?i)\.itx$"))
		Grep/Z/Q/E="(?i)^X // standalone install script" filePath
		if (V_flag==0 && V_value)
			return 1
		endif
	endif
	return 0
end

// Install from a local file:
// filePath is full path to file (local path from itx script works too).
// Path is install location, default is User Procedures.
// Path can be full path, "Igor Procedures", "Igor Extensions".
// If projectID, shortTitle, and version can be determined
// project will be added to install log.

// Multi-file projects must be packed into a zip archive.
// Usually filePathList will be path to one file, typically a zip archive.
// Provide a list (without setting projectID, shortTitle, and version) to
// install multiple packages.
function InstallFile(filePathList, [path, projectID, shortTitle, version])
	string filePathList, path, projectID, shortTitle, version
	
	int numPackagesToInstall = ItemsInList(filePathList)
	int numInstalled = 0, fileNum = 0
	string filePath
	string backupPathStr = SpecialDirPath(ksBackupLocation,0,0,0)
	
	for (fileNum=0;fileNum<numPackagesToInstall;fileNum+=1)
		filePath = StringFromList(fileNum, filePathList)
	
		if (isFile(filePath) == 0)
			// if InstallFile has been executed from an ITX script,
			// look in location of itx file for install files
			SVAR ITXpath = s_path
			if (SVAR_Exists(ITXpath))
				filePath = ITXpath + filePath
			endif
			if (isFile(filePath) == 0)
				Print "File not found " + filePath
				continue
			endif
		endif
		
		string fileList, ipfList, ipfFile, fileName, cmd
		int success, isZip, i
		projectID = SelectString(ParamIsDefault(projectID), projectID, "")
		shortTitle = SelectString(ParamIsDefault(shortTitle), shortTitle, "")
		version = SelectString(ParamIsDefault(version), version, "")
		
		if (ParamIsDefault(path) || stringmatch(path, "User Procedures") || strlen(path) == 0)
			path = SpecialDirPath("Igor Pro User Files",0,0,0) + "User Procedures:"
		elseif (stringmatch(path, "Igor Procedures"))
			path = SpecialDirPath("Igor Pro User Files",0,0,0) + "Igor Procedures:"
		elseif (stringmatch(path, "Igor Extensions"))
			path = GetIgorExtensionsPath()
		endif
		
		isZip = GrepString(filePath,"(?i)\.zip$")
		
		if (isZip)
			string archiveName = ParseFilePath(0, filePath, ":", 1, 0)
			string archiveFolder = ParseFilePath(1, filePath, ":", 1, 0)
			// create a temporary directory for the uncompressed files
			string unzipPathStr = CreateUniqueDir(archiveFolder, "Install")
			if (strlen(unzipPathStr) == 0)
				printf "could not create directory in %s\r", archiveFolder
				continue
			endif
			// inflate archive
			success = UnzipArchive(filePath, unzipPathStr)
			if (success == 0)
				printf "unzipArchive failed to inflate %s\r", filePath
				continue
			endif
			printf "Inflated %s to %s\r", archiveName, unzipPathStr
			fileList = RecursiveFileList(unzipPathStr, "*")
		else
			fileList = filePath
		endif
		
		ipfList = ListMatch(fileList, "*.ipf")
		if (ItemsInList(ipfList) == 1)
			ipfFile = StringFromList(0,ipfList)
			projectID = SelectString(strlen(projectID)==0, projectID, GetProjectIDString(ipfFile))
			shortTitle = SelectString(strlen(shortTitle)==0, shortTitle, GetShortTitle(ipfFile))
			version = SelectString(strlen(version)==0, version, num2str(GetProcVersion(ipfFile)))
		endif
			
		// check destination for file(s)
		GetFileFolderInfo/Q/Z path
		if (v_flag!=0 || V_isFolder==0)
			printf "Install path not found: %s\r", path
			continue
		endif
			
		fileList = "" // keep a list of installed files
		
		// move files/folders to destination
		if (isZip)
			// test to find out which files will overwritten
			fileList = MergeFolder(unzipPathStr, path, test=1, ignore=ksIgnoreFilesList)
			
			if (ItemsInList(fileList))
				cmd = GenerateOverwriteAlertString(filelist, rootPath=path)
				DoAlert 1, cmd
				if (v_flag == 2)
					printf "Install cancelled\r"
					continue
				endif
			endif
			// move files into user procedures folder
			fileList = MergeFolder(unzipPathStr, path, killSourceFolder=0, ignore=ksIgnoreFilesList)
			int numFiles = ItemsInList(fileList)
			for (i=0;i<numFiles;i+=1)
				fileName = StringFromList(i, fileList) // this is full path to file
				printf "Moved %s to %s\r", ParseFilePath(0, fileName, ":", 1, 0), ParseFilePath(1, fileName, ":", 1, 0)
			endfor
			
		else // a single file
			fileName = ParseFilePath(0, filePath, ":", 1, 0)
			GetFileFolderInfo/Q/Z path + fileName
			if (v_flag == 0) // already exists
				DoAlert 1, "overwrite " + fileName + "?"
				if (v_flag == 2)
					continue
				endif
			endif
			MoveFile/O/Z filePath as path + fileName
			if (V_flag != 0)
				continue
			endif
			fileList = path + fileName
			printf "Saved %s in %s\r", fileName, path
		endif
		
		// if we have the required parameters, register this project in the install log
		// to check for updated releases at wavemetrics.com
		if (strlen(projectID) && strlen(shortTitle) && strlen(version))
			LogUpdateProject(projectID, shortTitle, path, version, fileList, num2istr(datetime))
			printf "Added %s to install log\r", shortTitle
		endif
		numInstalled += 1
	endfor // next file
	return numInstalled
end

// del bit 0: overwrite, bit 1: delete
function/S GenerateOverwriteAlertString(string filelist, [string rootPath, int del])
	rootPath = SelectString(ParamIsDefault(rootPath), rootPath, "")
	del = ParamIsDefault(del)? 1 : del
	string cmd = ""
	sprintf cmd "The following files will be %s:\r", SelectString(del-2, "overwritten", "deleted", "overwritten or deleted")
	string tooMany = "\r*** TOO MANY FILES TO LIST ***\r"
	string cont = "\rContinue?"
	string fileName
	int numFiles = ItemsInList(filelist), startpos = strlen(rootPath)
	int cmdLen = strlen(cmd) + strlen(tooMany) + strlen(cont)
	int i
	for (i=0;i<numFiles;i+=1)
		fileName = StringFromList(i, fileList)
		if (stringmatch(fileName, rootPath + "*"))
			fileName = fileName[startpos,Inf]
		endif
		// avoid too-long alert
		if ( cmdLen+strlen(fileName) >= 1023 )
			cmd += tooMany
			break
		endif
		cmd += fileName + "\r"
		cmdLen += strlen(fileName + "\r")
	endfor
	cmd += cont
	return cmd
end

// uninstall is probably not undoable
// folders and subfolders will be left in place
function UninstallProject(string projectID)
	string installedfileList = LogGetFileList(projectID)
	string installPath = LogGetInstallPath(projectID)
	string deletefileList = "", filePath = "", fileName = "", deletePath = "", cmd = ""
	int numFiles, i
	numFiles = ItemsInList(installedfileList)
	for (i=0;i<numFiles;i+=1)
		filePath = StringFromList(i, installedfileList)
		deletefileList += SelectString(isFile(filePath), "", filePath + ";")
	endfor
	if (ItemsInList(deletefileList))
		cmd = GenerateOverwriteAlertString(deletefileList, rootPath=installPath, del=2)
		DoAlert 1, cmd
		if (v_flag == 2)
			STRUCT PackagePrefs prefs
			LoadPrefs(prefs)
			WriteToHistory("Uninstall cancelled", prefs, 0)
			return 0
		endif
		deletePath = CreateUniqueDir(SpecialDirPath("Temporary",0,0,0), projectID)
	endif
	
	MoveFiles(deletefileList, installPath, deletePath)
	LogRemoveProject(projectID)
	return 1
end

//function CreateAlias(string targetPathStr)
//
//	string folderPathStr = ""
//
//	if (stringmatch(targetPathStr, "*.ihf"))
//		folderPathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0)+"Igor Help Files:"
//	elseif (stringmatch(targetPathStr, "*.xop"))
//		folderPathStr = SpecialDirPath("Igor Pro User Files", 0, 0, 0)
//		if (grepstring(stringbykey("IGORKIND", igorinfo(0)), ".*64.*"))
//			folderPathStr += "Igor Extensions (64-bit):"
//		else
//			folderPathStr += "Igor Extensions:"
//		endif
//	else
//		print "installer: unsupported file type for alias creation"
//		return 0
//	endif
//
//	if (strlen(FindAlias(folderPathStr, targetPathStr)))
//		return 0
//	endif
//
//	string strAlias = ""
//
//end

// removes some potential url encodings
// probably OK to use URLDecode() instead of this?
threadsafe function/S RemoveHexEncoding(string s)
	Make/free/T w_encoded = {"%24","%26","%2B","%2C","%2D","%2E","%3D","%40","%20","%23","%25"}
	Make/free/T w_unencoded = {"$","&","+",",","-",".","=","@"," ","#","%"}
	int i, imax = numpnts(w_encoded)
	for (i=0;i<imax;i+=1)
		s = ReplaceString(w_encoded[i], s, w_unencoded[i])
	endfor
	return s
end

// removes some potential html encodings
threadsafe function/S RemoveHTMLEncoding(string s)
	Make/free/T w_encoded = {"&gt;", "&lt;", "&amp;", "&quot;", "&apos;", "&#039;"}
	Make/free/T w_unencoded = {">", "<", "&", "\"", "'", "'"}
	int i, imax = numpnts(w_encoded)
	for (i=0;i<imax;i+=1)
		s = ReplaceString(w_encoded[i], s, w_unencoded[i])
	endfor
	return s
end

function/S GetIgorExtensionsPath()
	NewPath/O/Q/Z tempPathIXI, SpecialDirPath("Igor Pro User Files", 0, 0, 0)
	string folderList = IndexedDir(tempPathIXI, -1, 0)
	KillPath/Z tempPathIXI
	string ExtensionsPath = ListMatch(folderList, "Igor Extensions*")
	return SpecialDirPath("Igor Pro User Files", 0, 0, 0) + StringFromList(0, ExtensionsPath) + ":"
end

// creates a file if one doesn't exist
function/S GetInstallerFilePath(string fileName)
	string UserFilesPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0)
	string InstallerPath = UserFilesPath + ksLogPath
	if (isFile(InstallerPath + fileName))
		return InstallerPath + fileName
	else
		string tmpPath = UserFilesPath //
		int i, subfolders
		subfolders = ItemsInList(ksLogPath, ":")
		for (i=0;i<subfolders;i+=1)
			tmpPath += StringFromList(i, ksLogPath, ":") + ":"
			NewPath/C/O/Q/Z tempPathIXI, tmpPath
		endfor
		KillPath/Z tempPathIXI
	endif
	// InstallerPath folder should now exist
	// before we create log file, check that we have a human-readable
	// file in the same location
	if (isFile(InstallerPath + "installer-readme.txt") == 0)
		variable refnum
		Open/A/Z refnum as InstallerPath + "installer-readme.txt"
		if (V_flag == 0)
			fprintf refnum, "The files in this folder were created by IgorExchange Installer\r\n"
			fprintf refnum, "https://www.wavemetrics.com/Project/Updater\r\n"
			fprintf refnum, "Do not delete or move %s!\r\n", ksLogFile
			Close refnum
		endif
	endif
	// now create the file
	Open/A/Z refnum as InstallerPath + fileName
	if (V_flag == 0)
		variable version = GetProcVersion(FunctionPath(""))
		fprintf refnum, "File created by IgorExchange Installer %0.2f\r\n", version
		Close refnum
	endif
	
	return InstallerPath + fileName
end

// *** Log file ***

// -------------- functions for writing to and querying install-log file ------------

// File name and location are set in string constants at the top of this file.
// First line records the version of this procedure that created the file.
// Subsequent lines are semicolon-separated lists, terminated by carriage return.
// Each list starts with projectID.
// First seven items are projectID;shortTitle;version;installDate;dirIDStr;installPath;lastUpdate;
// Next three items are reserved for future use
// List items 10 onward are paths to installed files.
// installPath is either path from directory specified by dirIDStr, or
// full path for installations outside of these locations. Paths to files
// start from folder given by installPath. dirIDStr specifies a file
// system directory parameter, as used by SpecialDirPath. When dirIDStr
// is empty, installPath is full path. Setting dirIDStr allows files to
// be copied to new installations.

// GetInstallerFilePath(ksLogFile) creates a log file if one doesn't exist

// replaces any existing log entry for projectID
function LogUpdateProject(projectID, shortTitle, installPath, newVersion, fileList, lastUpdate)
	string projectID, shortTitle, installPath, newVersion, fileList, lastUpdate
	int restricted
	
	string InstallDate = StringFromList(3, LogGetProject(projectID))
	if (strlen(InstallDate) == 0)
		InstallDate = num2istr(datetime)
	endif
	LogRemoveProject(projectID)
	int i
	string s_out, file, root = "", installSubPath = ""
	string UserFilesPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0)
	string DocumentsPath = SpecialDirPath("Documents", 0, 0, 0)
	if (stringmatch(installPath,UserFilesPath + "*"))
		root = "Igor Pro User Files"
		installSubPath = installPath[strlen(UserFilesPath), Inf]
	elseif (stringmatch(installPath,DocumentsPath + "*"))
		root = "Documents"
		installSubPath = installPath[strlen(DocumentsPath), Inf]
	else
		installSubPath = installPath
	endif
	
	sprintf s_out "%s;%s;%s;%s;%s;%s;%s;;;;", projectID, shortTitle, newVersion, InstallDate, root, installSubPath, lastUpdate
	for (i=0;i<ItemsInList(fileList);i+=1)
		file = StringFromList(i, fileList)
		// usually filelist will be a list of full paths, but if we're
		// using UpdateFile to replace a file it may contain just the filename.
		if (stringmatch(file, installPath + "*"))
			file = file[strlen(installPath), Inf]
		endif
		s_out += file + ";"
	endfor
	s_out += "\r"
	return LogAppend(s_out)
end

function LogReplaceProject(string projectID, string strLine)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return 0
	endif
	Make/T/N=0/free w
	string s_exp = ""
	sprintf s_exp, "^%s;", projectID
	// extract lines not starting with projectID into free text wave
	Grep/O/Z/ENCG=1/E={s_exp, 1} filePath as w
	// add new line
	w[numpnts(w)] = {strLine}
	// overwrite log file with all lines from textwave
	Grep/O/Z/E="" w as filePath
	return V_value // number of projects remaining in log
end

function LogUpdateInstallPath(string projectID, string installPath)
	if (strlen(installPath) == 0)
		return 0
	endif
	string root = ""
	string UserFilesPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0)
	string DocumentsPath = SpecialDirPath("Documents", 0, 0, 0)
	if (stringmatch(installPath, UserFilesPath + "*"))
		root = "Igor Pro User Files"
		installPath = installPath[strlen(UserFilesPath), Inf]
	elseif (stringmatch(installPath, DocumentsPath + "*"))
		root = "Documents"
		installPath = installPath[strlen(DocumentsPath), Inf]
	endif
		
	string logEntry = LogGetProject(projectID)
	LogRemoveProject(projectID)
	
	int i
	string s_out = ""
	for (i=0;i<ItemsInList(logEntry);i+=1)
		switch(i)
			case 4:
				s_out += root + ";"
				break
			case 5:
				s_out += installPath + ";"
	 			break
	 		default:
	 			s_out += StringFromList(i, logEntry) + ";"
		endswitch
	endfor
	return LogAppend(s_out)
end

// s is a complete line
function LogAppend(string s)
	if (!strlen(s))
		return 0
	endif
	
	string filePath = GetInstallerFilePath(ksLogFile)
	variable refnum
	Open/A/Z refnum as filePath
	if (V_flag)
		return 0
	endif
	s = RemoveEnding(s, "\r") + "\r"
	FBinWrite refnum, s
	Close refnum
	return 1
end

// returns the line from log file that starts with projectID
function/S LogGetProject(string projectID)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return ""
	endif
	Make/T/N=0/free w
	string s_exp = ""
	sprintf s_exp, "^%s;", projectID
	// extract lines starting with projectID into free text wave
	Grep/O/Z/ENCG=1/E=s_exp filePath as w
	if (V_value)
		return w[0]
	endif
	return ""
end

// returns currently installed version as string
function/S LogGetVersion(string projectID)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return ""
	endif
	Make/T/N=0/free w
	string s_exp = ""
	sprintf s_exp, "^%s;", projectID
	// extract lines starting with projectID into free text wave
	Grep/O/Z/ENCG=1/E=s_exp filePath as w
	if (V_value)
		return StringFromList(2, w[0])
	endif
	return ""
end

// for single file projects, get full path to file
function/S LogGetFilePath(string projectID)
	string logEntry = LogGetProject(projectID)
	if (strlen(logEntry) == 0)
		return ""
	endif
	string root = StringFromList(4, logEntry)
	if (strlen(root))
		root = SpecialDirPath(root, 0, 0, 0)
	endif
	return root + StringFromList(5, logEntry) + StringFromList(10, logEntry)
end

function/S LogGetInstallPath(string projectID)
	string logEntry = LogGetProject(projectID)
	if (strlen(logEntry) == 0)
		return ""
	endif
	string root = StringFromList(4, logEntry)
	if (strlen(root))
		root = SpecialDirPath(root, 0, 0, 0)
	endif
	return root + StringFromList(5, logEntry)
end

function/S LogGetFileList(string projectID)
	string logEntry = LogGetProject(projectID)
	if (strlen(logEntry) == 0)
		return ""
	endif
	string installPath = StringFromList(4, logEntry)
	if (strlen(installPath))
		installPath = SpecialDirPath(installPath, 0, 0, 0)
	endif
	installPath += StringFromList(5, logEntry)
	string fileList = ""
	int i
	int imax = ItemsInList(logEntry)
	for (i=10;i<imax;i+=1)
		fileList += installPath + StringFromList(i, logEntry) + ";"
	endfor
	return fileList
end

// remove empty lines and optionally missing projects from log file
// test = 1 returns number of missing projects
// test = 0 returns number of projects in cleaned file
function LogCleanup([int projects, int test])
	projects = ParamIsDefault(projects) ? 1 : projects
	test = ParamIsDefault(test) ? 0 : test
	
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return 0
	endif

	Make/T/N=0/free w
	// extract lines into free text wave
	Grep/O/Z/ENCG=1/E="" filePath as w
		
	int line, j, numFiles
	int badProjects = 0
	string root = "", installPath = ""
	
	for (line=numpnts(w)-1;line>1;line-=1)
		numFiles = 0
		if (GrepString(w[line], "^[0-9]+;") == 0)
			DeletePoints line, 1, w
			continue
		endif
		if (!projects)
			continue
		endif
		
		root = StringFromList(4, w[line])
		if (strlen(root))
			installPath = SpecialDirPath(root, 0, 0, 0)
		endif
		installPath += StringFromList(5, w[line]) // full path to install location
		// fileList starts at item 10 in list
		for (j=10;j<ItemsInList(w[line]);j+=1)
			numFiles += isFile(installPath + StringFromList(j, w[line]))
		endfor
		if (numFiles == 0)
			badProjects += 1
			if (!test)
				DeletePoints line, 1, w
			endif
		endif
	endfor
	
	// overwrite log file with lines from textwave
	Grep/O/Z/E="" w as filePath
	return test ? badProjects : V_value-1 // number of projects remaining in log
end

// returns a stringlist of projectIDs for installed projects
function/S ListOfProjectsFromInstallLog()
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return ""
	endif
	string projectList = "", strLine = ""
	int i, numLines
	// use grep to read all project lines into a string
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/O/Z/E="^[0-9]+;"/LIST="\r" filePath
	
	if (v_flag != 0)
		return ""
	endif
	
	numLines = ItemsInList(s_value, "\r")
	for (i=0;i<numLines;i+=1)
		strLine = StringFromList(i, s_value, "\r")
		projectList = AddListItem(StringFromList(0, strLine), projectList)
	endfor
	return projectList
end

// clear a project from the log file
function LogRemoveProject(string projectID)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return 0
	endif
	Make/T/N=0/free w
	string s_exp = ""
	sprintf s_exp, "^%s;", projectID
	// extract lines not starting with projectID into free text wave
	Grep/O/Z/ENCG=1/E={s_exp, 1} filePath as w
	// overwrite log file with all lines from textwave
	Grep/O/Z/E="" w as filePath
	return V_value // number of projects remaining in log
end

// lineNum is zero based line number
// projects start on line 1
function LogRemoveLine(int lineNum)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return 0
	endif
	Make/T/N=0/free w
	// extract lines into free text wave
	Grep/O/Z/ENCG=1/E="" filePath as w
	DeletePoints linenum, 1, w
	// overwrite log file with lines from textwave
	Grep/O/Z/E="" w as filePath
	return V_value // number of projects remaining in log
end

// examines log file to figure out whether project can be updated
// updates are not allowed for incomplete or missing projects
function/S GetUpdateStatus(string projectID, variable localVersion, variable remoteVersion)
	string status = GetInstallStatus(projectID)
	if (cmpstr(status, "complete") == 0)
		if (remoteVersion > localVersion)
			status += ", update available"
		else
			status += ", up to date"
		endif
	endif
	return status // "missing", "incomplete", "complete, up to date", or "complete, update available"
end

// returns "complete", "incomplete", or "missing" depending on how many of the installed files can be located
function/S GetInstallStatus(string projectID)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (strlen(projectID)==0 || isFile(filePath)==0)
		return ""
	endif
	
	// extract line starting with projectID into free text wave
	string s_exp = ""
	int numfiles = 0, i = 0
	sprintf s_exp, "^%s;", projectID
	Make/T/N=0/free w
	Grep/O/Z/ENCG=1/E=s_exp filePath as w
	
	if (numpnts(w) == 0)
		return ""
	endif
	
	string root = "", installPath = ""
	root = StringFromList(4, w[0])
	if (strlen(root))
		installPath = SpecialDirPath(root, 0, 0, 0)
	endif
	installPath += StringFromList(5, w[0]) // full path to install location
		
	for (i=10;i<ItemsInList(w[0]);i+=1) // list of files starts at item 10
		numFiles += isFile(installPath + StringFromList(i, w[0]))
	endfor
	if (numFiles == 0)
		return "missing"
	elseif (numFiles<(ItemsInList(w[0])-10))
		return "incomplete"
	endif
	return "complete"
end

// returns text describing the files associated with project
function/S GetInstalledFilesSummary(string projectID)
	string filePath = GetInstallerFilePath(ksLogFile)
	if (isFile(filePath) == 0)
		return ""
	endif
	
	// extract line starting with projectID into free text wave
	string s_exp = "", fileList = ""
	sprintf s_exp, "^%s;", projectID
	Make/T/N=0/free w
	Grep/O/Z/ENCG=1/E=s_exp filePath as w
	
	if (numpnts(w) == 0)
		return ""
	endif
	
	string root = "", subpath = "", installPath = "", filesInfo = ""
	root = StringFromList(4, w[0])
	subpath = StringFromList(5, w[0])
	if (strlen(root))
		installPath = SpecialDirPath(root, 0, 0, 0)
	endif
	installPath += subpath // full path to install location
		
	string strFile = ""
	int i = 0, numFiles = 0, numIPF = 0, numIHF = 0, numXOP = 0, numPXP = 0, numOther = 0, numMissing = 0
		
	for (i=10;i<ItemsInList(w[0]);i+=1) // list of files starts at item 10
		strFile = installPath + StringFromList(i, w[0])
		numFiles += 1
		if (isFile(strFile) == 0)
			numMissing += 1
		elseif (GrepString(strFile,"(?i)\.ipf$"))
			numIPF += 1
		elseif (GrepString(strFile,"(?i)\.ihf$"))
			numIHF += 1
		elseif (GrepString(strFile,"(?i)\.xop$"))
			numXOP += 1
		elseif (GrepString(strFile,"(?i)\.pxp$"))
			numPXP += 1
		else
			numOther += 1
		endif
	endfor
	
	sprintf filesInfo, "%s\r", subpath
	
	if (numIPF)
		filesInfo += " " + num2str(numIPF) + " ipf,"
	endif
	if (numIHF)
		filesInfo += " " + num2str(numIHF) + " ihf,"
	endif
	if (numXOP)
		filesInfo += " " + num2str(numXOP) + " xop,"
	endif
	if (numPXP)
		filesInfo += " " + num2str(numPXP) + " pxp,"
	endif
	if (numOther)
		filesInfo += " " + num2str(numOther) + " other,"
	endif
	if (numMissing)
		filesInfo += " " + num2str(numMissing) + " missing,"
	endif

	return RemoveEnding(filesInfo, ",")
end


// *** Cache file ***

// --------- functions for writing to and retrieving projects from cache file --------
// Cache file structure:
// Semicolon-separated list for each project, list starts with projectID,
// terminated by carriage return.
// 16 items in list:
// projectID;ProjectCacheDate;title;author;published;views;type;userNum;
// ReleaseCacheDate;shortTitle;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo
// Items 1-7 are extracted from the project index pages.
// The rest come from project web pages, which are parsed only for
// projects that exist in user procedures

// GetInstallerFilePath(ksCacheFile) creates a cache file if one doesn't exist

function/S CacheGetProjectsList() // about 16 ms
	string filePath = GetInstallerFilePath(ksCacheFile)
	if (isFile(filePath) == 0)
		return ""
	endif
	
	string projectList = "", strLine = ""
	int i, numLines
	// use grep to read all project lines into a string
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/O/Z/ENCG=1/LIST="\r"/E=";" filePath
	
	if (V_flag != 0)
		return ""
	endif
	
	numLines = ItemsInList(s_value, "\r")
	for (i=0;i<numLines;i+=1)
		strLine = StringFromList(i, s_value, "\r")
		projectList = AddListItem(StringFromList(0, strLine), projectList)
	endfor
	return projectList
end

function/wave CacheGetProjectsWave()
	
	string filePath = GetInstallerFilePath(ksCacheFile)
	
	Make/T/N=0/free w
	Grep/O/Z/ENCG=1/E=";" filePath as w // load cache without header
	int numLines = numpnts(w)
	
	if (numLines)
		Make/free/T/N=(numLines,10) ProjectsFullList
		SetDimLabels(ksProjectsDimLabelsList, 1, ProjectsFullList)
		// extract strings from the list on each line into corresponding columns
		ProjectsFullList = StringFromList(q, w[p])
	endif

	return ProjectsFullList
end

// retrieve project from cache and return keylist of cached parameters
function/S CacheGetKeyList(string projectID) // about 19 ms
	string s = CacheGetProject(projectID)
	if (strlen(s) == 0)
		return ""
	endif
	return CacheString2KeyList(CacheGetProject(projectID))
end

// retrieve project from cache and return list of cached parameters
function/S CacheGetProject(string projectID) // about 11 ms
	string filePath = GetInstallerFilePath(ksCacheFile)
	string s_exp
	sprintf s_exp, "^%s;", projectID
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Z/Q/LIST="\r"/ENCG=1/E=s_exp filePath
	if (strlen(s_value))
		return StringFromList(0, s_value, "\r")
	endif
	return ""
end

// turns a line from cache into a keylist
// avoids empty keypairs
// shortTitle will likely be the same as title
function/S CacheString2KeyList(string cacheEntry)
	string keyList = "", s = "", key = ""
	string keys = "projectID;ProjectCacheDate;title;author;published;views;type;userNum;"
	keys += "ReleaseCacheDate;shortTitle;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;"
	int i
	for (i=0;i<16;i+=1)
		s = StringFromList(i, cacheEntry)
		if (strlen(s))
			key = StringFromList(i,keys)
			keyList = ReplaceStringByKey(key, keyList, s)
		endif
	endfor
	return keyList
end

// inserts keyList values into cache
// keyList should not have empty values
// keylist will likely have name rather than shortTitle, so shortTitle will not be updated.
function CachePutKeylist(string keyList)	// about 25 ms
	string projectID = StringByKey("projectID", keyList)
	if (strlen(projectID) == 0)
		return 0
	endif
	string filePath = GetInstallerFilePath(ksCacheFile), oldKeyList = CacheGetKeyList(projectID)
	keyList += oldKeyList // items not in new keyList will be set to their value (if any) in oldKeyList

	string s_out = "", key = ""
	string keys = "projectID;ProjectCacheDate;title;author;published;views;type;userNum;"
	keys += "ReleaseCacheDate;shortTitle;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;"
	int i
	for (i=0;i<16;i+=1)
		key = StringFromList(i,keys)
		s_out += StringByKey(key, keyList) + ";"
	endfor
	
	string s_exp
	sprintf s_exp, "^%s;", projectID
	Make/T/N=0/free w
	// extract lines not starting with projectID into free text wave
	Grep/O/Z/ENCG=1/E={s_exp, 1} filePath as w
	w[numpnts(w)] = {s_out}
	Sort/A w, w // header remains at point 0
	// overwrite cache file with all lines from textwave
	Grep/O/Z/E="" w as filePath
	
	return V_value // number of projects remaining in cache
end

// ProjectsWave contains downloaded information for each project.
// if updates = 1, the list is
// projectID;ReleaseCacheDate;title;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;
// otherwise it is
// projectID;ProjectCacheDate;title;author;published;views;type;userNum;
function CachePutWave(wave/T ProjectsWave, int updates)
	if (DimSize(ProjectsWave, 0) == 0)
		return 0
	endif
	
	// load cache, if it exists, as text wave
	wave/T CacheWave = CacheLoad()
	
	string s_exp = "", strList = "", projectID = "", strLine = ""
	int i
	
	for (i=0;i<DimSize(ProjectsWave, 0);i+=1)
		projectID = StringFromList(0,ProjectsWave[i])
		if (strlen(projectID) == 0)
			continue
		endif
		// make an empty list for this project
		strList = projectID + ";;;;;;;;;;;;;;;;"
		
		// pull the project from the cache
		sprintf s_exp, "^%s;", projectID
		string S_Value = "" // workaround for Grep bug for Igor 8
		Grep/Z/Q/LIST=""/INDX/E=s_exp CacheWave
		wave/Z w_index
		if (strlen(s_value)) // put the cached project in list string
			// remove project from CacheWave
			do
				DeletePoints/M=0 (w_index[0]), 1, CacheWave
				DeletePoints 0, 1, w_index
			while (numpnts(w_index))
			
			// get any values that have been set by project installer
			strList = s_value
			do // remove any trailing items (should be 16 items per line)
				strList = RemoveListItem(16, strList)
			while (ItemsInList(strList) > 16)
		endif
		KillWaves/Z w_index
		
		// remove first item (projectID) from list
		strLine = RemoveListItem(0, ProjectsWave[i])
		
		if (updates)
			// insert new update info into list string
			strList = ReplaceListItem(8, strList, RemoveEnding(strLine, ";"), numItems=8) // avoid trailing ;
		else
			// insert new update info into list string
			strList = ReplaceListItem(1, strList, RemoveEnding(strLine, ";"), numItems=7) // avoid trailing ;
		endif
		
		// write project to CacheWave
		CacheWave[numpnts(CacheWave)] = {strList}
	endfor
	
	if (numpnts(CacheWave) == 0)
		return 0
	endif
	
	Sort/A CacheWave, CacheWave // header stays at point 0
	Grep/O/Z/E="" CacheWave as GetInstallerFilePath(ksCacheFile)
	return v_value
end

// expunges old projects from cache and returns remaining cached projects as a 1D text wave
function/wave CacheLoad()
	string filePath = GetInstallerFilePath(ksCacheFile)
	Make/T/N=0/free CacheWave
	Grep/O/Z/ENCG=1/E="" filePath as CacheWave // load cache if it exists
	if (numpnts(CacheWave) == 0)
		Print "* Updater error: couldn't open cache file *"
		return CacheWave // shouldn't arrive here
	endif
	Make/free/N=(numpnts(CacheWave)) CacheValid
	int timeNow = datetime, oneWeek = 60 * 60 * 24 * 7
	CacheValid = (timeNow - str2num(StringFromList(1, CacheWave[p]))) < oneWeek
	CacheValid[0] = 1 // preserve header row
	if (WaveMin(CacheValid) == 0)
		Extract/O/T CacheWave, CacheWave, CacheValid
		Grep/O/Z/E="" CacheWave as filePath
	endif
	return CacheWave
end

// set item 8, the time that updates info was cached, to 0 for each project
function CacheClearUpdates([string projectID])
	if (ParamIsDefault(projectID))
		string filePath = GetInstallerFilePath(ksCacheFile)
		Make/T/N=0/free CacheWave
		Grep/O/Z/ENCG=1/E="" filePath as CacheWave // load cache if it exists
		if (numpnts(CacheWave) == 0)
			return 0
		endif
		CacheWave[1,Inf] = ReplaceListItem(8, CacheWave[p], "0")
		Grep/O/Z/E="" CacheWave as filePath
		return v_value
	endif
	string keylist = ""
	keylist = CacheGetKeyList(projectID)
	keylist = ReplaceStringByKey("ReleaseCacheDate", keylist, "0")
	CachePutKeylist(keyList)
end

// reset cache file
function CacheClearAll()
	string filePath = GetInstallerFilePath(ksCacheFile)
	variable refnum
	Open/Z refnum as filePath
	if (V_flag == 0)
		variable version = GetProcVersion(FunctionPath(""))
		fprintf refnum, "Cache file created by IgorExchange Installer %0.2f\r\n", version
		Close refnum
	endif
	return V_flag
end

// replaces list item(s) in listStr, starting from itemNum, with contents of itemStr
// note that a trailing ; in itemStr will add an extra empty item
function/S ReplaceListItem(int itemNum, string listStr, string itemStr, [int numItems])
	numItems = ParamIsDefault(numItems) ? 1 : numItems
	int numAfterRemoval = ItemsInList(listStr)-numItems
	int i
	for (i=0;i<numItems;i+=1)
		listStr = RemoveListItem(itemNum, listStr)
	endfor
	
	for (i=0;ItemsInList(listStr)<numAfterRemoval;i++)
		listStr += ";"
	endfor
	
	return AddListItem(itemStr, listStr, ";", itemNum)
end

// -------------- end of Cache functions -----------

// returns truth that a procedure file is currently loaded
function isLoaded(string procPath)
	string procName = ParseFilePath(3, procPath, ":", 0, 0)
	wave/T w_loadedProcs = ListToTextWave(WinList("*",";","WIN:128,INDEPENDENTMODULE:1"),";")
	if (numpnts(w_loadedProcs))
		w_loadedProcs = FileNameFromProcName(w_loadedProcs)
	endif
	FindValue/TEXT=procName/TXOP=4/Z w_loadedProcs
	return (V_Value > -1)
end

// returns a path selected by user
// path leads to a subfolder of Igor Pro User Files when restricted is non-zero
function/S ChooseInstallLocation(string packageName, int restricted)
	int success
	string cmd = ""
	sprintf cmd, "Where would you like to install%s?", SelectString(strlen(packageName)>0, "", " " + packageName)
	do
		success = 1
		if (restricted)
			NewPath/O/Q/Z TempInstallPath SpecialDirPath("Igor Pro User Files",0,0,0) + "User Procedures:"
			if(cmpstr(packageName, "Procedure Loader")==0) // make a special case for the Procedure Loader package!
				NewPath/O/Q/Z TempInstallPath SpecialDirPath("Igor Pro User Files",0,0,0) + "Igor Procedures:"
			endif
			PathInfo/S TempInstallPath // set start directory to user procedures
		endif
		NewPath/M=cmd/O/Q/Z TempInstallPath
		if (v_flag)
			return ""
		endif
		PathInfo/S TempInstallPath
		if (restricted)
			if (stringmatch(S_path, SpecialDirPath("Igor Pro User Files",0,0,0) + "*") == 0)
				DoAlert 0, "Please select a location within the Igor Pro User Files folder\r(usually in the User Procedures folder)"
				success = 0
			endif
			if (stringmatch(S_path, SpecialDirPath("Igor Pro User Files",0,0,0)))
				DoAlert 0, "Please select a subfolder within the Igor Pro User Files folder\r(usually in the User Procedures folder)"
				success = 0
			endif
		endif
	while(!success)
	KillPath/Z TempInstallPath
	return S_path
end

// this is an emergency repair function.
// uses a fixed url to grab a recent working version.
// silently: bit 0, no history, bit 1: no doAlert
function RepairUpdater([int silently])
	
	silently = ParamIsDefault(silently) ? 0 : silently
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	CacheClearAll()
	
	URLRequest/time=(prefs.pageTimeout)/Z url=ksGitHub
	if (V_flag)
		return silently & 1 ? 0 : WriteToHistory("Updater could not be repaired", prefs, 1) < -Inf
	endif

	wave/T wProc = ListToTextWave(S_serverResponse, "\n")
	if (numpnts(wProc) < 2)
		wave/T wProc = ListToTextWave(S_serverResponse, "\r")
	endif
	
	variable GitHubVersion
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E="(?i)^#pragma[\s]*version[\s]*="/LIST/Z wProc
	
	if (v_flag != 0)
		return silently & 1 ? 0 : WriteToHistory("Updater could not be repaired", prefs, 1) < -Inf
	endif
	
	s_value = LowerStr(TrimString(s_value, 1))
	sscanf s_value, "#pragma version = %f", GitHubVersion
	if (V_flag!=1 || GitHubVersion<=0)
		return silently & 1 ? 0 : WriteToHistory("Updater could not be repaired", prefs, 1) < -Inf
	endif
	
	variable thisVersion = GetThisVersion()
	if (thisVersion >= GitHubVersion)
		if (!(silently & 2))
			DoAlert 1, "Do you want to replace this version (" + num2str(thisVersion) + ") with repair version " + num2str(GitHubVersion) + "?"
			if (v_flag == 2)
				return 0
			endif
		endif
	endif
		
	// It seems that requesting the file from Github with URLRequest
	// doesn't change the eol in the updater.ipf file.
	// In contrast, in S_serverResponse the /r become /n
	int success = ItemsInList(UpdateFile(FunctionPath(""), ksGitHub, "8197", shortTitle="Updater", localVersion=thisVersion, newVersion=GitHubVersion, silently=1))
	
	if (success && LogCleanup(test=1))
		DoAlert 1, "Updater has been replaced.\rDo you want to clear unrecognised projects from the installation log?"
		if  (v_flag == 1)
			LogCleanup()
		endif
	endif
	
	#if IgorVersion() >= 9
	Execute/P "RELOAD CHANGED PROCS "
	Execute/P/Q/Z "COMPILEPROCEDURES "
	Execute/P/Q/Z "updater#MakeInstallerPanel()"
	#endif
	
	// maybe kill panel and folder?

	return success
end


// this needs to be robust.
threadsafe function [variable GitHubVersion, string strAlert] GetGitHubVersion(int timeout)
	
	URLRequest/time=(timeout)/Z url=ksGitHub
	if (V_flag)
		return [0, ""]
	endif

	wave/T wProc = ListToTextWave(S_serverResponse, "\n")
	
	if (numpnts(wProc) < 2)
		wave/T wProc = ListToTextWave(S_serverResponse, "\r")
	endif
	
	strAlert = ""
	string S_Value = "" // workaround for Grep bug for Igor 8
	Grep/Q/E="(?i)^strconstant ksAlert = "/LIST/Z wProc
	if (strlen(s_value))
		strAlert = RemoveEnding(s_value[23,Inf], "\"")
	endif
	
	// if we need to fix a messed up file we can use this last-ditch method
	// use commented line to override the version number in the file
	Grep/Q/E="(?i)^// forced update ="/LIST/Z wProc
	if (strlen(S_Value)) // s_value must be initiallized
		return [str2num(S_Value[18,Inf]), strAlert]
	endif
	
	// check GitHub procedure version number
	Grep/Q/E="(?i)^#pragma[\s]*version[\s]*="/LIST/Z wProc
	
	if (v_flag != 0)
		return [0, strAlert]
	endif
	
	s_value = LowerStr(TrimString(s_value, 1))
	sscanf s_value, "#pragma version = %f", GitHubVersion
	if (V_flag != 1)
		return [0, strAlert]
	endif
	
	return [GitHubVersion, strAlert]
end


// -------------- A GUI for installing and updating user projects ------------

function MakeInstallerPanel()
	
	#ifdef debug
	Execute "SetIgorOption IndependentModuleDev=1"
	#endif
	
	// if we're rebuilding panel, record current state of popup menu
	int folder = 1
	ControlInfo/W=InstallerPanel popupFolder
	if (abs(V_flag) == 3)
		folder = v_value
	endif
	
	int isWin = 0
	#ifdef WINDOWS
	isWin = 1
	#endif
	KillWindow/Z InstallerPanel // saves window position and tab selection
	
	// create package folder and waves
	DFREF dfr = SetupPackageFolder()
	wave/T/SDFR=dfr/Z ProjectsFullList, ProjectsDisplayList, ProjectsHelpList, ProjectsColTitles
	wave/T/SDFR=dfr/Z UpdatesFullList, UpdatesDisplayList, UpdatesHelpList, UpdatesColTitles
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	int tabSelection = prefs.paneloptions & 1
	int BiggerPanel = 0
	
	if (IgorVersion() < 9)
		// panel height is 315 points
		// if panelresolution is set to 96, height will be
		// 315*96/screenresolution
		// this will not be needed in IP9
		BiggerPanel = prefs.paneloptions & 2
		variable sHeight = GetScreenHeight(), sMinHeight = 700
		if (BiggerPanel && sHeight < sMinHeight)
			BiggerPanel = 0
			prefs.paneloptions -= 2
			SavePackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
		endif
	endif
			
	folder = prefs.paneloptions & 4 ? 2 : folder // setting bit 2 allows us to set the folder popup selection
	// always clear folder selection bit
	prefs.paneloptions = prefs.paneloptions & ~4
	SavePackagePreferences ksPackageName, ksPrefsFileName, 0, prefs
		
	// make a control panel GUI
	variable pLeft = prefs.win.left, pTop = prefs.win.top
	variable pWidth = 520, pHeight = 315
		
	if ( BiggerPanel )
		Execute/Q/Z "SetIgorOption PanelResolution=?"
		NVAR vf = V_Flag
		variable oldResolution = vf
		Execute/Q/Z "SetIgorOption PanelResolution=96"
	endif
	
	NewPanel/K=1/W=(pLeft,pTop,pLeft+pWidth,pTop+pHeight)/N=InstallerPanel as "IgorExchange Projects"
	ModifyPanel/W=InstallerPanel, noEdit=1//, cbRGB=(65534,65535,65535)
		
	variable vTop = 5
	
	Button btnRefresh, win=InstallerPanel, pos={451,vTop}, size={17,17}, Picture=Updater#refresh, labelBack=0, title=""
	Button btnRefresh, win=InstallerPanel, Proc=Updater#InstallerButtonProc, help={"Refresh List"}, focusRing=0
	
	Button btnInfo, win=InstallerPanel, pos={473,vTop+1}, size={15,15}, Proc=updater#InstallerButtonProc, title=""
	Button btnInfo, win=InstallerPanel, help={"Show Info"}, Picture=updater#pInfo
	
	Button btnSettings, win=InstallerPanel, pos={495,vTop+1}, size={15,15}, Picture=Updater#cog, labelBack=0, title=""
	Button btnSettings, win=InstallerPanel, Proc=Updater#InstallerButtonProc, help={"Settings Menu"}, focusRing=0
	
	vTop += 10
	TabControl tabs, win=InstallerPanel, pos={-10,vTop}, size={540,280}, tabLabel(0)="Projects", focusRing=0
	TabControl tabs, win=InstallerPanel, tabLabel(1)="Updates", value=tabSelection, Proc=updater#InstallerTabProc
	
	vTop += 25
	// Listbox for install tab
	ListBox listboxInstall, win=InstallerPanel, pos={0,vTop},size={520, 200}, listwave=ProjectsDisplayList, fsize=10+2*BiggerPanel
	ListBox listboxInstall, win=InstallerPanel, mode=1, Proc=Updater#InstallerListBoxProc, selRow=-1, userColumnResize=1, focusRing=0
	ListBox listboxInstall, win=InstallerPanel, helpWave=ProjectsHelpList, titlewave=ProjectsColTitles, disable=(tabSelection==1)
	ListBox listboxInstall, win=InstallerPanel, widths={8,3,2,1}, userdata(sortcolumn)="-3;1;2;4;" // -3 = third column, reversed
	
	// Listbox for update tab
	ListBox listboxUpdate, win=InstallerPanel, pos={0,vTop},size={520, 200}, listwave=UpdatesDisplayList, fsize=10+2*BiggerPanel
	ListBox listboxUpdate, win=InstallerPanel, mode=1, Proc=Updater#InstallerListBoxProc, selRow=-1, userColumnResize=1, focusRing=0
	ListBox listboxUpdate, win=InstallerPanel, helpWave=UpdatesHelpList, titlewave=UpdatesColTitles, disable=(tabSelection==0)
	ListBox listboxUpdate, win=InstallerPanel, widths={22,16,6,6}, userdata(sortcolumn)="-2;1;3;4;" // -2 = second column, reversed
	
	// insert a notebook subwindow to be used for filtering lists
	DefineGuide/W=InstallerPanel filterTop={FB,-70}
	DefineGuide/W=InstallerPanel filterBottom={filterTop,20}
	DefineGuide/W=InstallerPanel filterR={FL,0.35,FR}
	NewNotebook/F=1/N=nb0/HOST=InstallerPanel/W=(5,0,20,20)/FG=($"",filterTop,filterR,filterBottom)/OPTS=3
	Notebook InstallerPanel#nb0 fSize=12-2*isWin, showRuler=0 // fSize=12+6*BiggerPanel
	Notebook InstallerPanel#nb0 spacing={2+1*BiggerPanel, 0, 5} // ={2+1*BiggerPanel, 0, 5}
	Notebook InstallerPanel#nb0 margins={0,0,1000}
	SetWindow InstallerPanel#nb0, activeChildFrame=0
	
	fClearText(1) // sets notebook to its default appearance
	
	// make a Button for clearing text in notebook subwindow
	Button ButtonClear, win=InstallerPanel, pos={185,247}, size={15,15}, title=""
	Button ButtonClear, win=InstallerPanel, labelBack=(65535,65535,65535,0), focusRing=0
	Button ButtonClear, Picture=Updater#fClearTextPic, Proc=Updater#InstallerButtonProc, disable=1
	
	vTop += 228
	// popup for install tab
	PopupMenu popupType, win=InstallerPanel, pos={5,vTop}, value="all;", mode=1, title="Type", Proc=Updater#InstallerPopupProc
	PopupMenu popupType, win=InstallerPanel, disable=(tabSelection==1)
	// popup for update tab
	PopupMenu popupFolder, win=InstallerPanel, pos={5,vTop}, value="Installed Projects;User Procedures Folder;Current Experiment;", mode=folder, title="Check files in ", Proc=Updater#InstallerPopupProc
	PopupMenu popupFolder, win=InstallerPanel, disable=(tabSelection==0)
		
	Button btnInstallOrUpdate, win=InstallerPanel, pos={455,vTop-2}, size={60,20}, Proc=Updater#InstallerButtonProc, title=SelectString(tabSelection, "Install", "Update")
	Button btnInstallOrUpdate, win=InstallerPanel, help={"Install selected user project"}, disable=2
	vTop += 32
	TitleBox statusBox, win=InstallerPanel, pos={5,vTop}, frame=0, title=""
		
	DoUpdate/W=InstallerPanel
	SetWindow InstallerPanel userdata(version) = num2str(GetThisVersion())
	SetWindow InstallerPanel hook(hInstallerHook)=updater#fHook
	
	SetActiveSubwindow InstallerPanel

	// resizing userdata for controls
	Button ButtonClear,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,GI!!#B1!!#<(!!#<(z!!#N3Bk1ctAnc('ATCZKzzzzzzzzzzzz!!#N3Bk1ctAnc('ATCZK"
	Button ButtonClear,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#?(FEDG<!,6(ZF8u:@zzzzzzzzz"
	Button ButtonClear,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#r+D.Oh\\ASGdjF8u:@zzzzzzzzzzzz!!!"
	TabControl tabs,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!0nY!!#<(!!#Cl!!#BFz!!#](Aon#azzzzzzzzzzzzzz!!#o2B4uAezz"
	TabControl tabs,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#u:DuaHi!,6(ZF8u:@zzzzzzzzz"
	TabControl tabs,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#?(FEDG<!-A3SF8u:@zzzzzzzzzzzz!!!"
	ListBox listboxInstall,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!*'\"!!#>.!!#Cg!!#AWz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	ListBox listboxInstall,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#u:Du_\"OASGdjF8u:@zzzzzzzzz"
	ListBox listboxInstall,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#?(FEDG<!-A2@zzzzzzzzzzzzz!!!"
	ListBox listboxInstall,win=InstallerPanel,userdata(sortcolumn)= "-3;1;2;4;"
	ListBox listboxUpdate,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!*'\"!!#>.!!#Cg!!#AWz!!#](Aon\"Qzzzzzzzzzzzzzz!!#o2B4uAezz"
	ListBox listboxUpdate,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#u:Du_\"OASGdjF8u:@zzzzzzzzz"
	ListBox listboxUpdate,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#?(FEDG<!-A2@zzzzzzzzzzzzz!!!"
	ListBox listboxUpdate,win=InstallerPanel,userdata(sortcolumn)= "-2;1;3;4;"
	PopupMenu popupType,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,?X!!#B@!!#?K!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	PopupMenu popupType,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#?(FEDG<zzzzzzzzzzz"
	PopupMenu popupType,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	PopupMenu popupFolder,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,?X!!#B@!!#>V!!#<Xz!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	PopupMenu popupFolder,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#?(FEDG<zzzzzzzzzzz"
	PopupMenu popupFolder,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	Button btnInstallOrUpdate,win=InstallerPanel,userdata(ResizeControlsInfo)= A"!!,IIJ,hrj!!#?)!!#<Xz!!#o2B4uAezzzzzzzzzzzzzz!!#o2B4uAezz"
	Button btnInstallOrUpdate,win=InstallerPanel,userdata(ResizeControlsInfo) += A"zzzzzzzzzzzz!!#?(FEDG<!,6(ZF8u:@zzzzzzzzz"
	Button btnInstallOrUpdate,win=InstallerPanel,userdata(ResizeControlsInfo) += A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	TitleBox statusBox,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,?X!!#BP!!#@b!!#;=z!!#](Aon\"Qzzzzzzzzzzzzzz!!#](Aon\"Qzz"
	TitleBox statusBox,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#?(FEDG<zzzzzzzzzzz"
	TitleBox statusBox,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#?(FEDG<zzzzzzzzzzzzzz!!!"
	Button btnSettings,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,I]J,hj-!!#<(!!#<(z!!#o2B4uAezzzzzzzzzzzzzz!!#o2B4uAezz"
	Button btnSettings,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#u:Duafnzzzzzzzzzzz"
	Button btnSettings,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#u:Duafnzzzzzzzzzzzzzz!!!"
	Button btnRefresh,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,IGJ,hj-!!#<@!!#<@z!!#o2B4uAezzzzzzzzzzzzzz!!#o2B4uAezz"
	Button btnRefresh,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#u:Duafnzzzzzzzzzzz"
	Button btnRefresh,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#u:Duafnzzzzzzzzzzzzzz!!!"
	Button btnInfo,win=InstallerPanel,userdata(ResizeControlsInfo)=A"!!,IRJ,hjM!!#<(!!#<(z!!#o2B4uAezzzzzzzzzzzzzz!!#o2B4uAeAnc('ATCZK"
	Button btnInfo,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzz!!#u:Duafnzzzzzzzzzzz"
	Button btnInfo,win=InstallerPanel,userdata(ResizeControlsInfo)+=A"zzz!!#u:Du_\"OASGdjF8u:@zzzzzzzzzzzz!!!"
		
	// resizing userdata for panel
	SetWindow InstallerPanel,userdata(ResizeControlsInfo)=A"!!*'\"z!!#Cg!!#BWJ,fQLzzzzzzzzzzzzzzzzzzzz"
	SetWindow InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzzzzzzzzzzzzzzz"
	SetWindow InstallerPanel,userdata(ResizeControlsInfo)+=A"zzzzzzzzzzzzzzzzzzz!!!"
	SetWindow InstallerPanel,userdata(ResizeControlsGuides)="filterTop;filterBottom;filterR;"
	SetWindow InstallerPanel,userdata(ResizeControlsInfofilterTop)="NAME:filterTop;WIN:InstallerPanel;TYPE:User;HORIZONTAL:1;POSITION:245.00;GUIDE1:FB;GUIDE2:;RELPOSITION:-70;"
	SetWindow InstallerPanel,userdata(ResizeControlsInfofilterBottom)="NAME:filterBottom;WIN:InstallerPanel;TYPE:User;HORIZONTAL:1;POSITION:265.00;GUIDE1:filterTop;GUIDE2:;RELPOSITION:20;"
	SetWindow InstallerPanel,userdata(ResizeControlsInfofilterR)="NAME:filterR;WIN:InstallerPanel;TYPE:User;HORIZONTAL:0;POSITION:182.00;GUIDE1:FL;GUIDE2:FR;RELPOSITION:0.35;"
	
	// resizing panel hook
	SetWindow InstallerPanel hook(ResizeControls)=ResizeControls#ResizeControlsHook
	
	// set cleanup hook
	SetWindow InstallerPanel hook(hCleanup)=updater#hookCleanup
	
	if (tabSelection == 0)
		ReloadProjectsList() // populate ProjectsFullList
		if (DimSize(ProjectsFullList,0) == 0)
			ProjectsDisplayList = {{"Download failed."},{""},{""},{""}}
		else
			int typeCol = FindDimLabel(ProjectsFullList, 1, "type")
			Duplicate/free/T/RMD=[][typeCol] ProjectsFullList, types
			types = ReplaceString(",",types,";")
			string typeList = "\"all;" + listOf(types) + "\""
			PopupMenu popupType, win=InstallerPanel, value=#typeList, mode=1
		endif
	endif
	
	if (tabSelection == 1)
		ReloadUpdatesList(2) // populate UpdatesFullList
		if (DimSize(UpdatesFullList,0) == 0)
			UpdatesDisplayList = {{"Download failed."},{""},{""},{""}}
		endif
	endif
	
	UpdateListboxWave("")
	
	if ( BiggerPanel )
		// reset panel resolution
		Execute/Q/Z "SetIgorOption PanelResolution=" + num2istr(oldResolution)
	endif
end


// get a list of user contributed projects from Wavemetrics.com
// if we already have an up-to-date list loaded in ProjectsFullList, do nothing
// load projects from cache into ProjectsFullList
// check for more recent releases and add to ProjectsFullList
// update cache
// forced = 0: if list wave looks okay do nothing
// forced = 1: reload cache; if cache is recent quit
// forced = 2: download everything
function ReloadProjectsList([int forced])
	
	forced = ParamIsDefault(forced) ? 0 : forced
	
	#ifdef debug
	forced = 1
	#endif
	
	DFREF dfr = root:Packages:Installer
	wave/T/SDFR=dfr ProjectsFullList, ProjectsDisplayList
	
	variable lastmod = NumberByKey("MODTIME", WaveInfo(ProjectsFullList,0))
	variable oneDay = 86400, pnt = 0
	
	if (forced==0 && ((datetime-lastmod) < oneDay) && (DimSize(ProjectsFullList, 0) >= kNumProjects))
		// looks like we already have an up-to-date list of projects
		return 0
	endif
	
	// load projects from cache and check that cached list is reasonably recent
	variable CacheTime = LoadProjectsListFromCache()
	if (forced<2 && CacheTime>(datetime-oneDay))
		return 0
	endif
	
	int i, pStart, pEnd, selStart, selEnd
	string cmd = "", strLine=""
	string strDate = num2istr(datetime)
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	CtrlNamedBackground animation, period=30, Proc=AnimateButton
	CtrlNamedBackground animation, start
	
	string url = "https://www.wavemetrics.com/projects"
	URLRequest/time=(prefs.pageTimeout)/Z url=url
	if (V_flag)
		sprintf cmd, "Installer could not load %s\r", url
		WriteToHistory(cmd, prefs, 0)
		SetPanelStatus("Download failed")
		CtrlNamedBackground animation, stop
		return 0
	endif
	
	selStart = strsearch(S_serverResponse, "title=\"Go to last page\"", 0, 2)
	selStart = strsearch(S_serverResponse, "<a href=\"?page=", selStart, 3)
	selStart += strlen("<a href=\"?page=")
	selEnd = strsearch(S_serverResponse, "\"", selStart, 2)
	variable numPages = str2num(S_serverResponse[selStart, selEnd-1]) + 1
	if (numtype(numPages))
		SetPanelStatus("Download failed")
		CtrlNamedBackground animation, stop
		return 0
	endif
		
	Make/free/wave/N=(numPages) wwPages
	multithread wwPages = ParseProjectsIndexPageAsWave(p, prefs.pageTimeout)
	int numNew
	
	// clear any incomplete or old list
	Redimension/N=(0,-1) ProjectsFullList
	
	for(i=0;i<numPages;i++)
		wave/T w = wwPages[i]
		if (!WaveExists(w))
			break
		endif
		numNew = DimSize(w, 0)
		if (!numNew)
			break
		endif

		pnt = DimSize(ProjectsFullList, 0)
		InsertPoints/M=0 pnt, numNew, ProjectsFullList
		ProjectsFullList[pnt,Inf][] = w[p-pnt][q]
	endfor
	
	#ifdef debug
	Print "downloaded list of " + num2str(DimSize(ProjectsFullList, 0)) + " projects"
	#endif
		
	ResortWaves()
	
	wave/T w = ProjectsFullList
	if (DimSize(w, 0))
		Make/free/T/N=(DimSize(w, 0)) toCache
		toCache = w[p][%projectID] + ";"
		toCache += strDate + ";"
		toCache += w[p][%name] + ";"
		toCache += w[p][%author] + ";"
		toCache += w[p][%published] + ";"
		toCache += w[p][%views] + ";"
		toCache += ReplaceString(";", w[p][%type], ",") + ";" // ReplaceString shouldn't be necessary
		toCache += w[p][%userNum] + ";"
		CachePutWave(toCache, 0)
	else
		LoadProjectsListFromCache()
	endif
	
	CtrlNamedBackground animation, stop
	SetPanelStatus("")
	return 1
end

function LoadProjectsListFromCache()
	
	DFREF dfr = root:Packages:Installer
	wave/T/SDFR=dfr ProjectsFullList
	
	variable OldestCacheDate = 0
	string filePath = GetInstallerFilePath(ksCacheFile)
	
	Make/T/N=0/free w
	Grep/O/Z/ENCG=1/E=";" filePath as w // load cache without header
	int numLines = numpnts(w)
	
	if (numLines)
		Redimension/N=(DimSize(w, 0),-1) ProjectsFullList
		// extract strings from the list on each line into corresponding columns
		ProjectsFullList = StringFromList(q, w[p])
		Make/free/N=(numpnts(w)) CacheDates
		CacheDates = str2num(ProjectsFullList[p][%ProjectCacheDate])
		OldestCacheDate = (numLines < kNumProjects) ? 0 : WaveMin(CacheDates)
		ResortWaves()
	endif
	
	#ifdef debug
	printf "loaded %d projects from cache into ProjectsFullList\r", numpnts(w)
	#endif
	
	return OldestCacheDate
end


// Parse html in WebPageText to find releases.
threadsafe function/WAVE ParseProjectsIndexPageAsWave(variable pageNum, variable timeout)
	
	Make/T/Free/N=(0,10) w_projects
	SetDimLabels(ksProjectsDimLabelsList, 1, w_projects)
			
	string baseURL, projectsURL, URL
	string WebPageText = ""
	baseURL = "https://www.wavemetrics.com"
	projectsURL = "/projects?os_compatibility=All&project_type=All&field_supported_version_target_id=All&page="
	sprintf URL "%s%s%d", baseURL, projectsURL, pageNum
	URLRequest/time=(timeout)/Z url=url
	if (V_flag)
		return w_projects
	endif
	
	int i, pnt
	int pStart, pEnd, selStart, selEnd
	string strAuthor, strName, strProjectURLfield, strUserNum, strProjectNum, strURL
	string projectID, strFooter, strPubDate, strViews, strTypes
	string cmd = ""
	string strDate = num2istr(datetime)
	

	string strProjectStart = "class=\"project-teaser-wrapper\""
	string strProjectEnd = "class=\"project-teaser-footer\"" // need to find the </div> that follows this
	string strUserStart = "class=\"user-profile-compact-wrapper\" href=\"/user/"
	string strAuthorStart = "class=\"username-wrapper\">"
	string strURLstart = "class=\"project-teaser-info\""
	string strTaxonomyStart = "<a href=\"/taxonomy/"
	string strFooterStart = "<div class=\"project-teaser-footer\">"
	
	string strProjectText
		
	pEnd = 0
	// loop through projects on listPage
	for (i=0;i<50;i++)
		pStart = strsearch(S_serverResponse, strProjectStart, pEnd, 2)
		pEnd = strsearch(S_serverResponse, strProjectEnd, pStart, 2)
		if (pEnd==-1 || pStart==-1)
			break // no more projects on this listPage
		endif
		pEnd = strsearch(S_serverResponse, "</div>", pEnd, 2)
		strProjectText = S_serverResponse[pStart, pEnd+6]
		
		strUserNum = GetTextField(strProjectText, strUserStart, strEnd="\">")
		strAuthor = GetTextField(strProjectText, strAuthorStart, strEnd="</span>")
		strProjectURLfield = GetTextField(strProjectText, strURLstart, strEnd="</a>")
		strURL = GetTextField(strProjectURLfield, "href=\"")
		strName = GetTextField(strProjectURLfield, "<h2>", strEnd="</h2>")
		if (isError(strUserNum) || isError(strAuthor) || isError(strURL) || isError(strName))
			continue
		endif
		strURL = baseURL + strURL
		strName = RemoveHTMLEncoding(strName)
		projectID = ParseFilePath(0, strURL, "/", 1, 0)
		if (strlen(projectID) == 0)
			continue
		endif
		
		selEnd = 0
		strTypes = ""
		do
			selStart = strsearch(strProjectText, "/taxonomy/", selEnd, 2)
			if (selStart < 0)
				break
			endif
			selStart = strsearch(strProjectText, ">", selStart, 0)
			selEnd = strsearch(strProjectText, "<", selStart, 0)
			if (selStart<0 || selEnd<0)
				break
			endif
			strTypes += strProjectText[selStart+1,selEnd-1] + ","
		while (1)
		
		strFooter = GetTextField(strProjectText, strFooterStart, strEnd="</div>")
		strPubDate = GetTextField(strFooter, "<span>")
		strPubDate = SelectString(isError(strPubDate), ParsePublishDate(strPubDate), "")
		strFooter = GetTextField(strFooter, "</span>", strEnd="/span>")
		strViews = GetTextField(strFooter, "<span>", strEnd=" views<")
		strViews = SelectString(isError(strViews), strViews, GetTextField(strFooter, "<span>", strEnd=" view<"))
		strViews = SelectString(isError(strViews), strViews, "")
		
		// columns correspond to those of ProjectsFullList
		w_projects[DimSize(w_projects, 0)][] = {{projectID},{""},{strName},{strAuthor},{strPubDate},{strViews},{strTypes},{strUserNum},{""},{""}}
	endfor	 // next project

	return w_projects
end

// returns a stringlist of projects found in user procedures folder
function/S UserProcsProjectsList()

	wave/T w = GetProcsRecursive(1)	
	if (numpnts(w))
		multithread w = GetProjectIDString(w)
	endif
	string list = ""
	TextWaveZapString(w, "")
	wfprintf list, "%s;", w
	
	return list
end

// returns a 2D wave of projects IDs and versions found in user procedures folder
function/wave UserProcsProjectsWave()
	wave/T wFiles = GetProcsRecursive(1)
	int numRows = numpnts(wFiles)
	Make/free/N=(numRows, 2) w
	if (numRows)
		multithread w[][0] = GetConstantFromFile("kProjectID", wFiles[p])
		multithread w[][1] = numtype(w[p][0])==0 ? GetProcVersion(wFiles[p]) : 0
		int i
		for (i=DimSize(w, 0)-1;i>=0;i-=1)
			if (numtype(w[i][0]) == 2)
				DeletePoints/M=0 i, 1, w
			endif
		endfor
	endif
	return w
end

// returns a 2D wave of projects IDs and versions loaded in current experiment
function/wave ExperimentProcsProjectsWave()
	
	wave/T wFiles = ListToTextWave(WinList("*",";","INDEPENDENTMODULE:1,INCLUDE:3"),";")
	wFiles = GetProcWinFilePath(wFiles)
	TextWaveZapString(wFiles, "")

	int numRows = numpnts(wFiles)
	Make/free/N=(numRows, 2) w
	if (numRows)
		multithread w[][0] = GetConstantFromFile("kProjectID", wFiles[p])
		multithread w[][1] = numtype(w[p][0])==0 ? GetProcVersion(wFiles[p]) : 0
		
		int i
		for (i=DimSize(w, 0)-1;i>=0;i-=1)
			if (numtype(w[i][0]) == 2)
				DeletePoints/M=0 i, 1, w
			endif
		endfor
		
	endif
	return w
end

// returns a 2D wave of project ID and version
// this is for updates tab only
function/wave ProjectWave(string projectID)
	Make/free/N=(0, 2) w
	DFREF dfr = root:Packages:Installer
	wave/T wList = dfr:UpdatesFullList
	FindValue/RMD=[][0,0]/TEXT=projectID/TXOP=4 wList
	if (V_row >= 0)
		w[0][] = {{str2num(projectID)}, {str2num(wList[V_row][%local])}}
	endif
	return w
end


// forced: bit 0: (forced = 1) recheck local file versions and install status
// bit 1: (forced = 2) reload from cache/install log
// bit 2: (forced = 4) reload remote
function ReloadUpdatesList(int forced, [string pid])
	if (WinType("InstallerPanel") != 7)
		return 0
	endif
	
	// get project name, update status, local and remote versions, release
	// URL, OS compatibility and release date for each project
	DFREF dfr = root:Packages:Installer
	wave/T UpdatesFullList = dfr:UpdatesFullList
	ResetColumnLabels()
	
	SetPanelStatus("Checking local files")
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	#ifdef debug
	forced = 2 + 4
	#endif
	
	// modtime is not an ideal measure. wave may be updated each time we load the tab!
	variable lastmod = NumberByKey("MODTIME", WaveInfo(UpdatesFullList, 0))
	variable oneDay = 86400, oneWeek = 604800, OneDayAgo = datetime - oneDay
	int checkFilesInUserProcsFolder = 0, checkFilesInExperiment = 0, checkInstalled = 1
	
	ControlInfo/W=InstallerPanel popupFolder
	checkInstalled = (V_Value == 1)
	checkFilesInUserProcsFolder = (V_Value == 2)
	checkFilesInExperiment = (V_Value == 3)
	
	if (DimSize(UpdatesFullList, 0) == 0)
		forced = forced | 2
	endif
	
	int numCols = ItemsInList(ksUpdatesDimLabelsList) // the number of columns we should have in the list waves
	
	if (forced==0 && ((datetime-lastmod) < oneDay) && (DimSize(UpdatesFullList, 0)>0) && (DimSize(UpdatesFullList, 1)==numCols)) // less than 1 day old
		// looks like we already have a recent list of projects
		return 0
	endif
	
	if (forced==1 && DimSize(UpdatesFullList, 0)>0 && DimSize(UpdatesFullList, 1)==numCols)		
		// update local info only
		if (checkInstalled)
			UpdatesFullList[][%local] = LogGetVersion(UpdatesFullList[p][%projectID])
			UpdatesFullList[][%status] = GetUpdateStatus(UpdatesFullList[p][%projectID], str2num(UpdatesFullList[p][%local]), str2num(UpdatesFullList[p][%remote]))
			UpdatesFullList[][%LastUpdate] = StringFromList(6, LogGetProject(UpdatesFullList[p][%projectID]))
		else
			multithread UpdatesFullList[][%local] = GetPragmaString("version", UpdatesFullList[p][%installPath])
			// maybe a file has been updated
			UpdatesFullList[][%status] = SelectString(str2num(UpdatesFullList[p][%local])>=str2num(UpdatesFullList[p][%remote]), UpdatesFullList[p][%status], "up to date")
			UpdatesFullList[][%lastUpdate] = num2istr(GetFileCreationDate(UpdatesFullList[p][%installPath]))
		endif
		ResortWaves()
	endif
	
	if (!(forced&6))
		return 0
	endif
		
	string filePath = ""
	variable currentIgorVersion = GetIgorVersion()
	int i, numProjects, numDownloads
	string UserFilesPath = SpecialDirPath("Igor Pro User Files", 0, 0, 0)
	
	// if we're checking one project, remove it from the list
	if (!ParamIsDefault(pid))
		FindValue/Z/TEXT=pid/TXOP=2/RMD=[][0,0] UpdatesFullList
		if (v_value >- 1)
			filePath = UpdatesFullList[v_value][%installPath]
			DeletePoints/M=0 v_value, 1, UpdatesFullList
			ResetColumnLabels()
		endif
	endif
	
	// get a list of IDs for projects we want to check
	if (ParamIsDefault(pid))
		if (checkInstalled)
			wave/T w = ListToTextWave(ListOfProjectsFromInstallLog(),";")
		else
			
			if (checkFilesInUserProcsFolder)
				wave/T w = GetProcsRecursive(1)
			elseif (checkFilesInExperiment) // check only open files
				wave/T w = ListToTextWave(WinList("*",";","INDEPENDENTMODULE:1,INCLUDE:3"),";")
				w = GetProcWinFilePath(w)
				TextWaveZapString(w, "")
			endif
			
			// remove this procedure from the list
			TextWaveZapString(w, FunctionPath(""))
			
			// add this file to start of list
			InsertPoints 0, 1, w
			w[0] = FunctionPath("")
		endif
	else // check one project
		if (checkInstalled)
			Make/free/T w = {pid}
		else
			Make/T/free w = {filePath}
		endif
	endif
	
	numProjects = DimSize(w, 0)
	Make/free/T/N=(numProjects, DimSize(UpdatesFullList,1)) wNew
	SetDimLabels(ksUpdatesDimLabelsList, 1, wNew)
	
	if (numProjects == 0)
		// shouldn't happen
		return 0
	endif
	
	if (checkInstalled)
		Make/free/T/N=(numProjects) wLogEntries
		wLogEntries = LogGetProject(w[p])
		
		for (i=numpnts(wLogEntries)-1;i>=0;i--)
			if (strlen(wLogEntries[i]) == 0)
				DeletePoints/M=0 i, 1, wLogEntries, wNew
				numProjects -= 1
			endif
		endfor
		
		if (DimSize(wNew, 0))
			wNew[][%projectID]          = StringFromList(0, wLogEntries[p])
			wNew[][%name]               = StringFromList(1, wLogEntries[p])
			wNew[][%status]             = GetInstallStatus(w[p])
			wNew[][%local]              = StringFromList(2, wLogEntries[p])
			wNew[][%installPath]        = StringFromList(4, wLogEntries[p]) // full path to install folder or to ipf
			wNew[][%installPath]        = SelectString(strlen(wNew)>0, "", SpecialDirPath(wNew,0,0,0))
			wNew[][%installPath]       += StringFromList(5, wLogEntries[p]) // path to install location
			wNew[][%releaseIgorVersion] = ""
			wNew[][%installDate]        = StringFromList(3, wLogEntries[p])
			wNew[][%filesInfo]          = GetInstalledFilesSummary(w[p])
			wNew[][%lastUpdate]         = StringFromList(6, wLogEntries[p])
		endif
	else
		
		multithread wNew[][%releaseURL] = GetUpdateURLfromFile(w[p])
		wNew[][%projectID]              = ParseFilePath(0, wNew[p][%releaseURL], "/", 1, 0)
		
		for(i=DimSize(wNew, 0)-1;i>=0;i--)
			if (strlen(wNew[i][%projectID]) == 0)
				DeletePoints/M=0 i, 1, wNew, w
				numProjects -= 1
			endif
		endfor
		
		if (numProjects)
			wNew[][%lastUpdate]        = GetFileLastUpdateStr(w[p]) // is it worth MT?
			multithread wNew[][%name]  = GetShortTitle(w[p])
			wNew[][%name]              = SelectString(strlen(wNew)==0, wNew, ParseFilePath(3, w[p], ":", 0, 0))
			multithread wNew[][%local] = GetPragmaString("version", w[p])
			wNew[][%installPath]       = w[p]
			wNew[][%filesInfo]         = w[p]
			wNew[][%filesInfo] = SelectString(stringmatch(filePath, UserFilesPath + "*"), wNew, (wNew[p][q])[strlen(UserFilesPath),Inf])
		endif
	endif
	
	if (numProjects)
		// reload from cache
		Make/free/T/N=(numProjects) wKeyLists, wStatusExtra
		Make/free/N=(numProjects) wCacheDates, wDoDownload, wReleaseVersions, wLocalVersions
		wKeyLists   = CacheGetKeylist(wNew[p][%projectID])
		wCacheDates = NumberByKey("ReleaseCacheDate", wKeyLists)
		wCacheDates = numtype(wCacheDates) == 0 ? wCacheDates : 0
		wDoDownload = forced&4 || wCacheDates<OneDayAgo

		numDownloads = sum(wDoDownload)
		#ifdef debug
		Print "started download of", numDownloads, "project pages"
		#endif

		if (numDownloads)
			SetPanelStatus("Checking IgorExchange")
		endif

		// potentially download new keylists
		multithread wKeyLists = SelectString(wDoDownload, wKeyLists, DownloadKeylistFromProjectPage(wNew[p][%projectID], prefs.pagetimeout) )

		// check for download errors before doing cache
		wDoDownload = wDoDownload && strlen(wKeyLists[p]) > 0
		#ifdef debug
		Print sum(wDoDownload), "successful downloads"
		#endif

		// revert to cached values for any failed downloads
		wKeyLists = SelectString(strlen(wKeyLists) > 0, CacheGetKeylist(wNew[p][%projectID]), wKeyLists)
		wKeyLists = SelectString(wDoDownload, wKeyLists, ReplaceStringByKey("ReleaseCacheDate", wKeyLists, num2istr(datetime)))
		wKeyLists = SelectString (strlen(StringByKey("ShortTitle", wKeyLists))==0, wKeyLists, ReplaceStringByKey("ShortTitle", wKeyLists, wNew[p][%name]))

		// cache new downloads
		wDoDownload = wDoDownload ? CachePutKeylist(wKeyLists) : 0

		wReleaseVersions = NumberByKey("remote", wKeyLists)
		// ignore release Igor version because we can't check it!
		if (checkInstalled)
			wLocalVersions   = str2num(wNew[p][%local])
			wStatusExtra     = SelectString(wReleaseVersions > wLocalVersions, ", up to date", ", update available")
			wNew[][%status] += SelectString(stringmatch(wNew[p][%status] , "complete"), "", wStatusExtra[p])
		else
			multithread wLocalVersions = GetProcVersion(w[p])
			wNew[][%status]  = SelectString(wReleaseVersions[p] > wLocalVersions[p], "up to date", "update available")
		endif

		wNew[][%remote]      = StringByKey("remote", wKeyLists[p])
		wNew[][%system]      = StringByKey("system", wKeyLists[p])
		wNew[][%releaseDate] = StringByKey("releaseDate", wKeyLists[p])
		wNew[][%releaseURL]  = StringByKey("releaseURL", wKeyLists[p])
		wNew[][%releaseInfo] = StringByKey("releaseInfo", wKeyLists[p]) // not just for available releases
	endif

	if (ParamIsDefault(pid))
		Duplicate/O/T wNew UpdatesFullList
	elseif (DimSize(wNew, 0))
		InsertPoints/M=0 DimSize(UpdatesFullList, 0), 1, UpdatesFullList
		UpdatesFullList[DimSize(UpdatesFullList, 0)-1][] = wNew[0][q]
	endif

	ResortWaves() // match current sort order for gui
	
	return 1
end

function/S GetFileLastUpdateStr(string filepath)
	GetFileFolderInfo/Q/Z filePath
	return SelectString(V_isFile == 0, num2istr(V_modificationDate), ""	)
end

function GetFileCreationDate(string strFilePath)
	GetFileFolderInfo/Q/Z strFilePath
	return V_creationDate
end

// returns string list, no shortTitle available from project page
// projectID;ReleaseCacheDate;name;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo
// Used in preemptive task
threadsafe function/S DownloadStringlistFromProjectPage(string projectID, variable timeout)
	string url = ""
	sprintf url, "https://www.wavemetrics.com/node/%s", projectID
	
	URLRequest/time=(timeout)/Z url=url
	if (v_flag)
		return ""
	endif
	
	return ParseProjectPageAsList(projectID, S_serverResponse)
end

// returns keylist of release info from project web page
// no shortTitle key, name key contains full title
threadsafe function/S DownloadKeylistFromProjectPage(string projectID, variable timeout)
	string url = "", list = "", keyList = "" // be careful to avoid key and list separators in list items
	sprintf url, "https://www.wavemetrics.com/node/%s", projectID
	
	URLRequest/time=(timeout)/Z url=url
	if (v_flag)
		return ""
	endif
	
	list = ParseProjectPageAsList(projectID, S_serverResponse)
	keylist = ReleaseList2KeyList(list)

	return keylist
end

// turns a string list of items extracted from release web page into a keylist
// avoids empty keypairs
// no shortTitle keypair
threadsafe function/S ReleaseList2KeyList(string ReleaseList)
	string keyList = "", s = "", key = ""
	string keys = "projectID;ReleaseCacheDate;name;remote;system;releaseDate;releaseURL;releaseIgorVersion;releaseInfo;"
	int i
	for (i=0;i<9;i+=1)
		s = StringFromList(i, ReleaseList)
		if (strlen(s))
			key = StringFromList(i, keys)
			keyList = ReplaceStringByKey(key, keyList, s)
		endif
	endfor
	
	return keyList
end

// Resort the 2D wave from which the listbox wave is extracted
// The listbox userdata holds the current sort order
// The code is convoluted because we want to retain current sorting as
// secondary sort order. Some columns may be reverse sorted and others
// not, so can't simply give sort order to SortColumns.
// instead we build a numerical ranking wave and negate columns
// that are to be reverse sorted, then resort the target wave based on
// values in rank wave
function ResortWaves([int col])
	
	// col: O resort according to user data
	// non-zero: sort by column, reversing sort if column matches previous
	
	col = paramisdefault(col) ? 0 : col
	
	controlinfo/W=InstallerPanel tabs
	if (v_flag != 8)
		return 0
	endif
	int tabNum = V_Value
	
	string lb = SelectString(tabNum, "listboxInstall", "listboxUpdate")
	DFREF dfr = root:Packages:Installer
	if (tabNum == 0)
		wave/T FullList = dfr:ProjectsFullList
	else
		wave/T FullList = dfr:UpdatesFullList
	endif
	
	int i, numRows
	numRows = DimSize(FullList, 0)
	if (numRows < 2)
		return 0
	endif
	
	// we're expecting a 4 item stringlist of unique column numbers
	string strSortOrder = GetUserData("InstallerPanel", lb, "sortColumn")
	Make/I/free/N=4 SortOrder = str2num(StringFromList(p, strSortOrder))
		
	if (col == 0) // keep same sort order
		col = SortOrder[0]
	elseif (col == abs(SortOrder[0]))
		col =- SortOrder[0] // reverse sort previous sort key column
	endif
	
	FindValue/I=(col) SortOrder
	if (V_value == -1)
		FindValue/I=(-col) SortOrder
	endif
	if (v_value == -1)
		Print "Updater ListBox sorting error"
		return 0
	endif
	DeletePoints v_value, 1, SortOrder
	InsertPoints/V=(col) 0, 1, SortOrder
		
	// record new sort order in listbox userdata
	wfprintf strSortOrder, "%d;", SortOrder
	ListBox/Z $lb win=InstallerPanel, userdata(sortcolumn)=strSortOrder
	
	// create a ranking wave for FullList where identical strings are given equal rank
	// this allows multiple columns to be used as sort keys
	Make/free/N=(numRows,4) rank
	Make/free/N=(numRows)/T colTextWave
	for (i=0;i<4;i+=1)
		colTextWave = FullList[p][i+1+(tabNum==0)]
		wave colRank = CreateRank(colTextWave)
		rank[][i] = colRank[p]
	endfor

	// negate values in columns of ranking wave that are to be reverse sorted
	for (i=0;i<4;i+=1) //
		rank[][abs(SortOrder[i])-1] = SortOrder[i]<0 ? -rank : rank
	endfor
	
	SortOrder = abs(SortOrder) - 1
	SortColumns/KNDX={SortOrder[0],SortOrder[1],SortOrder[2],SortOrder[3]} sortwaves={rank, FullList}
	
	UpdateListboxWave(fGetStub())
	return 1
end

// returns a free numerical wave containing alphanumeric rank of strings in w
// identical strings are assigned equal rank
function/WAVE CreateRank(wave/T w)
	Make/free/N=(DimSize(w,0)) rank, points, index
	points = p // record input order
	MakeIndex/A w, index
	IndexSort index points // order has input point values in alphanumeric sort order
	// give indentical strings equal rank
	rank[1,Inf] = cmpstr(w[points[p]], w[points[p-1]]) ? p : rank[p-1]
	Sort points rank
	return rank
end

// returns alphabetical list of textWave contents
function/S listOf(wave/T textWave, [string separator])
	separator = SelectString(ParamIsDefault(separator), separator, ";")
	string outputList = "", strItem
	int i, j, items
	for (i=0;i<DimSize(textWave,0);i+=1)
		items = ItemsInList(textWave[i][0], separator)
		for (j=0;j<items;j+=1)
			strItem = StringFromList(j, textWave[i][0], separator)
			if (WhichListItem(strItem,outputList, separator) == -1)
				outputList = AddListItem(strItem, outputList, separator)
			endif
		endfor
	endfor
	return SortList(outputList, separator)
end

// returns Julian date as string
threadsafe function/S ParseReleaseDate(string str)
	string strDay, strAMPM
	variable year, month, day, HH, MM
	
	str = ReplaceString("\"", str, "")
	sscanf str, "%s %g/%g/%d - %d:%d %s", strDay, month, Day, Year, HH, MM, strAMPM
	return num2istr(DateToJulian(year, month, day))
end

// returns Julian date as string
threadsafe function/S ParsePublishDate(string str)
	string months = "January;February;March;April;May;June;July;August;September;October;November;December"
	string strMon, strDay, strYear
	SplitString/E="([[:alpha:]]+) ([[:digit:]]+), ([[:digit:]]+)" str, strMon, strDay, strYear
	variable year, month, day
	month = WhichListItem(strMon, months) + 1
	day = str2num(strDay)
	year = str2num(strYear)
	return num2istr(DateToJulian(year, month, day))
end

function hookCleanup(STRUCT WMWinHookStruct &s)
	if (s.eventCode == 2) // kill
		variable GitVer = str2num(GetUserData(s.winName, "", "GitVer"))
		if (numtype(GitVer)==0 && GitVer > GetThisVersion())
			
			// what if updater has been updated, will we see the right version number? I think so...
			// in Igor 9 we execute compileprocedures
			// in igor 8 GetThisVersion() reads the version from the file
			
//			DoAlert 1, "It looks like Updater may need to be repaired or updated\r\rDo you want install repair version " + num2str(GitVer) + "?"
//			if (v_flag == 1) // yes
//				RepairUpdater(silently=2)
//			endif
		endif
		
		PrefsSaveWindowPosition(s.winName)
		KillDataFolder/Z root:packages:installer
		KillWindow/Z UpdaterPrefsPanel
	endif
	return 0
end

function InstallerPopupProc(STRUCT WMpopupAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	if (CheckPanelVersion(s.win, 0))
		return 0
	endif
	
	if (stringmatch(s.ctrlName, "popupFolder"))
		ReloadUpdatesList(2)
	else
		UpdateListboxWave(fGetStub())
	endif
	// send a keyboard event to filter hook
	// this updates text completion based on new popup selection
	STRUCT WMWinHookStruct hookstruct
	hookstruct.eventcode = 11
	hookstruct.winName = "InstallerPanel#nb0"
	fHook(hookstruct)
	return 0
end

function InstallerTabProc(STRUCT WMTabControlAction &s)
		
	if (s.eventCode != 2)
		return 0
	endif
	
	if (CheckPanelVersion(s.win, 1))
		return 0
	endif
	
	int UpdatesTab = (s.tab==1), ProjectsTab = (s.tab==0)
	
	// controls in projects tab
	ListBox listboxInstall, win=InstallerPanel, disable=UpdatesTab
	PopupMenu popupType, win=InstallerPanel, disable=UpdatesTab
	
	// controls in updates tab
	ListBox listboxUpdate, win=InstallerPanel, disable=ProjectsTab
	PopupMenu popupFolder, win=InstallerPanel, disable=ProjectsTab
	
	// change Button title
	Button btnInstallOrUpdate, win=InstallerPanel, title=SelectString (projectsTab, "Update","Install")
		
	if (projectsTab)
		ReloadProjectsList() // populate ProjectsFullList
		wave/T/SDFR=root:Packages:Installer ProjectsFullList, ProjectsDisplayList
		if (DimSize(ProjectsFullList, 0) == 0)
			ProjectsDisplayList = {{"Download failed."},{""},{""}}
		else
			int typeCol = FindDimLabel(ProjectsFullList, 1, "type")
			Duplicate/free/T/RMD=[][typeCol] ProjectsFullList, types
			types = ReplaceString(",", types, ";")
			string typeList = "\"all;" + listOf(types) + "\""
			PopupMenu popupType, win=InstallerPanel, value=#typeList, mode=1
		endif
	endif
	
	if (updatesTab)
		wave/T/SDFR=root:Packages:Installer UpdatesFullList, UpdatesDisplayList
		ReloadUpdatesList(0)
		if (DimSize(UpdatesFullList, 0) == 0)
			UpdatesDisplayList = {{"Download failed."},{""},{""},{""}}
		endif
	endif
	
//	UpdateListboxWave(fGetStub())
	// send a keyboard event to filter hook
	// this updates text completion based on new popup selection
	STRUCT WMWinHookStruct hookstruct
	hookstruct.eventcode = 11
	hookstruct.winName = "InstallerPanel#nb0"
	fHook(hookstruct)
		
	if (projectsTab)
		ControlInfo/W=InstallerPanel listboxInstall
		wave/T matchlist = $(S_DataFolder + "ProjectsMatchList")
	else
		ControlInfo/W=InstallerPanel listboxUpdate
		wave/T matchlist = $(S_DataFolder + "UpdatesMatchList")
	endif
	wave/T listWave = $(S_DataFolder + s_value)
	if (V_value<DimSize(listwave, 0) && V_value>-1)
		SetPanelStatus("Selected: " + matchlist[V_value][%name])
		if (projectsTab || stringmatch(listWave[V_value][%status], "*update available"))
			Button btnInstallOrUpdate, win=InstallerPanel, disable=0
		else
			Button btnInstallOrUpdate, win=InstallerPanel, disable=2
		endif
		#ifdef testing
		Button btnInstallOrUpdate, win=InstallerPanel, disable=0
		#endif
		
	else
		Button btnInstallOrUpdate, win=InstallerPanel, disable=2
	endif
	return 0
end

function InstallerButtonProc(STRUCT WMButtonAction &s)
	if (s.eventCode != 2)
		return 0
	endif
	
	if (CheckPanelVersion(s.win, 1))
		return 0
	endif
	
	strswitch(s.ctrlName)
		case "btnInstallOrUpdate" :
			ControlInfo/W=InstallerPanel tabs
			if (v_value == 0) // install something
				InstallSelection()
			else // update a project
				UpdateSelection()
			endif
			break
		case "ButtonClear" :
			fClearText(1)
			SetWindow InstallerPanel#nb0 userdata(stublen) = "0"
			Button ButtonClear, win=InstallerPanel, disable=3
			UpdateListboxWave("")
			break
		case "btnSettings" :
			SettingsMenu()
			break
		case "btnInfo" :
			InfoMenu()
			break
		case "btnRefresh" :
			CtrlNamedBackground BGCheck, status
			if (NumberByKey("RUN", s_info) != 0)
				break
			endif
			ControlInfo/W=InstallerPanel tabs
			if (v_value == 0)
				StartPreemptiveDownload(1, "")
				// Alternatively, this will download one page at a time, but as the
				// downloaded data are processed Igor becomes annoyingly laggy:
				// StartPreemptiveDownload(1, "", pagenum=0)
			else
				ControlInfo/W=InstallerPanel popupFolder
				variable options = 2^(V_Value)
				StartPreemptiveDownload(options, "")
			endif
			break
	endswitch
	return 0
end

function InstallerListBoxProc(STRUCT WMListboxAction &s)
	if (s.eventCode == -1)
		return 0
	endif
		
	// check for out-of-date panel on mousedown
	if (s.eventCode==1 && CheckPanelVersion(s.win, 2))
		Execute/Z/P "Updater#MakeInstallerPanel()"
		return 0
	endif
	
	DFREF dfr = root:Packages:Installer
	int tabNum = (cmpstr(s.ctrlName, "ListBoxUpdate")==0)
	if (tabNum == 0)
		wave/T matchlist = dfr:ProjectsMatchList
		wave/T fullList = dfr:ProjectsFullList
	else
		wave/T matchlist = dfr:UpdatesMatchList
		wave/T fullList = dfr:UpdatesFullList
		wave/T helpList = dfr:UpdatesHelpList
	endif
	string strStatus = "", projectID = ""
	
	switch (s.eventCode)
		case 1: // mousedown
			if (s.eventMod & 16) // right click?
				InstallerRightClick(s)
				return 0
			elseif (s.row == -1)
				ResortWaves(col=s.col+1)
			endif
			break
		case 2: // mouseup

			// set status and enable Button based on selection
			ControlInfo/W=$(s.win) $(s.ctrlName)
			
			if (V_value<DimSize(s.listwave,0) && V_value>-1)
				SetPanelStatus("Selected: " + matchlist[v_value][%name])
				if (stringmatch(s.ctrlName, "ListBoxInstall"))
					Button btnInstallOrUpdate, win=InstallerPanel, disable=0
				else
					Button btnInstallOrUpdate, win=InstallerPanel, disable=2-2*(stringmatch(s.listWave[v_value][%status], "*update available"))
				endif
				
				#ifdef testing
				Button btnInstallOrUpdate, win=InstallerPanel, disable=0
				#endif
				
				return 0
			endif
			sprintf strStatus "Showing %d of %d projects", DimSize(s.listWave, 0), DimSize(FullList, 0)
			SetPanelStatus(strStatus)
			Button btnInstallOrUpdate, win=InstallerPanel, disable=2
			break
			
		case 4: // Cell selection (mouse or arrow keys)
		case 5: // Cell selection + shift
			if (s.row<DimSize(s.listwave,0) && s.row>-1)
				SetPanelStatus("Selected: " + matchlist[s.row][%name])
				if (stringmatch(s.ctrlName, "ListBoxInstall"))
					Button btnInstallOrUpdate, win=InstallerPanel, disable=0
				else
					Button btnInstallOrUpdate, win=InstallerPanel, disable=2-2*(cmpstr(s.listWave[s.row][%status], "update available")==0)
				endif
						
				#ifdef testing
				Button btnInstallOrUpdate, win=InstallerPanel, disable=0
				#endif
				
				return 0
			endif
			sprintf strStatus "Showing %d of %d projects", DimSize(s.listWave, 0), DimSize(FullList, 0)
			SetPanelStatus(strStatus)
			break
			
		case 3: // double-click
			if (s.row>=DimSize(s.listwave, 0) || s.row<0)
				return 0
			endif
			// save current selection
			string strSelection = s.listwave[s.row][0]
			ResortWaves(col=s.col+1)
			// wait for mouseup event to be handled
			int wait = ticks + 10
			do
			while(ticks < wait)
			FindValue/TEXT=strSelection/TXOP=4/RMD=[][0,0] s.listwave
			ListBox $s.ctrlName win=$s.win, selRow=V_value
			break
			
		case 11: // column resize
			// this is needed when panel AND column widths are resizeable
			ControlInfo/W=$(s.win) $(s.ctrlName)
			variable c1, c2, c3, c4
			sscanf S_columnWidths, "%g,%g,%g,%g", c1, c2, c3, c4
			c1 /= 10; c2 /= 10; c3 /= 10; c4 /= 10
			ListBox $(s.ctrlName) win=$(s.win), widths={c1, c2, c3, c4}
			break
	endswitch
	return 0
end

function InstallerRightClick(STRUCT WMListboxAction &s)
	if (s.row>=DimSize(s.listwave, 0) || s.row<0)
		return 0
	endif
	
	DFREF dfr = root:Packages:Installer
	if (stringmatch(s.ctrlName, "ListBoxInstall"))
		wave/T matchlist = dfr:ProjectsMatchList
		wave/T fullList = dfr:ProjectsFullList
	else
		wave/T matchlist = dfr:UpdatesMatchList
		wave/T fullList = dfr:UpdatesFullList
		wave/T helpList = dfr:UpdatesHelpList
	endif
	string strStatus = "", projectID = "", cmd = "", url = ""
	
	projectID = matchlist[s.row][%projectID]
	
	// Projects tab
	if (cmpstr(s.ctrlName, "ListBoxInstall") == 0)
		if (s.col == 1)
			PopupContextualMenu "Author Profile Page;"
			if (v_flag == 1)
				url = "https://www.wavemetrics.com/user/" + matchlist[s.row][%userNum]
			endif
		else
			PopupContextualMenu "Browse Project Web Page;"
			if (v_flag == 1)
				url = "https://www.wavemetrics.com/node/" + matchlist[s.row][%projectID]
			endif
		endif
		if (strlen(url))
			BrowseURL url
		endif
		return 0
	endif
	
	// Updates tab
	if (GrepString(s.listWave[s.row][%status], "missing"))
		PopupContextualMenu "Remove Missing Project from List;Locate Missing Project;Reinstall " + matchlist[s.row][%status] + ";"
		if (v_flag == 1)
			LogRemoveProject(projectID)
			ReloadUpdateslist(2, pid=projectID)
			UpdateListboxWave(fGetStub())
		elseif (v_flag == 2)
			NewPath/M="Reset install path"/O/Q/Z TempInstallPath
			if (v_flag)
				return 0
			endif
			PathInfo/S TempInstallPath
			LogUpdateInstallPath(projectID, S_path)
			if (GrepString(GetInstallStatus(projectID), "missing"))
				LogUpdateInstallPath(projectID, ParseFilePath(1, S_path, ":", 1, 0))
			endif
			ReloadUpdateslist(2, pid=projectID) // force reload of local file
			UpdateListboxWave(fGetStub())
		elseif (v_flag == 3)
			string path = matchlist[s.row][%installPath]
			GetFileFolderInfo/Q/Z path
			path = SelectString( (v_flag!=0 || V_isFolder==0) , path, "")
			variable version = str2num(matchlist[s.row][%remote])
			InstallProject(matchlist[s.row][%projectID], gui=1, path=path, shortTitle=matchlist[s.row][%name])
			ReloadUpdatesList(2, pid=projectID) // force reload of local file
		endif
	else
		cmd = "Project Web Page;"
		ControlInfo/W=$(s.win) popupFolder
		if (V_Value == 1)
			sprintf cmd, "%sShow Install Location;Recheck Local Files;Recheck IgorExchange;Uninstall %s;", cmd, matchlist[s.row][%name]
			// check whether log is out of sync with proc file
			if (GrepString(helpList[s.row][0], "\r 1 ipf") && GrepString(helpList[s.row][%status], "missing")==0)
				projectID = matchlist[s.row][%projectID]
				string fileList = LogGetFileList(projectID)
				string filePath = StringFromList(0, ListMatch(fileList, "*.ipf"))
				variable fileVersion = GetProcVersion(filePath)
				if (fileVersion != str2num(matchlist[s.row][%local]))
					cmd += "Sync install log with file version header;"
				endif
			endif
			cmd += "Remove Project from this List;"
		else
			cmd += "Show File Location;Recheck Local File;Recheck IgorExchange;"
		endif
		PopupContextualMenu cmd
		if (v_flag == 1) // web page
			url = "https://www.wavemetrics.com/node/" + matchlist[s.row][%projectID]
			BrowseURL url
		elseif (v_flag == 2) // show files
			string strPath = matchlist[s.row][%installPath]
			strPath = SelectString(stringmatch(strPath, "*.ipf"), strPath, ParseFilePath(1, strPath, ":", 1, 0))
			NewPath/O/Q/Z TempInstallPath strPath
			PathInfo/SHOW TempInstallPath
		elseif (v_flag == 3) // recheck file
			ReloadUpdatesList(2, pid=projectID) // force reload of local file
		elseif (v_flag == 4) // recheck IgorExchange
			ReloadUpdatesList(4, pid=projectID)
		elseif (v_flag == 5) // uninstall
			STRUCT PackagePrefs prefs
			LoadPrefs(prefs)
			WriteToHistory("Uninstalling " + matchlist[s.row][%name], prefs, 0)
			UninstallProject(matchlist[s.row][%projectID])
			ReloadUpdateslist(2, pid=projectID) // force reload of local file
			UpdateListboxWave(fGetStub())
		elseif (stringmatch(S_selection, "Sync*"))  //v_flag == 6) // resync log file
			LogSyncWithProjectFile(matchlist[s.row][%projectID])
			ReloadUpdatesList(1, pid=projectID)
			UpdateListboxWave(fGetStub())
		elseif (stringmatch(S_selection, "Remove*"))
			LogRemoveProject(projectID)
			ReloadUpdateslist(2, pid=projectID) // force reload of local file
			UpdateListboxWave(fGetStub())
		endif
	endif
	KillPath/Z TempInstallPath
	return 0
end

// refresh listbox wave based on string str
function UpdateListboxWave(string str)
	ControlInfo/W=InstallerPanel tabs
	int SelectedTab = v_value, typeCol = 6
	int col, nameCol
	string listBoxName = "", regEx = ""
	
	nameCol = SelectedTab == 0 ? -1 : 1
	
	DFREF dfr = root:Packages:Installer
	
	STRUCT PackagePrefs prefs
	LoadPrefs(prefs)
	
	ResetColumnLabels() // maintain backward compatibility
	
	switch(selectedTab)
		case 0: // projects list
			wave/T FullList = dfr:ProjectsFullList, DisplayList = dfr:ProjectsDisplayList
			wave/T matchlist = dfr:ProjectsMatchList, HelpList = dfr:ProjectsHelpList
			wave/T titles = dfr:ProjectsColTitles
			listBoxName = "listboxInstall"
			break
		case 1: // updates list
			wave/T FullList = dfr:UpdatesFullList, DisplayList = dfr:UpdatesDisplayList
			wave/T matchlist = dfr:UpdatesMatchList, HelpList = dfr:UpdatesHelpList
			wave/T titles = dfr:UpdatesColTitles
			listBoxName = "listboxUpdate"
			break
	endswitch
	
	Duplicate/free/T FullList, subList
	
	// save current selection
	string strSelection = ""
	ControlInfo/W=InstallerPanel $listboxName
	if (V_Value>-1 && v_value<DimSize(DisplayList,0))
		strSelection = DisplayList[V_Value][0]
	endif
	
	if (selectedTab == 0)
		ControlInfo/W=InstallerPanel popupType
		if (cmpstr(S_Value, "all"))
			regEx = "\\b" + s_value + "\\b"
			Grep/GCOL=(typeCol)/Z/E=regEx subList as subList
		endif
	endif
	
	str = ReplaceString("+", str, "\+")
	
	regEx = "(?i)" + str
	Grep/GCOL=(nameCol)/Z/E=regEx subList as matchList
	
	switch(selectedTab)
		case 0:
			if (DimSize(matchList,0)) // check for non-zero rows
				Duplicate/T/O/R = [][2,5] matchList, dfr:ProjectsDisplayList, dfr:ProjectsHelpList
				DisplayList[][2] = JulianToSystemDate(str2num(DisplayList))
				HelpList = ""
				HelpList[][0] = "Project " + matchList[p][%projectID]
			else
				Make/O/N=(0,4)/T dfr:ProjectsDisplayList, dfr:ProjectsHelpList
			endif
			break
		case 1:
			if (DimSize(matchList, 0)) // check for non-zero rows
				Duplicate/T/O/R=[][1,4] matchList, dfr:UpdatesDisplayList, dfr:UpdatesHelpList
				HelpList = ""
				HelpList[][0] = "Project " + matchList[p][%projectID] + "\r" + matchList[p][%filesInfo]
				HelpList[][1] = SelectString(strlen(matchList[p][%releaseInfo])>0, matchList[p][%filesInfo], ReplaceString("</p>", matchList[p][%releaseInfo], "\r"))

				HelpList[][2] = SelectString(strlen(matchList[p][%installDate]), "", "Installed on " + Secs2Date(str2num(matchList[p][%installDate]), 0))
				HelpList[][2] += SelectString(strlen(matchList[p][%lastUpdate]), "", "\rLast Updated on " + Secs2Date(str2num(matchList[p][%lastUpdate]), 0))
				// if we're checking files rather than install log, check last mod date
				HelpList[][2] = SelectString(strlen(matchList[p][%installDate])==0 && strlen(matchList[p][%lastUpdate]), HelpList, "Last modified " + Secs2Date(str2num(matchList[p][%lastUpdate]), 0))

				//HelpList[][3] = "Released on " + JulianToDate(str2num(matchList[p][%releaseDate]), prefs.dateFormat)
				// use secs2date rather than JulianToDate because sec2date allows us to use system default formatting even for older Igor versions
				HelpList[][3] = "Released on " + JulianToSystemDate(str2num(matchList[p][%releaseDate]))
				HelpList[][3] += "\rFile type: " + ParseFilePath(4, matchList[p][%releaseURL], "/", 0, 0)
				
				// highlight available updates with a change in text colour
				wave/T UpdatesDisplayList = dfr:UpdatesDisplayList
				UpdatesDisplayList[][] = SelectString(stringmatch(UpdatesDisplayList[p][1], "*available"), UpdatesDisplayList, "\\K(4321,32885,448)" + UpdatesDisplayList)
				UpdatesDisplayList[][] = SelectString(GrepString(UpdatesDisplayList[p][1], "missing|incomplete"), UpdatesDisplayList, "\\K(65535,0,0)" + UpdatesDisplayList)
			else
				Make/O/N=(0,4)/T dfr:UpdatesDisplayList, dfr:UpdatesHelpList
			endif
			break
	endswitch
	
	if (DimSize(DisplayList, 0))
		for (col=0;col<DimSize(DisplayList, 1);col+=1)
			strswitch( (titles[0][col])[0,2] )
				case "\JC":
					DisplayList[][col,col] = "\JC" + DisplayList[p][q]
					break
				case "\JR":
					DisplayList[][col,col] = "\JR" + DisplayList[p][q]
					break
			endswitch
		endfor
	endif
	
	string s
	if (strlen(strSelection)>0)
		FindValue/TEXT=strSelection/TXOP=4/RMD=[][0,0] DisplayList
		ListBox $listboxName, win=InstallerPanel, selRow=v_value, row=-1
		if (v_value < 0)
			sprintf s "Showing %d of %d projects", DimSize(DisplayList, 0), DimSize(FullList, 0)
			SetPanelStatus(s)
			Button btnInstallOrUpdate, win=InstallerPanel, disable=2
		else
			sprintf s "Selected: %s", matchList[v_value][%name]
			SetPanelStatus(s)
		endif
	else
		sprintf s "Showing %d of %d projects", DimSize(DisplayList, 0), DimSize(FullList, 0)
		SetPanelStatus(s)
	endif
end

function/S JulianToSystemDate(variable Julian)
	return Secs2Date(date2secs(1995, 10, 9) + (Julian - 2450000) * 86400, 0)
end

function SetPanelStatus(string strText)
	TitleBox statusBox, win=InstallerPanel, title=strText
	DoUpdate/W=InstallerPanel
	return 0
end

threadsafe function/S GetUpdateURLfromFile(string filePath)
	string url = ""
	variable projectID = GetConstantFromFile("kProjectID", filePath)
	if (numtype(projectID) == 0)
		sprintf url, "https://www.wavemetrics.com/node/%d", projectID
		return url
	endif
	url = GetStringConstFromFile("ksLOCATION", filePath)
	return url // "" on failure
end

// selects project in the listbox for the selected tab
// doesn't update buttons
function SelectProject(string projectID)
	ControlInfo/W=InstallerPanel tabs
	if (v_flag != 8 || strlen(projectID)==0)
		return 0
	endif
	DFREF dfr = root:Packages:Installer
	string strListbox = SelectString(v_value, "listboxInstall","listboxUpdate")
	string strMatchWave = SelectString(v_value, "ProjectsMatchList","UpdatesMatchList")
	wave/T matchWave = dfr:$strMatchWave
	FindValue/Z/TEXT=projectID/TXOP=2/RMD=[][0,0] matchWave
	if (v_value >- 1)
		ListBox $strListbox win=InstallerPanel, selRow=v_value
		SetPanelStatus("Selected: " + matchWave[v_value][%name])
	endif
end

function InstallSelection()
		
	DFREF dfr = root:Packages:Installer
	wave/T matchlist = dfr:ProjectsMatchList
	
	ControlInfo/W=InstallerPanel listboxInstall
	if (v_value>-1 && v_value<DimSize(matchlist,0))
		int success
		string projectID = matchlist[v_value][%projectID]
		string url = "https://www.wavemetrics.com/node/" + projectID
		
		#ifdef testing
		variable refnum
		Open/R/D/F="ipf Files (*.ipf):.ipf;zip Files (*.zip):.zip;"/M="Looking for an installable file..." refnum
		if (strlen(S_fileName) == 0)
			return 0
		endif
		url = S_fileName
		#endif
				
		success = installProject(projectID, gui=2)
		
		if (success)
			SetPanelStatus("Reloading Updates List")
			ReloadUpdatesList(2, pid=projectID) // force reload of local file
			SetPanelStatus("Install Complete")
		else
			SetPanelStatus("Selected: " + matchlist[v_value][%name])
		endif
	endif
	
	#if IgorVersion() >= 9
	Execute/P "RELOAD CHANGED PROCS "
	Execute/P/Q/Z "COMPILEPROCEDURES "
	#endif
	
	return 0
end

function AnimateButton(STRUCT WMBackgroundStruct &s)
	
	if (WinType("InstallerPanel") != 7)
		return 1
	endif
	
	int rotated = str2num(GetUserData("InstallerPanel", "btnRefresh", "rotated"))
	rotated = numtype(rotated) ? 0 : rotated
	if (!rotated)
		Button/Z btnRefresh, win=InstallerPanel, Picture=Updater#refreshRotate, userdata(rotated)="1"
	else
		Button/Z btnRefresh, win=InstallerPanel, Picture=Updater#refresh, userdata(rotated)="0"
	endif
	return 0
end

// returns truth that this procedure file has been updated since initialisation
function CheckPanelVersion(string win, int restart)
	
	string strVersion = GetUserData(win, "", "version")
	if (strlen(strVersion) == 0)
		#ifdef debug
		Print "entering CheckPanelVersion with wrong window?"
		#endif
		return 0
	endif
	
	if (cmpstr(strVersion, num2str(GetThisVersion())))
		if (restart)
			DoAlert 0, "You have updated the package since this panel was created.\r\rThe package will restart to update the control panel."
			if (restart == 1)
				MakeInstallerPanel()
			endif
		else
			DoAlert 0, "You have updated the package since this panel was created.\r\rPlease close and reopen the panel to continue."
		endif
		return 1
	endif
	return 0
end

function SettingsMenu()
	PopupContextualMenu "Edit Settings;Show History;Fix problems...;"
	if (V_flag == 1)
		MakePrefsPanel()
		PauseForUser UpdaterPrefsPanel
	elseif (V_flag == 2)
		ShowHistory()
	elseif (V_flag == 3)
		RepairUpdater()
	endif
	return 0
end

function ShowHistory()
	string filePath = GetInstallerFilePath(ksHistoryFile)
	if (WinType("HistoryPanel") == 7)
		DoWindow/F HistoryPanel
	else
		// read history file into a notebook embedded in a panel
		GetMouse
		NewPanel/K=1/N=HistoryPanel/W=(v_left, v_top, v_left+400, v_top+500) as "History"
		variable grout = 5
		DefineGuide/W=HistoryPanel Ftop = {FT, 30}
		DefineGuide/W=HistoryPanel Fbottom = {FB, -grout}
		DefineGuide/W=HistoryPanel Fleft = {FL, grout}
		DefineGuide/W=HistoryPanel Fright = {FR, -grout}
		NewNotebook/F=1/N=nbHistory/HOST=HistoryPanel/FG=(Fleft,Ftop,Fright,Fbottom)/OPTS=8
				
		SetWindow HistoryPanel#nbHistory, activeChildFrame=0
		string s_value = ""
		Grep/Q/E=""/LIST="\r•" filePath // no need for Igor 8 workaround because s_value is created by GetWindow
		Notebook HistoryPanel#nbHistory selection={startOfFile,endofFile}, margins={0,0,2000}, text=RemoveEnding(s_value, "•")
		Notebook HistoryPanel#nbHistory selection={endofFile,endofFile}, findText={"",1}
		Button btnHistoryClear win=HistoryPanel, pos={5,5}, title="Clear All", size={60,20}, Proc=PrefsButtonProc
		Button btnHistoryShow win=HistoryPanel, pos={75,5}, title="Show File", size={75,20}, Proc=PrefsButtonProc
		Button btnHistoryOpen win=HistoryPanel, pos={160,5}, title="Open as Notebook", size={125,20}, Proc=PrefsButtonProc
	endif
end

function InfoMenu()
	string cmd = "(Version: " + num2str(GetThisVersion()) + ";"
	cmd += "Visit web page;Email the developer;" // Fix problems...;"
	PopupContextualMenu cmd
	if (V_flag == 2)
		BrowseURL /Z "https://www.wavemetrics.com/node/8197"
	elseif (V_flag == 3)
		Make/T/free/N=5 wt = "mail"
		string newline = "\r"
		#ifdef WINDOWS
		newline = "\n"
		#endif
		wt[3] = "subject=" + URLEncode("Updater Package for Igor Pro")
		wt[4] = "Type your message here" + newline + newline
		wt[4] += "VERSION:" + num2str(GetThisVersion()) + newline
		wt[4] += ReplaceString(";", IgorInfo(3), newline) + newline
		wt[4] = "body=" + URLEncode(wt[4])
		wt[1] = "tony withers"
		wt[2] = "uni-bayreuth de"
		sprintf cmd, "%sto:%s%%%d%s?%s&%s" wt[0], wt[1], 40, wt[2], wt[3], wt[4]
		BrowseURL/Z ReplaceString(" ", cmd, ".")
	elseif (V_flag == 4)
		RepairUpdater()
	endif
end

// ----------------------- filter code ----------------------------
// adapted to find text matches in multiple columns

// intercept and deal with keyboard events in notebook subwindow
function fHook(STRUCT WMWinHookStruct &s)

	if (s.eventcode == 2) // window is being killed
		return 0
	endif
	
	if (cmpstr(s.winName, "InstallerPanel#nb0"))
		GetWindow/Z InstallerPanel activeSW
		if (cmpstr(s_value, "InstallerPanel#nb0"))
			return 0
		endif
	endif
	
	if (s.eventCode == 22)
		return 1 // don't allow scrolling in notebook subwindow
	endif
	
	DFREF dfr = root:Packages:Installer
	
	variable stubLen = str2num(GetUserData("InstallerPanel#nb0", "", "stublen"))
	stubLen = numtype(stubLen) ? 0 : stubLen
	
	if (s.eventcode==3 && stubLen==0) // mousedown
		return 1
	endif

	if (s.eventcode == 5) // mouseup
		GetSelection Notebook, InstallerPanel#nb0, 1 // get current position in notebook
		V_endPos = min(stubLen,V_endPos)
		V_startPos = min(stubLen,V_startPos)
		Notebook InstallerPanel#nb0 selection={(0,V_startPos),(0,V_endPos)}
		return 1
	endif
	
	if (s.eventcode == 10) // menu
		strswitch(s.menuItem)
			case "Paste":
				GetSelection Notebook, InstallerPanel#nb0, 1 // get current position in notebook
				string strScrap = GetScrapText()
				strScrap = ReplaceString("\r", strScrap, "")
				strScrap = ReplaceString("\n", strScrap, "")
				strScrap = ReplaceString("\t", strScrap, "")
				Notebook InstallerPanel#nb0 selection={(0,V_startPos),(0,V_endPos)}, text=strScrap
				stubLen += strlen(strScrap)-abs(V_endPos-V_startPos)
				s.eventcode = 11
				// pretend this was a keyboard event to allow execution to continue
				break
			case "Cut":
				GetSelection Notebook, InstallerPanel#nb0, 3 // get current position in notebook
				PutScrapText s_selection
				Notebook InstallerPanel#nb0 selection={(0,V_startPos),(0,V_endPos)}, text=""
				stubLen -= strlen(s_selection)
				s.eventcode = 11
				break
			case "Clear":
				GetSelection Notebook, InstallerPanel#nb0, 3 // get current position in notebook
				Notebook InstallerPanel#nb0 selection={(0,V_startPos),(0,V_endPos)}, text="" // clear text
				stubLen -= strlen(s_selection)
				s.eventcode = 11
				break
		endswitch
		Button ButtonClear, win=InstallerPanel, disable=3*(stublen == 0)
		fClearText(stubLen == 0);
	endif
				
	if (s.eventcode != 11)
		return 0
	endif
	
	if (stubLen == 0) // Remove "Filter" text before starting to deal with keyboard activity
		Notebook InstallerPanel#nb0 selection={startOfFile,endofFile}, text=""
	endif
	
	// deal with some non-printing characters
	switch(s.keycode)
		case 9:	// tab: jump to end
		case 3:
		case 13: // enter or return: jump to end
			Notebook InstallerPanel#nb0 selection={startOfFile,endofFile}, textRGB=(0,0,0)
			Notebook InstallerPanel#nb0 selection={endOfFile,endofFile}
			GetSelection Notebook, InstallerPanel#nb0, 1 // get current position in notebook
			stubLen = V_endPos
			break
		case 28: // left arrow
			fClearText(stubLen == 0); return 0
		case 29: // right arrow
			GetSelection Notebook, InstallerPanel#nb0, 1
			if (V_endPos >= stubLen)
				if (s.eventMod & 2) // shift key
					Notebook InstallerPanel#nb0 selection={(0,V_startPos),(0,stubLen)}
				else
					Notebook InstallerPanel#nb0 selection={(0,stubLen),(0,stubLen)}
				endif
				fClearText(stubLen == 0); return 1
			endif
			fClearText(stubLen == 0); return 0
		case 8:
		case 127: // delete or forward delete
			GetSelection Notebook, InstallerPanel#nb0, 1
			if (V_startPos == V_endPos)
				V_startPos -= (s.keycode == 8)
				V_endPos += (s.keycode == 127)
			endif
			V_startPos = min(stubLen,V_startPos); V_endPos = min(stubLen,V_endPos)
			V_startPos = max(0, V_startPos); V_endPos = max(0, V_endPos)
			Notebook InstallerPanel#nb0 selection={(0,V_startPos),(0,V_endPos)}, text=""
			stubLen -= abs(V_endPos-V_startPos)
			break
	endswitch
		
	// find and save current position
	GetSelection Notebook, InstallerPanel#nb0, 1
	int selEnd = V_endPos
		
	if (strlen(s.keyText) == 1) // a one-byte printing character
		// insert character into current selection
		Notebook InstallerPanel#nb0 text=s.keyText, textRGB=(0,0,0)
		stubLen += 1 - abs(V_endPos-V_startPos)
		// find out where we want to leave cursor
		GetSelection Notebook, InstallerPanel#nb0, 1
		selEnd = V_endPos
	endif
	
	string strStub = "", strInsert = "", strEnding = ""
		
	// select and format stub
	Notebook InstallerPanel#nb0 selection={startOfFile,(0,stubLen)}, textRGB=(0,0,0)
	// get stub text
	GetSelection Notebook, InstallerPanel#nb0, 3
	strStub = s_selection
	// get matches based on stub text
	UpdateListboxWave(strStub)
	
	// do auto-completion based on stubLen characters
	ControlInfo/W=InstallerPanel tabs
	int maxcol
	if (v_value == 0)
		wave/T matchList = dfr:ProjectsMatchList
		maxcol = 2 // look for a match in columns 1 and 2 of matchList
	else
		wave/T matchList = dfr:UpdatesMatchList
		maxcol = 1 // look for a match in column 1 of matchList
	endif
	
	if (s.keycode==30 || s.keycode==31) // up or down arrow
		Notebook InstallerPanel#nb0 selection={(0,stubLen),endOfFile}
		GetSelection Notebook, InstallerPanel#nb0, 3
		strEnding = s_selection
		strInsert = fArrowKey(strStub, strEnding, 1-2*(s.keycode == 30), matchList, maxcol)
	else
		strInsert = fCompleteStr(strStub, matchList, maxcol)
	endif
	// insert completion text in grey
	Notebook InstallerPanel#nb0 selection={(0,stubLen),endOfFile}, textRGB=(50000,50000,50000), text=strInsert
	Notebook InstallerPanel#nb0 selection={startOfFile,startOfFile}, findText={"",1}
	Notebook InstallerPanel#nb0 selection={(0,selEnd),(0,selEnd)}, findText={"",1}
	
	Button ButtonClear, win=InstallerPanel, disable=3*(stublen == 0)
	fClearText(stubLen == 0)
	
	SetWindow InstallerPanel#nb0 userdata(stublen) = num2str(stubLen)
	
	return 1 // tell Igor we've handled all keyboard events
end

function fClearText(int doIt)
	if (doIt)
		Notebook InstallerPanel#nb0 selection={startOfFile,endofFile}, textRGB=(50000,50000,50000), text="Filter"
		Notebook InstallerPanel#nb0 selection={startOfFile,startOfFile}
	endif
end

function/T fGetStub()

	variable stubLen = str2num(GetUserData("InstallerPanel#nb0", "", "stublen"))
	stubLen = numtype(stubLen) ? 0 : stubLen
	
	// find and save current position
	GetSelection Notebook, InstallerPanel#nb0, 1
	int selEnd = V_endPos
	// select stub
	Notebook InstallerPanel#nb0 selection={startOfFile,(0,stubLen)}
	// get stub text
	GetSelection Notebook, InstallerPanel#nb0, 3
	string strStub = s_selection
	// reset position
	Notebook InstallerPanel#nb0 selection={(0,selEnd),(0,selEnd)}, findText={"",1}
	return strStub
end

// returns completion text for first match of string s in text wave w
function/T fCompleteStr(string stub, wave/T w, int maxcol)
	int stubLen = strlen(stub)
	if (stubLen == 0)
		return ""
	endif
	Make/free/T/N=0 w_out
	string list = ""
	int i
	for (i=1;i<=maxcol;i++)
		Grep/A/GCOL=(i)/DCOL={0}/Z/E="(?i)^"+stub w as w_out
	endfor
	Sort w_out, w_out
	RemoveDuplicates(w_out)
	if (numpnts(w_out))
		return (w_out[0])[stubLen,Inf]
	endif
	return ""
end

// find next or previous matching entry in wList and return completion text
// look in columns 1... maxcol
function/T fArrowKey(string stub, string ending, int increment, wave/T wList, int maxcol)
	
	int stubLen = strlen(stub)
	if (stubLen == 0)
		return ""
	endif
	Make/free/T/N=0 w_out
	int i
	for(i=1;i<=maxcol;i++)
		Grep/A/Z/GCOL=(i)/DCOL={0}/E="(?i)^"+stub wList as w_out
	endfor
	RemoveDuplicates(w_out)
	Sort w_out, w_out
	if (DimSize(w_out, 0) == 0)
		return ""
	endif
	FindValue/TEXT=stub+ending/TXOP=4/Z w_out
	if (v_value>-1)
		v_value += increment
		v_value = V_value<0 ? DimSize(w_out,0)-1 : v_value
		v_value = V_value>=DimSize(w_out,0) ? 0 : v_value
	else
		return ""
	endif
	return (w_out[v_value])[stubLen,Inf]
end

// this proc pic has a transparent background.
// Use with button ... labelBack=(65535,65535,65535,0)
// PNG: width= 120, height= 40
Picture fClearTextPic
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"D!!!!I#R18/!&a%*,ldoF&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U$*Qog5u`*!m@7s5g?-t@07aU`NNa-)G!)`O7O2t$%[j\lrilBQpZJs5oRPaH:&lX_2l'h45[\+oJ
	DLg>ZlNA@]\Pufe,'ef,bCL5=GM7f&ON8?i*ZD'+l;q0Mi.tHh/5"c$ufJggU=@<$\2bCM4uE>Z:lU
	/@=<PE78\_"A,QqrpSkB]K5KB:%)]ld/:+uNb8=&U<A0V0Z*CS([i$sdr&t@=78pR-RU2c:TMhc9m<
	3JTGH$9A8RcORNDc`D/sg'jFnJK=)0LD#$O\u)?E\_+C6d8s;]Nhd4<EBpZ$8Bk/B`G2`>95H71+ac
	SJX*Hr&uK?VJ+/Y]YhWSrqPLa%)]lhmJgq+nT^"(=YuUB*64c1msEBQ5JOT<UWtM"R-NU9YNOI%FXi
	X`_r20QoBpElgU:fSRg]K'@^2<0Za6u[8rPgGW#ulLVI`n:]jBmPX&kg`TAQX<I!D7'?ngO9n%\&Lk
	\-r2UWtMb#^,Xqi?=IYjcbi%mC2!Jjd0<ip/9E970tmm>d)bmPEQZ7_r2sfEINA^aiOjs>&CDSUWtN
	-po"CdVWkd>o7g#<':SW(Yo'OBX/&WB*65lLN.i%p1l[cc'h4r1X]FaWQg8o<SPFrT[E?M/L,Z6kc/
	UaN9Ge0B%#72\=[plIL%lO?_>3meU*u2JjbUt;\)J2m";,J)[b#1LBXc`ih5DG%,a1fCG'5:!9'EjH
	U*p;ao^=78!fE_FlT-\+^?#+]k@??9)[?4UIG4'Hc"8d(Zf^fL4:fW@3''*p>V8sUeZ`n;ApsA8&)4
	OleS>$Wj,a-7l`]r,]hk+SO'biu7'L):r;QT^;l,5KW]Y\(OCun2O\2IkB!Y$k`(rVr`5T\akV\6ln
	BEoLYe@_E-Bl8g>s-H.>V>X,_hT2o4-%5Xr][;\b1k_,r90J'O.U-T]RB[CrV_/!_]eDj)qT6.qWk=
	V,SHg&fXB&*=0FSI5,Qrt+\<;u+AaPQf\G7eMI0<p3-[D&dd;4G9I?G\-Bh"Z2E"+&;TQ-`3.*P$;6
	<l;Uh`]RcukoHm;5g&72.DA8u5G%lg#CKa)nrLd/#eaT4M1'q<+@YLI3'%#okRT,/n$]7_1JdK3GCs
	naS?2BegTdJp%"CbOCE>7(=5\?i?-rE#aX.Vo-2ppJ=j)8Wq/*1),Yc+Jnm/ehiAWSK/b9IZ1;,`8b
	iBf;7BndqCQt5<kdONdmY\31_\E_P6s==_<)1S[5XY9[gq&?$a1*eS6ri$,2T4_r0bBLtAh;A""b)n
	JFi\8>jql^OMl@Q'J3@72[h1e'h5j:JYVpBG^s8EgbtJA,?-fj7/L]4H?:Q4F-K#?.VXpP9c>`FBrO
	'GF/!qFlMpNj7/Lc^X)H?1$*G$DKBD,#%qR]_=8`I1ej`E.^?\#9fegTehmkg_o"iV[2P?B@9FAR>)
	c.N6Dr9=^.15TAp\lo;Q2L^3P3Qiaq3N0#0_rS++DIT?'e'B*jNGn%M2%6Wi?'[oD.<%>h6r1[7[u7
	?>,k]lh0K7H9iQVPb2=S,tYuB[f+OQ<i_Ub#sbiM$sph_Io.a4.@!LRMR#(R-pr[2['Rj0(XM]_\@A
	28XYLrYg"kHn;R!1$JT2Am#pRGI9b%[EWRpH7S$D:hc=^"'Jfp.G,UaFd`8bhePtI-i:"'N">deJSO
	fPK3:S'\B:af"S`ocfL1.8YM_M]<Sr_mUmnMn+_#;oYIUu36-<n1qBlLk"jRb?kF2:@iQkGQu&GYG5
	?$Yo64Vt`,Nf6%FS_SVa%N*hem_IWt`Muhncantu460)?p0)T?in&q#.?s2&NfA)+QVJ//>p+2$TlO
	g$C$Mf'5OF@-<^F1=K(B#oc3JbMJ`a,tNps:jW]tHRL\QifXi^_)HhVM/p%j7!*OA%!Rj4j&Z%"j1b
	"'Vg-BKGfBbe_-3;WT-^?^)_NV)&fS=Z?jce%*19rKKH>-dRFkkPF_Cr2/^`s"jV<4\[:Wb:h!LJK#
	'H1^J\`/Bd7gcJus+".A69gfCHZ5VAB2B$S+cNl>Ilb@M[6R="s7Q=XT0%ZV@ekBS,/j%uf,Gl@J]+
	Hq2DS'0mnBXM$[bh:UiPKAJUWIuhG1["(4r1XT3?tEo'e^[[RmInbfYKiHOFRHu]!<@InH_EKGhX&r
	d-BfU:aTTYBo"-qe%b%t8H[>`4*#sXsjE\)tC&F\6&KmRfP0ITap[6ke'<f`J_fW'==\dGfZY%h@f=
	ID'(ZBRd[N)/crGHnL:7a>TT#EA*&-7s9Ul`]/4Acfjc?g9piSM7pUsj$'8XcW"Vs._l<S?*[U=!XJ
	Fg*9OUsnRh2PMkAcaI]9cHbYJqm`dj;s-p)aeieCrr%33hnMD+JRSJNN'J_d;COAh%'`pEEZ,FC+5O
	&e2d=![],lr$\?=#o`Pp>DXg(ue[C*D=>rn&(?^oW!]3Y#?bL^CYU*q3W&rB"#oR?HqISiQ3]C3H95
	aLO3'1J$aWtcO!r\&XU)DN.iGlRb+5QCZQb_aVi4JpYD+\<=:GT=UTpu-uM3'020D6sq4">=,rjNB3
	k]Fc1Uq"[]78<SWSMJR-Hn`%Lq&rFQVVC<RIPL&E3?'iZDJu370qsCk'Ze<\IdO]iE7;ua;;&!GSCW
	h)!mTlc7S4k83QGqUfDeV,!$]P\#cE9BZpqUQ"U>,'i7^-5$o(d[sB?fHQMoA46P<=6fOF06QU*t)P
	V5prgc-8sN;.ON\/Mr(BnV\k\](<))W_b5^4i_PU[9>M`CbhC]G>a`X@2Lei.R=VJ>?g.8UIR-7+4&
	s`MoBSaiQc5-(?H?$gt5f(lagJmVUt;25M<\,PtLT)_#ndbT52*<o8=MR4-n^Y?,$1#X%u4El-lQCG
	k#6Oj$fMGPRtDd.[`s;KgNTXrg$&Ai%j\r;CS2$I7g20=R+V=o8=6Y5+@eYA;&dp>n>lSjFg:+KB"q
	8ZDbNflG8)XPY.cV77Pf&70O&^5$G#;]Jjcccu-=4*,"Q^`d*BZ@`YiK2OgOF/5e#7n&0HJkP%!An,
	qU$_8'hES!;*-]%ueu*KFRt-&DSOFZQ)-;r^<;hrhknJ)RWC\gmXNfSVU-%dE`b(kt>[f>DTuO*#@c
	OU1iB"B)35J(KGFW:Tmk=?(o9_uDr[Ws5*f*uLHDIIc'.eG4MBgtKUEidV(1&"^g5==2#e"TSN&!(f
	US7'8jaJc
	ASCII85End
end

// --------------------------- end of filter functions --------------------------

// PNG: width= 90, height= 30
Picture cog
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"&!!!!?#R18/!3BT8GQ7^D&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U%adj95u_NKeXCo&'5*oW5;QerS2ddE(FP;'6Ql#oBiuS1dW/'TBu9uWoJd,<?@,Ku[OT_*C6>N&V
	5fgKO-Z!0m]BHZFE$kSY/b+).^UIV80KE-KEW"FQ9_,eF^bT7+UPEE3;1R;IlL+VJZGMtc/)57aYSB
	X^5kLMq7Sp9q0YBG@U214ph]9b)&eA4@(!#Ip%g0/F0_UH>\E'7M.=ui]mI6`m'G"T)B'OA[IVmQDm
	=?Eat`-Qd[5bR1c#F]`cT(Se*XgJen[DI=<Y8YF7N!d-X+iY2pq;SVDt;siWS_bs$!E]WT^pRhs]aH
	M%csq\akmJ4tMo<HGU1WqT,5cib%XrHM`>*]/&U:](RQ7QDj\u&#cMNi8>`?8;-?rCcXX>+1^gW10F
	n!h-2G-M;R\a+TD2op'?`R]"%W!DpJmO],i(@-(/F?,;L7Vkt%YOa,f\8+CV@lHVOEMgMZPnh$6>!V
	MTYBm^8f[O,?Z$2MnH6.T'JWSM4HtSissRo-):4d:ecoe5Tn^(gUEQm+o94@;L(/[91%aXk:!pP;mm
	\kh$s.7qbe%=-p1eBtDs*CHp:+$CUY\0A,jM0:4J2&pY-HWBG?nb`"BE/M-#*)+E?I*C/(r;J]APNh
	3!Ea<(u)`o?0R`ma=QV<n?GV/s3:I0Wf2_M0p@:__T%OEl+sL@10K8&ViQgR(0Q3qMLYA':/iba:,;
	]Y$@ACMV&9b[fD4A`Vq5+A!37VD0na`;0#fWNWKq#f5N>Mt)$S['[2:?=(p2$Q$$NX_cXoJ`iVOcHm
	Rb+"_b#*b4@tp)Xq9r*1_<^IVlpMJ=kE>MhiHa2]]q9<d*4(lA_8$4ej2NM5Z!#`oc=+Ttk-]%D5"O
	Yiu,o$V/I<=@2fN3Ds,PNfIEnqn6C?^[OYDs4q2k*s6TFu+@1>SKUmdko@B5>Pp)-]8`l_Ig,/1c.T
	K'Z+asa)qDc*mqZAKmijlOd;;&H$MEMWY1:\q<G#aaNVlho?TWCGL35!G658MH$RpQ,/[:S#==eP-@
	T+s%'h-7&.0)\eW6j@1gNW'FYlgRIid1g1dP0.MtL)"o@*4A+B&XU\9bRSJWg?B!keI%b6T7FS'?W(
	@7j-a-n[,Adkh%U((6"oN9G"iRV$rmb0"2lqXk08!N&V_b13Oo*tc)h=[L]E@W<ihr:]%Dbs-*cCbc
	T^`<b81D1(d_gue7JX)rMl-Q!ag!0.a4mbCL5'MQH2X<p3`1nA#69QNiWDnN[J^:kIm`JPCXo#W8lo
	?KFN_dOMp#7s\i!;q:1Vb`q^Za5j'0Sg8ALVn\tm:OM*.G/IF;=K4S+O/0U]^`u\O,i'69Y*0'f,SH
	:Kp)mH3.EQ3hDf%?f;W[LbJbR7R5Lb$8U4I7,[8ZM7fU7H5(>6BlSlr1cG6"263q!"YH.\`>aLYN(!
	e3hZYm666$Mq_c(_GHO?%CE(rnI-UV=I6M\e$%CXt$`9q"IB8d`/4e)0&Dcf`43oobf6MqdV?d>\73
	X/dI(2jZ+#[Nt'sQg5KRFl_^rEVX>cZ5h3g1gR#*IhTZf+KqmsVrW[`UcE6>MM*N0fMcT[S!:h'=ju
	EaL@5>OfU]WXd+d/JISLYCQZ_BPkB$IiAYUBq1l^ecC4a8EYJ'WJ,pak5V59k6$F23m\(d</D&W$.c
	&:n64N(\`j0%h;m7iB=j)(R^kh8BUCfn<.JP[26K1F7\>0JOc56jWCOX(6k=i$m^+A%<G5QZ.i$e8]
	01cU/k$R?&@c[1P\L>tK[OkSMmQ7lT_puI&4&#-'R99q+p;3\Sn`Ic2G%kDj/"N6oB<E0?Z6Kl"@,Y
	?4P5G,Nu\q^LTs(Vj(g3YCoZEl;W9!T)>ePG,S!10n_Y\rP(FBr90.J3;jVP^MYp<-ML6>(=)*bFsB
	&uWX-VWg'<P8G@$+\A?J1@G'F,/Z.<q/;.,=8I?;gFp>>;IjEQPE_:7`.R+3bElA@DB6<k@ksJ9lg(
	=CVM=g<G(^E#SiiFHZ8.qF-^ppkE&\[U*_);<'Lfk*Fq]^#W339=Q'IWpj"KgUWU]1,ETW<&G^OtOH
	MkGSX1r0@A!=Gd&>m2;$s(nF8b!K?8R`eZjO8V38_I$<1AcnP!)B*`T#3.X=hE[s8PMoFf*/H2@32u
	N'Len`GUk?n:K*@=9gMMi1ES9gF7flQcCD`2n^,h:`S5=GNQ^G#@^/a:?]W`PV50n4Xue>QVk8E1=]
	lWKB?uV(SiXjL_hVC,G-+W-bHd)[C`^u(BPM:VV58ltJcZ8d$CEhp-Ek)Qb.'^'f)4eT`-]7*:O[1>
	WO?>HRRZ3%&Aum4gNS.jU=.^S*B#H\'0H3Z)tG>O;)WW1_IO09[>@PI4Y3R7J0]^!UgQhj+u1-,O_#
	4q7aj2?Y5.V]ph=D*J`g8?n%JH:8P)K%MLrfVTs(X1]A:d+mFtdNBG"";'8siHNZC4&bKJq`%mNb7r
	SW;=`2-+n=L)HDOsFHoS$CX_6m<3W758iRSt7"9?7u`s%5^"&NsfV]&fKiR),nod"F>!-ZZj257RH'
	BCpkU2>pgE:BYW?=m,Fa:(R[)N0g+8U_d1?h6?87.J?1.S8QM+N.?c/5H^[K9Qq/KSe*09PFi*)kOs
	Cpa8151hB![K\`b9:/2t#`0h)TQGGW^_mOCaj@jCA@uU*q95,uIW@7!X&<O\"P/_=YGg"!\PP(fcMs
	XX8]B01I/5GVm/oHal.qLkA^e?r`*cq5<6cMYpEN]i/%/Vl(p'^fIMd8C\oHLnT1!)7oQm]mKeID*1
	Nn<=:2#ZkEe#YpHHH,[1j)T%7I4;@/)4cu_Q1)PbZM:[@i"UEI%;r>p03XoVZ_RkU=+$'7#=USG/bL
	8-+m<=>h,iqN=A8kNQ3E0-ce+TlUO7L$\:&5CW07\^Y5(=Lpj3bn5fXf]+hD?H]7Wq?&[-c"7hNK0#
	/)B'Mj<HT8ma3CurC,*bh\'aHR7Z[QbX-ZmAk800m):lpO:?P+(!;TY'R\j"AmjWGZ^'4n^bf?W3J@
	>&NBK1HqWkVhSJ@2:%U$9,hq:d,G1cCmI-TcrP\J*Ut[2@6?BcK3XN6]^DH?sm>]m;PWk0+t]M3*pb
	_i5ToaNr1&dko4ib1O7G-^#a3R58IWd+6c;6ULrU<E06&]A7B"H::^+p=jM"Cht@E-\k9W-F%RN7[f
	g9`s&hll-^kfa*7KZfMd!Yc("^(?tb@(G_h8BF>IEA!<RhTlND,!db&r!Y3m>2$M&6dHhJmnR;"(TN
	7k9deNFM:rt_%M:_\bI5MO2h<A0N#R:ZSrC"&ps\iY*%&:=-;@IrX+"G9!l_&sOI?=_'7)$hsk)[Og
	CfZ9V$@mNB]AS#G_>V6^Z_/)$iF?19\*_+U8'Lh!@O$@74\ogtP<K2K,l#,B;0e6NJ*#oS35C1Gqa?
	[/#EMYbdp\'g083t^Hm.OC']=?TCh[+\@'/CD^$lb9k>s0TnKIaqh4fI!&lDq*\4*U*,*??/2AnId;
	.P@%q^Y_gV7L#<Y@CP!Nm,EKn=&i8<r@!PTa5]H_PQ](fBqn;iMUE,Pl5E-<#!*W9G0Gifi6\]*<o4
	FnfrX,WF^_\F$1nF]^fU-bLO!=bm%5lG.k3$IWMqUu'c@l,R*B4I#7$5RGsBAo;S"q!W&r%8C2/"PK
	bsa<4<J73edT0;DW#W4)GM@uFDONL"9R+_N^([T!(k&'aJc*VLHV&^R;!(_#4Z$g7@#[rnEd4b][m6
	"s2Cf6FX#Yth+![-Bc9;DCc35!#ZOe]>R5l%A3s9r*"E3cZ^HAq!@!X3ZLR*.A7oQ8om.\p[kV)RYJ
	YS_VJ,ke(!91A):`eg`H3<A0s%C//=2RBq,pC2:S]*\P@U_Oa*3.T[g!Hf.uI$^Z574:Ig+a&Rh&b)
	g:i!IBPVCY]Y$?Mc-nM/==coe'#A=jP*M;$C2,4.LP+[KAA[:ZiG]VW6ipmf;5gRtUogbYmG#,M=Y+
	23\;kLm>:;.qMlKqn)uClJ![.i',6Vo?VRu"<5C39QHia.rIUXNcq/492/E<t4:q=5j]#0#BT^2C8R
	r=7NOaA&EGCimE'I"(o(b72sE7cRPmWBnj]tHh/;(=(Hs(iTH$*GN/REC6P4"-OQ)1Z*S9OlNXqYG,
	/qFo"%Xt5WcH)DMDo_@'gn2mp\l)\(b!Y0Pa!2n,Nj%-R@Yjn?WT$E#t(FUbj=.R08ON,:0qYL%:/M
	0]<Q1)2)G':0@s*h8ZZ<4MLPu4'A3d&SI6l9j+cCI%0ltDh?G(&13<0N\Q=?t??;p9Q8$59_n3Rli=
	5b`N"1`$#>;[JNr+$!*^fli%qGlHBaGd#r_gndbH0<a<pR0sE5L0:j)I_t)\EH/7Wqt8QJMd<r<&WK
	8J3cuoH9hij#22_bS-?/1q+bUC@(DjDc_1Dg*LCYK([C$_m"OB=44C54XF6CiRHM)#JSik-Qi#lgdX
	C:AAV;n0(-%L_0m!T,"d5MVG@HhTKZ87K.p%WH^Xh3kCpXcTY<@p]%p!H!PcGm8Ma`dWI-i:%O`.@A
	\EMhGlp>Rk7O<G2m`*r,h[u\8;4r,bUaQp%EDN*J]D4B1hFXuppq^tpModARV5%<QlNN?L%hAEkIlW
	/#`^]Bs#-d.f-97RH2#l<o@ZXZ&T?iRH-<%N9SU+'so7AAgW2mil0fWaM)A,6@)4Rp@WFC0@Y,uIN:
	5uCJkMPAJFd6VVd/UR6[rI=?0fVgq/kI,s^(YARDN54WD\PD#"bV<C5XKS<`]Fql#m@)ul]O#Nn]-2
	[lB);<HM,sPARkJs:;d4_S!/nh?qGe7@I:AsnMi7DjM_D$2XW>fsY^ZQI8$;`nm!f"mg^^mq'BNs/!
	!!!j78?7R6=>B
	ASCII85End
end

// PNG: width= 120, height= 40
Picture refresh
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"D!!!!I#R18/!&a%*,ldoF&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U$]mqJ5u`*!m@/TEPP#s:hr!V=P99ac1i:^=Tdah'eCFt-fUNA)3cDoej+J(biafAhjG2s04+GIA3
	V74L[Y'G'KKC'm&*F.qY^2tJJLeg8=Ons;e!;(IqD4pAC!nh4T'*FEg4Zh-Jk6?Y]tWs,bL>XGkF6\
	db5:f/nN:ANKQ4u7VP^6Zg-SbYhmJ#Th,oX=*oe.D4N95gG`59Re-<L1gc0.6M&Q8:C@5n)VtVY@^l
	UYZ`fs_/@[Mnl]#'9T2dWoNZ+hld,XjIPI/Ho$<'LKHnT]$@gc8WLE.RA!45=^4!$EL2!sXC/'bqH,
	0/#!<odqaIGj`-*-o!FggU:r<G(2GSE<2@r_Qg\IfN5>Aat4t`94X,3#iOea31^4;O?*[H>)Bnp*p=
	;a/1b+Za6n>,V'kP[mF^6s=M4Ao9$!0jZFXMT4qf25_PpJ3E9PXl3d^QO"@7Q)Tn#f`"3:'M/Q!5@o
	D,>s],OqU(3AW^_*\_r`3`]bYar522E^s1e"g$F;-dHjD#S=L=KKuI0<CdUh'^Ot"h,@aI0*AO"W5k
	kLWpZgN6/kV1@RsA^IL\=EsLK%4BVTreQ@+kZcptKM-oV=:R(:&.6enE55H*4?Z6E6+dJ=XfXuJcfk
	`RBUnf+f0bK?Rp;ccPE:`mQE&\j$m-M[M`J_!Cku-*_eV1DHf9.6^0UYToEo[L$S2`7Ehaj@dIHq#/
	,[o_i%CG/r^He!H"FY0&f^fpsGU<O5n_b8qT&ZM8<^<cf6d1au\*e)Q1&mG&"A8D55<fZ@`t.uu8<S
	YngUGZ2rVM_CQA4bmm-suY^u]h_Ek*0)[2OM/+(]"pq!>?5Lkm/Z!qPsSK;frPqGr,p@Lo&Vs&X<jr
	\%dtCVe+PO@8Sb7=YAWJ5"7@E=@3p/<beSpO\\]'e#MK!.2$S@ZQ?Cr;=9n%h5bhkJOlRl_pPP!nl8
	[i&D37"J=!FTWb*2A3m^Fa+`>K.M[huMI<pJiV34rrUp*p7]W["=<\&e&,h5HDa08(P6P<0?F[1`^q
	;cVW/XU[.X:nu>\_"Z4on2L98#2RV%<!%a?5Yp_?9sOI:.D_a$8.=,RGDJCnSqn9'Gqo\6LY.G'8In
	OI;LCV,E/ASfUub('oKl[9AQs['W+J%c%Nt6a4>f3,WO7hXmGte%_B4,#P7)b;\gu5PG10RJTX#GKr
	kf]KCG1./EDDV&\t&G7T-"<>kFS3i)(?YE`n+5@ffErSY_s*BSGkR58KK<i]Z8fe?pU%*Y2"O-Pro5
	S/Tar^7>5'br,I/#2\+EYo2hk]FD?8IhOY!.<"Vkc3cdGjC8P6^],`e#pUC9D5]k=a,T`QfhnHR<oH
	Vk2+"U>JJ"C%nin<eVq/_'75o_RV%QjQKGufGZ7U?K6Q4$(C:BSONZb<Z=OCo/.=`hj*;]pVbbA*l-
	id`I6H/b?Va_'[9jdm\:m6kXbuEAQ&hObn:XBMD:nm@7hO\ie?'UtiPW]#AO`%p]@[ss?bQ_.*c9cH
	R2BGTcHaG\X]m$e*@R,nKPfJP0qD&EX48,n:C`(A=qqckS&^)%+VWTGmUfX&>"fAQa:n*AH!=G3V.R
	6@G"!F!nLVC<\>,f$.4H]jrUnd17\bh)>*V^6QX4upfk`RVh<qN3*=ICmI^>Z2Smjn2LBMm3bRHLT2
	IcL]7qn^>#d%,HKZSp5k5$3AE@,q^Y$K9?pHtcT`I+fDDT@Yg^.>fF\^5*!&c:NA?(qL/*Z*VOX#;N
	ar;_[g?C5WPmt2J*%gPVWZ6AnWJfqu8\##o).p&l!T''N;R0KKF>ae0`L>DZ:k=$rU4-pQg$KU@2L+
	UGsI2NEOW,LN/f[.uq2/Cd)7\`7U?=(CB7[kW`<Xl*NO3`H6p\]u5N<tu>C[<trQ>tk,hb:Q9h;)2H
	H8TEE>3+c*$lVfn9CcbN$Ojr/Uk)Fd<2ffMN9[Uk0jRjiQp0;+_FgLuTXq]qk*lTE77B/Vd>_..^^o
	n%94-CJa4sdGl7G!l`(?g=@db+CdH]8_WN)sJk3Isq,BiM1acoEZ%<+0['c-;*[aQX1Z97n@OT^dl8
	0gMG$"Dem6m>$uGMclC%#_[TVNfl9W[]Q([Of?=6'A%JRja.:,$6B3>e5#ke<ermFkm[)7"$bc+OpC
	o&h[<>UZI(JHQW'6.:e=*iOck>#]M(]!YOD^ji_=RCrE2FS![G5^ODqf85TC$#SI>nm16b9^(0P]%d
	[R!&MpB'hkI_[,,4B)Y,eUUh/:9&Dna=K1G`sL^QG1Fonq+_>Y,osi+ngmXqpFp&,ri@/2"G=^DEX*
	O3;bJDP.+;dMf](>?_K5dht+"St7!ZU)963OeRX<V>s/?/'ej^g)[-kT,G\Ar$!c'Nijo-q9C(G8l4
	KqjelU;Os:ZOk\FS@XfW$i2)X$qDdQagSPCPu04.IHV%UCamiHVt@KdH#_,AoOe[8,R;'T^_2P*)0'
	Qs)Y@sZV)h&TU;n8W492FFU&D%/Mh01oB5,RJ4n)FgJ6YJ'WJGs%[cg31#3GkpHfWP,tc8P)Knq&:c
	?#ZqL,/Ob1q:cJd+b_h+$*h_fLDnaa@Ibe7cKtHN0finVL%-rE6LUbcP4i!4+TqJ%YmHs:C[;$H,f@
	PMQG0OVT<j#\!(5i=rnB<]7N8!n*;+brF`'PB(i*OJ-_QCc\BWs@'rgs#O_1Dhm4Cot2Q@2iLl&mIj
	EQ3;CJ$7WpA[NU&/Ooo8>t!qJX)P]MNjt#QqV-T"DJ5FBJAT/i1c.$s`JPCPhgP6-mbG@S\@B'+F@d
	08<*!%oXK7A@+$U7+:'[E;LII+:TqJ&$/q5*7;>T3d8JNOk5aqS1pDqH$dNMVg_--(Q*'J\:7#qI\8
	hP4B3]O\jYW+:fj:]r[8XO`m(0W=O0Jh`qr-%f&i_E"R\aI7a<aa+pbX?2\.V`^5:gRI'5+`>iK)qs
	NWGjnhBP;&Z@gje8.57/`BPM9K8P'4\91qctH@[Jp6PhXqlY@ZbjY.PDr>%CA,gkNeZ>q^_C"0u^pV
	G>?6*&lMU]M3JR/eoII\.,[AikI'2@EaO^WhM=-o,`k,aZ]:Q'E)h>VjB-0GpJ7lf%I2i:2'MEk*:u
	![^X1"JGMJ4fd+j.9!,%eQ6*h@pr6q\g=qbedSJD.[2\7R[Yf]\Sr/a\Lcau9-Ot,!u-T4#UJ_!8!7
	iAiBk_A.p-u8PBc&X=4g=jZidH32Ohs13#kaC'PM5r6:!m<"@7jt2`&IH<%@bclfdOt@q-`!/6IE;.
	orn%I$6co;5["J\mDo84aNK0<GC*+nrL0DjE@?`;dmbu6]n#IK'cXf!s:=#O,b`]\705DN[c,4(VI_
	9R/<Xe0cl_F3ZJXBn\uMAUXA"jGM]$G#7i"A4WO`Z!D93Z]$$I9V\=6c*I>C?)`MYFe##hY(4RPt@K
	3YWn+UO<HZ:b[(?_>ZN98D4lo_nN%\5h7%^?I7RO"gE(#WXc,S24u7!H*VSk]eYSR1*:4Tgb2r0mS+
	o%[YXVk-%u2AI#EUU@LPcm"5#DT@;1#O'gF@rSt`85;p78u2U8o>-+mYLa/kgC94aK;heI@fH<$Ct>
	[jENN0#o`&_5$[CN8mj31=$[Wt@5O'H4q3EL01k(9Sm2*jkFThc<O=?<WCd;Du1&J]TDJ57`_f!&m[
	$8/5]!,ntVPoCi[C*D%J,VQH2B+ZI:&ofL/k8B###$?WRlY[AP*;)bjCM9l#(!1*6gZ7>UdS'"&J)d
	=FMJK(dR]*#?pqdN%3#3:J8n$.38cNoEPQ'hrs',.NHI#=JqO+(!!#SZ:.26O@"J
	ASCII85End
end

// PNG: width= 120, height= 40
Picture refreshRotate
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"D!!!!I#R18/!&a%*,ldoF&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U$eS$=5u`*!m9=pV;cOn<cFLJWdl)'s1mY!LBPA\i8r#%/K>K1`U?g*H70OGA'g'%8/A=Ss=3#;_F
	kL2X?$/1<%&!A\H&7PM<g]-iF^<Z(?)L#o/!SJH=4>O'9p7D.dec$$7ijMS9m]gc:"atORJT)o?h3%
	AGCK:1mNmfH9Odq`m-OXW;]$8AIna;`h_-;[^<SG^n9'a_JZj-.P]kpZp9![lkOF3eX0Tr<_lCW8W`
	b=4eZ2cXe#,thgoe<&**]mirSI>r',1W<%shZT;2UO"&oa';7lYHe'3Z#$]MAVJ5"8*l&A8#1p)esp
	cf]r2C.1]c#q2Y.3"?qKJPrMX9kfF@NZC31&:V_(`=T`Sh@I[mk9/Jp2MeXEO\)7C/4*kk6s5,_6qF
	ThM2@=^*;9gd=i@GskHUlPgs3WVS@BoA?[hf^iph9?f%($sOs!=/6rAoG&,jST$s=X*T-WC3#9RJle
	uW:3/M5S-?SXoE?qWri)HIk*Ug!qjXZ[q?=NmJ^OQ[<&=bP!E`@hd6$%B^ODgP5efq+hB^O6#.2VJ>
	.#._:TfXc2U&Hi+mRnZa^-)$SH8J2)U!*WT2n`Za/ZI`E0NK&*I9Jj[^ZHR#A@*cst+d(MqOI/#Ebu
	(1Pa-<7Gkj[2m:W[GE>j*uOfPtXFIabNY"i]D"&^SbJ`[e7*&f"Q8jf":2*3B@G<f?A"\!%[cAfrrg
	(&Raoa1?EZf\k]G<Ui]tN1*25CCL7ei3Z`[d'-`X\6-?%C0C?C"9;A8%c1=%LYO$8,L`0C0DiK!,Pu
	8D'^)2eMq$6U&43&;BLW7G&UH!Z!PiA*@cPIf`+V!EBJcHo\J`^VpDb-Sbs]CH!cL)"c[+edR&?<\`
	=.YT%LLT.)dTP(PYBTanLEe6i'qUh$"*BG_8ah$GZAn7?+Y87YLa/gfrQU#>(H\s4ZshOeu^/lV\=?
	$GrU*?,dqRE2W<u3E<Ye(3O/PKbpY-fNsZ_fA1>$5/6#<B7!70gn9,<bheL/k'<gD&kIqcLEL4k&IJ
	``3W2N8;poDDo<iZsn(+k-mm7(Mm+W;7;d+Hu1/q1oo\,u-sjpdWBUBeig&^HXU`a<Eg#=l"mnc@b7
	lA(,WO^"!$oq+E0Y,#k5rr(&K0L2D\N%&]kI&fPUFZ&FLlN>K)YZNI/Zt\!B::fElr'BqdaI88PA;h
	75DO#NR/r32Y3Mm!F/t</%8-)2B@5?bmhhK$]%OFgHj,ZEZa^g8ZWlsKB&[p5_ZEb+*)7Ic59K4"%*
	'&$b@=H<"7=icE:Vdoj5bmLO7#e_.f%Q/E?T"OZ[4TDOC;<[UMN#Lc"!T.ia=53Imc/441tK(D\&7<
	JJ`h;IEG[TQ)B0W8p?^Ic68S[]*/FIiHjG<(8h%tr1CbBa0O`"27=gNS)kfpVNXX0+7/NDDQm*7'n#
	O2MI%MJImH7Fp=[QUi2$#JJ&It3h#(1RX.,9A;ea:-KmQ75?UaV822Ob.FUChkHllh<B[(!LljBs*p
	<AVW[.>?/_6rR"t]O%f,p;mG+JM6_f@i@KN1<,%Olur$<i6T9p/)DL>`bB\pT(e)V;o&3M(K;\`&NG
	26BJ^W(6GZM.oEH?8IIW]ip3+'=.Cn'pF@)nSiPcU?,Sl:A0>6ujnTql.J,Xg^!r)E^LA6JGSpJ'k9
	he?^gF!XK"h&b>5^<tUQ3C-9UYUc$GJ6gM[:oVk.0^1:J)Cn.G6ZH7afan:AL?GHh`9n!p!Gh/hOqo
	gY%H3mYcFf4*66$S.gQ4CFuu:Frct6ilN$utZPf5kD^HNd#9=g*lM/IVlukJ_H@</\SX,Rr[^NUN)5
	]p7%jk\C774G_ZO]8NWQ'l9B#^?PaXFsmq`Z8gkPA"gS-m$ha(SJQ`_0Zido5`S53-+g+XKR4:9V5:
	A1/:)dEp[tdt7f3(1@"2kqVA^k2rDP^7KFhFWiCk%tQtGUK+:^S"%7c4F!HY$EV_@d+-[30Y_.KibX
	cDQN>bY\i!l'&7lI1*ZsgLIR%nQD5siXs&f4/!J"Oi[>9*[DX>++6Xn<.1#gu:-[2hc>Z5_K$6Yu]L
	S,J\9fajX/Qu@jN'S.HGW[$H='$pCbKnMThS"7B!7]TNZMsiPeCW<9io8r0k8l[+LmcNMkR8.:9"ZK
	cku,pF;[dr5#-ZhZ0pt<G!,aDm&@WlIYD8_$_q'/M7Flk9]XNLG4dTX'3Sj?MI+6Spr5(Qm_LW=0*2
	0#rCl6e[2FA1^N;8De#_IT,WiERG;GpDSP*1ET(GB7OZtXd]l)34rbEl_aBkqM%B:jU,r;?J[WCB3$
	mM)t$^c._*al%[\h%g5A9Znmi7hlIt!_%fAO]u;706^Dd733<<@I:lgD#0,;i&+\WKSIDk*$eC5.5a
	UQl&q2B&e&(a#"2<V5sYN2N`4!%W!F/s"ckh?=B&hGhiA3c2R(WXd[9Mt.>9$=0H,qNq'?[g"eJdT+
	/4gIal0m!%a>?[mZ^OA/"2?s_G&b"pMP/rI/skl[t=;=qN,&l$3,!Mo],ZL0eKFo[7t8ZSddssU'1k
	C(pmJKC4:gI9V"3ZB!W@jf</ZpLBC=8ob7c<K-T0pE?+n*57.`)-DZV9"]!UF@6r:-pg%<p&ATso<H
	lU5cr2%;dSclD;R#B8Rog3i5fKhqW,!Uq1aNk7mXA,<k,RiVYLd:0S2p*7I*m@nJGLu_o!Co$Bdken
	1U1u^9'5em0luL$(i^eZg$A=*]Y%Kls2fr(=nKk:)WG`F!!"i:%NV.!&0uCT#*"M\_-1TmJd"*.U1,
	H/Weh=S,92:;6"G#h.*nHL&Fh&>QB8hp:iV0OH!J(2)1iuid43@YLk&O,(%^V77n#kcLrXlkV$I2*8
	5E#O=]nlor/q5'"^YG[4%dr&)!DE\:]dMXE9tG+eTDcG2r`3N/5nC)MX68&gFkRkUjQ=^`,E3J().G
	s^ut<?&->0(NZV?sT\sdEAnPbsC_&[H\(e04n`#5t,n&]>9F8]7g\sn%(]#;51=C48Gk]-<Wc%O@E-
	<4L81u;8?We0L7J&Qc;)>+&iUMn*MC5$DP4\D=5aGsu$jI\6GYf-iiFD4nf1%rU+J??Y)p=O!RulY`
	0ZJeG9nbOd=$M!6h/.&*B'\s.\\Fi;o:*!HNB/oI[G8"UI-+BY*h$Ai.>GKTOftjf`:E$5iG^c<St:
	t;7uuZZWDd<uM^.G)_-:)HY]T,-R*Fc5nOj(Fq;D/!$i`KSRt$=Po3PrAUuAd)X^Ni3cfgoLL?$p']
	A8%fTE1,"s8>s.UTUb[<)lr7l#\+23u]+sCg_.iHZX_S6F>0aB4iU!=tNdW=uBaE$`FW(&rNf8^I8q
	#g]jD"O"RR;^OCYYF8Fm_mNVD8_o$QVRHdUn*^i7%@'#8t9R`48rVH1tcC?oaGW]rWh0A(MB39(jn#
	1*_KkQM,5R>3ai#mWf+NCupOr^Q/?/[dq2W+0SWNCCbJNa+lp)_8;*K/UdTMP**&ohbj9M0"i=;h\"
	1mD8b$Sl\ImQ3m;]FkCoo6B5J(Wc1/b:t\)JC`:PeCE)(^L-ff0&k<8QqCeuXK2gWP6k#In\g6@f0k
	5UGEXGKpt\`;,n9Sj-F:"YT[W,?F*ud7#pE_sLPG!EEV[U0/$]L<@Ob^ErZRN#[^MK<fs6<rQ'FY9e
	O$$f?[7Q?hP2B"<iZrq3B8f/YDEI(X^;&]hIpB+pHBSQAmf"?L<O1!i?`!^OEDEmB3X<](r.L0+!YO
	DU#X,/KaV$X:!FE%N.E]!I03sBH=ZosR58fm>hHT.-Q-5#:%fC=YPGpn[p\(&hGK`0>H,3bI5RBLCY
	$#P;(=(H;dJ]a-<tTss1]`1*Ba.Hn9'a_JZj,g$@JCS;W-j\rria^HG38*=Kqi+!!#SZ:.26O@"J
	ASCII85End
end

// PNG: width= 90, height= 30
Picture pInfo
	ASCII85Begin
	M,6r;%14!\!!!!.8Ou6I!!!"&!!!!?#R18/!3BT8GQ7^D&TgHDFAm*iFE_/6AH5;7DfQssEc39jTBQ
	=U#t@KS5u_NKc'hjQ<7_k>^N6#'iu's#@iL6?EN#,SR%ORqWY?g_DQ6ZakX-9m6UF`Y7B5's^*$E%B
	u3<(a:i;5<Ct\*^a)hT'K%0QC]d[0jPV;N@+9cG@fjB`p38^oR<*NngmMP4QXaLkr6j/Tp8k\$ZiA^
	F[J/@;&;!fa/0Y"8EKlO!*92tV8I!509L_n[prdb[0DD]b^77\4Qh+<X22WSL=^Tpl!>%R?bOV1l`F
	.H/kj.Q0YHO!p0Z_o!(t!"2!0>1<o&\&oX/k93#9I:/\ol*"]HFk2"&^kI,Op^Po$LJ:qE[=Zdn*%1
	/%c)$r:,4%r)#UgVCL9-4fb:)2uc00,SCF2g"FKhP:)ciSp&'<om1=hD5F)*"ddDT8%a$Z"blrKB1V
	t"bqBnEcNrlWWRU];Q?b;\6c%+`!0V&SGg^%NRV$e":,J(6+Q,'.qs8WXZ?]HQd?\@;-q_mAJ,]9,i
	ondb3ItHg(Zjc?GW[$h>t<@#!7L*gWDnag1eK/1,*>Cr1P3*D[BX`3`d.+2D9NUG(..rXX^7$1"@82
	!1KE^Ub4(b^NWMsF;Ht6&&;b$b#dun1L:o\#UFM.3gNK`n[l7Cp+c[X/cDaa?O<b.!b=-Pr2.^?1Nd
	)e2#U:Q=,SCE:&8^%*L$dX(UQj\B/Bea\(..rm00Qspp'-Bu;ci@[g2Ab(7h`\ZA=S45.(4!_jMmH)
	qUNK^MN[#3[D>08n\uMdd,!N;U*ru@<Dd(/5&X;O&;3@n7RotRD4?;%HAGk=G+fW.>tiHTqLp0W7=4
	1t\u)fWAJng`QIdQ"8TJr%$paau+6@''?G#H(RO^<AUs^^G[]\cSB@c5aI;=JigY9^3e#1T9SXPucg
	hq>mG`bOMiSe2FC2.Jjp@_T>`piIOWDnc;k%;&=gQn1M0p,[l:OIIe[!*"QkrNrEAXG*0N(r07]$fZ
	h/$5=fV3Tb,=$\psV/^EJ)4IFB]PEW'\qbg(SsMlA:JXaHWi@OR/f1s5k:MsaPoMc&J--#d&-rCGg1
	@0&:")(CjpXC94`bia)`#WJ(G?agO/a)!%!Za'1b>,JjlN'!=]&V5U;CI@Et9%o2-h+N"!1EAB5`,M
	Th&'lHW;8P&FJlPBUVCZ77C(9D;1qiXUW&&O5KD=a,V0/D%4B*&."qC)Xk?1%Zs:M/7mre"!%<ET2<
	bOD<cB%HGLYk/]p$:.Z,bn[7sj`?B9ZXXV6Rq]_Pti2gd\J3f(i:R&5_pm4KmDXm$aS/B^J!/^)#uG
	%6sfYult1cH[_1nRTfUip]H>d<$0>4r9NH8sWQ9)djkQAg3E#:]C\]o'uTN1rJBf7mE:cKPfJ<US@o
	sfC=1##U)g+pYUIm80gMI'&gcc'97IQ?8%%Ad+-[#D;.]AGGtPU1e&m.iUpnuW^=]Xm<&%d+jRgmR6
	q<!"K4)c%%V>s6.boU<k:W9@PN6o+0)@'G&kQ@q=8),*BN8CpR@_H@2O[8@=!9Ifs"n;A,h79HFe;'
	<AQ<<*SW3\4hYn'7c+!LCK<HgOtdE6\7T^B_C4`os.\g?L1-<OUon"8QFD=fRPcBo,tYs-%!5e<il-
	gK-hM%Q-;cW@=dI0o(g+V`I[7Hll^gmF1C8U`9;n:SDf?'4kXX)YA6CN6o]r]qT!s1+^3pK)B6pt_B
	a+O@`IRg8=:@XkJL"[Wg"k-TK%RqsK*5:)MTX360]U/4Wi@77;Jt3uP7<CJ.#Pn:q"VM]0-o&(8.o9
	`MEo2(5'MS@J+Rq@q<5kKI!A\?`c`\j5Xs.C`^\u^];Gr<!]0NL(T`^;0>7#+XNrGfbj/DFR`<:aKO
	an5L'f'H$C6<N=ieH_Ns:8r/-F>E>*(o2.ET1%BpgNq9:F_:'kIT8!)),C3GlcmYHU;j&0aK<:WMel
	3Ze-Om%!i`\)#_:DlKDdZeWg@P_C[O5M'iUB8>_-2HE;O1>jM;$8=V+SNHPXHb;/UA2:]pC+19D\Bd
	qtPsUXEa5qKga#B2SZ=.SRp%A!RdqL(!Ea7bt3ql@F;Uj=M08??L+[=OW75>HDQ5.GO:69br-505tC
	KaJC@jCMg**JRJQascSIH0iWNK&pUTkRi35A[F<CY2`i#$#_f\:6RcLI9_:V"&,4[]HN!OfQlP*Qtb
	VGkuA?F_!6F<)ocgU#D#V(':e98CFiHpC[p2PjB,D#;1";i6n,<g%nVGOf<>lBjHXs8BA(fD;DdgE&
	_+N0,P*1$jPnaB'W+c:JFR2daE`AbT2\$"\Atc30k=3]2,.R>E*Nf"c^j@=F?-EhKuZgDlI9;bg[c+
	#@$`/2$kB@MhsTDp>G]B0oZ#`%fgeAhHcB?i5($LInM,P9MS?gJ,auQDYK=UG;=]pX[t0`Ddn+h)@5
	*f*'#BK+[7+e+25ad[WOTm!ShS%o^pU.1GgqQgF=j%Y7Q;ZTcp"RlDZ'E)=kG_qYSr#Wb]AY@*-(nJ
	s#A#q"YFMfsgRh]Kt<,gI6=12lg#`?;TLp_*KtthTY]\gR%W:!I8"sroVaPFBo;RFjF5*7K$9'/M"a
	&=8b8<:r],W]a;6"MF%U=g2!m3l-^kmCMU]X>\[CWf<8QErql0Iq<+A?>3\a$'Y&&M_Vt+amGf@imo
	bQW3d]\44-GFK,M+U?MapjQn$rZ2MO]A366&(1N))Y5K\G-`9XF4l;%/:LK#,8h*dQfYG3mlOSIcZr
	>bLn*pC6ZP>8Kg\bG_@CKr2I%"\bg,9T7gnab8=Dm!=-WrDiH(kdbct`7o4FNN0!X<E0c>,]?+,R:L
	D]PZ0,$>?`&92Jr:c#b4?2.q.C==rdOGT-GEe&/PNlY926R6do>OS3)p0O\R3Y8&I`m-S_GCD(TPUp
	#Oh0$f?=CMoA(S7gE=*>mMVCq0YVL.YYcK,Y=`@\X=h:G[ec2^3h=YF;C/g`2VT*c?qXpKj]]U?cVq
	fC?DNujYDHgQ#<&Y/Z3l"'p#PjIED$6^p\*"iPGcpqYD$G(gq`=S8``85)IVK,7k,W='%mZ6N^%W9s
	ZH4Ib4'RZ77*WgpE7az8OZBBY!QNJ
	ASCII85End
end

// ------------------- from UserProcLoader, but modified ---------------

// search recursively for ipf files and return list of files as textwave
function/wave GetProcsRecursive(int fast)
	
	int maxFolders = 1000, fullpath = 1
	int folderIndex, i
	string strFile = "", strFolder = ""
	Make/free/T/N=0 w_folders, w_allFiles
	
	w_folders = {SpecialDirPath("Igor Pro User Files",0,0,0) + "User Procedures:"} // search recursively starting in this folder

	// w_folders will grow as subfolders are added
	for (folderIndex=0;folderIndex<numpnts(w_folders);folderIndex+=1)
		// check files in folderIndexth folder from w_folders
		NewPath/O/Q/Z tempPathIXI, w_folders[folderIndex]
		
		if (fast) // don't worry about semicolons in filenames, or shortcuts ending in .ipf!
			// add list of ipf files in current folder to w_allFiles
			wave/T w = ListToTextWave(IndexedFile(tempPathIXI, -1, ".ipf"),";")
			if (fullpath)
				w = w_folders[folderIndex] + w
			endif
			TextWaveConcatenate(w_allFiles, w)
			// add list of folders in current folder to w_folders
			wave/T w = ListToTextWave(IndexedDir(tempPathIXI, -1, 1),";")
			w += ":"
			TextWaveConcatenate(w_folders, w)
			
			#ifdef WINDOWS
			// get a list of shortcuts
			wave/T w = ListToTextWave(IndexedFile(tempPathIXI, -1, ".lnk"),";")
			if (numpnts(w))
				w = ResolveAlias(w_folders[folderIndex] + w)
				Duplicate/free w w_f
				// keep shortcuts to files in w, shortcuts to folders in w_f
				if (fullpath == 0)
					w = ParseFilePath(0, w, ":", 1, 0)
				endif
				TextWaveStringMatch(w, "*.ipf")
				TextWaveConcatenate(w_allFiles, w)
				TextWaveStringMatch(w_f, "*:")
				TextWaveConcatenate(w_folders, w_f)
			endif
			#else // mac
			// get a list of file aliases
			wave/T w = ListToTextWave(IndexedFile(tempPathIXI, -1, "alis"),";")
			if (numpnts(w))
				w = ResolveAlias(w_folders[folderIndex] + w)
				if (fullpath == 0)
					w = ParseFilePath(0, w, ":", 1, 0)
				endif
				TextWaveStringMatch(w, "*.ipf")
				TextWaveConcatenate(w_allFiles, w)
			endif
			// get a list of folder aliases
			wave/T w = ListToTextWave(IndexedFile(tempPathIXI, -1, "fdrp"),";")
			if (numpnts(w))
				w = ResolveAlias(w_folders[folderIndex] + w)
				TextWaveZapString(w, "")
				TextWaveConcatenate(w_folders, w)
			endif
			#endif
			continue // next folder
		endif
				
		// the slow way: loop through files in folder
		for (i=0;1;i+=1)
			strFile = IndexedFile(tempPathIXI, i, "????")
			if (strlen(strFile) == 0)
				break
			endif
			GetFileFolderInfo/Q/Z w_folders[folderIndex] + strFile
			if (V_isAliasShortcut)
				strFile = ResolveAlias(w_folders[folderIndex] + strFile)
				if (stringmatch(strFile,"*:"))
					w_folders[numpnts(w_folders)] = {strFile}
				endif
				if (stringmatch(strFile,"*.ipf"))
					if (fullpath == 0)
						strFile = ParseFilePath(0, strFile, ":", 1, 0)
					endif
					w_allFiles[numpnts(w_allFiles)] = {strFile}
				endif
				continue // next file
			endif
			
			if (stringmatch(strFile,"*.ipf"))
				if (fullpath)
					strFile = w_folders[folderIndex] + strFile
				endif
				w_allFiles[numpnts(w_allFiles)] = {strFile}
				continue
			endif
		endfor // next file
		
		// add subfolders in current folder
		for (i=0;1;i+=1)
			strFolder = IndexedDir(tempPathIXI, i, 1)
			if (strlen(strFolder) == 0)
				break
			endif
			w_folders[numpnts(w_folders)] = {strFolder + ":"}
		endfor // next subfolder
		if (folderIndex == maxFolders)
			Print "Warning: GetProcsRecursive exceeding max iterations"
			break
		endif
	endfor // next folder
	
	KillPath/Z tempPathIXI
	return w_allFiles
end

// appends w2 to w
function TextWaveConcatenate(wave/T w, wave/T w2)
	int oldPnts = numpnts(w), newPnts = numpnts(w2)
	if (newPnts)
		Redimension/N=(oldPnts+newPnts), w
		w[oldPnts,] = w2[p-oldPnts]
	endif
end

// Recursively resolve shortcuts to files/directories
// returns full path or an empty string if the file does not exist or the
// shortcut points to a non existing file/folder
function/S ResolveAlias(string strPath) // full path to file, folder or alias
	GetFileFolderInfo/Q/Z RemoveEnding(strPath, ":")
	if (V_isAliasShortcut)
		return ResolveAlias(S_aliasPath)
	endif
	if (v_flag == 0)
		return strPath // path to a file or folder
	endif
	return ""
end

// keep only points of textwave matching strMatch
function TextWaveStringMatch(wave/T w, string strMatch)
	if (numpnts(w))
		w = SelectString(stringmatch(w,strMatch),"",w)
		TextWaveZapString(w, "")
	endif
end

// Remove points from textwave w (and optionally the corresponding points
// of waves in wave reference wave w_zapRefs) that match matchStr. Does
// not check numbers of points in w_zapRefs waves. Wildcards okay.
function TextWaveZapString(wave/T w, string matchStr, [wave/Z/WAVE w_zapRefs])
	int i, j
	for (i=numpnts(w)-1;i>=0;i-=1)
		if (stringmatch(w[i],matchStr))
			DeletePoints i, 1, w
			if (WaveExists(w_zapRefs))
				for (j=0;j<numpnts(w_zapRefs);j+=1)
					DeletePoints i, 1, w_zapRefs[j]
				endfor
			endif
		endif
	endfor
	return numpnts(w)
end

function TextWaveZapList(wave/T w, string matchList, [wave/Z/WAVE w_zapRefs])
	Make/free/N=(ItemsInList(matchList)) index
	index = TextWaveZapString(w, StringFromList(p,matchList), w_zapRefs=w_zapRefs)
	return index[numpnts(index)-1]
end

// ------------------ end of stuff from UserProcLoader ------------------

// cleans up version number in log
// when project has been updated outside of updater
function LogSyncWithProjectFile(string projectID)
	string fileList = LogGetFileList(projectID)
	string filePath = StringFromList(0, ListMatch(fileList, "*.ipf"))
	if (!isFile(filePath))
		return -1
	endif
	variable fileVersion = GetProcVersion(filePath)
	string strLine = LogGetProject(projectID)
	int itemNum = 2
	variable logVersion = str2num(StringFromList(itemNum, strLine))
	
	if (fileVersion != logVersion)
		strLine = RemoveListItem(itemNum, strLine)
		strLine = AddListItem(num2str(fileVersion), strLine, ";", itemNum)
		LogReplaceProject(projectID, strLine)
		CacheClearUpdates(projectID=projectID)
		
		#ifdef debug
		string cmd = ""
		sprintf cmd, "Resynching log for %s. Log version (%g) was reset to match file version (%g).", StringFromList(1, strLine), logVersion, fileVersion
		Print cmd
		#endif
		return 1
	endif
	
	return 0
end

function WriteToHistory(string str, STRUCT PackagePrefs &prefs, int alert)
	if (strlen(str)==0)
		return 0
	endif
	
	int forced = 0
	#ifdef debug
	forced = 1
	#endif
	
	str = RemoveEnding(str, "\r")
	if (forced || (prefs.options & 2)) // copy to experiment history
		Print str
	endif
	if (alert)
		DoAlert 0, str
	endif
	string filePath = GetInstallerFilePath(ksHistoryFile)
	variable refnum
	Open/A/Z refnum as filePath
	if (V_flag)
		return 0
	endif
	
	// convert 'narrow no-break space' character in Apple Sonoma's system time to an ASCII space
	string strTime = ReplaceString(num2char(0x202F), time(), " ")
	
	fprintf refnum, "%s %s %s\r\n", date(), strTime, str
	Close refnum
		
	if (WinType("HistoryPanel") == 7)
		sprintf str, "%s %s %s\r\n", date(), strTime, str
		Notebook HistoryPanel#nbHistory selection={EndOfFile,EndOfFile}, text="•"+str
	endif
		
	return 1
end

// Utility function to help prepare project releases.
// Potentially overwrites archive on desktop.
// Text fields for version (string) and release identifier are formatted
// following the old IgorExchange website enforced formatting style.
// They don't have to be entered this way.

// To add menu, either uncomment the #define statement, or (better) copy
// the menu definition into another procedure

//#define developer

#ifdef developer
menu "Misc"
	"Prepare Project Release", Updater#PrepareProjectRelease()
end
#endif

function PrepareProjectRelease()
	variable winIndex, moreFiles
	int helpFileAlert = 0
	string proclist = WinList("*",";","WIN:128,INDEPENDENTMODULE:1")
	Prompt winIndex, "Select procedure", Popup, proclist
//	string msg = "Do you need to select additional files, for instance a help file? "
	string msg = "Note that #included files from the user procedure folder will be automatically added to archive.  "
	msg += "Only filename includes in the selected procedure file are supported (no paths!).    \r\r"
	msg += "Do you need to select additional files, for instance a help file? "
	Prompt moreFiles, msg, Popup, "no;yes;"
	DoPrompt "Prepare Project Release", winIndex, moreFiles
	if (V_Flag)
		return 0
	endif
	string procedure = StringFromList(winIndex-1, proclist)
	
	GetWindow $procedure needupdate
	if (V_flag)
		DoAlert 0, "Please save procedure file before preparing release!"
		return 0
	endif
	string filePath   = GetProcWinFilePath(procedure)
	string projectID  = GetProjectIDString(filePath)
	string shortTitle = GetShortTitle(filePath)
	variable version  = GetProcVersion(filePath)
	variable IgorVer  = GetPragmaVariable("IgorVersion",filePath)
	string extraFiles = "", includes = ""
	
	if (strlen(shortTitle) == 0)
		shortTitle = ParseFilePath(3, filePath, ":", 0, 0)
	endif
	
	if (moreFiles!=2 && cmpstr(projectID,"8197")==0)
		DoAlert 0, "You forgot the install script. Doh!"
		return 0
	endif
		
	if (moreFiles == 2)
		int refnum
		NewPath/O/Q/Z TempInstallPath ParseFilePath(1, filePath, ":", 1, 0)
		Open/R/D/M="Select Additional Files"/MULT=1/P=TempInstallPath/F="All Files:.*;" refnum
		KillPath/Z TempInstallPath
		S_fileName = ReplaceString("\r", S_fileName, ";")
		extraFiles = RemoveFromList(filePath, S_fileName)
		if (strsearch(extraFiles, ".ihf;", 0, 2) > -1)
			helpFileAlert = 1
		endif
	endif
	
	int i, j, k
	string file
	if (helpFileAlert)
		DoAlert 1, "Do you want to reset window positions for ihf files?\rEach file will be opened and repositioned."
		if (v_flag == 1)
			for (i=ItemsInList(extraFiles)-1;i>=0;i--)
				file = StringFromList(i, extraFiles)
				if (stringmatch(file, "*.ihf") == 0)
					continue
				endif
				OpenHelp/INT=0/Z/V=1 file
				DoIgorMenu "Control", "Move to Preferred Position"
				CloseHelp/FILE=file // save the new position
				if (V_alreadyOpen == 1)
					OpenHelp/INT=0/Z file
				endif
			endfor
			helpFileAlert = 0
		endif
	endif
		
	Make/free/T/N=0/O wFiles
	Grep/E="^#include\s*\"" filePath as wFiles
	if (numpnts(wFiles))
		wFiles = (wFiles)[8,Inf]
		wFiles = ReplaceString ("\"", wFiles, "")
		wFiles = TrimString(wFiles)
		wFiles += ".ipf"
		wFiles = GetProcWinFilePath(wFiles)
		Extract/O/T wFiles, wFiles, strlen(wFiles)>0
		if (numpnts(wFiles))
			wfprintf includes, "%s;", wFiles
			includes = RemoveFromList(extraFiles, includes)
			extraFiles += includes
		endif
	endif
	
	if (strlen(extraFiles))
		filePath += ";" + extraFiles
	endif
		
	printf "\r * Preparing project release for %s *\r", shortTitle
	
	
	// try to check for missing include statements
	string listOfIncludedWMprocs = WinList("*", ";", "INCLUDE:4")
	listOfIncludedWMprocs = CleanIncludesList(listOfIncludedWMprocs)
	
	string listOfFunctions = ""
	string WMProc = ""
	string theFile = ""
	string theFunction = ""
	int numAllIncludedProcs = ItemsInList(listOfIncludedWMprocs)
	int numFiles = ItemsInList(filePath)
	int numFunctions
	int includedInRelease
	
	for (i=0;i<numAllIncludedProcs;i++)
		WMProc = StringFromList(i, listOfIncludedWMprocs)
		includedInRelease = 0
		for (j=0;j<numFiles;j++)
			theFile = StringFromList(j, filePath)
			if (!stringmatch(theFile, "*.ipf"))
				continue
			endif
			Grep/Q/E="^#include\s*<\s*"+WMProc theFile
			if (v_value)
				includedInRelease = 1
				break
			endif
		endfor
		
		if (includedInRelease)
			continue
		endif
			
		// only affects procGlobal procedures, IM won't compile if #include is missing?
		listOfFunctions = FunctionList("*", ";", "KIND:18,WIN:"+ WMProc + ".ipf [procGlobal]")
		numFunctions = ItemsInList(listOfFunctions)
		
		for (j=0;j<numFiles;j++)
			theFile = StringFromList(j, filePath)
			if (!stringmatch(theFile, "*.ipf"))
				continue
			endif
			
			for (k=0;k<numFunctions;k++)
				theFunction = StringFromList(k,listOfFunctions)
				Grep/E=theFunction/Q theFile
				if (v_value)
					
					printf "*** Check %s for missing #include <%s>, found function %s() ***\r", ParseFilePath(0, theFile, ":", 1, 0), WMproc, theFunction
					
					break
				endif
			endfor
		endfor
	endfor

	string archive = ""
	// edit fileName format here
	sprintf archive, "%s%d%02d.zip" shortTitle, floor(version), 100*(version-floor(version))
		
	zipFiles(filePath, SpecialDirPath("Desktop", 0, 0, 0) + archive, verbose=0)
	Print "Files added to archive:"
	for (i=ItemsInList(filePath)-1;i>=0;i--)
		Print ParseFilePath(0, StringFromList(i, filePath), ":", 1, 0)
	endfor
	Print ""
	
	// print a warning if we find any development flag symbols defined in the package file[s]
	for (i=ItemsInList(filepath)-1;i>=0;i--)
		file = StringFromList(i, filepath)
		Grep/Q/E="^\s*?#define\s*debug" file
		if (v_value)
			printf "*** WARNING  debug is defined in %s ***\r", ParseFilePath(0, file, ":", 1, 0)
		endif
		Grep/Q/E="^\s*?#define\s*test" file
		if (v_value)
			printf "*** WARNING  test[ing] is defined in %s ***\r", ParseFilePath(0, file, ":", 1, 0)
		endif
		Grep/Q/E="^\s*?#define\s*(dev\b|developer\b)" file
		if (v_value)
			printf "*** WARNING  dev[eloper] is defined in %s ***\r", ParseFilePath(0, file, ":", 1, 0)
		endif
	endfor
	
	if (helpFileAlert)
		printf "*** WARNING  ihf files remember their screen position ***\r"
	endif
	
	// check that we have a version number
	if (numtype(version))
		DoAlert 1, "No version pragma found in procedure\r\rContinue?"
		if (v_flag == 2)
			return 0
		endif
	endif

	// The suggestions for release identifier and version string fields
	// are based on the format that was enforced on the old IgorExchange
	// web site. Edit as you please.
		
	printf "Version (String) Suggestion: IGOR.%0.2f.x-%0.2f\r", IgorVer, version
	Print "\"Version - Date\" fields should be cleared"
	printf "Version - Major: %g\r", floor(version)
	printf "Version - Patch: %02.0f\r", mod(version, 1)*100
	Print "\"Version - Extra\" changing this field will not trigger an update notification for users"
	printf "Release Identifier Suggestion: %s IGOR.%0.2f.x-%0.2f\r", shortTitle, IgorVer, version
	printf "Igor Version: %g (Check that this is correct, nothing to fill on release page)\r", IgorVer
	printf "Upload file from desktop: %s\r", archive
		
	// bring commandline to front
	DoWindow/H
	
	if (strlen(projectID))
		DoAlert 1, "Open project page in browser?"
		if (v_flag == 1)
			BrowseURL/Z "https://www.wavemetrics.com/node/" + projectID
		endif
	endif
	
end

function/S CleanIncludesList(string inList)
	int numItems = ItemsInList(inList)
	int i
	string strItem = "", outlist = ""
	for (i=0;i<numItems;i++)
		strItem = RemoveEnding(StringFromList(i, inList), ".ipf")
		if (FindListItem(strItem, outList) == -1)
			outlist = AddListItem(strItem, outlist)
		endif
	endfor
	return outlist
end

// for testing
function zipGUI()
	// get a list of files to zip
	variable refnum
	string fileFilters = "All Files:.*;"
	Open/D/R/F=fileFilters/MULT=1/M="Select files to zip" refnum
	if (strlen(S_fileName) == 0)
		return 0
	endif
	zipFiles(ReplaceString("\r", S_fileName, ";"), "")
end

// utility function, creates a zip archive
// all paths are junked, no subfolders are preserved.
// not tested much on windows
function zipFiles(string FilePathListStr, string zipPathStr, [int verbose])
	verbose = ParamIsDefault(verbose) ? 1 : verbose // choose whether to print output from executescripttext
	string msg = "", cmd = "", zipFileStr = ""
	int i, numfiles
	
	numfiles = ItemsInList(FilePathListStr)
	for (i=0;i<numfiles;i+=1)
		GetFileFolderInfo/Q/Z StringFromList(i, FilePathListStr)
		if (V_Flag || V_isFile==0)
			printf "Could not find %s\r", StringFromList(i, FilePathListStr)
			return 0
		endif
	endfor
	
	if (strlen(zipPathStr) == 0)
		zipPathStr = SpecialDirPath("Desktop",0,0,0)
		zipFileStr = "archive.zip"
		DoAlert 1, "Zip to Desktop:archive.zip?"
		if (v_flag == 2)
			return 0
		endif
	else
		if (cmpstr(zipFileStr[strlen(zipFileStr)-1], ":") == 0)
			zipFileStr = "archive.zip"
		else
			zipFileStr = ParseFilePath(0, zipPathStr, ":", 1, 0)
			zipPathStr = ParseFilePath(1, zipPathStr, ":", 1, 0)
		endif
		GetFileFolderInfo/Q/Z zipPathStr
		if (V_Flag || V_isFolder==0)
			sprintf msg, "Could not find zipPathStr folder\rCreate %s?", zipPathStr
			DoAlert 1, msg
			if (v_flag == 2)
				return 0
			endif
		endif
	endif
	
	// make sure zipPathStr folder exists - necessary for mac
	NewPath/C/O/Q acw_tmpPath, zipPathStr
	KillPath/Z acw_tmpPath
	
	#ifdef WINDOWS
	string strVersion = StringByKey("OSVERSION", IgorInfo(3))
	variable WinVersion = str2num(strVersion) // turns "10.1.2.3" into 10.1 and 6.23.111 into 6.2 (windows 8.0)
	if (WinVersion<6.3)
		Print "zipArchive requires Windows 10 or later"
		return 0
	endif

	zipPathStr = ParseFilePath(5, zipPathStr, "\\", 0, 0)
	cmd = "powershell.exe Compress-Archive -Force -LiteralPath "
	string strPath
	for (i=0;i<numFiles;i+=1)
		strPath = ParseFilePath(5, StringFromList(i, FilePathListStr), "\\", 0, 0)
		strPath = ReplaceString("'", strPath, "''")
		cmd += SelectString(i>0, "", ", ") + "'" + strPath + "'"
	endfor

	strPath = ReplaceString("'", zipPathStr + zipFileStr, "''")
	cmd += " -DestinationPath '" + strPath + "'"
	#else // Mac
	zipPathStr = ParseFilePath(5, zipPathStr, "/", 0, 0)

	sprintf cmd, "zip -j -r -X \\\"%s%s\\\"", zipPathStr, zipFileStr

	for (i=0;i<numfiles;i++)
		cmd += " \\\"" + ParseFilePath(5, StringFromList(i, FilePathListStr), "/", 0,0) + "\\\""
	endfor
	sprintf cmd, "do shell script \"%s\"", cmd
	#endif
	
	ExecuteScriptText/B/UNQ/Z cmd
	if (verbose)
		Print S_value // output from executescripttext
	endif
	
	return (v_flag == 0)
end

// For developers only. Files to be installed should be packaged in one
// folder together with the itx file created by this function.
function CreateInstallScript()
	
	string InstallLocation, FileList, FileName, script, msg
	int refnum, i, numfiles
	variable restart


	Open/R/D/M="Select files to be installed"/MULT=1/P=IgorUserFiles/F="All Files:.*;" refnum
	if (!strlen(S_fileName))
		return 0
	endif
	FileList = ReplaceString("\r", S_fileName, ";")
	numfiles = ItemsInList(FileList)
	
	Prompt InstallLocation, "Select install location", Popup, "User Procedures;Igor Procedures;"
	Prompt restart, "Prompt for restart", Popup, "No;Yes;"
	DoPrompt "Prepare Install Script", InstallLocation, restart
	if (V_Flag)
		return 0
	endif
	restart -= 1
	
	script = "IGOR\r"
	script += "X // standalone install script\r"
	script += "X KillVariables/Z V_install\r"
	script += "X Variable V_install = 0\r"
	script += "X KillStrings/Z S_install\r"
	script += "X DoAlert 1, \"Okay to install?\\r\\rFiles in the Igor Pro User Files folder may be deleted\\ror replaced during installation.\"\r"
	script += "X String S_install = SelectString(V_flag-1, S_path, \"?\")\r"
	for (i=0;i<numfiles;i++)
		FileName = ParseFilePath(0, StringFromList(i, FileList), ":", 1, 0)
		script += "X CopyFile/Z/O/D S_install + \"" + FileName + "\" as SpecialDirPath(\"Igor Pro User Files\", 0, 0, 0) + \"" + InstallLocation + ":\"\r"
		script += "X V_install = V_install || V_flag\r"
	endfor
	
	if (i > 1)
		msg = "Package files were saved in " + InstallLocation
	else
		msg = FileName + " saved in " + InstallLocation
	endif
	
	// a doAlert with empty string does not put up a dialog
	
	// failure alert
	script += "X DoAlert 0, SelectString(V_install!=0, \"\", \"Installation Failed\")\r"
	
	// success alert
	if (restart)
		msg += ".\\r\\rDo you want to quit to complete installation?"
		script += "X DoAlert 1, SelectString(V_install==0, \"\", \"" + msg + "\")\r"
		script += "X Execute/Q/Z SelectString(V_install==0 && V_flag==1, \"\", \"Quit\")\r"
	else
		script += "X DoAlert 0, SelectString(V_install==0, \"\", \"" + msg + "\")\r"
	endif
	
	// clean up (if user hasn't quit)
	script += "X KillVariables/Z V_install\r"
	script += "X KillStrings/Z S_install\r"
	
	FileName = SelectString(i==1, "InstallPackage.itx", "Install" + ParseFilePath(3, FileName, ":", 0, 0) + ".itx")
	Open/D/F="Igor text wave files (*.itx):.itx;"/M="Save install script" refnum as ParseFilePath(1, StringFromList(0, FileList), ":", 1, 0) + FileName
	if (strlen(S_fileName) == 0)
		return 0
	endif
	
	refnum = 0
	Open/Z refnum as S_fileName
	if (!refnum)
		Abort "Could not write file"
	endif
	
	fprintf refnum, "%s", script
	Close refnum
	
	DoAlert 0, "NOTE: Opening " + ParseFilePath(0, S_fileName, ":", 1, 0) + " in Igor will write the files to the install location!"
	NewPath/O/Q/Z TempInstallPath ParseFilePath(1, S_fileName, ":", 1, 0)
	PathInfo/SHOW TempInstallPath	// show file on desktop
	KillPath/Z TempInstallPath
end

function tic()
	variable/G tictoc = StartMSTimer
end
 
function toc()
	NVAR/Z tictoc
	variable ttTime = StopMSTimer(tictoc)
	printf "%g seconds\r", (ttTime/1e6)
	KillVariables/Z tictoc
	return ttTime
end
