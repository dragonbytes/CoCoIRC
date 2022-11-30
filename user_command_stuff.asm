
****************************************
* IRC client user command code
****************************************

; ----------------------------------------------
; connect to an IRC server 
; Entry: X = pointer to one character after command word (usually a space or CR) 
; ----------------------------------------------
COMMAND_SERVER
	pshs 	U,Y,X,D 

	lda 	<connectedStatus
	beq 	COMMAND_SERVER_NOT_CONNECTED
	; since we are already connected, do a QUIT before closing ports and reconnecting 
	lda 	<networkPath
	leax 	strQuitChangingServer,PCR 
	lbsr 	WRITE_CRLF_STRING
	leax 	strUserMsgChangingServer,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	ldx 	#120
	os9 	F$Sleep 
	lbsr 	DRIVEWIRE_RESET 	; close any potential open paths, reset variables 
	lbsr 	DESTINATION_INITIALIZE_ARRAY
	lbsr 	STATUS_BAR_UPDATE
COMMAND_SERVER_NOT_CONNECTED
	ldx 	2,S 			; restore X original value from stack 
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	bne 	COMMAND_SERVER_USE_CUSTOM
	; if here, no server specified so connect to user's default server 
	leax 	strUserMsgDefaultServer,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	leax 	userServerDefault,U 
	stx 	<serverCmdPtr
	bra 	COMMAND_SERVER_USE_DEFAULT

COMMAND_SERVER_USE_CUSTOM
	stx 	<serverCmdPtr 		; save pointer to server param 
	lbsr 	CHECK_FOR_PORT_NUMBER
	bcc 	COMMAND_SERVER_PORT_ALREADY_PRESENT
	; no port specified so append the default onto the command 
	lda 	#':' 
	sta 	,X+
	ldd 	#"66"
	std 	,X++
	ldd 	#"67"
	std 	,X++
	lda 	#C$CR 
	clrb 
	std 	,X
COMMAND_SERVER_USE_DEFAULT
COMMAND_SERVER_PORT_ALREADY_PRESENT
	; build the command to connect to server 
	leay 	outputBuffer,U 
	leax 	strIRCserverConnect,PCR
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; setup drivewire if it hasnt already been initialized
	lbsr 	DRIVEWIRE_SETUP 	; setup a new path to drivewire server 
	lbcs 	COMMAND_SERVER_ERROR_NO_DRIVEWIRE
	; send command to drivewire server 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; ok we sent connect command. let user know.
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strUserMsgTrying,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	; let mainloop know we are waiting on connection confirmation. setup timeout signal 
	clr 	<connectTimeoutFlag
	clr 	<connectedStatus
	inc 	<connectPendingFlag
	lda 	<nilPath
	bmi 	COMMAND_SERVER_EXIT
	ldb 	#SS.FSet  	; code $C7
	ldx 	#1800 		; 30 seconds 
	ldy 	#0
	ldu 	#connect_timeout_signal
	os9 	I$SetStt 
COMMAND_SERVER_EXIT
	puls 	D,X,Y,U,PC 

COMMAND_SERVER_ERROR_NO_DRIVEWIRE
	leax 	strErrorDWPath1,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	leax 	strErrorDWPath2,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE

COMMAND_SERVER_ERROR_INVALID_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE

	puls 	D,X,Y,U,PC 


; -----------------------------------
; Exit the IRC client back to nitros9
; -----------------------------------
COMMAND_EXIT
	pshs 	Y,X,D 

	lda 	<connectedStatus
	beq 	COMMAND_EXIT_CLOSE_ALL_PATHS
	leay 	outputBuffer,U 
	leax 	strIRCserverQuit,PCR 
	lbsr 	STRING_COPY_RAW
	ldd 	#" :"
	std 	,Y++
	leax 	userQuitMessage,U 
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	; write quit command to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
; wait about a second to make sure server got our command 
	ldx 	#120
	os9 	F$Sleep 
COMMAND_EXIT_CLOSE_ALL_PATHS
	; close /NIL path 
	lda 	<nilPath 
	bmi 	COMMAND_EXIT_SKIP_NIL_CLOSE
	os9 	I$Close 
COMMAND_EXIT_SKIP_NIL_CLOSE
	; close all the text IO window paths 
	lda 	<inputbarPath
	os9 	I$Close 
	lda 	<statusbarPath
	os9 	I$Close 
	lda 	<chatlogPath
	os9 	I$Close 
	; finally close the drivewire network path 
	lda 	<networkPath
	bmi 	COMMAND_EXIT_SKIP_NETWORK_CLOSE
	os9 	I$Close 		; just in case the path is still somehow open 
COMMAND_EXIT_SKIP_NETWORK_CLOSE
	clrb 
	os9 	F$Exit 

	puls 	D,X,Y,PC 

; ----------------------------------------------------
; QUIT from an IRC server (with optional quit message)
; ----------------------------------------------------
COMMAND_QUIT 
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_QUIT_EXIT

	; send actual command word 
	leay 	outputBuffer,U 
	leax 	strIRCserverQuit,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#':'
	sta 	,Y+
	ldx 	2,S 		; get X value from stack 
	; figure out if there is a quit message 
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR
	beq 	COMMAND_QUIT_NO_MSG
	; copy over quit msg 
	lbsr 	STRING_COPY_CR
	bra 	COMMAND_QUIT_SEND_NETWORK

COMMAND_QUIT_NO_MSG
	; no quit message specified so use default 
	leax 	userQuitMessage,U 
	lbsr 	STRING_COPY_CR
COMMAND_QUIT_SEND_NETWORK
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING

	ldx 	#120
	os9 	F$Sleep 	; wait about two seconds to make sure server got our command 
COMMAND_QUIT_EXIT
	puls 	D,X,Y,PC 


; ----------------------------------------------------------
; join an irc channel 
; ----------------------------------------------------------
COMMAND_JOIN
	pshs 	Y,X,D 

 IFDEF debug_mode
 ;	leax 	strJoinStart,PCR 
; 	lbsr 	PRINT_CHATLOG_NULL_STRING
; 	ldx 	2,S 
 ENDC 
	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_JOIN_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#'#'
	bne 	COMMAND_JOIN_INVALID_CHANNEL_NAME
	stx 	<serverCmdPtr
	; first check to see if they are trying to join a channel they already are in 
	lbsr 	DESTINATION_FIND_ENTRY
	bcc 	COMMAND_JOIN_ERROR_ALREADY_JOINED
	; nope, do we have room for another channel in the destination array though?
	; since the IRC server parser actually adds the entry to the list, we still have 
	; to check here first, otherwise we could be joined to a channel and getting traffic 
	; from it without being able to talk in it or PART it.
	lbsr 	DESTINATION_FIND_EMPTY 
	lbcs 	COMMAND_JOIN_ERROR_CHANLIST_FULL
	; all good. build the server command string 
	leay 	outputBuffer,U
	leax 	strJOINkeyword,PCR
	lbsr 	STRING_COPY
	lda 	#C$SPAC
	sta 	,Y+
	ldx 	<serverCmdPtr
	; add the channel name to the output string 
	lbsr 	PARAM_COPY
	ldd 	#cr_lf
	std 	,Y++ 		; terminate it with a CR+LF 
	; send the irc server command 
	lda 	<networkPath 
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
 IFDEF debug_mode
 ;	leax 	strJoinEnd,PCR 
 ;	lbsr 	PRINT_CHATLOG_NULL_STRING
 ;	ldx 	2,S 
 ENDC 
	puls 	D,X,Y,PC 

COMMAND_JOIN_ERROR_CHANLIST_FULL
	leax 	strErrorMsgDestListFull,PCR 
	bra 	COMMAND_JOIN_ERROR_EXIT

COMMAND_JOIN_ERROR_ALREADY_JOINED
	leax 	strErrorJoinedAlready,PCR 
	bra 	COMMAND_JOIN_ERROR_EXIT

COMMAND_JOIN_INVALID_CHANNEL_NAME
	leax 	strErrorInvalidChanName,PCR 
COMMAND_JOIN_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_JOIN_EXIT
	puls 	D,X,Y,PC 

; ----------------------------------------------------------
; leave an irc channel 
; ----------------------------------------------------------
COMMAND_PART
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_PART_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	; check if user specified a channel or part message 
	cmpa 	#'#'
	beq 	COMMAND_PART_GET_MANUAL_CHAN
	; if here, use active channel name 
	stx 	<serverCmdPtr 	; save pointer to part msg 
	lbsr 	DESTINATION_GET_ACTIVE
	bcs 	COMMAND_PART_ERROR_NO_ACTIVE 	; if carry set, no active destination 
	; X now should be pointing at currently active channel name 
	leay 	destChanName,U 
	lbsr 	STRING_COPY
	bra 	COMMAND_PART_DO_MSG

COMMAND_PART_GET_MANUAL_CHAN
	leay 	destChanName,U 
	lbsr 	PARAM_COPY
	; move to next param (or just CR if its the end)
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	stx 	<serverCmdPtr
COMMAND_PART_DO_MSG
	; setup the PART server command 
	leay 	outputBuffer,U 
	leax 	strIRCserverPart,PCR
	lbsr 	STRING_COPY_RAW
	leax 	destChanName,U 
	lbsr 	STRING_COPY
	; do we have a part message?
	ldx 	<serverCmdPtr
	lda 	,X 
	cmpa 	#C$CR 
	beq 	COMMAND_PART_SKIP_MSG
	; add in part msg 
	ldd 	#" :"
	std 	,Y++
	lbsr 	STRING_COPY_CR
COMMAND_PART_SKIP_MSG
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; send to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	puls 	D,X,Y,PC 

COMMAND_PART_ERROR_NO_ACTIVE
	leax 	strErrorMsgNoActiveWin,PCR
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_PART_EXIT
	puls 	D,X,Y,PC 

; ---------------------------------------------------
; send a private message
; ---------------------------------------------------
COMMAND_MSG
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	lbcs 	COMMAND_MSG_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	lbeq 	COMMAND_MSG_MISSING_PARAMS
	; copy destination nickname 
	leay 	destNickname,U 
	lbsr 	PARAM_COPY
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_MSG_MISSING_PARAMS
	stx 	<serverCmdPtr
	; setup PRIVMDG command 
	leay 	outputBuffer,U 
	leax 	strIRCserverMsg,PCR
	lbsr 	STRING_COPY
	lda 	#C$SPAC
	sta 	,Y+
	leax 	destNickname,U 
	lbsr 	STRING_COPY
	ldd 	#" :"
	std 	,Y++
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; now write out the command to the server 
	lda 	<networkPath
	leax  	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; now format it for printing to screen 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#'>'
	sta 	,Y+
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	destNickname,U 
	lbsr 	STRING_COPY
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#'<'
	sta 	,Y+
	lda 	#C$SPAC
	sta 	,Y+
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	puls 	D,X,Y,PC 

COMMAND_MSG_MISSING_PARAMS
	leax  	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_MSG_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; change nickname 
; ------------------------------------------------------
COMMAND_NICK
	pshs 	Y,X,D

	lda 	<connectedStatus
	beq 	COMMAND_NICK_ERROR_NOT_CONNECTED
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_NICK_ERROR_MISSING_PARAMS	
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	leax 	strIRCserverNick,PCR 
	lbsr 	STRING_COPY
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	puls 	D,X,Y,PC 

COMMAND_NICK_ERROR_NOT_CONNECTED
	leax 	strErrorNotConnected,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_NICK_EXIT

COMMAND_NICK_ERROR_MISSING_PARAMS
	leax  	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_NICK_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; start a private conversation with new nickname as 
; destination 
; ------------------------------------------------------
COMMAND_QUERY
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_QUERY_EXIT

	; first check to see if they already have an open query for that nickname 
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#'#'
	beq 	COMMAND_QUERY_INVALID_SYNTAX
	stx 	<serverCmdPtr
	lbsr 	DESTINATION_FIND_ENTRY
	bcc 	COMMAND_QUERY_ALREADY_EXISTS
	; if here, then its a new nickname. add it to destination list if not full 
	clrb 
	lbsr 	DESTINATION_ADD_ENTRY 
	bcs 	COMMAND_QUERY_ERROR_LIST_FULL
	puls 	D,X,Y,PC 

COMMAND_QUERY_ALREADY_EXISTS
	; since nick already exists, move active destination to there and redraw statusbar
	std 	destOffset,U 
	lbsr 	STATUS_BAR_UPDATE
	bra 	COMMAND_QUERY_EXIT

COMMAND_QUERY_ERROR_LIST_FULL
	leax 	strErrorMsgDestListFull,PCR 
	bra 	COMMAND_QUERY_ERROR_EXIT

COMMAND_QUERY_INVALID_SYNTAX
	leax 	strErrorMsgInvalid,PCR
COMMAND_QUERY_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_QUERY_EXIT
	puls 	D,X,Y,PC 

; ----------------------------------------------------------
COMMAND_ACTION
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	lbcs 	COMMAND_ACTION_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	lbeq 	COMMAND_ACTION_MISSING_PARAMS
	stx 	<serverCmdPtr 		; save pointer to action string 
	; build string to send to server 
	leay 	outputBuffer,U 
	leax 	strIRCserverMsg,PCR 
	lbsr 	STRING_COPY
	lda 	#C$SPAC
	sta 	,Y+
	lbsr 	DESTINATION_GET_ACTIVE 	; get pointer to current destination 
	lbcs 	COMMAND_ACTION_NO_ACTIVE_CHAN
	; X should now be pointing to string name of destination 
	stx 	<outputBufferPtr
	lbsr 	STRING_COPY
	ldd 	#" :"
	std 	,Y++
	lda 	#$01 		; IRC control code for CTCP 
	sta 	,Y+
	leax 	strIRCserverAction,PCR 
	lbsr 	STRING_COPY
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	sta 	,Y+ 		; add closing control code for CTCP action 
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; now write out the command to the server 
	lda 	<networkPath
	leax  	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; now format it for printing to screen 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#'{'
	sta 	,Y+
	; check if action is going to a nick or channel and set color accordingly 
	ldx 	<outputBufferPtr
	ldb 	,X 
	cmpb 	#'#'
	bne 	COMMAND_ACTION_NICK_DEST
	lda 	#colorChanName
	bra 	COMMAND_ACTION_CHANGE_COLOR
COMMAND_ACTION_NICK_DEST
	lda 	#colorNickChan
COMMAND_ACTION_CHANGE_COLOR
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	STRING_COPY
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"} "
	std 	,Y++
	ldd 	#"* "
	std 	,Y++
	lda 	#colorYourNick
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	serverYourNick,U 
	lbsr 	STRING_COPY 
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#C$SPAC 
	sta 	,Y+
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR	
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	puls 	D,X,Y,PC 

COMMAND_ACTION_NO_ACTIVE_CHAN
	leax 	strErrorMsgNoActiveWin,PCR
	bra 	COMMAND_ACTION_ERROR_EXIT

COMMAND_ACTION_MISSING_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
COMMAND_ACTION_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_ACTION_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; request a WHOIS on a nickname 
; ------------------------------------------------------
COMMAND_WHOIS
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_WHOIS_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	bne 	COMMAND_WHOIS_CHECK_FOR_CHAN	
	; if here, use the active destination instead 
	lbsr 	DESTINATION_GET_ACTIVE
	bcs 	COMMAND_WHOIS_NO_ACTIVE
	lda 	,X 
COMMAND_WHOIS_CHECK_FOR_CHAN
	cmpa 	#'#'
	beq 	COMMAND_WHOIS_INVALID_PARAMS
	stx 	<outputBufferPtr
	; build our server command now 
	leay 	outputBuffer,U 
	leax 	strIRCserverWhois,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<outputBufferPtr
	lbsr 	PARAM_COPY
	lda 	#C$SPAC 
	sta 	,Y+
	ldx 	<outputBufferPtr
	lbsr 	PARAM_COPY 		; send nickname in whois twice to get idle/signon info msgs 
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	; now write out the command to the server 
	lda 	<networkPath
	leax  	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	puls 	D,X,Y,PC 

COMMAND_WHOIS_NO_ACTIVE
	leax 	strErrorMsgNoActiveWin,PCR 
	bra 	COMMAND_WHOIS_ERROR_EXIT

COMMAND_WHOIS_INVALID_PARAMS
	leax 	strErrorMsgInvalid,PCR 
COMMAND_WHOIS_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_WHOIS_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; close a destination window
; ------------------------------------------------------
COMMAND_CLOSE 
	pshs 	Y,X,D 

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	bne 	COMMAND_CLOSE_MANUAL_DEST
	; if here, use the active destination instead 
	lbsr 	DESTINATION_GET_ACTIVE
	bcs 	COMMAND_CLOSE_NO_ACTIVE
	lda 	,X 
	cmpa 	#'#'
	beq  	COMMAND_CLOSE_PART_CHAN
	; if here, its the active nickname window they want to close. since we already 
	; are pointing at it's entry, write $0000 to mark it as available and move to next 
	; available destination to be active if any. then update status bar 
	ldd 	#0
	std 	,X 
COMMAND_CLOSE_NEXT_DEST_AND_EXIT
	lbsr 	COMMAND_NEXT_DESTINATION
	puls 	D,X,Y,PC 

COMMAND_CLOSE_MANUAL_DEST
	cmpa 	#'#'
	beq 	COMMAND_CLOSE_PART_CHAN 	; if they are specifying a channel name, PART it 
	lbsr 	DESTINATION_FIND_ENTRY 	; attempt to find entry for specified nickname 
	bcs 	COMMAND_CLOSE_ERROR_NOT_FOUND
	leax  	destArray,U 
	leax 	D,X 
	ldy 	#0
	sty 	,X  			; zero out entry to free it up 
	cmpd 	destOffset,U 		; check if entry we just deleted is current active dest 
	bne 	COMMAND_CLOSE_EXIT 	; if not, we are done. peace out yo 
	bra 	COMMAND_CLOSE_NEXT_DEST_AND_EXIT 	; otherwise, move next dest and exit 

COMMAND_CLOSE_PART_CHAN
	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_CLOSE_EXIT
	; setup server command in outputBuffer 
	stx 	<outputBufferPtr
	leay 	outputBuffer,U 
	leax 	strIRCserverPart,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<outputBufferPtr
	lbsr 	PARAM_COPY
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; send to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; for channel parts, the server parsing code does the actual removal from dest list
	; so we are done
COMMAND_CLOSE_EXIT  
	puls 	D,X,Y,PC  	

COMMAND_CLOSE_ERROR_NOT_FOUND
	leax 	strErrorCloseDestNotFound,PCR 
	bra 	COMMAND_CLOSE_ERROR_EXIT

COMMAND_CLOSE_NO_ACTIVE
	leax 	strErrorMsgNoActiveWin,PCR
COMMAND_CLOSE_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	puls 	D,X,Y,PC 

; ---------------------------------------------------------------
; send a NOTICE message to an IRC user nickname 
; ---------------------------------------------------------------
COMMAND_NOTICE
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_NOTICE_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_NOTICE_ERROR_MISSING_PARAMS
	stx 	<outputBufferPtr
	; build the server command 
	leay 	outputBuffer,U 
	leax 	strIRCserverNotice,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<outputBufferPtr
	lbsr 	PARAM_COPY
	ldd 	#" :"
	std 	,Y++
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_NOTICE_ERROR_MISSING_PARAMS
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	; send finished command to network/server 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; now build output string to print to chatlog 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice 
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"->"
	std 	,Y++
	lda 	#colorNickChan
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	ldx 	<outputBufferPtr
	lbsr 	PARAM_COPY
	lda 	#colorNotice
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"<-"
	std 	,Y++
	lda 	#C$SPAC 
	sta 	,Y+
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf 
	std 	,Y++ 
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

	puls 	D,X,Y,PC 

COMMAND_NOTICE_ERROR_MISSING_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_NOTICE_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; kick (or try to kick) out a user from a channel
; ------------------------------------------------------
COMMAND_KICK 
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_KICK_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	leax 	strIRCserverKick,PCR 
	lbsr 	STRING_COPY_RAW
	cmpa 	#C$CR 
	beq 	COMMAND_KICK_ERROR_MISSING_PARAMS
	cmpa 	#'#'
	beq 	COMMAND_KICK_MANUAL_CHAN_SPECIFIED
	; use current active destination 
	lbsr 	DESTINATION_GET_ACTIVE 		; get pointer to current destination 
	lbcs 	COMMAND_KICK_NO_ACTIVE_CHAN	
	lbsr 	PARAM_COPY 			; copy channel name in to output string 
	ldx 	<serverCmdPtr
	bra 	COMMAND_KICK_CHAN_COPIED

COMMAND_KICK_MANUAL_CHAN_SPECIFIED
	lbsr 	PARAM_COPY 			; copy manual chan name in 	
COMMAND_KICK_CHAN_COPIED
	lda 	#C$SPAC
	sta 	,Y+
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip white space to find nickname to kick 
	cmpa 	#C$CR 
	beq 	COMMAND_KICK_ERROR_MISSING_PARAMS
	lbsr 	PARAM_COPY 			; copy nickname in 
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip whitespace to CR or kick message 
	cmpa 	#C$CR 
	beq 	COMMAND_KICK_NO_MSG
	ldd 	#" :"
	std 	,Y++
	lbsr 	STRING_COPY_CR
COMMAND_KICK_NO_MSG
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 		; NULL terminate 
	; send command to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; all done. return 
	puls 	D,X,Y,PC 

COMMAND_KICK_ERROR_MISSING_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_KICK_EXIT

COMMAND_KICK_NO_ACTIVE_CHAN
	leax 	strErrorMsgNoActiveWin,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_KICK_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; this sections has multiple entry points for setting 
; various channel modes like +o -v +b etc 
; Entry: X = pointer to command parameters 
; ------------------------------------------------------
COMMAND_OP 
	pshs 	Y,X,D 
	ldd 	#"+o"
	bra 	COMMAND_MODES_ALL

COMMAND_DEOP 
	pshs 	Y,X,D 
	ldd 	#"-o"
	bra 	COMMAND_MODES_ALL

COMMAND_VOICE 
	pshs 	Y,X,D 
	ldd 	#"+v"
	bra 	COMMAND_MODES_ALL

COMMAND_DEVOICE 
	pshs 	Y,X,D 
	ldd 	#"-v"
	bra 	COMMAND_MODES_ALL

COMMAND_BAN
	pshs 	Y,X,D 
	ldd 	#"+b"
	bra 	COMMAND_MODES_ALL

COMMAND_UNBAN
	pshs 	Y,X,D 
	ldd 	#"-b"
	bra 	COMMAND_MODES_ALL

COMMAND_MODE 
	pshs 	Y,X,D 
	ldd 	#0

COMMAND_MODES_ALL
	std 	strModeOperators,U  		; save our flag string or zero for custom MODE flags 
	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_MODES_EXIT
	leay 	outputBuffer,U 
	leax 	strIRCserverMode,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	2,S 
	; copy chan name into outputbuffer from either command or active dest 
	lbsr 	COPY_CHAN_FROM_CMD_OR_ACTIVE
	bcs 	COMMAND_MODES_NO_ACTIVE_CHAN
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_MODES_ERROR_MISSING_PARAMS
	lda 	#C$SPAC 
	sta 	,Y+
	ldd 	strModeOperators,U 
	bne 	COMMAND_MODES_ALL_SPECIFIC_FLAG
	lbsr 	STRING_COPY_CR
	bra 	COMMAND_MODES_ALL_FINISH

COMMAND_MODES_ALL_SPECIFIC_FLAG
	std 	,Y++
	lda 	#C$SPAC 
	sta 	,Y+
	lbsr 	PARAM_COPY
COMMAND_MODES_ALL_FINISH
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; send command to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; all done. return 
	puls 	D,X,Y,PC 	

COMMAND_MODES_ERROR_MISSING_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_MODES_EXIT

COMMAND_MODES_NO_ACTIVE_CHAN
	leax 	strErrorMsgNoActiveWin,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_MODES_EXIT
	puls 	D,X,Y,PC 

; -------------------------------------------------------
; change channel topic if you have operator privledges 
; -------------------------------------------------------
COMMAND_TOPIC 
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_TOPIC_EXIT

	leay 	outputBuffer,U 
	leax 	strIRCserverTopic,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	2,S  			; get back pointer to parameters from stack 
	; skip any whitespace, check if X points to manual chan name. if so, copies it, 
	; otherwise tries to use active destination 
	lbsr 	COPY_CHAN_FROM_CMD_OR_ACTIVE
	bcs 	COMMAND_TOPIC_ERROR_NO_ACTIVE_CHAN
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_TOPIC_REQUEST_CURRENT
	; if here, user is trying to SET a new topic 
	ldd 	#" :"
	std 	,Y++
	lbsr 	STRING_COPY_CR
	bra 	COMMAND_TOPIC_SEND_OUTPUT

COMMAND_TOPIC_REQUEST_CURRENT
COMMAND_TOPIC_SEND_OUTPUT
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; send to network path 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING

	puls 	D,X,Y,PC 

COMMAND_TOPIC_ERROR_MISSING_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
	bra 	COMMAND_TOPIC_PRINT_ERROR_EXIT

COMMAND_TOPIC_ERROR_NO_ACTIVE_CHAN
	leax 	strErrorMsgNoActiveWin,PCR 
COMMAND_TOPIC_PRINT_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_TOPIC_EXIT 
	puls 	D,X,Y,PC 	

; -------------------------------------------------------
; request list of nicnames in a particular channel 
; -------------------------------------------------------
COMMAND_NAMES 
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_NAMES_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	bne 	COMMAND_NAMES_MANUAL_CHAN
	; use active channel if exists 
	lbsr 	DESTINATION_GET_ACTIVE 		; get pointer to current destination 
	bcc 	COMMAND_NAMES_SETUP_NAMES
	bra 	COMMAND_NAMES_ERROR_NO_ACTIVE_CHAN

COMMAND_NAMES_MANUAL_CHAN
	cmpa 	#'#'
	bne 	COMMAND_NAMES_ERROR_INVALID_PARAM
COMMAND_NAMES_SETUP_NAMES
	stx 	<serverCmdPtr 			; save pointer to channel name 
	; setup NAMES command 
	leay 	outputBuffer,U 
	leax 	strIRCserverNames,PCR
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	; send to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING

	; let the IRC server parser know to defintely display results since it was requested by user 
	inc 	<namesRequestedFlag 

	puls 	D,X,Y,PC 


COMMAND_NAMES_ERROR_NO_ACTIVE_CHAN
	leax 	strErrorMsgNoActiveWin,PCR 
	bra 	COMMAND_NAMES_ERROR_EXIT

COMMAND_NAMES_ERROR_INVALID_PARAM
	leax 	strErrorMsgInvalid,PCR 
COMMAND_NAMES_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_NAMES_EXIT
	puls 	D,X,Y,PC 


; -------------------------------------------------------
; quick way to leave a channel and then rejoin it again 
; immediately afterwards automatically 
; -------------------------------------------------------
COMMAND_CYCLE
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_CYCLE_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	bne 	COMMAND_CYCLE_MANUAL_CHAN
	; use active channel if exists 
	lbsr 	DESTINATION_GET_ACTIVE 		; get pointer to current destination 
	bcc 	COMMAND_CYCLE_SETUP_PART
	bra 	COMMAND_CYCLE_NO_ACTIVE_CHAN

COMMAND_CYCLE_MANUAL_CHAN
	cmpa 	#'#'
	bne 	COMMAND_CYCLE_ERROR_INVALID_PARAM
COMMAND_CYCLE_SETUP_PART
	stx 	<serverCmdPtr 			; save pointer to channel name 
	; send PART command 
	leay 	outputBuffer,U 
	leax 	strIRCserverPart,PCR
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	leax 	strCycleChanMsg,PCR 
	lbsr 	STRING_COPY_RAW
	; send to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	ldx 	#120
	os9 	F$Sleep  		; give server time to process PART before trying to rejoin 
	; setup JOIN command 
	leay 	outputBuffer,U
	leax 	strIRCserverJoin,PCR
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; send to network 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING

	puls 	D,X,Y,PC 

COMMAND_CYCLE_NO_ACTIVE_CHAN
	leax 	strErrorMsgNoActiveWin,PCR 
	bra 	COMMAND_CYCLE_ERROR_EXIT

COMMAND_CYCLE_ERROR_INVALID_PARAM
	leax 	strErrorMsgInvalid,PCR 
COMMAND_CYCLE_ERROR_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_CYCLE_EXIT
	puls 	D,X,Y,PC 

; -----------------------------------------------------
; Sends commands to NickServ. If no parameters are given, assumes you just want to auto-identify
; and if a password is set, will automatically send the IDENTIFY command with it. Otherwise
; command assumes they want to manually send commands to nickserv and sends the entire expression
; as a PRIVMSG to NickServ
; -----------------------------------------------------
COMMAND_NICKSERV
	pshs  	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	lbcs 	COMMAND_NICKSERV_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	lbeq 	COMMAND_NICKSERV_MISSING_PARAMS
	stx 	<serverCmdPtr
	leay  	strIDENTIFYkeyword,PCR 
	lbsr  	COMPARE_PARAM
	bcs  	COMMAND_NICKSERV_PARAM_NOT_IDENTIFY
	; if here, user specified identify nickserv command. check for manual password param
	lbsr   FIND_NEXT_SPACE_NULL_CR 	; skip over identify keyword
	lbsr  	FIND_NEXT_NONSPACE_CHAR 	; skip whitespace 
	cmpa  	#C$CR  
	beq  	COMMAND_NICKSERV_TRY_AUTOLOGIN
	; if here, user entered a manual password with identify so treat the whole command as manaul entry
COMMAND_NICKSERV_PARAM_NOT_IDENTIFY
	; send the entire command as a manual command as PRIVMSG to NickServ 
	leay 	outputBuffer,U 
	leax 	strIRCserverMsg,PCR
	lbsr 	STRING_COPY_RAW
	lda 	#C$SPAC
	sta 	,Y+
	leax 	strNICKSERVkeyword,PCR  
	lbsr 	STRING_COPY_RAW
	ldd 	#" :"
	std 	,Y++
	ldx 	<serverCmdPtr
	lbsr  	STRING_COPY_CR
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; now write out the command to the server 
	lda 	<networkPath
	leax  	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; now let user know we sent it
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax  	strUserMsgNickServCustom,PCR 
	lbsr  	STRING_COPY_RAW
	lda 	#colorNormal
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_WITH_WORD_WRAP
	puls 	D,X,Y,PC 

COMMAND_NICKSERV_TRY_AUTOLOGIN
	lda  	<nickServPassFlag
	beq  	COMMAND_NICKSERV_TRY_AUTOLOGIN_NOT_SETUP
	leax  	userNickservPass,U 
	lbsr  	NICKSERV_SEND_IDENTIFY
	bra  	COMMAND_NICKSERV_EXIT

COMMAND_NICKSERV_TRY_AUTOLOGIN_NOT_SETUP
	leax  	strErrorNickServNoPass,PCR 
	bra  	COMMAND_NICKSERV_PRINT_MSG_EXIT

COMMAND_NICKSERV_MISSING_PARAMS
	leax  	strErrorMsgMissingParam,PCR 
COMMAND_NICKSERV_PRINT_MSG_EXIT
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_NICKSERV_EXIT
	puls 	D,X,Y,PC 


; ------------------------------------------------------
; send a raw string directly to the server. mostly for 
; testing/debugging or a command isnt supported 
; ------------------------------------------------------
COMMAND_RAW
	pshs 	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_RAW_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq 	COMMAND_RAW_ERROR_MISSING_PARAM
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_CR 
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	; send it to network now 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING

	puls 	D,X,Y,PC 

COMMAND_RAW_ERROR_MISSING_PARAM
	leax 	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_RAW_EXIT
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; toggle to the previous destination in the array if any 
; automatically updates statusbar 
; ------------------------------------------------------
COMMAND_PREV_DESTINATION
	pshs 	Y,X,D 

	leax 	destArray,U 
	ldd 	destOffset,U 
COMMAND_PREV_DESTINATION_MOVE_BACKWARDS
	subd 	#nickChanByteSize
	bcc 	COMMAND_PREV_DESTINATION_CHECK_ENTRY
	; if here, we need to loop back passed 0
	ldd 	#destArraySz-nickChanByteSize
COMMAND_PREV_DESTINATION_CHECK_ENTRY
	ldy 	D,X 
	bne 	COMMAND_PREV_DESTINATION_FOUND
	; if here, we found an empty entry.
	cmpd 	destOffset,U  	; check if we've looped through the whole array 
	bne 	COMMAND_PREV_DESTINATION_MOVE_BACKWARDS
	; if here, we went through whole array and found no destinations.
	; re-init the offset to beginning to be ready for when one is added 
	ldd 	#0
	std 	destOffset,U 
	sta 	<activeDestFlag
	lbsr 	STATUS_BAR_UPDATE
	orcc 	#1
	puls 	D,X,Y,PC 

COMMAND_PREV_DESTINATION_FOUND
	std 	destOffset,U 
	lda 	#1
	sta 	<activeDestFlag
	lbsr 	STATUS_BAR_UPDATE
	andcc 	#$FE 
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; toggle to the next destination in the array if any
; automatically updates statusbar 
; ------------------------------------------------------
COMMAND_NEXT_DESTINATION
	pshs 	Y,X,D 

	leax 	destArray,U 
	ldd 	destOffset,U 
COMMAND_NEXT_DESTINATION_MOVE_FORWARD
	addd 	#nickChanByteSize		; jump to next entry to check 
	cmpd 	#destArraySz  		; check if we need to loop back to start 
	bne 	COMMAND_NEXT_DESTINATION_CHECK_ENTRY
	; if here we need to reset offset to beginning 
	ldd 	#0
COMMAND_NEXT_DESTINATION_CHECK_ENTRY
	ldy 	D,X 
	bne 	COMMAND_NEXT_DESTINATION_FOUND
	; if here, we found an empty entry.
	cmpd 	destOffset,U  	; check if we've looped through the whole array 
	bne 	COMMAND_NEXT_DESTINATION_MOVE_FORWARD
	; if here, the array was empty so reset pointers/variables 
	ldd 	#0
	std 	destOffset,U 
	sta 	<activeDestFlag
	lbsr 	STATUS_BAR_UPDATE
	orcc 	#1  		; something went wrnog. didnt find any destinations 
	puls 	D,X,Y,PC 

COMMAND_NEXT_DESTINATION_FOUND
	std 	destOffset,U 
	lda 	#1
	sta 	<activeDestFlag
	lbsr 	STATUS_BAR_UPDATE
	andcc 	#$FE
	puls 	D,X,Y,PC 

; ------------------------------------------------------
; set internal settings like default nickname, username,
; etc. 
; ------------------------------------------------------
COMMAND_SET 
	pshs 	Y,X,D 

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	strNICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_NICKNAME
	leay 	strREALNAMEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_REALNAME
	leay 	strUSERkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_USERNAME
	leay 	strCOLORkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_COLOR
	leay 	strQUITMSGkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_QUIT_MSG
	leay 	strVERSIONkeyword,PCR 
	lbsr  	COMPARE_PARAM
	lbcc 	COMMAND_SET_VERSION_REPLY
	leay 	strSERVERkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_DEFAULT_SERVER
	leay 	strTIMESTAMPkeyword,PCR
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_TIMESTAMP_DISPLAY
	leay 	strMOTDkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_MOTD_DISPLAY
	leay 	strNAMESkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_NAMES_ON_JOIN_DISPLAY
	leay  	strNICKSERVkeyword,PCR 
	lbsr  	COMPARE_PARAM
	lbcc  	COMMAND_SET_NICKSERV
	lbra 	COMMAND_SET_EXIT 

COMMAND_SET_NICKNAME
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the NICK keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	currentNickname,U 
	lbsr 	PARAM_COPY
	lda 	#C$CR 
	sta 	,Y
	; tell the user its changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultNick,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	currentNickname,U 
	lbsr 	STRING_COPY_CR
	lbra 	COMMAND_SET_PRINT_NOTE

COMMAND_SET_REALNAME
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the NAME keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	currentRealname,U 
	lbsr 	STRING_COPY_CR
	lda 	#C$CR 
	sta 	,Y
	; tell the user its changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultRealname,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	currentRealname,U 
	lbsr 	STRING_COPY_CR
	lbra 	COMMAND_SET_PRINT_NOTE

COMMAND_SET_USERNAME
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the USER keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	currentUsername,U 
	lbsr 	PARAM_COPY
	lda 	#C$CR 
	sta 	,Y
	; tell the user its changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultUsername,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	currentUsername,U 
	lbsr 	STRING_COPY_CR
	lbra 	COMMAND_SET_PRINT_NOTE

COMMAND_SET_QUIT_MSG
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the QUITMSG keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	userQuitMessage,U 
	lbsr 	STRING_COPY_CR
	lda 	#C$CR 
	sta 	,Y 
	; tell the user the value has been changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultQuitMsg,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	userQuitMessage,U 
	lbsr 	STRING_COPY_CR
	lbra 	COMMAND_SET_PRINT_RESULT

COMMAND_SET_VERSION_REPLY
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the VERSION keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	userVersionReply,U 
	lbsr 	STRING_COPY_CR
	lda 	#C$CR 
	sta 	,Y 
	; tell the user the value has been changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultCTCPver,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	userVersionReply,U 
	lbsr 	STRING_COPY_CR
	lbra 	COMMAND_SET_PRINT_RESULT

COMMAND_SET_DEFAULT_SERVER
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the SERVER keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	userServerDefault,U 
	lbsr 	STRING_COPY_CR
	lda 	#C$CR 
	sta 	,Y 
	; tell the user the value has been changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultServer,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	userServerDefault,U 
	lbsr 	STRING_COPY_CR
	lbra 	COMMAND_SET_PRINT_NOTE

COMMAND_SET_TIMESTAMP_DISPLAY
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the TIMESTAMP keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	strTRUEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_TIMESTAMP_DISPLAY_TRUE
	leay 	strONkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_TIMESTAMP_DISPLAY_TRUE
	leay 	strFALSEkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_TIMESTAMP_DISPLAY_FALSE
	leay 	strOFFkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_TIMESTAMP_DISPLAY_FALSE
	lbra 	COMMAND_SET_ERROR_INVALID_PARAM

COMMAND_SET_TIMESTAMP_DISPLAY_TRUE
	lda 	#1
	sta 	<showTimestampFlag
	leax 	strMsgTimestampEnabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_TIMESTAMP_DISPLAY_FALSE
	clr 	<showTimestampFlag
	leax 	strMsgTimestampDisabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT	

COMMAND_SET_MOTD_DISPLAY
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the MOTD keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	strTRUEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_MOTD_DISPLAY_TRUE
	leay 	strONkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_MOTD_DISPLAY_TRUE
	leay 	strFALSEkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_MOTD_DISPLAY_FALSE
	leay 	strOFFkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_MOTD_DISPLAY_FALSE
	lbra 	COMMAND_SET_ERROR_INVALID_PARAM

COMMAND_SET_MOTD_DISPLAY_TRUE
	lda 	#1
	sta 	<printMOTDflag
	leax 	strMsgMOTDenabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_MOTD_DISPLAY_FALSE
	clr 	<printMOTDflag
	leax 	strMsgMOTDdisabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_NAMES_ON_JOIN_DISPLAY
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the NAMES keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	strTRUEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NAMES_ON_JOIN_DISPLAY_TRUE
	leay 	strONkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NAMES_ON_JOIN_DISPLAY_TRUE
	leay 	strFALSEkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NAMES_ON_JOIN_DISPLAY_FALSE
	leay 	strOFFkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NAMES_ON_JOIN_DISPLAY_FALSE
	lbra 	COMMAND_SET_ERROR_INVALID_PARAM

COMMAND_SET_NAMES_ON_JOIN_DISPLAY_TRUE
	lda 	#1
	sta 	<showNamesOnJoinFlag
	leax 	strMsgNamesOnJoinEnabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_NAMES_ON_JOIN_DISPLAY_FALSE
	clr 	<showNamesOnJoinFlag
	leax 	strMsgNamesOnJoinDisabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_NICKSERV
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the NICKSERV keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay  	strAUTOLOGINkeyword,PCR 
	lbsr  	COMPARE_PARAM
	bcc  	COMMAND_SET_NICKSERV_AUTOLOGIN
	leay  	strPASSkeyword,PCR 
	lbsr  	COMPARE_PARAM
	lbcs  	COMMAND_SET_ERROR_INVALID_PARAM
	; if here, they specified the PASS keyword to set or change nickserv pass
	lbsr 	FIND_NEXT_SPACE_NULL_CR  		; skip over the keyword we just checked
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	userNickservPass,U 
	lbsr 	PARAM_COPY
	; tell the user its changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultNickserv,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	leax 	userNickservPass,U 
	lbsr 	STRING_COPY_RAW
	lda  	<nickServPassFlag
	lbne  	COMMAND_SET_PRINT_NOTE ; a previous password was already set, so flag doesnt need changed. skip
	inc  	<nickServPassFlag
	lbra 	COMMAND_SET_PRINT_NOTE

COMMAND_SET_NICKSERV_AUTOLOGIN
	lbsr 	FIND_NEXT_SPACE_NULL_CR  		; skip over the keyword we just checked
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	strTRUEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NICKSERV_AUTOLOGIN_TRUE
	leay 	strONkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NICKSERV_AUTOLOGIN_TRUE
	leay 	strFALSEkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NICKSERV_AUTOLOGIN_FALSE
	leay 	strOFFkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_NICKSERV_AUTOLOGIN_FALSE
	lbra 	COMMAND_SET_ERROR_INVALID_PARAM 

COMMAND_SET_NICKSERV_AUTOLOGIN_TRUE
	lda  	<nickServPassFlag
	beq   	COMMAND_SET_NICKSERV_AUTOLOGIN_NO_PASS_SET
	lda  	#$80
	sta  	<nickServPassFlag
	leax 	strMsgNickServLoginEnabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_NICKSERV_AUTOLOGIN_FALSE
	lda  	<nickServPassFlag
	beq   	COMMAND_SET_NICKSERV_AUTOLOGIN_NO_PASS_SET
	lda  	#1
	sta  	<nickServPassFlag
	leax 	strMsgNickServLoginDisabled,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_NICKSERV_AUTOLOGIN_NO_PASS_SET
	leax   strErrorNickServLogin,PCR 
	lbsr   PRINT_INFO_ERROR_MESSAGE
	lbra 	COMMAND_SET_EXIT

COMMAND_SET_COLOR
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip over the COLOR keyword 
	lbcs 	COMMAND_SET_MISSING_PARAMS
	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any white space 
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	leay 	strDEFAULTSkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_SET_COLOR_DEFAULTS
	clrb 
	leay 	strBACKGROUNDkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strSTATUSBARkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strTEXTkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strTIMESTAMPkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strCHANNAMEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strQUITkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strYOURNICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strCHANINFOkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strNOTICEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	incb 
	leay 	strCHANNICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	COMMAND_SET_COLOR_FOUND_VALID
	lbra 	COMMAND_SET_ERROR_INVALID_PARAM

COMMAND_SET_COLOR_FOUND_VALID
	stb 	<tempChar
	leay 	configFileVariables,U  
	leay 	B,Y 
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the color value keyword 
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	lbeq 	COMMAND_SET_MISSING_PARAMS
	stx 	<tempPtr 
	; convert ascii decimal number to an 8 bit value
	lbsr 	COPY_STRING_DEC_TO_BYTE 
	lbcs 	COMMAND_SET_ERROR_INVALID_PARAM
	stb 	,Y  				; save new value to correct variable 
	; actually change the cuurent palette value for object requested 
	leay 	outputBuffer,U 
	ldd 	#$1B31
	std 	,Y++
	ldb 	<u8Value 	; grab new value from our previous conversion 
	lda 	<tempChar 	; tempchar is our index value from the compares 
	cmpa 	#1
	bhi 	COMMAND_SET_COLOR_FOREGROUND
	inca 			; compensate for our usable background colors starting at #1
	bra 	COMMAND_SET_COLOR_WRITE_VALUE

COMMAND_SET_COLOR_FOREGROUND
	adda 	#6 		; this ensures we start at palette register #8 
COMMAND_SET_COLOR_WRITE_VALUE
	std 	,Y
	; write our palette change code sequence to window path 
	; first select chatlog window 
	lda 	<chatlogPath
	ldy 	#2 
	leax 	dwSelectCodes,PCR 
	os9 	I$Write
	; now execute palette-change codes 
	leax 	outputBuffer,U 
	ldy 	#4
	os9 	I$Write
	; reselect input bar which should be the normally selected window 
	lda 	<inputbarPath
	ldy 	#2 
	leax 	dwSelectCodes,PCR 
	os9 	I$Write
	; now inform the user 
	leay 	outputBuffer,U 
	lbsr  	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultColor,PCR 
	lbsr 	STRING_COPY_RAW
	leax 	colorNamePtr,PCR 
	ldb 	<tempChar
	lslb 
	ldd 	B,X 
	leax 	0,PCR 
	leax 	D,X 
	lbsr 	STRING_COPY_RAW
	lda 	#colorYourNick
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	ldx 	<tempPtr 		; restore pointer to ascii number to print back to user 
	lbsr 	PARAM_COPY
	bra 	COMMAND_SET_PRINT_RESULT

	; TODO: change these sections to display current setting and instructions for 
	; changing it when they do a /SET <command> with no other params 

COMMAND_SET_COLOR_DEFAULTS
	; write our palette change code sequence to window path 
	; first select chatlog window 
	lda 	<chatlogPath
	ldy 	#2 
	leax 	dwSelectCodes,PCR 
	os9 	I$Write
	lbsr 	INIT_COLOR_SETTINGS
	lbsr 	WRITE_COLOR_CONFIG_TO_PALETTE
	; give user the result 
	leax 	strMsgColorResetDefaults,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_SET_EXIT

COMMAND_SET_PRINT_NOTE
	ldd 	#cr_lf 
	std 	,Y++
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strMsgNewDefaultNextConnect,PCR 
	lbsr 	STRING_COPY_RAW
COMMAND_SET_PRINT_RESULT
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	puls 	D,X,Y,PC 

COMMAND_SET_MISSING_PARAMS
	leax 	strErrorMsgMissingParam,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	leax 	strErrorMsgUseHelp,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_SET_EXIT

COMMAND_SET_ERROR_INVALID_PARAM
	leax 	strErrorMsgInvalid,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	leax 	strErrorMsgUseHelp,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
COMMAND_SET_EXIT
	puls 	D,X,Y,PC 

; ---------------------------------------------------------------------
; save user settings such as color palette and nickname/user/real name
; ---------------------------------------------------------------------
COMMAND_SAVE 
	pshs 	Y,X,D 

	leay 	outputBuffer,U 
	leax 	strMsgConfigSaving,PCR 
	lbsr 	STRING_COPY_RAW
	leax 	configFilePathName,PCR 
	lbsr 	STRING_COPY_CR
	leax 	strMsgConfigDots,PCR
	lbsr 	STRING_COPY_RAW
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

	leax 	configFilePathName,PCR
	os9 	I$Delete 
	bcc 	COMMAND_SAVE_CREATE_NEW
	cmpb 	#E$PNNF 	; its ok if file doesnt exist. ignore that error 
	beq 	COMMAND_SAVE_CREATE_NEW
	lbra 	COMMAND_SAVE_ERROR_DELETING

COMMAND_SAVE_CREATE_NEW
	; create new settings file to save to 
	lda 	#WRITE.
	ldb 	#%00011011
	leax 	configFilePathName,PCR 
	os9 	I$Create
	lbcs 	COMMAND_SAVE_ERROR_WRITING
	sta 	<configFilePath

	; write color palette and flag values first 
	leax 	configFileVariables,U 
	ldy 	#13 			; 2 background colors + 8 foreground + 3 config flags 
	os9 	I$Write
	lbcs 	COMMAND_SAVE_ERROR_WRITING
	; now write out the strings 
	leax 	currentNickname,U 
	ldy 	#33 
	os9 	I$WritLn 
	lbcs 	COMMAND_SAVE_ERROR_WRITING
	leax 	currentUsername,U 
	ldy 	#33
	os9	I$WritLn 
	lbcs 	COMMAND_SAVE_ERROR_WRITING
	leax 	currentRealname,U 
	ldy 	#33
	os9 	I$WritLn 
	bcs 	COMMAND_SAVE_ERROR_WRITING
	leax 	userQuitMessage,U 
	ldy 	#64
	os9 	I$WritLn 
	bcs 	COMMAND_SAVE_ERROR_WRITING
	leax 	userVersionReply,U 
	ldy 	#64
	os9 	I$WritLn 
	bcs 	COMMAND_SAVE_ERROR_WRITING
	leax 	userServerDefault,U 
	ldy 	#64
	os9 	I$WritLn 
	bcs 	COMMAND_SAVE_ERROR_WRITING
	; now add header to indicate this config has extended params like nickserv password
	leax 	outputBuffer,U 
	ldy  	#"EX"
	sty 	,X
	; now add nickserv flag indicating if user saved password and whether or not to autologin if so 
	ldb  	<nickServPassFlag  	
	stb  	2,X  	
	ldy  	#3  	; write 3 bytes
	os9  	I$Write 
	bcs 	COMMAND_SAVE_ERROR_WRITING
	ldb  	<nickServPassFlag
	beq  	COMMAND_SAVE_NO_NICKSERV_PASS
	; if here, user has set a default nickserv password for auto-authentication
	leay  	outputBuffer,U 
	lbsr  	COPY_ENCRYPT_NICKSERV_PASS  	; encrypt password and copy result through ptr in Y 
	; B should contain total bytes in password. add 1 for the extra length prefix byte
	incb 
	clra 
	tfr  	D,Y 
	lda  	<configFilePath
	leax  	outputBuffer,U 
	os9  	I$Write 
	bcs 	COMMAND_SAVE_ERROR_WRITING	
COMMAND_SAVE_NO_NICKSERV_PASS
	; burn some cycles to wait for hardware to finish write commands
	exg  	X,X 
	exg  	X,X
	exg  	X,X
	exg  	X,X
	exg  	X,X 
	exg  	X,X
	exg  	X,X
	exg  	X,X
	lda  	<configFilePath
	os9 	I$Close 	; close config file path since we are done 
	; report success to the user 
	leax 	strMsgDefaultsSaved,PCR 
	lbsr 	PRINT_CHATLOG_NULL_STRING

	puls 	D,X,Y,PC 

COMMAND_SAVE_ERROR_WRITING
	lda  	<configFilePath
	os9 	I$Close 	; close config file path
	leax 	strErrorWritingConfig,PCR 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	bra 	COMMAND_SAVE_EXIT 

COMMAND_SAVE_ERROR_DELETING
	leax 	strErrorDeletingConfig,PCR
	lbsr 	PRINT_CHATLOG_NULL_STRING
COMMAND_SAVE_EXIT
	puls 	D,X,Y,PC 

; --------------------------------------------------------------------
; attempt to load user settings from config file
; --------------------------------------------------------------------
COMMAND_LOAD
	pshs 	X,D 

	; inform user we are trying to load config file 
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
	bcs 	COMMAND_LOAD_ERROR
      	; inform the user saved settings are successfully loaded 
      	leax 	strMsgConfigFileLoaded,PCR 
      	lbsr 	PRINT_CHATLOG_NULL_STRING
      	lda  	<oldConfigFlag
      	beq  	COMMAND_LOAD_RECENT_VERSION
      	leax  	strMsgConfigOldVersion,PCR 
      	lbsr 	PRINT_CHATLOG_NULL_STRING
COMMAND_LOAD_RECENT_VERSION
      	lbsr 	WRITE_COLOR_CONFIG_TO_PALETTE 	; apply new palette values to window paths	
      	puls 	D,X,PC 

COMMAND_LOAD_ERROR
	leax 	strMsgNoConfigFile,PCR 
	lbsr 	PRINT_CHATLOG_NULL_STRING
      	puls 	D,X,PC 

; -------------------------------------------------------------------
; clear the chatlog window 
; -------------------------------------------------------------------
COMMAND_CLEAR
	pshs 	Y,X,D 

	lda 	<chatlogPath
	leax 	charClear,PCR 
	ldy 	#1
	os9 	I$Write

	puls 	D,X,Y,PC 

; --------------------------------------------------------------------
COMMAND_HELP
	pshs 	Y,X,D 

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	clrb 
	cmpa 	#C$CR 
	lbeq 	COMMAND_HELP_BUILD_USAGE_STRING 	; no command word given so just display generan help info
	; start comparing parameter against all the different command words 
	ldb 	#2
	leay 	strSERVERkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strCONNECTkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strQUITkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strNICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strJOINkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strPARTkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strCYCLEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strTOPICkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strNAMESkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strACTIONkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strMEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strMSGkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strQUERYkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strCLOSEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strNOTICEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strOPkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strDEOPkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strVOICEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strDEVOICEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strBANkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strUNBANkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strKICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strMODEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strWHOISkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strRAWkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strNICKSERVkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	; now for the local program commands 
	leay 	strHELPkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strABOUTkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strLOADkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strSAVEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strCLEARkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strEXITkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strPREVkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strNEXTkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	; NOTE: SET MUST BE THE LAST COMMAND CHECKED SINCE THERE ARE SUB SETTINGS FOR IT 
	leay 	strSETkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcs 	COMMAND_HELP_ERROR_INVALID
	; if here, they issued a /HELP SET command of some kind. check if they want general SET help or specific subsetting 
	stb 	<tempChar 			; save current index value since B will be lost in the next code lines 
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	ldb 	<tempChar
	cmpa 	#C$CR 
	lbeq 	COMMAND_HELP_BUILD_USAGE_STRING_SKIP_STORE
	; if here, they requested subsetting help 
	incb 
	leay 	strNICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strREALNAMEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strUSERkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strCOLORkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strQUITMSGkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strVERSIONkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strSERVERkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strTIMESTAMPkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strMOTDkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb
	leay 	strNAMESkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	COMMAND_HELP_BUILD_USAGE_STRING
	incb 
	leay 	strNICKSERVkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcs 	COMMAND_HELP_ERROR_INVALID
COMMAND_HELP_BUILD_USAGE_STRING
	stb 	<tempChar
COMMAND_HELP_BUILD_USAGE_STRING_SKIP_STORE
	; open the help/usage file 
	lda 	#READ.
	leax 	helpUsageFilename,PCR
	os9 	I$Open 
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	sta 	<helpFilePath 
	; read in list of string offsets 
	leax 	inputBuffer,U 
	ldy 	#256 
	os9 	I$Read 
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	ldb 	<tempChar 		; get back the offset to string pointer offset 
	; if it's 0, then no command words were given, so just display general help/usage info 
	beq 	COMMAND_HELP_PRINT_GENERAL
	; if here, we found command word. use index value calculate a seek value to correct usage string 
	; in config file. there will be 4 bytes per entry, so multiply by 4 
	lslb 
	lslb 
	clra 
	leax 	D,X 			; move X to point to offset values and length of string we need 
	ldu 	,X++ 			; get offset to start of string within the file 
	ldx 	,X  			; grab length of string to read and save it 
	stx 	<tempWord 
	ldx 	#0 			; high word used in seek will always be 0 
	lda 	<helpFilePath
	os9 	I$Seek 
	ldu 	<uRegImage 		; restore data area pointer 
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	; finally read the correct usage string into outputBuffer
	leax 	outputBuffer,U 
	ldy 	<tempWord  
	os9 	I$Read
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	; add an extra line feed to the end and a null terminator to end of data  
	tfr 	Y,D 
	subd 	#1  			; move pointer to the original NULL so we can overwrite it 
	ldy 	#$0A00
	sty 	D,X 
	bra 	COMMAND_HELP_PRINT_CLOSE_EXIT

COMMAND_HELP_ERROR_INVALID
	leax 	strErrorHelpNotFound1,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	leax 	strErrorHelpNotFound2,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_HELP_EXIT

COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	leax 	strErrorHelpFile,PCR 
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	bra 	COMMAND_HELP_EXIT

COMMAND_HELP_PRINT_GENERAL
	ldu 	inputBuffer,U 
	ldx 	#0 
	os9 	I$Seek
	ldu 	<uRegImage 
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	ldy 	inputBuffer+2,U 
	leax 	outputBuffer,U 
	os9 	I$Read 
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	lbsr 	PRINT_CHATLOG_NULL_STRING
	ldu 	inputBuffer+4,U 
	ldx 	#0
	os9 	I$Seek 
	ldu 	<uRegImage
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
	ldy 	inputBuffer+6,U  
	leax 	outputBuffer,U 
	os9 	I$Read 
	bcs 	COMMAND_HELP_ERROR_ACCESS_CONFIG_FILE
COMMAND_HELP_PRINT_CLOSE_EXIT
	lda 	<helpFilePath
	lbsr 	PRINT_CHATLOG_NULL_STRING
	os9 	I$Close 		; close the usage/help file 
COMMAND_HELP_EXIT
	puls 	D,X,Y,PC 

; --------------------------------------------------------------------
COMMAND_ABOUT
	pshs 	Y,X,D 

	leax 	strAbout1,PCR 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	leax 	strCoCoIRCversion,PCR
	lbsr 	PRINT_CHATLOG_NULL_STRING
	leax 	strAbout2,PCR
	lbsr 	PRINT_CHATLOG_NULL_STRING

	lda 	<chatlogPath
	leax 	strAboutDescription,PCR 
	ldy 	#strAboutDescriptionSz
	os9 	I$Write

	puls 	D,X,Y,PC 

; --------------------------------------------------------------------
COMMAND_EPOCH
	pshs  	Y,X,D 

	lbsr 	CONVERT_EPOCH_ASCII_TO_DWORD
	lbsr 	EPOCH_CALCULATE_DATE_TIME

	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	COPY_STRING_EPOCH_TIMESTAMP
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

 IFDEF kjea
	;ldd 	<u32Value 
	;lbsr 	PRINT_WORD_HEX
	;ldd 	<u32Value+2
	;lbsr 	PRINT_WORD_HEX
	lda 	<epochYear
	sta 	<u8Value 
	lbsr 	PRINT_BYTE_HEX

	lda 	<epochMonth 
	sta 	<u8Value 
	lbsr 	PRINT_BYTE_HEX

	lda 	<epochDay 
	sta 	<u8Value 
	lbsr 	PRINT_BYTE_HEX

	lda 	<epochHour 
	sta 	<u8Value 
	lbsr 	PRINT_BYTE_HEX

	lda 	<epochMinute 
	sta 	<u8Value 
	lbsr 	PRINT_BYTE_HEX

	lda 	<epochSecond 
	sta 	<u8Value 
	lbsr 	PRINT_BYTE_HEX
 ENDC 

	puls 	D,X,Y,PC 

; -------------------------------------------------------------------
COMMAND_INTRO
	pshs 	X 

	leax 	strIntro,PCR 
	lbsr 	PRINT_CHATLOG_WITH_WORD_WRAP

	puls 	X,PC 

; -------------------------------------------------------------------
COMMAND_CTCP
	; TODO: convert ctcp keyword user entered to UPPERCASE
	pshs  	Y,X,D 

	lbsr 	CHECK_CONNECT_STATUS_REPORT_ERROR
	bcs 	COMMAND_CTCP_EXIT

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#C$CR 
	beq  	COMMAND_CTCP_ERROR_MISSING_PARAMS
	stx  	<serverCmdPtr
	leay  	outputBuffer,U
	leax 	strPRIVMSGkeyword,PCR 
	lbsr  	STRING_COPY_RAW
	lda  	#C$SPAC 
	sta  	,Y+
	ldx  	<serverCmdPtr
	lbsr  	PARAM_COPY
	ldb  	#':'
	std  	,Y++
	lda  	#$01  	; ctcp control code character
	sta  	,Y+
	lbsr  	FIND_NEXT_NONSPACE_CHAR
	cmpa  	#C$CR
	beq  	COMMAND_CTCP_ERROR_MISSING_PARAMS
	stx  	<tempPtr 	; save ptr to ctcp word command user is sending
	lbsr  	PARAM_COPY_UPPER
	lda  	#$01
	sta  	,Y+
	ldd  	#cr_lf
	std  	,Y++
	clr  	,Y 
	; send it to network now 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING
	; display the result to user
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgCTCPSentRequest1,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<tempPtr 	; grab ptr to ctcp command word we just sent
	lbsr  	PARAM_COPY_UPPER
	leax  	strUserMsgCTCPSentRequest2,PCR 
	lbsr  	STRING_COPY_RAW
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx  	<serverCmdPtr  	; finally, grab ptr to nickname we sent ctcp command to
	lbsr  	PARAM_COPY
	ldd  	#cr_lf 
	std 	,Y++
	clr 	,Y 
	leax  	outputBuffer,U 
	lbsr  	PRINT_CHATLOG_NULL_STRING

COMMAND_CTCP_ERROR_MISSING_PARAMS
	; TODO: make a proper error msg for this 
COMMAND_CTCP_EXIT
	puls  	D,X,Y,PC 

; -------------------------------------------------------------------
CHECK_CONNECT_STATUS_REPORT_ERROR
	pshs 	X,A 

	lda 	<idValidatedFlag
	beq 	CHECK_CONNECT_STATUS_REPORT_ERROR_NOT_CONNECTED
	andcc 	#$FE 
	puls 	A,X,PC 

CHECK_CONNECT_STATUS_REPORT_ERROR_NOT_CONNECTED
	leax 	strErrorNotConnected,PCR
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	orcc 	#1
	puls 	A,X,PC 