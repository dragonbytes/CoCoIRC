

; Colors 
colorNormal 			EQU 	16	; this is really color 0 since upper 4 bits 
						; are truncated, but lets me use NULL terminated
						; strings with color codes
						; (nice trick @Deek !)
colorTimestamp 		EQU 	1
colorChanName 		EQU 	2
colorQuit 			EQU 	3
colorYourNick 		EQU 	4
colorJoinPart 		EQU 	5
colorNotice 			EQU 	6
colorNickChan 		EQU 	7

		pragma 	cescapes
		org 		0

; first 4 WORDs are for the general help string offsets and sizes 
				FDB 	strHelpCommandList
				FDB 	strHelpCommandListSz 
				FDB 	strHelpCommandNotes
				FDB 	strHelpCommandNotesSz
; offset/size table structure: first WORD is the string's offset in file, second WORD is the string's size 
				FDB 	strHelpUsageServer
				FDB 	strHelpUsageServerSz
				FDB 	strHelpUsageConnect
				FDB 	strHelpUsageConnectSz
				FDB 	strHelpUsageQuit
				FDB 	strHelpUsageQuitSz
				FDB 	strHelpUsageNick
				FDB 	strHelpUsageNickSz
				FDB 	strHelpUsageJoin
				FDB 	strHelpUsageJoinSz
				FDB 	strHelpUsagePart
				FDB 	strHelpUsagePartSz
				FDB 	strHelpUsageCycle
				FDB 	strHelpUsageCycleSz
				FDB 	strHelpUsageTopic
				FDB 	strHelpUsageTopicSz 
				FDB 	strHelpUsageNames 
				FDB 	strHelpUsageNamesSz 
				FDB 	strHelpUsageAction 
				FDB 	strHelpUsageActionSz
				FDB 	strHelpUsageMe 
				FDB 	strHelpUsageMeSz 
				FDB 	strHelpUsageMsg 
				FDB 	strHelpUsageMsgSz 
				FDB 	strHelpUsageQuery
				FDB 	strHelpUsageQuerySz 
				FDB 	strHelpUsageClose 
				FDB 	strHelpUsageCloseSz 
				FDB 	strHelpUsageNotice 
				FDB 	strHelpUsageNoticeSz 
				FDB 	strHelpUsageOp 
				FDB 	strHelpUsageOpSz 
				FDB 	strHelpUsageDeop
				FDB 	strHelpUsageDeopSz
				FDB 	strHelpUsageVoice 
				FDB 	strHelpUsageVoiceSz 
				FDB 	strHelpUsageDeVoice
				FDB 	strHelpUsageDeVoiceSz
				FDB 	strHelpUsageBan
				FDB 	strHelpUsageBanSz 
				FDB 	strHelpUsageUnBan
				FDB 	strHelpUsageUnBanSz
				FDB 	strHelpUsageKick 
				FDB 	strHelpUsageKickSz
				FDB 	strHelpUsageMode
				FDB 	strHelpUsageModeSz
				FDB 	strHelpUsageWhois
				FDB 	strHelpUsageWhoisSz
				FDB 	strHelpUsageRaw
				FDB 	strHelpUsageRawSz
				FDB  	strHelpUsageNickServ
				FDB  	strHelpUsageNickServSz
; offsets for local program command usage strings 
				FDB 	strHelpUsageHelp 
				FDB 	strHelpUsageHelpSz
				FDB 	strHelpUsageAbout
			 	FDB 	strHelpUsageAboutSz
			 	FDB 	strHelpUsageLoad
			 	FDB 	strHelpUsageLoadSz 
			 	FDB 	strHelpUsageSave
			 	FDB 	strHelpUsageSaveSz
			 	FDB 	strHelpUsageClear
			 	FDB 	strHelpUsageClearSz 
			 	FDB 	strHelpUsageExit
			 	FDB 	strHelpUsageExitSz 
			 	FDB 	strHelpUsagePrev
			 	FDB 	strHelpUsagePrevSz
			 	FDB 	strHelpUsageNext
			 	FDB 	strHelpUsageNextSz
			 	; MAKE SURE SET IS LAST SINCE THERE ARE SUBSETTINGS FOR IT TO CHECK 
			 	FDB 	strHelpUsageSet
			 	FDB 	strHelpUsageSetSz 
			 	FDB 	strHelpUsageSetNick
			 	FDB 	strHelpUsageSetNickSz
			 	FDB 	strHelpUsageSetRealname
			 	FDB 	strHelpUsageSetRealnameSz
			 	FDB 	strHelpUsageSetUser
			 	FDB 	strHelpUsageSetUserSz
			 	FDB 	strHelpUsageSetColor
			 	FDB 	strHelpUsageSetColorSz
			 	FDB 	strHelpUsageSetQuitMsg
			 	FDB 	strHelpUsageSetQuitMsgSz
			 	FDB 	strHelpUsageSetVersion
			 	FDB 	strHelpUsageSetVersionSz
			 	FDB 	strHelpUsageSetServer
			 	FDB 	strHelpUsageSetServerSz
			 	FDB 	strHelpUsageSetTimestamp
			 	FDB 	strHelpUsageSetTimestampSz
			 	FDB 	strHelpUsageSetMOTD
			 	FDB 	strHelpUsageSetMOTDsz
			 	FDB 	strHelpUsageSetNames
			 	FDB 	strHelpUsageSetNamesSz
			 	FDB  	strHelpUsageSetNickServ
			 	FDB  	strHelpUsageSetNickServSz

; --------------------------------------------------------------------------------------------------------------
; Main help page strings 
; --------------------------------------------------------------------------------------------------------------
strHelpCommandList		FCB 	$0D,$0A,$1B,$32,colorNotice
				FCC 	" -= "
				FCB 	$1B,$32,colorJoinPart
				FCC 	"Available Commands"
				FCB 	$1B,$32,colorNotice
				FCC 	" =-\r\n\n"
				FCB 	$1B,$32,colorYourNick
		 		FCC 	"For IRC:  "
				FCB 	$1B,$32,colorNormal 
				FCC 	"SERVER    CONNECT   QUIT      NICK      JOIN      PART\r\n"
		 		FCC 	"          CYCLE     TOPIC     NAMES     ACTION    ME        MSG\r\n"
		 		FCC 	"          QUERY     CLOSE     NOTICE    OP        DEOP      VOICE\r\n"
		 		FCC 	"          DEVOICE   BAN       UNBAN     KICK      MODE      WHOIS\r\n"
		 		FCC 	"          RAW       NICKSERV\r\n\n"
				FCB 	$1B,$32,colorYourNick
		 		FCC 	"General:  "
				FCB 	$1B,$32,colorNormal 
				FCC 	"HELP      ABOUT     SET       LOAD      SAVE      CLEAR\r\n"
		 		FCN 	"          EXIT      PREV      NEXT\r\n"
strHelpCommandListSz 	EQU 	*-strHelpCommandList

strHelpCommandNotes 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"To cycle through your active channels and private messages, you can press\r\n"
				FCC 	"    CTRL-LEFT or CTRL-RIGHT in addition to using the /PREV and /NEXT commands.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"All commands must be prefixed with a forward-slash. (Ex: /JOIN #coco_chat)\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"For usage information about a specific command, type /HELP [command]\r\n"
strHelpCommandNotesSz 	EQU 	*-strHelpCommandNotes

; --------------------------------------------------------------------------------------------------------------
; Individual command usage/help strings 
; --------------------------------------------------------------------------------------------------------------
strHelpUsageServer 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /SERVER <address[:port]>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Open a connection to the specified IRC server and/or port number.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"If no parameters are given, user's default address/port will be used.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"If no port is specified, default of 6667 will be used.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"You may optionally use the /CONNECT alias instead of /SERVER. The two are\r\n"
				FCN 	"    interchangeable and their usage is the same.\r\n"
strHelpUsageServerSz 	EQU 	*-strHelpUsageServer

strHelpUsageConnect 		FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"/CONNECT is an alias for the /SERVER command and it's usage is the same.\r\n"
				FCN  	"    Type /HELP SERVER for more information.\r\n"
strHelpUsageConnectSz  	EQU  	*-strHelpUsageConnect

strHelpUsageQuit 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /QUIT [quit message]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
			 	FCN 	"Disconnect from the current IRC server with an optional quit message.\r\n"
strHelpUsageQuitSz 		EQU 	*-strHelpUsageQuit

strHelpUsageNick 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /NICK <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCN 	"Change your current nickname on IRC.\r\n"
strHelpUsageNickSz 		EQU 	*-strHelpUsageNick

strHelpUsageJoin 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /JOIN <channel>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCN 	"Join a channel.\r\n"
strHelpUsageJoinSz 		EQU 	*-strHelpUsageJoin

strHelpUsagePart 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /PART [channel]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Leave a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsagePartSz 		EQU 	*-strHelpUsagePart

strHelpUsageCycle 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /CYCLE [channel]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Quickly leave and rejoin a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageCycleSz 		EQU 	*-strHelpUsageCycle

strHelpUsageTopic 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /TOPIC [channel] [new topic text]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
			 	FCN 	"Change or display current topic message on a channel.\r\n"
strHelpUsageTopicSz 		EQU 	*-strHelpUsageTopic

strHelpUsageNames 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /NAMES [channel]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Display a list of nicknames currently joined in a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageNamesSz 		EQU 	*-strHelpUsageNames

strHelpUsageAction 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Usage: /ACTION <message>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal	
				FCC 	"Chat in the 3rd person using your nickname. Example: /ACTION jumps up and down.\r\n"
				FCN 	"    If your nickname was SamGime, the output would be \x22* SamGime jumps up and down.\x22\r\n"
strHelpUsageActionSz 	EQU 	*-strHelpUsageAction

strHelpUsageMe 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /ME <message>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"This is just an alias of /ACTION and works the same way.\r\n"
strHelpUsageMeSz 		EQU 	*-strHelpUsageMe

strHelpUsageMsg 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /MSG <nickname> <message>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"Send a private message to a nickname without creating a new window.\r\n"
strHelpUsageMsgSz 		EQU	 *-strHelpUsageMsg

strHelpUsageQuery 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /QUERY <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"Open a new private message window for a nickname.\r\n"
strHelpUsageQuerySz 		EQU 	*-strHelpUsageQuery

strHelpUsageClose 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /CLOSE [channel | nickname]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Close an open query or channel window.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"If no window name is specified, the active one will be closed.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If the window is a channel, it will also PART that channel on IRC.\r\n"
strHelpUsageCloseSz 		EQU 	*-strHelpUsageClose

strHelpUsageNotice 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /NOTICE <nickname> <message>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"Send a message to a nickname as an IRC Notice.\r\n"
strHelpUsageNoticeSz 	EQU 	*-strHelpUsageNotice

strHelpUsageOp 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /OP [channel] <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Give Operator privileges to specified nickname on a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageOpSz 		EQU 	*-strHelpUsageOp

strHelpUsageDeop 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /DEOP [channel] <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Remove Operator privileges from specified nickname om a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageDeopSz 		EQU 	*-strHelpUsageDeop

strHelpUsageVoice 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /VOICE [channel] <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Set the Voice mode flag (+v) on specified nickname in a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageVoiceSz 		EQU 	*-strHelpUsageVoice

strHelpUsageDeVoice 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /DEVOICE [channel] <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Remove Voice mode flag (-v) from specified nickname on a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageDeVoiceSz 	EQU 	*-strHelpUsageDeVoice

strHelpUsageBan 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /BAN [channel] <hostmask>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Bans a user's hostmask on specified channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Hostmasks have a syntax of nickname!user@host and can include wildcards\r\n"
				FCC 	"    in any of the values denoted by an asterix character.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageBanSz 		EQU 	*-strHelpUsageBan

strHelpUsageUnBan 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /UNBAN [channel] <hostmask>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Remove a user's banned hostmask from a specified channel."
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Hostmasks have a syntax of nickname!user@host and can include wildcards\r\n"
				FCC 	"    in any of the values denoted by an asterix character.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageUnBanSz 		EQU 	*-strHelpUsageUnBan

strHelpUsageKick 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /KICK [channel] <nickname> [message]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Kick the specified nickname out of a channel and display an optional\r\n"
				FCC 	"    reason/message along with it.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageKickSz 		EQU 	*-strHelpUsageKick

strHelpUsageMode 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /MODE [channel] <flags> <parameters>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Set your own specific mode flags and parameters on a channel.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"If no channel name is specified, the active channel is used.\r\n"
strHelpUsageModeSz 		EQU 	*-strHelpUsageMode					

strHelpUsageWhois 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /WHOIS <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"Request user information on given nickname from the IRC server.\r\n"
strHelpUsageWhoisSz		EQU 	*-strHelpUsageWhois

strHelpUsageRaw 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /RAW <text string>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Send a raw string of text directly to the IRC server. Used for\r\n"
			 	FCN 	"    executing commands not yet supported by CoCoIRC or debugging.\r\n"
strHelpUsageRawSz 		EQU 	*-strHelpUsageRaw

strHelpUsageNickServ 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /NICKSERV <IDENTIFY [password]> | <manual command string>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Used to either login (identify) with a registered nickname, or to send\r\n"
			 	FCC 	"    other various manually entered commands to NickServ.\r\n"
			 	FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
			 	FCC  	"You can optionally omit the password when using IDENTIFY to have CoCoIRC\r\n"
			 	FCC  	"    automatically fill it in for you if you have one saved in your config.\r\n"
			 	FCN  	"    Type /HELP SET NICKSERV for more information about this.\r\n"
strHelpUsageNickServSz 	EQU 	*-strHelpUsageNickServ

strHelpUsageHelp 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /HELP [command]\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Displays the usage syntax of the specified command word.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"If no command word is given, will display a full list of available commands\r\n"
 				FCN 	"    as well as general program instructions.\r\n"
strHelpUsageHelpSz 		EQU 	*-strHelpUsageHelp

strHelpUsageAbout 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /ABOUT\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Displays CoCoIRC version/author information, a few shoutouts to those that\r\n"
 				FCN 	"    helped me write this, and the story of how I came up with the idea.\r\n"
strHelpUsageAboutSz 		EQU 	*-strHelpUsageAbout

strHelpUsageSet 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET <parameter> <value>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Used to change program default settings or enable/disable other functions.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"These parameters are all saved to the config file using the /SAVE command\r\n"
 				FCC 	"    and automatically reloaded when CoCoIRC is launched. You can also manually\r\n"
 				FCC 	"    load them on your own using the /LOAD command. Available parameters are:\r\n\n"
 				FCC 	"    NICK        REALNAME    USER        COLOR       QUITMSG\r\n"
 				FCC 	"    VERSION     SERVER      TIMESTAMP   MOTD        NAMES\r\n"
 				FCC  	"    NICKSERV\r\n\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"For an explanation of these sub-settings as well as their syntax, type\r\n"
 				FCN 	"    /HELP SET <parameter>\r\n"
strHelpUsageSetSz 		EQU 	*-strHelpUsageSet

strHelpUsageLoad 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /LOAD\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Load and apply settings from the config file into the current session.\r\n"
 				FCN 	"    Config file is located at /DD/SYS/cocoirc.conf\r\n"
strHelpUsageLoadSz 		EQU 	*-strHelpUsageLoad

strHelpUsageSave 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SAVE\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Save the current settings to the config file.\r\n"
 				FCN 	"    Config file is located at /DD/SYS/cocoirc.conf\r\n"
strHelpUsageSaveSz 		EQU 	*-strHelpUsageSave

strHelpUsageClear 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /CLEAR\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCN 	"Clear the chatlog window and return the cursor to the top of the screen.\r\n"
strHelpUsageClearSz 		EQU 	*-strHelpUsageClear

strHelpUsageExit 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /EXIT\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Exit CoCoIRC back into NitrOS-9. If you are connected to an IRC server,\r\n"
 				FCN 	"    a QUIT command will automatically be sent before the program closes.\r\n"
strHelpUsageExitSz 		EQU 	*-strHelpUsageExit

strHelpUsagePrev 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /PREV\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Cycle the active window to the previous channel or nickname.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCN 	"This performs the same function as pressing the key combo CTRL-LEFT.\r\n"
strHelpUsagePrevSz 		EQU 	*-strHelpUsagePrev

strHelpUsageNext 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /NEXT\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Cycle the active window to the next channel or nickname.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCN 	"This performs the same function as pressing the key combo CTRL-RIGHT.\r\n"
strHelpUsageNextSz 		EQU 	*-strHelpUsageNext

; ----------------------------------------------------------------------------------------------------------------

strHelpUsageSetNick 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET NICK <nickname>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Sets the default nickname used when you connect to an IRC server.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCN 	"This does NOT change your current nickname. Use /NICK for that.\r\n"
strHelpUsageSetNickSz 	EQU 	*-strHelpUsageSetNick

strHelpUsageSetRealname 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET REALNAME <text string>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Sets the default \x22Real Name\x22 shown to other users on IRC. This can include\r\n"
 				FCC 	"    spaces or any other alphanumeric characters or symbols.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCN 	"This change only takes effect when reconnecting to an IRC server.\r\n"
strHelpUsageSetRealnameSz 	EQU 	*-strHelpUsageSetRealname

strHelpUsageSetUser 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET USER <username>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Sets the default \x22Username\x22 to use when connecting to an IRC server.\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCN 	"This change only takes effect when reconnecting to an IRC server.\r\n"
strHelpUsageSetUserSz 	EQU 	*-strHelpUsageSetUser

strHelpUsageSetColor		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET COLOR <category> <new palette value>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Changes the current color palette value for the specified category. Value\r\n"
 				FCC 	"    should be a decimal number between 0 and 63. Available categories:\r\n\n"
 				FCC 	"    TEXT      = Foreground text       BACKGROUND = Screen background\r\n"
 				FCC 	"    STATUSBAR = Status bar            TIMESTAMP  = Timestamp\r\n"
 				FCC 	"    CHANNAME  = Channel names         YOURNICK   = Your own nickname\r\n"
 				FCC 	"    QUIT      = Quit messages         CHANINFO   = Join/Part/Topic/Mode/Misc\r\n"
 				FCC 	"    NOTICE    = Notices/Whois info    CHANNICK   = Other people's nickname\r\n\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"To reset all color palette values to their original default, you can use\r\n"
				FCC 	"    the command /SET COLOR DEFAULTS\r\n"
 				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
 				FCC 	"Changes made to these settings can be saved to the config file for future\r\n"
 				FCN 	"    sessions by using the /SAVE command.\r\n"
strHelpUsageSetColorSz	EQU 	*-strHelpUsageSetColor

strHelpUsageSetQuitMsg 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET QUITMSG <text string>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Sets the default \x22Quit Message\x22 shown to users on IRC when you disconnect\r\n"
				FCN 	"    using the /QUIT command without specifying one.\r\n"
strHelpUsageSetQuitMsgSz 	EQU 	*-strHelpUsageSetQuitMsg

strHelpUsageSetVersion 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET VERSION <text string>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Sets the text string reply to return when someone sends you a CTCP\r\n"
				FCC 	"    \x22Version\x22 request.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"This can be any text you want, but it is commonly used to tell other users\r\n"
				FCN 	"    what IRC client and/or computer system you are using to connect with.\r\n"
strHelpUsageSetVersionSz 	EQU 	*-strHelpUsageSetVersion

strHelpUsageSetServer 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET SERVER <address:[port]>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Sets the default IRC server to connect to if you don't specify one when\r\n"
				FCC 	"    using the /SERVER command.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"Port number will default to 6667 when connecting if none is specified.\r\n"
strHelpUsageSetServerSz 	EQU 	*-strHelpUsageSetServer

strHelpUsageSetTimestamp 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET TIMESTAMP <ON | OFF>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Enables or disables the timestamp shown on each line of text in the\r\n"
				FCC 	"    chatlog.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"ENABLE/DISABLE can also be used instead of ON/OFF.\r\n"
strHelpUsageSetTimestampSz 	EQU 	*-strHelpUsageSetTimestamp

strHelpUsageSetMOTD 		FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET MOTD <ON | OFF>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Enables or disables showing the \x22Message Of The Day\x22 when connecting to\r\n"
				FCC 	"    an IRC server.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"This message can be rather long on some servers so some may prefer not to\r\n"
				FCC 	"    wait for it scroll through each time they connect.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"ENABLE/DISABLE can also be used instead of ON/OFF.\r\n"
strHelpUsageSetMOTDsz 	EQU 	*-strHelpUsageSetMOTD

strHelpUsageSetNames 	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET NAMES <ON | OFF>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Enables or disables displaying a list of nicknames currently in the\r\n"
				FCC 	"    channel whenever you join one.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Printing this list can take awhile in channels that have alot of users.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"This can be done manually at any time by using the /NAMES command.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCN 	"ENABLE/DISABLE can also be used instead of ON/OFF.\r\n"
strHelpUsageSetNamesSz 	EQU 	*-strHelpUsageSetNames

strHelpUsageSetNickServ	FCB 	$0D,$0A,$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Usage: /SET NICKSERV PASS <password>\r\n"
				FCC  	"           /SET NICKSERV AUTOLOGIN <ON | OFF>\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Configures NickServ settings to be used with your default IRC server.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"Use the PASS argument to set your local NickServ password on CoCoIRC.\r\n"
				FCC 	"    Use the AUTOLOGIN argument to enable/disable automatic login with NickServ\r\n"	
				FCC  	"    when you connect to an IRC server. (A password must be set using the PASS\r\n"
				FCC  	"    argument before this can be enabled)\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC  	"IMPORTANT NOTE: These settings do NOT discriminate between different IRC\r\n"
				FCC  	"    networks. So if you connect to another server on a different network and\r\n"
				FCC  	"    you use a different NickServ password there, it will send the wrong\r\n"
				FCC  	"    one unless you update the setting with the new password first.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"ENABLE/DISABLE can also be used instead of ON/OFF.\r\n"
				FCB 	$1B,$32,colorNotice,$20,$20,'-',$20,$1B,$32,colorNormal
				FCC 	"These settings will only be temporary unless you use the /SAVE command\r\n"
				FCN  	"    afterwards to update your config file.\r\n"
strHelpUsageSetNickServSz 	EQU 	*-strHelpUsageSetNickServ