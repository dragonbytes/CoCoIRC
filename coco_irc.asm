******************************************************************
* CoCoIRC - a simple IRC client for nitros-9 that uses drivewire
* 	   to communication with internet
* 	   Written by Todd Wallace (LordDragon)
******************************************************************

; TODO STUFF 
; ---------------------------------------------------------------------------------
; - add a command to list all of the current settings in your config file
; - add filtering ability to ONLY see channel messages from the active channel 
; - add CTCP PING function 
; - implement wordwrap on inputbar when it scrolls to next "page"
; - add support to play BELL when your nickname is said in chatlog by someone 
; - add CTCP VERSION requesting

; potential structure for channel allocation ram blocks 
; 0-1 = 16 bit offset to start of ring buffer 
; 2-3 = 16bit offset to current location of chatlog buffer 
; 4-255 = channel name / private nick name / etc in null terminated ASCII 

; Definitions/equates 
STDOUT      			EQU   1
STDIN 				EQU   0
H6309    			set   1

network_signal 		EQU 	32
keyboard_signal 		EQU 	33
connect_timeout_signal 	EQU 	$88
server_timeout_signal 	EQU 	$99

nickChanByteSize 		EQU 	32
max_nick_length 		EQU 	20
server_timeout_interval	EQU 	3600 		; 60 * 60 = 1 minute 
server_timeout_count 	EQU 	5 		; minutes 
cr_lf  			EQU 	$0D0A 

screen_width 			EQU 	80

; Color number defintions 
colorNormal 		EQU 	16 			; this is really color 0 since upper 4 bits 
							; are truncated, but lets me use NULL terminated
							; strings with color codes
							; (nice trick @Deek !)
colorTimestamp 	EQU 	1
colorChanName 	EQU 	2
colorQuit 		EQU 	3
colorYourNick 	EQU 	4
colorJoinPart 	EQU 	5
colorNotice 		EQU 	6
colorNickChan 	EQU 	7

;debug_mode 		EQU 	1
use_word_wrap 	EQU 	1

	include 	os9.d
	include 	rbf.d
	include 	scf.d 
	pragma 	cescapes

; Module header setup info 
	MOD 	MODULE_SIZE,moduleName,$11,$80,START_EXEC,data_size

START_MODULE
**************************************************************************************
; -----------------------------------------------------
; Variables 
		org 	0

uRegImage         	RMB 	2

chatlogPath  		RMB 	1
statusbarPath 	RMB 	1
inputbarPath 		RMB 	1
networkPath 		RMB 	1
nilPath 		RMB 	1
configFilePath 	RMB 	1
helpFilePath 		RMB 	1

; pointers 
inputBufferStart	RMB 	2
inputBufferPtr 	RMB 	2
inputBufferEnd 	RMB 	2
networkBufferPtr 	RMB 	2
serverBufferPtr 	RMB 	2
serverBufferEnd 	RMB 	2
serverBufferLength 	RMB 	2
netBufferBytesRem 	RMB 	1
keyInputCount 	RMB 	1
outputBufferPtr 	RMB 	2 

tempPtr 		RMB 	2
nickPtr 		RMB 	2
chanPtr 		RMB 	2
msgPtr 		RMB 	2
paramLength 		RMB 	1
serverCmdPtr 		RMB 	2
sourceHostmaskPtr 	RMB 	2
wrapSourcePtr 	RMB 	2
wrapDestPtr 		RMB 	2

cmdWordLength 	RMB 	1
cmdWordCounter 	RMB 	1
u8Value 		RMB 	1
u16Value 		RMB 	2
u32Value 		RMB 	4
epochYear 		RMB 	1
epochMonth 		RMB 	1
epochDay 		RMB 	1
epochHour 		RMB 	1
epochMinute 		RMB 	1
epochSecond 		RMB 	1
strNumeric 		RMB 	6
decDigitCounter 	RMB 	1
columnWidth 		RMB 	1
columnSpacing 	RMB 	1
columnCounter 	RMB 	1

; flags 
networkDataReady 	RMB 	1
keyboardDataReady 	RMB 	1
abortFlag		RMB 	1
connectTimeoutFlag 	RMB 	1
connectPendingFlag 	RMB 	1
disconnectedFlag 	RMB 	1
connectedStatus 	RMB 	1
idValidatedFlag 	RMB 	1
activeDestFlag 	RMB 	1
moreNamesPendingFlag RMB 	1
timeoutCounter	RMB 	1
namesRequestedFlag 	RMB 	1
nickServLoginPending	RMB  	1
oldConfigFlag  	RMB  	1

tempCounter 		RMB 	1
tempChar 		RMB 	1
tempWord 		RMB 	2

; this area contains block of settings written to config file 
; ---------------------------
; color theme values 
configFileVariables 	EQU 	.
backColorChatlog 	RMB 	1
backColorStatusbar 	RMB 	1
textColorNormal	RMB 	1
textColorTimestamp 	RMB 	1
textColorChanName 	RMB 	1
textColorQuit 	RMB 	1
textColorYourNick	RMB 	1
textColorJoinPart 	RMB 	1
textColorNickNotice 	RMB 	1
textColorNickChan	RMB 	1
; config file flags 
printMOTDflag 	RMB 	1
showTimestampFlag 	RMB 	1
showNamesOnJoinFlag 	RMB 	1
; ---------------------------
; Extended config file params 
nickServPassFlag  	RMB  	1 	; 0 = no password saved, and therefore, no auto-login possibile either
					; positive non-zero = password saved, but auto-login is disabled. 
					; negative non-zero = password saved and auto-login enabled
; ---------------------------

currentNickname	RMB 	32
currentUsername	RMB 	32
currentRealname 	RMB 	32

pdBuffer 		RMB 	32
sysDateTime 		RMB 	6
strTimestamp 		RMB 	18
palBuffer 		RMB 	16

; buffers/windows arrays etc 
inputBuffer 		RMB 	256
inputBufferSz 	EQU 	.-inputBuffer
networkBuffer 	RMB 	256
networkBufferSz 	EQU 	.-networkBuffer
serverBuffer 		RMB 	512 
serverBufferSz 	EQU 	.-serverBuffer
outputBuffer 		RMB 	1024
 IFDEF use_word_wrap
wordWrapBuffer 	RMB 	1024 
 ENDC 
; Structure of Destination Array: 
; First 2 bytes are 0 when that slot is empty/unused, otherwise, they are part of the
; channel/nick name.
destOffset 		RMB 	2
destArray 		RMB 	nickChanByteSize*16 	; enough for 16 channels/nicknames total
destArraySz 		EQU 	.-destArray		

; server variables 
serverAddress 	RMB 	64
serverPort 		RMB 	6
serverHostname	RMB 	128
serverYourNick 	RMB 	20
serverYourNickUpper 	RMB  	20
serverNetworkName 	RMB 	32
serverChanName 	RMB 	32
sourceNickname 	RMB 	max_nick_length 
destNickname 		RMB 	max_nick_length
destChanName 		RMB 	32
yourHostmask 		RMB 	128
strFixedOutput 	RMB 	64

strModeOperators 	RMB 	2

userQuitMessage 	RMB 	64
userVersionReply 	RMB 	64
userServerDefault 	RMB 	64
userNickservPass  	RMB  	32
userNickservPassSz  	EQU  	.-userNickservPass

; End of Variables
; -----------------------------------------------------
data_size         EQU   .

; -----------------------------------------------------
; Constants
moduleName   		FCS 	"cocoirc"
networkPathName	FCS 	"/N"
winPathName 		FCC 	"/W\r"
nilPathName		FCC 	"/NIL\r"
configFilePathName 	FCC 	"/DD/SYS/cocoirc.conf\r"
helpUsageFilename 	FCC 	"/DD/SYS/cocoirc.hlp\r"

charEraseLn 		FCB 	$03,$0D
charBell 		FCB 	C$BELL 
charsBSO 		FCB 	C$BSP,C$SPAC,C$BSP
charClear 		FCB 	C$FORM

strCoCoIRCversion 	FCN 	"1.0"
strIntro1 		FCN 	"Welcome to \x1b\x32\x05CoCoIRC v"
strIntro2 		FCN 	"\x1b\x32\x10, a native Internet Relay Chat Client\r\n\n"
strAuthor 		FCN 	"Written by \x1b\x32\x04Todd Wallace\x1b\x32\x10 for the Tandy Color Computer 3\r\n"
strWebsite 		FCN 	"For the latest updates on all my CoCo projects, go to \x1b\x32\x04https://tektodd.com\x1b\x32\x10\r\n\n"

strTitleGraphical 	FCN 	"CoCoIRC v"

strIntroHelp		FCN 	"Type /HELP for program instructions and a list of other commands you can use.\r\n\n"
strCocoIRC 		FCN 	" CoCoIRC - "
strStateDisconnected FCN 	"Disconnected"
strStateConnected 	FCN 	"Connected | "
strStatusActive 	FCN 	"Active Window: "
strStatusActiveNone 	FCN 	"No Active Windows"
; user variable defaults 
strVersionReply	FCN 	"CoCoIRC v1.0 / NitrOS-9 / Tandy Color Computer 3\r"
strExitQuitMsg 	FCN 	"CoCoIRC user has quit. Soarrry about that.\r"
strDefaultNickname 	FCN 	"SamGime\r"
strDefaultUsername 	FCN 	"cocouser\r" 	; THIS MUST BE LOWERCASE CUZ, REASONS?
strDefaultRealname 	FCN 	"Samuel Gimes\r"
strServerDefault 	FCN 	"irc.libera.chat:6667\r"
encryptionKey  	FCN  	"coco4eva"

dwSetChatlog 		FCB 	$1B,$20,2,0,0,80,22,0,1,1
dwSetStatusbar 	FCB 	$1B,$20,0,0,22,80,1,0,2
dwSetInputbar 	FCB 	$1B,$20,0,0,23,80,1,0,1

paletteDefs 	 	FCB 	0,8				; background colors main + statusbar 
			FCB 	63,56,48,9,25,18,36,52	; 8 foreground colors 

dwSelectCodes		FCB 	$1B,$21
setFontCodes 		FCB 	$1B,$3A,$C8,$42

; constats for epoch adder routine 
epochDigitCounters 	FQB 	1
			FQB 	10
			FQB 	100
			FQB 	1000
			FQB 	10000
			FQB 	100000
			FQB 	1000000
			FQB 	10000000
			FQB 	100000000
			FQB 	1000000000

epochConstDay 	FQB 	86400 			; seconds per day 
epochConstHour 	FQB 	3600
epochConst72offset 	FQB 	63072000 		; seconds between 1970 and 1972 (first leap year)
epochConstOffset 	FQB 	94694400 		; seconds between epoch begin (1970) and start of 1973 
epochMonthTable 	EQU 	* 
epochConstJan		FQB 	2678400 		; (31 * 86400)
epochConstFeb		FQB 	2419200 		; (28 * 86400)
epochConstMar		FQB 	2678400 		; (31 * 86400)
epochConstApr		FQB 	2592000 		; (30 * 86400)
epochConstMay		FQB 	2678400 		; (31 * 86400)
epochConstJun		FQB 	2592000 		; (30 * 86400)
epochConstJul		FQB 	2678400 		; (31 * 86400)
epochConstAug		FQB 	2678400 		; (31 * 86400)
epochConstSep		FQB 	2592000 		; (30 * 86400)
epochConstOct		FQB 	2678400 		; (31 * 86400)
epochConstNov		FQB 	2592000 		; (30 * 86400)
epochConstDec		FQB 	2678400 		; (31 * 86400)
			
strEpochJan		FCN 	"January"
strEpochFeb		FCN 	"February"
strEpochMar		FCN 	"March"
strEpochApr		FCN 	"April"
strEpochMay		FCN 	"May"
strEpochJun		FCN 	"June"
strEpochJul		FCN 	"July"
strEpochAug		FCN 	"August"
strEpochSep		FCN 	"September"
strEpochOct		FCN 	"October"
strEpochNov		FCN 	"November"
strEpochDec		FCN 	"December"

strEpochMonthPtrs 	FDB 	strEpochJan
			FDB 	strEpochFeb
			FDB 	strEpochMar
			FDB 	strEpochApr
			FDB 	strEpochMay
			FDB 	strEpochJun 
			FDB 	strEpochJul
			FDB 	strEpochAug
			FDB 	strEpochSep
			FDB 	strEpochOct
			FDB 	strEpochNov
			FDB 	strEpochDec 
; user command words 
userCmdWords 		EQU 	*
strSERVERkeyword	FCN 	"SERVER"
strCONNECTkeyword 	FCN  	"CONNECT"
strEXITkeyword	FCN 	"EXIT"
strQUITkeyword	FCN 	"QUIT"
strJOINkeyword	FCN 	"JOIN"
strPARTkeyword	FCN 	"PART"
strCYCLEkeyword	FCN 	"CYCLE"
strTOPICkeyword	FCN 	"TOPIC"
strNAMESkeyword	FCN 	"NAMES"
strMSGkeyword		FCN 	"MSG"
strMEkeyword		FCN 	"ME"
strACTIONkeyword	FCN 	"ACTION"
strNICKkeyword	FCN 	"NICK"
strQUERYkeyword	FCN 	"QUERY"
strWHOISkeyword	FCN 	"WHOIS"
strCLOSEkeyword	FCN 	"CLOSE"
strNOTICEkeyword	FCN 	"NOTICE"
strKICKkeyword	FCN 	"KICK"
strMODEkeyword	FCN 	"MODE"
strOPkeyword		FCN 	"OP"
strDEOPkeyword	FCN 	"DEOP"
strVOICEkeyword	FCN 	"VOICE"
strDEVOICEkeyword	FCN 	"DEVOICE"
strBANkeyword		FCN 	"BAN"
strUNBANkeyword	FCN 	"UNBAN"
strNICKSERVkeyword 	FCN 	"NICKSERV"
strNSkeyword 		FCN 	"NS" 			; alternate for NickServ
strRAWkeyword		FCN 	"RAW"
strSETkeyword		FCN 	"SET"
strSAVEkeyword	FCN 	"SAVE"
strLOADkeyword	FCN 	"LOAD"
strCLEARkeyword	FCN 	"CLEAR"
strHELPkeyword	FCN 	"HELP"
strABOUTkeyword	FCN 	"ABOUT"
strPREVkeyword 	FCN 	"PREV"
strNEXTkeyword	FCN 	"NEXT"
strEPOCHkeyword	FCN 	"EPOCH"
strINTROkeyword 	FCN 	"INTRO"
strCTCPkeyword 	FCN  	"CTCP"
			FCB 	$FF

userCmdWordPtrs	FDB 	COMMAND_SERVER 
			FDB  	COMMAND_SERVER
			FDB 	COMMAND_EXIT 
			FDB 	COMMAND_QUIT
			FDB 	COMMAND_JOIN
			FDB 	COMMAND_PART
			FDB 	COMMAND_CYCLE
			FDB 	COMMAND_TOPIC
			FDB 	COMMAND_NAMES
			FDB 	COMMAND_MSG
			FDB 	COMMAND_ACTION
			FDB 	COMMAND_ACTION
			FDB 	COMMAND_NICK
			FDB 	COMMAND_QUERY
			FDB 	COMMAND_WHOIS 
			FDB 	COMMAND_CLOSE
			FDB 	COMMAND_NOTICE
			FDB 	COMMAND_KICK
			FDB 	COMMAND_MODE
			FDB 	COMMAND_OP
			FDB 	COMMAND_DEOP 
			FDB 	COMMAND_VOICE
			FDB 	COMMAND_DEVOICE
			FDB 	COMMAND_BAN
			FDB 	COMMAND_UNBAN
			FDB 	COMMAND_NICKSERV
			FDB 	COMMAND_NICKSERV
			FDB 	COMMAND_RAW
			FDB 	COMMAND_SET 
			FDB 	COMMAND_SAVE
			FDB 	COMMAND_LOAD  
			FDB 	COMMAND_CLEAR 
			FDB 	COMMAND_HELP 
			FDB 	COMMAND_ABOUT
			FDB 	COMMAND_PREV_DESTINATION
			FDB 	COMMAND_NEXT_DESTINATION
			FDB 	COMMAND_EPOCH
			FDB 	COMMAND_INTRO
			FDB  	COMMAND_CTCP

dwConnected 			FCC 	"CONNECTED\r\n"
dwConnectedSize 		EQU 	*-dwConnected
noCarrier 			FCC 	"NO CARRIER\r\n"
noCarrierSize 		EQU 	*-noCarrier 
strQuitChangingServer 	FCN 	"QUIT :Changing servers...\r\n"
strCycleChanMsg 		FCN 	" :Cycling...\r\n"
; keywords and other parameter constants 
strNetworkKeyword 		FCN 	"NETWORK="
strPRIVMSGkeyword 		FCN 	"PRIVMSG"
strPINGkeyword 		FCN 	"PING"
strVERSIONkeyword 		FCN 	"VERSION"
strREALNAMEkeyword 		FCN 	"REALNAME"
strUSERkeyword 		FCN 	"USER"
strQUITMSGkeyword 		FCN 	"QUITMSG"
strMOTDkeyword 		FCN 	"MOTD"
strCOLORkeyword 		FCN 	"COLOR"
strTEXTkeyword 		FCN 	"TEXT"
strTIMESTAMPkeyword 		FCN 	"TIMESTAMP"
strCHANNAMEkeyword 		FCN 	"CHANNAME"
strYOURNICKkeyword 		FCN 	"YOURNICK"
strCHANINFOkeyword 		FCN 	"CHANINFO"
strCHANNICKkeyword 		FCN 	"CHANNICK"
strBACKGROUNDkeyword 	FCN 	"BACKGROUND"
strSTATUSBARkeyword 		FCN 	"STATUSBAR"
strDEFAULTSkeyword 		FCN 	"DEFAULTS"
strTRUEkeyword 		FCN 	"TRUE"
strONkeyword 			FCN 	"ON"
strFALSEkeyword 		FCN 	"FALSE"
strOFFkeyword 		FCN 	"OFF"
strIDENTIFYkeyword  		FCN  	"IDENTIFY"
strPASSkeyword  		FCN  	"PASS"
strLOGINkeyword  		FCN  	"LOGIN"
strAUTOLOGINkeyword  	FCN  	"AUTOLOGIN"
strIRCserverConnect		FCN 	"ATD "
strIRCserverQuit 		FCN 	"QUIT "
strIRCserverPart 		FCN 	"PART "
strIRCserverJoin 		FCN 	"JOIN "
strIRCserverMsg 		FCN 	"PRIVMSG "
strIRCserverNotice 		FCN 	"NOTICE "
strIRCserverNick 		FCN 	"NICK "
strIRCserverUser 		FCN 	"USER "
strIRCserverAction 		FCN 	"ACTION "
strIRCserverWhois 		FCN 	"WHOIS "
strIRCserverKick 		FCN 	"KICK "
strIRCserverMode 		FCN 	"MODE "
strIRCserverTopic 		FCN 	"TOPIC "
strIRCserverNames 		FCN 	"NAMES "

strTimestampTemplate 	FCB 	$1B,$32,colorTimestamp
				FCC 	"[  :  :  ] "
				FCB 	$1B,$32,colorNormal
strTimestampTemplateSz 	EQU 	*-strTimestampTemplate
				FCB 	$00 	; NULL for string-copying routines 
strUserMsgTrying 		FCN 	"-- Trying IRC server "
strUserMsgTryingPort 	FCN 	" port "
strUserMsgDefaultServer 	FCN 	"-- Using your saved server address or the default if not set\r\n"
strUserMsgConnected 		FCN 	"-- Connected. Logging in...\r\n"
strUserMsgDisconnected 	FCN 	"-- Disconnected from IRC server\r\n"
strUserMsgChangingServer 	FCN 	"-- Disconnected to change server\r\n"
strUserMsgYouJoined 		FCN 	"You have joined channel "
strUserMsgHasJoined 		FCN 	" has joined channel "
strUserMsgYouParted 		FCN 	"You have left channel "
strUserMsgHasParted 		FCN 	" has left channel "
strUserMsgTopic 		FCN 	"Topic for "
strUserMsgTopicSetBy 	FCN 	" set by "
strUserMsgTopicNotSet 	FCN 	"Topic not set for channel "
strUserMsgNames 		FCN 	"Current users on channel "
strUserMsgNamesEnd 		FCN 	"End of user list"
strUserMsgQuit 		FCN 	" has quit IRC "
strUserMsgMOTDsuppress 	FCN 	"-- Ignoring MOTD messages... "
strUserMsgMOTDsuppressed 	FCN 	"Done!\r\n"
strUserMsgYourNick 		FCN 	"Your nickname is "
strUserMsgYourNewNick 	FCN 	"Your nickname is now "
strUserMsgNickChanged 	FCN 	" changed their nickname to "
strUserMsgSetsMode 		FCN 	" sets mode "
strUserMsgOnChannel 		FCN 	" on channel "
strUserMsgUserModeChg 	FCN 	"* You set usermode "
strUserMsgVersionRequested 	FCN 	"* Received a CTCP VERSION request from "
strUserMsgVersionSent 	FCN 	"* Sent CTCP VERSION reply: "
strUserMsgCTCPSentRequest1 	FCN  	"* Sent CTCP "
strUserMsgCTCPSentRequest2 	FCN  	" request to "
strUserMsgYouKicked 		FCN 	"* You have been kicked from "
strUserMsgWasKicked 		FCN 	" was kicked from "
strUserMsgKickedBy		FCN 	" by "
strUserMsgWhoisIdle 		FCN 	"Idle "
strUserMsgWhoisDays 		FCN 	" days "
strUserMsgWhoisHours 	FCN 	" hours "
strUserMsgWhoisMins 		FCN 	" minutes "
strUserMsgWhoisSecs 		FCN 	" seconds"
strUserMsgWhoisSignon 	FCN 	"Signed on "
strUserMsgNickServCustom 	FCN 	"* You sent NICKSERV command: "
strUserMsgNickServIDsent 	FCN  	"* Sent NickServ identify request\r\n"

strMsgTryingConfigFile 	FCN 	"Trying to load configuration from file "
strMsgConfigFileLoaded 	FCN 	"Config loaded successfully.\r\n\n"
strMsgNoConfigFile 		FCN 	"Config file could be not found or is inaccessible.\r\n\n"
strMsgStartupNoConfigFile 	FCN 	"Config file not found or inaccessible.\r\n\n\x1b\x32\x04Default\x1b\x32\x10 settings will be used for this session. If this is your first time using CoCoIRC or IRC in general, type \x1b\x32\x05/INTRO\x1b\x32\x10 for some tips on how to get started or \x1b\x32\x05/HELP\x1b\x32\x10 to view the complete list of available commands and other program instructions.\r\n\n"
strMsgConfigSaving 		FCN 	"Saving configuration to file "
strMsgConfigDots 		FCN 	"...\r\n"
strMsgConfigOldVersion  	FCB  	$1B,$32,colorNotice
				FCC  	"Warning: "
				FCB  	$1B,$32,colorNormal
				FCC 	"Your config file is from a older version of CoCoIRC. While it will\r\n"
				FCC  	"still work just fine, the next time you use /SAVE to update your config file,\r\n"
				FCN 	"it will be overwritten with the new version format.\r\n\n"

strIntro			FCN 	"\x1b\x32\x06-=\x1b\x32\x07 Introduction \x1b\x32\x06=-\x1b\x32\x10\r\n\nOh hai thar! To get started chatting with CoCoIRC, you can use the command \x1b\x32\x05/SERVER <address>[:port]\x1b\x32\x10 to connect to an IRC network. A list of popular networks and their address info can be found at \x1b\x32\x04http://irchelp.org/networks/\x1b\x32\x10. If you don't specify a port number, the default of 6667 will be used.\r\n\nIf you would like to chat with other CoCo users on IRC, I would recommend connecting to \x1b\x32\x06irc.libera.chat\x1b\x32\x10 and joining us in the \x1b\x32\x02#coco_chat\x1b\x32\x10 channel by using the command \x1b\x32\x05/JOIN \x1b\x32\x02#coco_chat\x1b\x32\x10. Have fun and long live the CoCo!\r\n\n"

strMsgDefaultsSaved 		FCN 	"Configuration saved.\r\n\n"
strMsgNewDefaultNextConnect	FCN 	"-- You must (re)connect to server for change to take effect"
strMsgNewDefaultNick 	FCN 	"-- New default for your NICKNAME: "
strMsgNewDefaultRealname 	FCN 	"-- New default for your REAL NAME: "
strMsgNewDefaultUsername 	FCN 	"-- New default for your USERNAME: "
strMsgNewDefaultQuitMsg 	FCN 	"-- New default for your QUIT MESSAGE: "
strMsgNewDefaultCTCPver 	FCN 	"-- New default for your CTCP VERSION REPLY: "
strMsgNewDefaultServer 	FCN 	"-- New default for your IRC SERVER: "
strMsgNewDefaultNickserv 	FCN 	"-- New default for your NICKSERV PASSWORD: "
strMsgNewDefaultColor 	FCN 	"-- New default color for "		
strMsgColorResetDefaults 	FCN 	"-- Color palette has been reset to default values\r\n"
strMsgDefaultChanInfo 	FCN 	"CHANNEL INFORMATION: "
strMsgDefaultChatlogText 	FCN 	"CHATLOG TEXT: "
strMsgDefaultBackground 	FCN 	"BACKGROUND: "
strMsgDefaultNotice 		FCN 	"NOTICES: "
strMsgDefaultQuit 		FCN 	"QUIT MESSAGES: "
strMsgDefaultChatNicks 	FCN 	"CHANNEL NICKNAMES: "
strMsgDefaultYourNick 	FCN 	"YOUR NICKNAME: "
strMsgDefaultStatusbar 	FCN 	"STATUS BAR: "
strMsgDefaultChanName 	FCN 	"CHANNEL NAMES: "
strMsgDefaultTimestamp 	FCN 	"TIMESTAMP: "
strMsgTimestampEnabled 	FCN 	"-- Timestamps are now ENABLED\r\n"
strMsgTimestampDisabled 	FCN 	"-- Timestamps are now DISABLED\r\n"
strMsgMOTDenabled 		FCN 	"-- Server MOTD messages are now ENABLED\r\n"
strMsgMOTDdisabled 		FCN 	"-- Server MOTD messages are now DISABLED\r\n"
strMsgNamesOnJoinEnabled 	FCN 	"-- Display of nicknames when joining channels is now ENABLED\r\n"
strMsgNamesOnJoinDisabled 	FCN 	"-- Display of nicknames when joining channels is now DISABLED\r\n"
strMsgNickServLoginEnabled 	FCN  	"-- NickServ auto-login is now ENABLED\r\n"
strMsgNickServLoginDisabled FCN  	"-- NickServ auto-login is now DISABLED\r\n"
; pointers for the color variable labels 
colorNamePtr 			FDB 	strMsgDefaultBackground
				FDB 	strMsgDefaultStatusbar
				FDB 	strMsgDefaultChatlogText
				FDB 	strMsgDefaultTimestamp
				FDB 	strMsgDefaultChanName
				FDB 	strMsgDefaultQuit
				FDB 	strMsgDefaultYourNick
				FDB 	strMsgDefaultChanInfo
				FDB 	strMsgDefaultNotice
				FDB 	strMsgDefaultChatNicks
; errors 
strErrorInvalidCmd 		FCN 	"-- Invalid command. Use /HELP to see a list of available commands.\r\n"
strErrorVRNmodule 		FCN 	"-- Couldn't load VRN /NIL module. Timeout timers will not function\r\n"
strErrorIRCtimeout 		FCN 	"-- Connection attempt has timed out. Aborting\r\n"
strErrorPingTimeout 		FCN 	"-- Connection with IRC server has timed out (300 seconds). Aborted\r\n"
strDisconnectedMsg 		FCN 	"-- Disconnected\r\n"
strErrorDWPath1 		FCN 	"-- Could not open path to /N device descriptor. This is\r\n"
strErrorDWPath2 		FCN 	"required for internet connectivity. Is DriveWire installed?\r\n"
strErrorReading 		FCC 	"-- Error reading bytes from DriveWire server\r"
strErrorWritingConfig 	FCN 	"Error writing to config file. Could not save settings.\r\n"
strErrorDeletingConfig 	FCN 	"Error deleting old config file. Could not save settings.\r\n"
strErrorHelpFile 		FCN 	"-- Could not open or access the help file at /DD/SYS/cocoirc.hlp\r\n"
strErrorHelpNotFound1 	FCN 	"-- No help info found on that command. Type /HELP to see a complete\r\n"
strErrorHelpNotFound2 	FCN 	"   list of available commands.\r\n"

strErrorTime 			FCC 	"-- Error reading time\r\n"
strErrorTimeSz 		EQU 	*-strErrorTime 
strErrorJoinedAlready	FCN 	"-- You already joined that channel\r\n"
strErrorNotConnected 	FCN 	"-- You must be connected to an IRC server to use that command\r\n"
strErrorMsgInvalid 		FCN 	"-- Invalid parameter(s)\r\n"
strErrorMsgUseHelp 		FCN 	"-- Use /HELP for a list of commands their usage\r\n"
strErrorMsgMissingParam 	FCN 	"-- Missing parameter(s)\r\n"
strErrorMsgNoActiveWin 	FCN 	"-- No active window to use\r\n"
strErrorMsgDestListFull 	FCN 	"-- Window list is full. Please use /PART or /CLOSE and try again\r\n"
strErrorInvalidChanName	FCN 	"-- Invalid channel name\r\n"
strErrorNickInUse1		FCN 	"* Nickname "
strErrorNickInUse2 		FCN 	" is already in use.\r\n"
strErrorNickChooseAnother 	FCN 	"-- Choose another using /NICK <nickname>\r\n"
strErrorNoSuchNick 		FCN 	"* No such nickname "
strErrorNoSuchChannel 	FCN 	"* No such channel "
strErrorNoOps 		FCN 	"* You are not an operator on channel "
strErrorNickInvalid 		FCN 	"-- Missing parameter. Syntax is /NICK <nickname>\r\n"
strErrorCloseDestNotFound 	FCN 	"-- Cannot find that window entry to close\r\n"
strErrorCloseMissingParam 	FCN 	"-- No active window to close or none specified\r\n"
strErrorNickServLogin   	FCN  	"-- Cannot set auto-login because no NickServ password has been set yet\r\n"
strErrorNickServNoPass  	FCN  	"-- Cannot login to NickServ because no password has been set\r\n"

; About section 
strAbout1 			FCB 	$1B,$32,colorJoinPart
				FCN 	"\r\nCoCoIRC v"
strAbout2 			FCB 	$1B,$32,colorNormal
				FCC 	" Written by "
				FCB 	$1B,$32,colorYourNick
				FCN 	"Todd Wallace\r\n\n"
strAboutDescription		FCB 	$1B,$32,colorNormal
				FCC 	"CoCoIRC was a labor of love of mine that has been several months in the\r\n"
				FCC 	"making. I actually first had the idea back in the 90s when I was in college.\r\n"
				FCC 	"I had seen terminal-based solutions for the CoCo that let you chat on IRC\r\n"
				FCC 	"using telnet, but I thought it would be so much cooler to have some kind of\r\n"
				FCC 	"native client similiar to mIRC on Windows. At the time, I lacked the skill to\r\n"
				FCC 	"write something like that and didn't have access to the modern hardware\r\n"
				FCC 	"luxuries we have now, but when I learned about DriveWire and it's virtual\r\n"
				FCC 	"terminal functionality, CoCoIRC was born! In the future, I do plan to support\r\n"
				FCC 	"other serial to TCP/IP solutions if they have working NitrOS-9 drivers.\r\n\n"
				FCC 	"I want to really thank the CoCo community for all their advice and support\r\n"
				FCC 	"in writing this program, without which this would NOT have been possible.\r\n\n"
				FCC 	"Special thanks goes out to "
				FCB 	$1B,$32,colorYourNick
				FCC 	"L. Curtis Boyle"
				FCB 	$1B,$32,colorNormal,',',C$SPAC,$1B,$32,colorYourNick
				FCC 	"William Astle"
				FCB 	$1B,$32,colorNormal
				FCC 	", and "
				FCB 	$1B,$32,colorYourNick
				FCC 	"Deek"
				FCB 	$1B,$32,colorNormal
				FCC 	". You guys\r\n"
				FCC 	"are always around to answer my questions or just chat. Thank you!\r\n\n"
strAboutDescriptionSz 	EQU 	*-strAboutDescription

; debug strings 
 IFDEF debug_mode
strJoinStart 			FCN 	"Join Started\r\n"
strJoinEnd 			FCN 	"Join Finished\r\n"

asciiHexList         	FCC  	"0123456789ABCDEF"
asciiHexPrefix      		FCB  	'$'
 ENDC
; -----------------------------------------------------

START_EXEC
**************************************************************************************
* Program code area 
* RULE #1 - USE U TO REFERENCE ANY CHANGEABLE VARIABLES IN THE DATA AREA.
* RULE #2 - USE PCR TO REFERENCE CONSTANTS SINCE THEY RESIDE WITH EXECUTABLE CODE.
* RULE #3 - NEVER USE JSR FOR CALLING SUBROUTINES. ALWAYS USE BSR OR LBSR INSTEAD.
**************************************************************************************

      	stu   	<uRegImage        ; save copy of data area pointer in U 

      	; init some variables 
      	ldd 	#0
      	std 	<serverBufferLength
      	sta 	<keyboardDataReady
      	sta 	<networkDataReady
      	sta 	<abortFlag
      	sta 	<connectTimeoutFlag
      	sta 	<connectPendingFlag
      	sta 	<disconnectedFlag
      	sta 	<connectedStatus
      	sta 	<idValidatedFlag
      	sta 	<activeDestFlag
      	sta 	<moreNamesPendingFlag
      	sta 	<printMOTDflag
      	sta 	serverYourNick,U 
      	sta 	serverHostname,U 
      	sta 	serverNetworkName,U 
      	std 	destOffset,U 
      	sta 	<namesRequestedFlag
      	sta  	<nickServPassFlag
      	sta  	<nickServLoginPending
      	ldd 	#$FFFF 
      	sta 	<networkPath
      	sta 	<nilPath 
      	sta 	<configFilePath
      	lda 	#1
      	sta 	<showTimestampFlag
      	sta 	<showNamesOnJoinFlag

      	lda 	#80
      	sta 	<columnCounter

      	lda 	#server_timeout_count
      	sta 	<timeoutCounter

      	leay 	networkBuffer,U 
      	sty 	<networkBufferPtr

      	leay 	serverBuffer,U 
      	sty 	<serverBufferPtr
      	leay 	serverBufferSz,Y 
      	sty 	<serverBufferEnd

      	leay 	inputBuffer,U 
      	sty 	<inputBufferStart
      	sty 	<inputBufferPtr
      	leay 	inputBufferSz-1,Y  	; always leave room for a CR at the end 
      	sty 	<inputBufferEnd

      	; setup timestamp delimitters/brackets/bordering spaces 
      	leay 	strTimestamp,U 
      	leax 	strTimestampTemplate,PCR
      	lbsr 	STRING_COPY_RAW

	; setup the channel/nickname destination array 
	lbsr 	DESTINATION_INITIALIZE_ARRAY

	; init the fixed width printing variables 
	lda 	#20
	sta 	<columnWidth
	lda 	#3
	sta 	<columnSpacing

      	; setup path to VRN driver for timer functionality like timeout timers  
 	lda 	#UPDAT.
 	clrb 
 	leax 	nilPathName,PCR 
 	os9 	I$Open 
 	bcc 	GOT_VRN_PATH
 	; tell user vrn is needed for the timeout timers to work 
 	leax 	strErrorVRNmodule,PCR
 	lbsr 	PRINT_INFO_ERROR_MESSAGE
 	lda 	#$FF 		; this makes sure bit 7 is set so we know there is no VRN 
GOT_VRN_PATH
 	sta 	<nilPath
       
     	; setup all the window paths 
      	lda 	#UPDAT.
      	clrb 
      	leax 	winPathName,PCR
      	os9 	I$Open 
      	sta 	<chatlogPath
      	ldy 	#10
      	leax 	dwSetChatlog,PCR 
      	os9 	I$Write 
      	; you must select the main window before doing anything else it seems 
      	lda 	<chatlogPath
      	leax 	dwSelectCodes,PCR 
      	ldy 	#2
     	os9 	I$Write 

     	; setup statusbar window path 
      	lda 	#UPDAT.
      	clrb 
      	leax 	winPathName,PCR
      	os9 	I$Open 
      	sta 	<statusbarPath
      	ldy 	#9
      	leax 	dwSetStatusbar,PCR 
      	os9 	I$Write

      	; setup input bar window path 
      	lda 	#UPDAT.
      	clrb 
      	leax 	winPathName,PCR
      	os9 	I$Open 
      	sta 	<inputbarPath
      	ldy 	#9
      	leax 	dwSetInputbar,PCR 
      	os9 	I$Write 

      	; start with default color palette 
      	lbsr 	INIT_COLOR_SETTINGS
      	lbsr 	WRITE_COLOR_CONFIG_TO_PALETTE

      	; turn off echo/linefeed for inputbar window so we can edit out backspace codes and CR etc 
       lda 	<inputbarPath
      	ldb 	#SS.Opt  
	leax 	pdBuffer,U 
	os9 	I$GetStt
	clr 	PD.EKO-PD.OPT,X 
	clr 	PD.ALF-PD.OPT,X 

	lda 	<inputbarPath
	ldb 	#SS.Opt 
	leax 	pdBuffer,U 
	os9 	I$SetStt 
    	; select inputbar 
	ldy 	#2 
	leax 	dwSelectCodes,PCR 
	os9 	I$Write

	; print initial status bar 
	lbsr 	STATUS_BAR_UPDATE

      	; setup the intercept stuff 
      	leax 	SIGNAL_HANDLER,PCR
      	os9 	F$Icpt
	; setup the signal for keyboard input 
	lda 	<inputbarPath
	ldb 	#SS.SSig
	ldx 	#keyboard_signal
	os9 	I$SetStt

	; print the intro information 
      	leax 	strIntro1,PCR 
    	lbsr 	PRINT_CHATLOG_NULL_STRING
    	leax 	strCoCoIRCversion,PCR 
    	lbsr 	PRINT_CHATLOG_NULL_STRING
    	leax 	strIntro2,PCR 
    	lbsr 	PRINT_CHATLOG_NULL_STRING
    	leax 	strAuthor,PCR 
    	lbsr 	PRINT_CHATLOG_NULL_STRING
    	leax 	strWebsite,PCR 
    	lbsr 	PRINT_CHATLOG_NULL_STRING
    ;	leax 	strIntroHelp,PCR 
    ;	lbsr 	PRINT_CHATLOG_NULL_STRING

  	;lbsr 	DRAW_INTRO_BOX

	; tell user you are trying to load config file and if exists, load them into their variables if exists.
	; otherwise, load defaults 
	leay 	outputBuffer,U 
	leax 	strMsgTryingConfigFile,PCR 
	lbsr 	STRING_COPY_RAW
	leax 	configFilePathName,PCR 
	lbsr 	STRING_COPY_CR
	leax 	strMsgConfigDots,PCR
	lbsr 	STRING_COPY_RAW
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

      	lbsr 	CONFIG_LOAD_FROM_FILE
      	bcs 	CONFIG_FILE_NONE_LOAD_DEFAULTS
      	; inform the user saved settings are successfully loaded 
      	leax 	strMsgConfigFileLoaded,PCR 
      	lbsr 	PRINT_CHATLOG_NULL_STRING

      	lda  	<oldConfigFlag
      	beq  	CONFIG_FILE_RECENT_VERSION
      	leax  	strMsgConfigOldVersion,PCR 
      	lbsr 	PRINT_CHATLOG_NULL_STRING
CONFIG_FILE_RECENT_VERSION
      	; display the normal /HELP notice since a config file exists and this is not a brand new user 
    	leax 	strIntroHelp,PCR 
    	lbsr 	PRINT_CHATLOG_NULL_STRING
      	; write the config's palette values to the window paths 
	lbsr 	WRITE_COLOR_CONFIG_TO_PALETTE    
      	bra 	CONFIG_FILE_DONE

CONFIG_FILE_NONE_LOAD_DEFAULTS
	; this could mean it's a new user so tell them about /INTRO and /HELP 
	leax 	strMsgStartupNoConfigFile,PCR
	lbsr 	PRINT_CHATLOG_WITH_WORD_WRAP
	; init internal settings variables such as nickname, username, realname with defaults 
	leax 	strDefaultNickname,PCR 
	leay 	currentNickname,U 
	lbsr 	STRING_COPY_RAW
	leax 	strDefaultUsername,PCR
	leay 	currentUsername,U 
	lbsr 	STRING_COPY_RAW
	leax 	strDefaultRealname,PCR
	leay 	currentRealname,U 
	lbsr 	STRING_COPY_RAW
	leax 	strVersionReply,PCR 
	leay 	userVersionReply,U 
	lbsr 	STRING_COPY_RAW
	leax 	strExitQuitMsg,PCR 
	leay 	userQuitMessage,U 
	lbsr 	STRING_COPY_RAW
	leax 	strServerDefault,PCR 
	leay 	userServerDefault,U 
	lbsr 	STRING_COPY_RAW
CONFIG_FILE_DONE


MAINLOOP
	ldb 	<abortFlag 
	lbne 	EXIT_ABORT
	; check to see if we suddenly lost connection to drivewire server 
	ldb 	<disconnectedFlag
	beq 	MAINLOOP_CHECK_CONNECTION_ATTEMPT_TIMEOUT
	; we have been disconnected either on purpose, or unexpecedly
	; disable any running timeout timers 
	lda 	<nilPath 
	bmi 	MAINLOOP_SKIP_DISABLE_VRN_TIMER
	ldb 	#SS.FClr  
	ldx 	#0
	ldy 	#0
	os9 	I$SetStt 
MAINLOOP_SKIP_DISABLE_VRN_TIMER 
	; let the user know what the situation is 
	leax 	strDisconnectedMsg,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbsr 	DRIVEWIRE_RESET 	; close the path, reset flags, variables, ptrs, etc 
	lbsr 	DESTINATION_INITIALIZE_ARRAY
	lbsr 	STATUS_BAR_UPDATE
	bra 	MAINLOOP

MAINLOOP_CHECK_CONNECTION_ATTEMPT_TIMEOUT
	; check to see if a connection attempt to irc server has timed out 
	ldb 	<connectTimeoutFlag
	beq 	MAINLOOP_CHECK_SERVER_TIMEOUT
	; connecting to IRC server has timed out. inform the user of the bad news  
	leax 	strErrorIRCtimeout,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbsr 	DRIVEWIRE_RESET 	; close the path, reset flags, variables, ptrs, etc 
	lbsr 	DESTINATION_INITIALIZE_ARRAY
	lbsr 	STATUS_BAR_UPDATE
	bra 	MAINLOOP

MAINLOOP_CHECK_SERVER_TIMEOUT
	; check to see if we have stopped receiving messages from the IRC server.
	ldb 	<timeoutCounter 
	bne 	MAINLOOP_CHECK_KEYBOARD
	; if here, we have not seen any network traffic from the IRC server in awhile. assume we 
	; have lost the connection somehow and abort.
	; first, disable signal timer
	lda 	<nilPath 
	ldb 	#SS.FClr  
	ldx 	#0
	ldy 	#0
	os9 	I$SetStt 
	; then reset timeout counter value
	lda 	#server_timeout_count
	sta 	<timeoutCounter 
	; let the user know 
	leax 	strErrorPingTimeout,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbsr 	DRIVEWIRE_RESET 	; close the path, reset flags, variables, ptrs, etc 
	lbsr 	DESTINATION_INITIALIZE_ARRAY
	lbsr 	STATUS_BAR_UPDATE
	bra 	MAINLOOP

MAINLOOP_CHECK_KEYBOARD
	ldb 	<keyboardDataReady
	lbeq 	MAINLOOP_CHECK_NETWORK

 	ldx 	<inputBufferPtr
 	lda 	<inputbarPath
 	ldb 	#SS.Ready 
 	os9 	I$GetStt
 	lbcs 	MAINLOOP_KEYBOARD_RESET_SIGNAL 	; something went wrong, just reset/ignore 
 	stb 	<keyInputCount
MAINLOOP_KEYBOARD_NEXT_READ
 	ldy 	#1
 	os9 	I$Read 
  	ldb 	,X 
 	; figure out what it is and what to do with it.
 	cmpb 	#C$CR 
 	lbeq 	MAINLOOP_KEYBOARD_CR
 	cmpb 	#C$BSP 
 	beq  	MAINLOOP_KEYBOARD_BACKSPACE
 	cmpb 	#$11 		; CTRL + Right Arrow 
 	beq 	MAINLOOP_KEYBOARD_NEXT_DEST
 	cmpb 	#$10 		; CTRL + Left Arrow 
 	beq 	MAINLOOP_KEYBOARD_PREV_DEST
 	cmpb 	#$20
 	blo 	MAINLOOP_KEYBOARD_DEC_COUNTER 	; skip special characters like esc codes
 	; if here, its a normal character 
 	cmpx 	<inputBufferEnd
 	lbhs 	MAINLOOP_KEYBOARD_PLAY_BELL  ; buffer is full, so ignore unless its a CR or BS 
 	; normal char, write to screen etc 
 	ldy 	#1
 	os9 	I$Write
 	dec 	<columnCounter
 	bne 	MAINLOOP_KEYBOARD_SKIP_COLUMN_RESET
 	ldb 	#screen_width
 	stb 	<columnCounter
MAINLOOP_KEYBOARD_SKIP_COLUMN_RESET
 	leax 	1,X 
MAINLOOP_KEYBOARD_DEC_COUNTER
	dec 	<keyInputCount
	bne 	MAINLOOP_KEYBOARD_NEXT_READ	
	stx 	<inputBufferPtr 		; save the inputbuffer pointer 
	lbra 	MAINLOOP_KEYBOARD_RESET_SIGNAL

MAINLOOP_KEYBOARD_NEXT_DEST
	lbsr 	COMMAND_NEXT_DESTINATION
	bra 	MAINLOOP_KEYBOARD_DEC_COUNTER

MAINLOOP_KEYBOARD_PREV_DEST
	lbsr 	COMMAND_PREV_DESTINATION
	bra 	MAINLOOP_KEYBOARD_DEC_COUNTER

MAINLOOP_KEYBOARD_BACKSPACE
 	cmpx 	<inputBufferStart
 	bls 	MAINLOOP_KEYBOARD_PLAY_BELL
  	; before we do anythig else, check to see if we are backspacing to a previous page off-screen
 	ldb 	<columnCounter
 	cmpb 	#screen_width
 	beq 	MAINLOOP_KEYBOARD_BACKSPACE_RESTORE_PREV_LINE
 	inc 	<columnCounter
 	; do a destructive backspace to screen 
 	pshs 	X 
 	leax 	charsBSO,PCR 
 	ldy 	#3
 	os9 	I$Write
 	puls 	X
 	leax 	-1,X 
 	bra 	MAINLOOP_KEYBOARD_DEC_COUNTER

MAINLOOP_KEYBOARD_BACKSPACE_RESTORE_PREV_LINE
	stx 	<tempPtr
	leax 	-screen_width,X 
	ldy 	#screen_width-1
 	os9 	I$Write 
 	ldx 	<tempPtr 
  	leax 	-1,X 
  	ldb 	#1
  	stb 	<columnCounter
 	bra 	MAINLOOP_KEYBOARD_DEC_COUNTER

MAINLOOP_KEYBOARD_PLAY_BELL
	pshs 	X
	; play the BELL noise to let them know the buffer is full 
	leax 	charBell,PCR 
	ldy 	#1
	os9 	I$Write 
	puls 	X 
	bra 	MAINLOOP_KEYBOARD_DEC_COUNTER

MAINLOOP_KEYBOARD_CR
	; clear the line 
	pshs 	X 
	lda 	<inputbarPath
	leax 	charEraseLn,PCR 
	ldy 	#2 
	os9 	I$Write 
	; reset the column counter for next time 
	ldb 	#screen_width
	stb 	<columnCounter
	puls 	D 
	addd 	#1 
	subd 	<inputBufferStart
	tfr 	D,Y 
	ldx 	<inputBufferStart 	
	stx 	<inputBufferPtr 	; reset pointer to start for next time 
	; WE HAVE A FULL COMPLETE LINE TO PROCESS NOW 
	; check if the input line was a user irc command 
	lda 	,X+
	cmpa 	#'/'
	lbeq 	MAINLOOP_KEYBOARD_IRC_COMMAND
	cmpa 	#'|'
	bne 	MAINLOOP_KEYBOARD_SKIP_DEBUG
	; DEBUG: use this to just dump text to driverwire server 
	leax  	inputBuffer+1,U  	; skip the | flag char 
	lda 	<networkPath
	; Y should already contain amount of bytes read to write 
	os9 	I$Write 
	lbra 	MAINLOOP_KEYBOARD_RESET_SIGNAL
MAINLOOP_KEYBOARD_SKIP_DEBUG
	lda 	<activeDestFlag
	lbeq 	MAINLOOP_KEYBOARD_RESET_SIGNAL 	; do nothing since no place to send text to
	; setup text string command to send to destination 
	leay 	outputBuffer,U 
	leax 	strPRIVMSGkeyword,PCR
	lbsr 	STRING_COPY
	lda 	#C$SPAC 
	sta 	,Y+
	lbsr 	DESTINATION_GET_ACTIVE
	lbcs 	MAINLOOP_KEYBOARD_RESET_SIGNAL 	; do nothing since no place to send text to
	stx 	<outputBufferPtr
	lbsr 	STRING_COPY
	ldd 	#" :"
	std 	,Y++
	leax 	inputBuffer,U  
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf  
	std 	,Y++
	leax 	outputBuffer,U 
	lda 	<networkPath
	lbsr 	WRITE_CRLF_STRING
	; AFTER SENDING TO NETWORK, FORMAT AND SEND OUR OUTPUT TO SCREEN TOO
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	ldx 	<outputBufferPtr
	lda 	#'{'
	sta 	,Y+
	lda 	,X  		; grab the first character in destination to see if
				; nick or channel 
	cmpa 	#'#'
	bne 	MAINLOOP_KEYBOARD_NICK_OUTPUT
	lda 	#colorChanName
	bra 	MAINLOOP_KEYBOARD_PRINT_RESULT
MAINLOOP_KEYBOARD_NICK_OUTPUT
	lda 	#colorNickChan
MAINLOOP_KEYBOARD_PRINT_RESULT
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	STRING_COPY
	; change back to normal text color 
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"} "
	std 	,Y++
	lda 	#'<'
	sta 	,Y+
	; change foreground color for YOUR nickname 
	lda 	#colorYourNick
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	serverYourNick,U 
	lbsr 	STRING_COPY
	; change back to normal text color 
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"> "
	std 	,Y++
	leax 	inputBuffer,U 
	clrb 
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U
 IFDEF use_word_wrap
 	lbsr 	PRINT_CHATLOG_WITH_WORD_WRAP
 ELSE
 	lbsr 	PRINT_CHATLOG_NULL_STRING
 ENDC  
	;lda 	<chatlogPath
	;lbsr 	WRITE_CRLF_STRING
	bra 	MAINLOOP_KEYBOARD_RESET_SIGNAL

MAINLOOP_KEYBOARD_IRC_COMMAND
	lbsr 	COMMAND_LOOKUP
	bcs 	MAINLOOP_KEYBOARD_IRC_COMMAND_INVALID
	leay 	0,PCR 
	jsr 	D,Y 
	bra 	MAINLOOP_KEYBOARD_RESET_SIGNAL

MAINLOOP_KEYBOARD_IRC_COMMAND_INVALID
	leax 	strErrorInvalidCmd,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	MAINLOOP_KEYBOARD_RESET_SIGNAL

MAINLOOP_KEYBOARD_RESET_SIGNAL
	clr 	<keyboardDataReady 	; reset the flag 

	; reset the signal for the next one 
	lda 	<inputbarPath 
	ldb 	#SS.SSig
	ldx 	#keyboard_signal
	os9 	I$SetStt
	lbra 	MAINLOOP 

MAINLOOP_CHECK_NETWORK
	ldb 	<networkDataReady
	lbeq 	MAINLOOP_SLEEP
	lbsr 	DRIVEWIRE_GET_DATA
	bcc 	MAINLOOP_NETWORK_VALID_READ

	; error reading 
	lda 	<chatlogPath
	leax 	strErrorReading,PCR 
	ldy 	#256
	os9 	I$WritLn 
	lbra 	MAINLOOP_NETWORK_SERVER_BUFFER_NOT_READY
	
MAINLOOP_NETWORK_VALID_READ
MAINLOOP_NETWORK_NEXT_SERVER_CMD
	lbsr 	FILL_SERVER_BUFFER
	lbcs 	MAINLOOP_NETWORK_SERVER_BUFFER_NOT_READY
	; AT THIS POINT, WE SHOULD HAVE A COMPLETE MESSAGE OF SOME KIND. FIRST, SOME STATUS CHECKS  
	; check for just a blank CR+LF and skip it if found 
	ldd 	serverBuffer,U 
	cmpd 	#cr_lf
	beq 	MAINLOOP_NETWORK_NEXT_SERVER_CMD 	
	; are we already connected?
	ldb 	<connectedStatus 
	lbne 	MAINLOOP_NETWORK_CONNECTED_ALREADY
	; nope not yet. are we waiting for a CONNECTED confirmation?
	ldb 	<connectPendingFlag
	beq 	MAINLOOP_NETWORK_NEXT_SERVER_CMD 	; skip to next command if any and wait 
	; if here, we are looking for CONNECTED word, so check the command we got 
	lbsr 	NETWORK_SEARCH_CONNECTED_STRING
	bcs 	MAINLOOP_NETWORK_NEXT_SERVER_CMD 	; nothing yet, check for more data 
	; we found "CONNECTED" signature! set appropriate flags and disable connection timeout timer 
	clr 	<connectPendingFlag
	clr 	<connectTimeoutFlag
	inc 	<connectedStatus
	lda 	<nilPath
	bmi 	MAINLOOP_NETWORK_SKIP_VRN_DISABLE
	ldb 	#SS.FClr 
	ldx 	#0
	ldy 	#0
	os9 	I$SetStt 
MAINLOOP_NETWORK_SKIP_VRN_DISABLE
	; tell them we are connected 
	leax 	strUserMsgConnected,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	; now setup the login process. first build nickname login command 
	leay 	outputBuffer,U 
	leax 	strIRCserverNick,PCR 
	lbsr 	STRING_COPY
	leax 	currentNickname,U 
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	; send it to the network 
	lda 	<networkPath 
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; now build the USER login command and write it to network 
	leay 	outputBuffer,U 
	leax 	strIRCserverUser,PCR 
	lbsr 	STRING_COPY_RAW
	leax 	currentUsername,U 
	lbsr 	STRING_COPY_CR
	ldd 	#" 8" 	; user ID code for +i invisible
	std 	,Y++ 
	ldd 	#" *"
	std 	,Y++
	ldd 	#" :"
	std 	,Y++
	leax 	currentRealname,U 
	lbsr 	STRING_COPY_CR 		; use STRING_COPY since realname can have SPACES in it 
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	lbra 	MAINLOOP_NETWORK_NEXT_SERVER_CMD

MAINLOOP_NETWORK_CONNECTED_ALREADY
	; check for a "NO CARRIER" signature from the DW server 
	lbsr 	NETWORK_SEARCH_NO_CARRIER_STRING
	bcs 	MAINLOOP_NETWORK_PARSE_CMD
	; we have lost connection to remote server. close paths, reset variables.
	lbsr 	DRIVEWIRE_RESET
	leax 	strUserMsgDisconnected,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbsr 	DESTINATION_INITIALIZE_ARRAY 	; erase desintation list 
	lbsr 	STATUS_BAR_UPDATE
	bra 	MAINLOOP_NETWORK_SERVER_RESET_SIGNAL 

MAINLOOP_NETWORK_PARSE_CMD
	; NOW PROCESS THE SERVER COMMAND, THEN CHECK IF THERES ADDITIONAL DATA LEFT IN 
	; DRIVEWIRE BUFFER BEFORE GETTING BACK INTO THE MAIN LOOP 
 	lbsr 	PARSE_SERVER_CMD
	lbra 	MAINLOOP_NETWORK_NEXT_SERVER_CMD
	
MAINLOOP_NETWORK_SERVER_BUFFER_NOT_READY
MAINLOOP_NETWORK_SERVER_RESET_SIGNAL
	clr 	<networkDataReady

	; reset signal for network activity 
	lda 	<networkPath
	ldb 	#SS.SSig 
	ldx 	#network_signal
	os9 	I$SetStt 
	lbra 	MAINLOOP 

MAINLOOP_SLEEP
	ldx 	#0
	os9 	F$Sleep
      	lbra 	MAINLOOP 

; -----------------------------------------------
CLOSE_ALL_PATHS
	lda 	<networkPath
	bmi 	CLOSE_ALL_PATHS_SKIP_NETWORK_CLOSE
	os9 	I$Close 
CLOSE_ALL_PATHS_SKIP_NETWORK_CLOSE
	lda 	<nilPath
	os9 	I$Close 
	lda 	<inputbarPath
	os9 	I$Close 
	lda 	<statusbarPath
	os9 	I$Close 
	lda 	<chatlogPath
	os9 	I$Close 
	rts 
; -----------------------------------------------	

EXIT_ABORT
	; close all open paths 
	bsr 	CLOSE_ALL_PATHS
EXIT 
      	clrb 
      	os9 	F$Exit 

**********************************************************************
* subroutine area 
**********************************************************************
; --------------------------------------------------------------------
; signal handler 
; --------------------------------------------------------------------
SIGNAL_HANDLER
	cmpb 	#network_signal 
	beq 	SIGNAL_HANDLER_FLAG_NEW_NET_DATA
	cmpb 	#keyboard_signal
	beq 	SIGNAL_HANDLER_FLAG_NEW_KEY_DATA
	cmpb 	#connect_timeout_signal
	beq 	SIGNAL_HANDLER_FLAG_TIMER
	cmpb 	#server_timeout_signal
	beq 	SIGNAL_HANDLER_SERVER_TIMEOUT
	cmpb 	#S$Intrpt
	beq 	SIGNAL_HANDLER_ABORT
	cmpb 	#S$Abort
	beq 	SIGNAL_HANDLER_ABORT
	cmpb 	#S$HUP 
	beq 	SIGNAL_HANDLER_DISCONNECTED
	rti 

SIGNAL_HANDLER_FLAG_NEW_NET_DATA
	inc 	<networkDataReady
	rti 

SIGNAL_HANDLER_FLAG_NEW_KEY_DATA
	inc 	<keyboardDataReady
	rti 

SIGNAL_HANDLER_FLAG_TIMER
	ldb 	<connectPendingFlag 	; are we waiting for a connection? if not, skip and return
	beq 	SIGNAL_HANDLER_FLAG_TIMER_SKIP
	inc 	<connectTimeoutFlag
SIGNAL_HANDLER_FLAG_TIMER_SKIP
	rti 

SIGNAL_HANDLER_SERVER_TIMEOUT
	dec 	<timeoutCounter
	rti 

SIGNAL_HANDLER_ABORT
	inc 	<abortFlag
	rti 

SIGNAL_HANDLER_DISCONNECTED
	inc 	<disconnectedFlag
	rti 

; --------------------------------------------------------------------
; setup drivewire server network paths 
; --------------------------------------------------------------------
DRIVEWIRE_SETUP
	pshs 	Y,X,D 

	; close the open path, reset everything, etc if theres already open path 
	lbsr 	DRIVEWIRE_RESET
DRIVEWIRE_SETUP_PATH_ALREADY_CLOSED
	lda 	#UPDAT. 
	leax 	networkPathName,PCR 
	os9 	I$Open 
	bcs 	DRIVEWIRE_SETUP_EXIT
	sta 	<networkPath 

	ldb 	#SS.Opt  
	leax 	pdBuffer,U 
	os9 	I$GetStt
	bcs 	DRIVEWIRE_SETUP_EXIT

	; switch to RAW mode instead now 
       leax 	PD.UPC-PD.OPT,X
	ldb 	#PD.QUT-PD.UPC 
DRIVEWIRE_SETUP_RAW_LOOP        
	clr 	,X+
	decb
	bpl 	DRIVEWIRE_SETUP_RAW_LOOP

	lda 	<networkPath
	ldb 	#SS.Opt  
	leax 	pdBuffer,U 
	os9 	I$SetStt 
	bcs 	DRIVEWIRE_SETUP_EXIT

	; setup the initial network signal 
	lda 	<networkPath
	ldb 	#SS.SSig 
	ldx 	#network_signal
	os9 	I$SetStt 

DRIVEWIRE_SETUP_EXIT
	; carry will already be set if error or clear if not 
	puls 	D,X,Y,PC 

; -------------------------------------------------------------------
; close drivewire and reset flags, buffers, pointers, etc 
; -------------------------------------------------------------------
DRIVEWIRE_RESET 
	pshs 	X,D 

	lda 	<networkPath
	bmi 	DRIVEWIRE_RESET_ALREADY_CLOSED 	; skip the close call if no valid path 
	os9 	I$Close 
DRIVEWIRE_RESET_ALREADY_CLOSED
	lda 	#$FF
	sta 	<networkPath 
	ldd 	#0
	sta 	<connectedStatus
	sta 	<connectPendingFlag
	sta 	<connectTimeoutFlag
	sta 	<networkDataReady
	sta 	<disconnectedFlag
	sta 	<idValidatedFlag
	sta 	<activeDestFlag

	; reset buffer stuff
	leax 	networkBuffer,U 
	stx 	<networkBufferPtr
	sta 	<netBufferBytesRem
	leax 	serverBuffer,U 
	stx 	<serverBufferPtr
	std 	<serverBufferLength

	; disable any VRN signal timers that may be running 
	lda 	<nilPath 
	bmi 	DRIVEWIRE_RESET_SKIP_VRN
	ldb 	#SS.FClr  
	ldx 	#0
	ldy 	#0
	os9 	I$SetStt 
DRIVEWIRE_RESET_SKIP_VRN 

	puls 	D,X,PC 

; -------------------------------------------------------------------
; check if drivewire server has new data for us and read it if we do 
; -------------------------------------------------------------------
DRIVEWIRE_GET_DATA
	pshs 	X,D

	; check if we have data to read before trying to do it 
	lda 	<networkPath	
	ldb 	#SS.Ready
	os9 	I$GetStt
	bcs 	DRIVEWIRE_GET_DATA_ERROR
	clra 
	tfr 	D,Y 
	lda 	<networkPath
	leax 	networkBuffer,U 
	os9 	I$Read 
	bcs 	DRIVEWIRE_GET_DATA_ERROR

	; got new data, reset pointers and return 
	leax 	networkBuffer,U 
	stx 	<networkBufferPtr
	tfr 	Y,D 
	stb 	<netBufferBytesRem
	andcc 	#$FE 
	puls 	D,X,PC 

DRIVEWIRE_GET_DATA_ERROR
	orcc 	#1 	; carry set for error 
	puls 	D,X,PC 

; --------------------------------------------------------------------------------------
; copies available bytes from drivewire network buffer into a server buffer 
; and looks for a LF to mark end of complete server command. CRs are ignored/skipped.
;
; On success of getting a full server command: 
; Carry is clear. serverBufferPtr reset to beginning. serverBufferLength has # of bytes 
; in full server command. command end is marked with a CR and LF.
;
; on failure to build a full server command/incomplete command:
; Carry is set either when server buffer is full and cant fit anymore, or 
; when drivewire buffer is empty and still havent found a LF. 
;
; buffer pointers and number of bytes left in networkBuffer are always udpated on exit.
; --------------------------------------------------------------------------------------
FILL_SERVER_BUFFER
	pshs 	Y,X,D

	ldb 	<netBufferBytesRem
	beq 	FILL_SERVER_BUFFER_NONE_LEFT
	ldx 	<networkBufferPtr 
	ldy 	<serverBufferPtr
FILL_SERVER_BUFFER_NEXT_CHAR
	lda 	,X+
	cmpa 	#C$LF 
	bne 	FILL_SERVER_BUFFER_NOT_LF	
	; if here, we have a complete server command 
	decb 
	stb 	<netBufferBytesRem
	stx 	<networkBufferPtr 
	ldd 	#$0D0A
	cmpy 	<serverBufferEnd 
	bhs 	FILL_SERVER_BUFFER_FULL 
	sta 	,Y+
	cmpy 	<serverBufferEnd 
	bhs 	FILL_SERVER_BUFFER_FULL 
	stb 	,Y+
	tfr 	Y,D 
	leay 	serverBuffer,U 
	sty 	<serverBufferPtr 	; reset server buffer pointer to start for next time
	subd 	<serverBufferPtr
	std 	<serverBufferLength
	andcc 	#$FE 		; carry clear means we have a fully built server command ready 
	puls 	D,X,Y,PC 

FILL_SERVER_BUFFER_NOT_LF
	cmpa 	#C$CR
	beq 	FILL_SERVER_BUFFER_SKIP_CR_CHAR
FILL_SERVER_BUFFER_NORMAL
	sta 	,Y+
FILL_SERVER_BUFFER_SKIP_CR_CHAR
	decb 
	beq 	FILL_SERVER_BUFFER_FULL
	cmpy 	<serverBufferEnd 
	blo 	FILL_SERVER_BUFFER_NEXT_CHAR
	; if here, we have gotten all the currently available bytes from drivewire buffer 
FILL_SERVER_BUFFER_FULL
 	stb 	<netBufferBytesRem
	stx 	<networkBufferPtr 	
	sty 	<serverBufferPtr
FILL_SERVER_BUFFER_NONE_LEFT
	orcc 	#1 	; set carry to show we dont have a complete server command built yet 
	puls 	D,X,Y,PC 

; -------------------------------------------------------------
; look for the drivewire server "CONNECTED" response from using 
; the ATD command.
; -------------------------------------------------------------
NETWORK_SEARCH_CONNECTED_STRING
	pshs 	Y,X,D 

	leax 	serverBuffer,U 
	leay 	dwConnected,PCR	
	ldb 	#dwConnectedSize
NETWORK_SEARCH_CONNECTED_STRING_NEXT_CHAR
	lda 	,X+
	cmpa 	,Y+
	bne 	NETWORK_SEARCH_CONNECTED_STRING_FAILED
	decb 
	bne 	NETWORK_SEARCH_CONNECTED_STRING_NEXT_CHAR
	; success! 
	andcc 	#$FE
	puls 	D,X,Y,PC 

NETWORK_SEARCH_CONNECTED_STRING_FAILED
	orcc 	#1
	puls 	D,X,Y,PC 

; ------------------------------------------------------------
; check for "NO CARRIER" signature if we lost connection 
; ------------------------------------------------------------
NETWORK_SEARCH_NO_CARRIER_STRING
	pshs 	Y,X,D 

	leax 	serverBuffer,U 
	leay 	noCarrier,PCR 
	ldb 	#noCarrierSize
NETWORK_SEARCH_NO_CARRIER_STRING_NEXT_CHAR
	lda 	,X+
	cmpa 	,Y+ 
	bne 	NETWORK_SEARCH_NO_CARRIER_STRING_FAILED
	decb 
	bne 	NETWORK_SEARCH_NO_CARRIER_STRING_NEXT_CHAR
	; found it
	andcc 	#$FE 
	puls 	D,X,Y,PC 

NETWORK_SEARCH_NO_CARRIER_STRING_FAILED
	orcc 	#1
	puls 	D,X,Y,PC 

; --------------------------------------
; update/draw the status line at bottom
; --------------------------------------
STATUS_BAR_UPDATE
	pshs 	Y,X,D 

	leay 	outputBuffer,U 
	ldd 	#$030D 		; $03 = erase line, $0D = CR 
	std 	,Y++
	leax 	strCocoIRC,PCR 
	lbsr 	STRING_COPY

	; print the state 
	ldb 	idValidatedFlag,U 
	bne 	STATUS_BAR_UPDATE_CONNECTED
	leax 	strStateDisconnected,PCR
	lbsr 	STRING_COPY
	bra 	STATUS_BAR_UPDATE_PRINT

STATUS_BAR_UPDATE_CONNECTED
	leax 	strStateConnected,PCR
	lbsr 	STRING_COPY
	ldb 	<activeDestFlag
	bne 	STATUS_BAR_UPDATE_SHOW_DESTINATION
	; no active window/session selected 
	leax 	strStatusActiveNone,PCR
	lbsr 	STRING_COPY
	bra 	STATUS_BAR_UPDATE_PRINT

STATUS_BAR_UPDATE_SHOW_DESTINATION
	leax 	strStatusActive,PCR 
	lbsr 	STRING_COPY
	lbsr 	DESTINATION_GET_ACTIVE
	lbsr 	STRING_COPY
STATUS_BAR_UPDATE_PRINT
	leax 	outputBuffer,U 
	clra 
	lbsr 	FIND_CUSTOM_CHAR
	tfr 	D,Y 
	lda 	<statusbarPath
	os9 	I$Write 

STATUS_BAR_UPDATE_EXIT
      	puls 	D,X,Y,PC 

 IFDEF not_needed
; ----------------------------------------
; build a timestamp
; Entry: B = 0 to print result to screen
; 	  B != 0 to build only, no printing
; ----------------------------------------
GET_TIMESTAMP
	pshs 	Y,X,D 

	leax 	sysDateTime,U 
	os9  	F$Time 

	leay 	strTimestamp+4,U 

	; do hours value 
	ldb 	3,X 
	lbsr 	CONVERT_TIME_BYTE_DEC
	; do minutes value 
	ldb 	4,X 
	lbsr 	CONVERT_TIME_BYTE_DEC
	; do seconds value 
	ldb 	5,X 
	lbsr 	CONVERT_TIME_BYTE_DEC

	; print to chatlog if B on entry was zero
	ldb 	1,S 
	bne 	GET_TIMESTAMP_SKIP_PRINTING
	lda 	<chatlogPath
	leax 	strTimestamp,U 
	ldy 	#strTimestampTemplateSz
	os9 	I$Write
GET_TIMESTAMP_SKIP_PRINTING
	puls 	Y,X,D,PC 
 ENDC 

; ---------------------------------------------------------------------
; sets up and intializes the color palette for background/foreground 
; ---------------------------------------------------------------------
INIT_COLOR_SETTINGS
	pshs 	Y,X,D 

      	; copy palette values for default theme 
      	leax 	paletteDefs,PCR 
      	leay 	configFileVariables,U 
      	ldb 	#10
INIT_COLOR_SETTINGS_LOOP
      	lda 	,X+
      	sta 	,Y+
      	decb 
      	bne 	INIT_COLOR_SETTINGS_LOOP
    	
    	puls 	D,X,Y,PC 

; ---------------------------------------------------------------------
; construct series of palette change codes to set all of the colors up 
; on GIME palette registers and send them to window path
; ---------------------------------------------------------------------
WRITE_COLOR_CONFIG_TO_PALETTE
	pshs 	Y,X,D 

     	; setup all the control codes needed to change all the palette values 
      	leay 	outputBuffer,U 
      	leax 	configFileVariables,U 
      	ldu 	#$1B31
      	stu	,Y++
      	; main background color 
      	lda 	#1  
      	ldb 	,X+
      	std 	,Y++
       inca 
       ; status bar background color 
       ldb 	,X+
       stu	,Y++
      	std 	,Y++    
	lda 	#8 			; skip to foreground/text color registers 
WRITE_COLOR_CONFIG_TO_PALETTE_LOOP
       ldb 	,X+
       stu 	,Y++
       std 	,Y++
       inca 
       cmpa 	#15
       bls 	WRITE_COLOR_CONFIG_TO_PALETTE_LOOP
       ldu 	<uRegImage
      	; write color theme code values to window path after it's selected 
    	lda 	<chatlogPath
	ldy 	#2 
	leax 	dwSelectCodes,PCR 
	os9 	I$Write

	lda 	<chatlogPath
	clrb 
    	leax 	outputBuffer,U 
    	ldy 	#40 		; (8 foreground colors and 2 background ones) * 4 bytes per code sequence
    	os9 	I$Write 

	; reselect input bar which should be the normally selected window 
	lda 	<inputbarPath
	clrb 
	ldy 	#2 
	leax 	dwSelectCodes,PCR 
	os9 	I$Write

  	puls 	D,X,Y,PC 

; --------------------------------------------------------------------
; try and load configuration from file 
; Exit: carry set on error. B = error code. carry clear on success and 
; 	 config is written to their variables 
; --------------------------------------------------------------------
CONFIG_LOAD_FROM_FILE
	pshs 	Y,X,A 

	clr  	<oldConfigFlag

      	lda 	#READ. 
      	leax 	configFilePathName,PCR 
      	os9 	I$Open 
      	lbcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	sta  	<configFilePath
      	leax 	configFileVariables,U 
      	; read all color palette and flag values directly into their variables 
      	ldy 	#13 			; 10 color values and 3 config flags 
      	os9 	I$Read 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	; now read nickname string 
      	leax 	currentNickname,U 
      	ldy 	#32
      	os9 	I$ReadLn 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	; now read username string 
      	leax 	currentUsername,U 
      	ldy 	#32 
      	os9 	I$ReadLn 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	leax 	currentRealname,U 
      	ldy 	#32
      	os9 	I$ReadLn 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	leax 	userQuitMessage,U 
      	ldy 	#64
      	os9 	I$ReadLn 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	leax 	userVersionReply,U 
      	ldy 	#64
      	os9 	I$ReadLn 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	leax 	userServerDefault,U 
      	ldy 	#64
      	os9 	I$ReadLn 
      	bcs 	CONFIG_LOAD_FROM_FILE_ERROR
      	; now read in whatever is left to see if its an extended config file
      	leax  	outputBuffer,U 
      	ldy  	#64  				; read UP TO 64 bytes (probably overkill)
      	os9  	I$Read 
      	bcs  	CONFIG_LOAD_FROM_FILE_OLD_VERSION  ; probably an old config file version. warn user
      	ldd  	,X++ 
      	cmpd  	#"EX"
      	bne  	CONFIG_LOAD_FROM_FILE_OLD_VERSION  ; old version detected. warn user
      	; if here, this IS the updated config file format. check if user set nickserv password
      	ldb  	,X+ 
      	beq  	CONFIG_LOAD_FROM_FILE_DONE 	; no nickserv pass saved. we are done
      	stb  	<nickServPassFlag  		; set flag indicating we have a nickserv password 
     	; decrypt and copy password into variable
     	lbsr  	COPY_DECRYPT_NICKSERV_PASS
CONFIG_LOAD_FROM_FILE_DONE
      	; success! close the file and return 
      	lda  	<configFilePath
      	os9 	I$Close
      	clra 			; carry clear for success
      	puls 	A,X,Y,PC 

CONFIG_LOAD_FROM_FILE_OLD_VERSION
	inc  	<oldConfigFlag
	bra  	CONFIG_LOAD_FROM_FILE_DONE

CONFIG_LOAD_FROM_FILE_ERROR
	stb 	<tempChar 
	lda  	<configFilePath	
	os9 	I$Close 
	ldb 	<tempChar 
	orcc 	#1  		; carry set for error
	; B should contain OS9 error code 
	puls 	A,X,Y,PC 

; ---------------------------------------------------------------------
; look for a matching command in table of words 
; Entry: X = pointer to beginning of command to search for 
; 	  B = length of command word to check for  
; Exit: on success, carry clear. D = offset to COMMAND subroutine,
; 	  X = pointing to one past last char of found word  
; ---------------------------------------------------------------------
COMMAND_LOOKUP
	pshs 	Y,X,D 

	lbsr 	FIND_NEXT_SPACE_NULL_CR
	bcs 	COMMAND_LOOKUP_NO_MATCHES
	stb 	<cmdWordLength

	ldx 	2,S 		; restore original value of X from stack 
	leay 	userCmdWords,PCR
	clr 	<cmdWordCounter 
COMMAND_LOOKUP_NEW_PASS
	; make sure we arent at end of possible commands 
	lda 	,Y 
	bmi 	COMMAND_LOOKUP_NO_MATCHES
	ldb 	<cmdWordLength
COMMAND_LOOKUP_NEXT
	lda 	,X+
	lbsr 	CONVERT_UPPERCASE 
	cmpa 	,Y+
	bne 	COMMAND_LOOKUP_CHECK_NEXT_WORD
	decb 
	bne 	COMMAND_LOOKUP_NEXT
	; probably a match. check last byte 
	lda 	,Y 
	bne 	COMMAND_LOOKUP_CHECK_NEXT_WORD
	; success, get the pointer to command code 
	clra 
	ldb 	<cmdWordCounter
	lslb  
	leay 	userCmdWordPtrs,PCR 
	ldd 	B,Y 
	leas 	4,S 		; skip D and X on stack 
	andcc 	#$FE 		; carry clear for success 
	puls 	Y,PC 

COMMAND_LOOKUP_CHECK_NEXT_WORD
	leay 	-1,Y 
	ldx 	2,S  		; restore original pointer from stack 
	inc 	<cmdWordCounter 
	clrb
COMMAND_LOOKUP_CHECK_NEXT_WORD_LOOP
	lda 	,Y+
	beq 	COMMAND_LOOKUP_NEW_PASS
	decb 
	bne 	COMMAND_LOOKUP_CHECK_NEXT_WORD_LOOP
	; overflow, something went wrong. let carry get set for error
COMMAND_LOOKUP_NO_MATCHES
	orcc 	#1
	puls 	D,X,Y,PC

; -----------------------------------------------------------------
; draw graphical intro box
; -----------------------------------------------------------------
DRAW_INTRO_BOX
	pshs 	Y,X,D 

	leay 	outputBuffer,U 
	; copy palette setup codes in first 
	leax 	introBackPalette,PCR
	lbsr 	STRING_COPY_RAW

	leax 	introPosMainBox,PCR
	lbsr 	STRING_COPY_RAW

	; select main box color 
	ldd 	#$1B33
	std 	,Y++
	ldb 	#3
	stb 	,Y+

	ldb 	#$20
DRAW_INTRO_BOX_NEXT_LINE
	stb 	<tempCounter

	ldx 	#$0230
	stx 	,Y++
	stb 	,Y+

	ldb 	#48
	lda 	#C$SPAC 
DRAW_INTRO_BOX_LOOP
	sta 	,Y+
	decb 
	bne 	DRAW_INTRO_BOX_LOOP
	ldb	<tempCounter
	incb 
	cmpb 	#$24
	bls 	DRAW_INTRO_BOX_NEXT_LINE

	; now draw the box shadow 
	ldd 	#$1B33
	std 	,Y++
	ldb 	#5
	stb 	,Y+

;	leax 	introPosShadow

	ldd 	#$1B33
	std 	,Y++
	ldd 	#$0100
	std 	,Y 

	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

	puls 	D,X,Y,PC 

introPosMainBox	FCB 	$02,$30,$21,0
introBackPalette 	FCB 	$1B,$31,$0B,24
			FCB 	$1B,$31,$0C,1
			FCB 	$1B,$31,$0D,7
			FCB 	0



*************************************************************************************
      ; include the source for the various user commands 
      include string_stuff.asm 
      include user_command_stuff.asm 
      include ircserver_stuff.asm
      include window_management.asm

*************************************************************************************
	EMOD 
MODULE_SIZE 	; put this at the end so it can be used for module size 

