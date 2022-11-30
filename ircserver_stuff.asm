
***************************************************************
* IRC client server command parsing and handling routines 
***************************************************************

; --------------------------------------------------------------------------
; This is the main parsing routine that interprets the IRC server's commands
; and copies/formats/prints output or fills variables etc 
; --------------------------------------------------------------------------
PARSE_SERVER_CMD
	pshs 	Y,X,D 

	lda 	#server_timeout_count
	sta 	<timeoutCounter 

 	leax 	serverBuffer,U 
 	lda 	,X
 	cmpa 	#':'
 	bne 	PARSE_SERVER_CMD_CHECK_KEYWORDS
 	; if here, we have either server message or hostmask from other user
 	leax 	1,X 					; advance pointer passed the ':'
 	stx 	<sourceHostmaskPtr 			; save pointer to source for later use if needed 
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; find end of origin address/hostmask  
	leax 	1,X 					; skip expected space 
	; now check if the server command is numeric or keyword 
	lda 	,X 
	cmpa 	#'0'
	lbeq 	PARSE_SERVER_CMD_PREFIX_ZEROS
	blo 	PARSE_SERVER_CMD_CHECK_KEYWORDS
	cmpa 	#'2'
	lbeq 	PARSE_SERVER_CMD_PREFIX_TWOS
	cmpa 	#'3'
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES
	cmpa 	#'4'
	lbeq 	PARSE_SERVER_CMD_PREFIX_FOURS
	cmpa 	#'6'
	lbeq 	PARSE_SERVER_CMD_PREFIX_SIXES
	cmpa 	#'9'
	lbls 	PARSE_SERVER_CMD_SHOW_RAW_CMD
PARSE_SERVER_CMD_CHECK_KEYWORDS
	; check for KEYWORD commands 
	leay 	strJOINkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_JOIN
	leay 	strPINGkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_PING
	leay 	strQUITkeyword,PCR
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_QUIT
	leay 	strPARTkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_PART
	leay 	strNICKkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_NICKNAME
	leay 	strNOTICEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_NOTICE
	leay 	strMODEkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_MODE 
	leay 	strKICKkeyword,PCR
	lbsr 	COMPARE_PARAM
	lbcc 	PARSE_SERVER_CMD_KICK
	leay 	strTOPICkeyword,PCR 
	lbcc 	PARSE_SERVER_CMD_TOPIC
	; PRIVMSG CHECK HAS TO BE THE LAST ONE CHECKED 
	leay 	strPRIVMSGkeyword,PCR
	lbsr 	COMPARE_PARAM
	lbcs 	PARSE_SERVER_CMD_SHOW_RAW_CMD 	; TEMPRARY for now 
	; if here, its a PRIVMSG server command 
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the keyword command 
	lda 	,X+ 
	cmpa 	#C$SPAC
	lbne 	PARSE_SERVER_CMD_ERROR	
	; check if the destination is a channel or nickname 
	lda 	,X 
	cmpa 	#'#'
	lbne 	PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_CHECK_YOUR_NICK
	; format message for channel text 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#'{'
	sta 	,Y+
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	PARAM_COPY
	lbsr 	SKIP_SERVER_MSG_COLON 	; skip the expected space and possible ':'
	stx 	<serverCmdPtr 		; save buffer position 
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"} "
	std 	,Y++
	; check for CTCP control code in case of an ACTION 
	lda 	,X+ 
	cmpa 	#$01
	bne 	PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_NORMAL_CHAN_MSG
	sty 	<outputBufferPtr
	leay 	strACTIONkeyword,PCR 
	lbsr 	COMPARE_PARAM
	lbcs 	PARSE_SERVER_CMD_SHOW_RAW_CMD
	ldy 	<outputBufferPtr
	; structure the ACTION to print 
	ldd 	#"* "
	std 	,Y++
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	stx 	<serverCmdPtr
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	lda 	#C$SPAC 
	sta 	,Y+
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	leax 	1,X 				; skip expected space 
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_NORMAL_CHAN_MSG
	lda 	#'<'
	sta 	,Y+
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	sourceNickname,U 
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	lbsr 	STRING_COPY
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"> "
	std 	,Y++
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_CHECK_YOUR_NICK
	leay 	serverYourNick,U 
	lbsr 	COMPARE_PARAM
	lbcs 	PARSE_SERVER_CMD_SHOW_RAW_CMD
	; if here, we have received a PRIVMSG from another user
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip our nickname in the command string 
	lbsr 	SKIP_SERVER_MSG_COLON 	; skip expected space and possible ':' char
	; check to see if this is a CTCP query 
	lda 	,X	
	cmpa 	#$01 		; $01 = control code for CTCP messages 
	lbne 	PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_PRIVMSG_FOR_YOU
	; if here, we have a CTCP query of some kind 
	leax 	1,X 		; skip control code prefix 
	leay 	strVERSIONkeyword,PCR
	lbsr 	COMPARE_PARAM
	bcc 	PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_CTCP_VERSION
	leay 	strACTIONkeyword,PCR 
	lbsr 	COMPARE_PARAM
	bcc 	PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_ACTION 
	lbra 	PARSE_SERVER_CMD_IGNORE_WHOLE_THING 	; unsupported CTCP query so ignore 

PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_ACTION
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip keyword 
	leax 	1,X 					; skip expected space 
	stx 	<serverCmdPtr
	; build ACTION message to print 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	ldd 	#"* "
	std 	,Y++
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#C$SPAC 
	sta 	,Y+
	ldx 	<serverCmdPtr
	lbsr  	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_CTCP_VERSION
	; inform user we got a CTCP version request 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgVersionRequested,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	PARAM_COPY
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	; now send our VERSION string back to reply 
	leax 	sourceNickname,U 
	lbsr 	SEND_CTCP_VERSION_REPLY
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgVersionSent,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	userVersionReply,U 
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_PRIVMSG_FOR_YOU
	stx 	<serverCmdPtr
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	DESTINATION_FIND_ENTRY
	bcc 	PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_DEST_ALREADY_EXISTS
	; if here, it doesn't exist as a destination yet. add it if there is room in the list 
	ldb 	#1
	lbsr 	DESTINATION_ADD_ENTRY
PARSE_SERVER_CMD_PREFIX_NOT_NUMERIC_DEST_ALREADY_EXISTS
	; format message for private message 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#'<'
	sta 	,Y+
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"> "
	std 	,Y++
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

; JOIN KEYWORD COMMAND HANDLER 
PARSE_SERVER_CMD_JOIN
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the keyword command 
	lda 	,X+ 
	cmpa 	#C$SPAC
	lbne 	PARSE_SERVER_CMD_ERROR
	leay 	serverChanName,U 
	lbsr 	PARAM_COPY
	; was it YOU joining a channel?
	leay 	serverYourNick,U 
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	COMPARE_PARAM
	bcs 	PARSE_SERVER_CMD_JOIN_NOT_YOU
	; it WAS you. add new entry to destination list and tell user they joined 
	leax 	serverChanName,U 
	clrb 
	lbsr 	DESTINATION_ADD_ENTRY
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgYouJoined,PCR
	lbsr 	STRING_COPY_RAW
PARSE_SERVER_CMD_JOIN_PRINT_RESULT
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	serverChanName,U 
	lbsr 	STRING_COPY_RAW
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_JOIN_NOT_YOU
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgHasJoined,PCR 
	lbsr 	STRING_COPY_RAW
	bra 	PARSE_SERVER_CMD_JOIN_PRINT_RESULT

PARSE_SERVER_CMD_NOTICE
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the keyword command 
	lda 	,X+ 				; grab the expected space and skip passed it 
	cmpa 	#C$SPAC
	lbne 	PARSE_SERVER_CMD_ERROR 	; something went wrong I guess 
	stx 	<serverCmdPtr
	; check if notice is sent to YOUR nick or something else 
	leay 	serverYourNick,U 
	lbsr 	COMPARE_PARAM
	bcc 	PARSE_SERVER_CMD_NOTICE_YOUR_NICK
	; if here, we have either a channel or unknown recipient 
	lda 	,X 
	cmpa 	#'#'
	beq 	PARSE_SERVER_CMD_NOTICE_CHANNEL
	; essentially ignore the unknown nick and print the message content only 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	bra 	PARSE_SERVER_CMD_NOTICE_DO_MSG_BODY

PARSE_SERVER_CMD_NOTICE_CHANNEL
	; build the output string for channel notice 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#'-'
	sta 	,Y+
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#'/'
	sta 	,Y+
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"- "
	std 	,Y++
	bra 	PARSE_SERVER_CMD_NOTICE_DO_MSG_BODY

PARSE_SERVER_CMD_NOTICE_YOUR_NICK
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#'-'
	sta 	,Y+
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK	
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"- "
	std 	,Y++
	ldx 	<serverCmdPtr
	; skip over our nickname and any potential ':' characters 
	lbsr 	FIND_NEXT_SPACE_NULL_CR
PARSE_SERVER_CMD_NOTICE_DO_MSG_BODY
	lbsr 	SKIP_SERVER_MSG_COLON
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
 	; before exiting, check if that was a notice from nickserv so we can maybe trigger an autologin
 	leay  	strNICKSERVkeyword,PCR 
 	leax  	sourceNickname,U 
 	lbsr  	COMPARE_PARAM
 	lbcs  	PARSE_SERVER_CMD_DONE

 	lda  	<nickServPassFlag 
 	lbpl  	PARSE_SERVER_CMD_DONE 	; NickServ isnt set to autologin or hasnt been setup yet. exit
 	; check if we already sent login info
 	lda  	<nickServLoginPending 
 	lbeq  	PARSE_SERVER_CMD_DONE 	; yep already sent login so we are done here
 	leax  	userNickservPass,U
 	lbsr  	NICKSERV_SEND_IDENTIFY
 	clr  	<nickServLoginPending
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_PREFIX_ZEROS
	ldd 	1,X
	cmpd 	#"01"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"02"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"03"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"04"
	beq 	PARSE_SERVER_CMD_PREFIX_ZEROS_004
	cmpd 	#"05"
	beq 	PARSE_SERVER_CMD_PREFIX_ZEROS_005
	lbra 	PARSE_SERVER_CMD_SHOW_RAW_CMD

PARSE_SERVER_CMD_PREFIX_ZEROS_004
	leax 	4,X 			; skip over code 
	leay 	serverYourNick,U 
	lbsr 	PARAM_COPY
	lbcs 	PARSE_SERVER_CMD_ERROR
	leax  	1,X 		; skip bordering space char 
	; this should be the server's name that we use to identify messages from it 
	leay 	serverHostname,U 
	lbsr 	PARAM_COPY
	lbcs 	PARSE_SERVER_CMD_ERROR
	inc 	<idValidatedFlag
	inc  	<nickServLoginPending  ; if autologin is setup for nickserv, this enables detection for it
	; setup initial server timeout counter using VRN driver if exists  
	lda 	<nilPath 
	lbmi 	PARSE_SERVER_CMD_DONE
	ldb 	#SS.FSet 
	ldx 	#server_timeout_interval
	ldy 	#0
	ldu 	#server_timeout_signal
	os9 	I$SetStt 
	ldu 	<uRegImage 
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_PREFIX_ZEROS_005
	leax 	4,X 			; skip over code 
	leay 	strNetworkKeyword,PCR 
	lbsr 	STRING_SEARCH_KEYWORD
	lbcs 	PARSE_SERVER_CMD_IGNORE_WHOLE_THING 	; could be in next 005 msg 
	leay 	serverNetworkName,U 
	lbsr 	PARAM_COPY
	lbcs 	PARSE_SERVER_CMD_ERROR
	lbsr 	STATUS_BAR_UPDATE
	; tell the user what their actual nickname is from the server 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgYourNick,PCR 
	lbsr 	STRING_COPY
	lda 	#colorYourNick
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	serverYourNick,U 
	lbsr 	STRING_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_TWOS 
	ldd 	1,X 
	cmpd 	#"50"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"51"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"52"
	beq 	PARSE_SERVER_CMD_PREFIX_TWOS_SINGLE_PARAM_MSG
	cmpd 	#"53"
	beq 	PARSE_SERVER_CMD_PREFIX_TWOS_SINGLE_PARAM_MSG
	cmpd 	#"54"
	beq 	PARSE_SERVER_CMD_PREFIX_TWOS_SINGLE_PARAM_MSG
	cmpd 	#"55"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"65"
	beq 	PARSE_SERVER_CMD_PREFIX_TWOS_SKIP_TWO_PARAMS
	cmpd 	#"66"
	beq 	PARSE_SERVER_CMD_PREFIX_TWOS_SKIP_TWO_PARAMS
	lbra 	PARSE_SERVER_CMD_SHOW_RAW_CMD

PARSE_SERVER_CMD_PREFIX_TWOS_SINGLE_PARAM_MSG
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	ldd 	#"* "
	std 	,Y++
	lbsr 	PARAM_COPY
	lda 	#C$SPAC 
	sta 	,Y+
	lbsr 	SKIP_SERVER_MSG_COLON
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_TWOS_SKIP_TWO_PARAMS
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	leax 	1,X 
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	lbsr 	SKIP_SERVER_MSG_COLON
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	ldd 	#"* "
	std 	,Y++
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES
	ldd 	1,X 
	cmpd 	#"75"
	beq 	PARSE_SERVER_CMD_PREFIX_THREES_MOTD_START
	cmpd 	#"72"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_MOTD
	cmpd 	#"76"
	beq 	PARSE_SERVER_CMD_PREFIX_THREES_MOTD_END
	cmpd 	#"24"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_CHANMODE
	cmpd 	#"31"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_TOPIC_NOT_SET
	cmpd 	#"32"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_TOPIC
	cmpd 	#"33"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_TOPIC_SET_BY
	cmpd 	#"53"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES
	cmpd 	#"66"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES_END
	cmpd 	#"11"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_HOSTMASK
	cmpd 	#"12"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_GENERIC
	cmpd 	#"17"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_IDLE_SIGNON
	cmpd 	#"18"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_GENERIC
	cmpd 	#"19" 					; whois channel list 
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_GENERIC
	cmpd 	#"30"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_LOGIN
	cmpd 	#"78"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_GENERIC
	lbra 	PARSE_SERVER_CMD_SHOW_RAW_CMD 	; DEBUG for now 

PARSE_SERVER_CMD_PREFIX_THREES_MOTD_START
	lda 	<printMOTDflag
	lbne 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	; if here, then we are suppressing the MOTD cuz of crazy scrolling 
	leax 	strUserMsgMOTDsuppress,PCR
	lbsr 	PRINT_INFO_ERROR_MESSAGE
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_PREFIX_THREES_MOTD_END
	lda 	<printMOTDflag
	lbne 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	; if here, we are done supressing. let user know 
	leax 	strUserMsgMOTDsuppressed,PCR 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_PREFIX_THREES_MOTD
	; check if user wants MOTD printed to screen (it can be very long)
	lda 	<printMOTDflag
	lbne 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_PREFIX_THREES_CHANMODE
	; TODO LATER 
	lbra 	PARSE_SERVER_CMD_SHOW_RAW_CMD

PARSE_SERVER_CMD_PREFIX_THREES_TOPIC_NOT_SET
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr 		; save pointer to chan name 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgTopicNotSet,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_TOPIC
	lbsr 	SKIP_COMMAND_AND_NICKNAME
PARSE_SERVER_CMD_PREFIX_THREES_TOPIC_KEYWORD_ENTRY
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgTopic,PCR 
	lbsr 	STRING_COPY
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbsr 	SKIP_SERVER_MSG_COLON
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#": "
	std 	,Y++
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_TOPIC_SET_BY
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgTopic,PCR 
	lbsr 	STRING_COPY
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	leax 	1,X 			; skip expected space 
	stx 	<serverCmdPtr 	; save pointer to start of hostmask 
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgTopicSetBy,PCR
	lbsr 	STRING_COPY_RAW
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	; extract the topic creator's nickname from his/her hostmask 
	ldx 	<serverCmdPtr 	; get topic creator hostmask or nickname pointer back 
	lbsr 	PARAM_COPY_NICK_FROM_HOSTMASK
	lbcs 	PARSE_SERVER_CMD_ERROR
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	; FOR TESTING 
	ldd 	#" o"
	std 	,Y++
	ldd 	#"n "
	std 	,Y++
	lbsr 	CONVERT_EPOCH_ASCII_TO_DWORD 	; this always updates X to point to terminating char at end of epoch string 
	lbsr 	EPOCH_CALCULATE_DATE_TIME
	lbsr 	COPY_STRING_EPOCH_TIMESTAMP
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_NAMES
	; if this is result of /NAMES command, always display it 
	lda 	<namesRequestedFlag
	bne 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES_REQUESTED
	; if here, this is result of a JOIN. check if user wants these displayed 
	lda 	<showNamesOnJoinFlag
	lbeq 	PARSE_SERVER_CMD_IGNORE_WHOLE_THING 	; nope. ignore NAME server commands 
PARSE_SERVER_CMD_PREFIX_THREES_NAMES_REQUESTED
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	; now skip the next two chars which can be things like "= " or "@ " etc
	leax 	2,X 
	;ldd 	,X++
	;cmpd 	#"= "
;	lbne 	PARSE_SERVER_CMD_ERROR 	; something is wrong with syntax 
	; check names flag to see if we are expecting more nicknames from another 
	; 353 command 
	lda 	<moreNamesPendingFlag
	beq 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES_FIRST_TIME
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the channel name 
	ldd 	,X++
	cmpd 	#" :"
	lbne 	PARSE_SERVER_CMD_ERROR
	; skip to printing the names 
	bra 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES_NEXT 	

PARSE_SERVER_CMD_PREFIX_THREES_NAMES_FIRST_TIME
	inc 	<moreNamesPendingFlag
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgNames,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY 		; copy the channel name into the user message 
	lbsr 	SKIP_SERVER_MSG_COLON
	stx 	<serverCmdPtr
	; add the colon in the user msg and print 
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lda 	#':'
	sta 	,Y+
	ldd 	#cr_lf 
	std 	,Y++
	; add color codes for normal foreground in at the end for usernames 
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	clr 	,Y
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	; now lets do the fixed width printing of nicknames 
	ldx 	<serverCmdPtr
PARSE_SERVER_CMD_PREFIX_THREES_NAMES_NEXT
	leay 	outputBuffer,U 
	lbsr 	PARAM_COPY
	leay 	outputBuffer,U
	lda 	<chatlogPath
	lbsr 	PRINT_FIXED_WIDTH
	lda 	,X+ 
	cmpa 	#C$CR 
	bne 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES_NEXT
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_PREFIX_THREES_NAMES_END
	; if this is result of /NAMES command, always display it 
	lda 	<namesRequestedFlag
	bne 	PARSE_SERVER_CMD_PREFIX_THREES_NAMES_END_REQUESTED
	; if here, this is result of a JOIN. check if user wants these displayed 
	lda 	<showNamesOnJoinFlag
	lbeq 	PARSE_SERVER_CMD_IGNORE_WHOLE_THING 	; nope. ignore NAME server commands 
	; even if user wants to use names from join, skip if channel list was empty 
	lda 	<moreNamesPendingFlag
	lbeq 	PARSE_SERVER_CMD_IGNORE_WHOLE_THING
PARSE_SERVER_CMD_PREFIX_THREES_NAMES_END_REQUESTED
	clr 	<moreNamesPendingFlag
	clr 	<namesRequestedFlag 				; reset flag for next time 
	leay 	outputBuffer,U 
	ldd 	#cr_lf 
	std 	,Y++
	lbsr 	STRING_COPY_TIMESTAMP 	; grab new timestamp and copy it in 
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgNamesEnd,PCR
	lbsr 	STRING_COPY_RAW
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_HOSTMASK
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#'['
	sta 	,Y+
	lbsr 	PARAM_COPY
	ldd 	#"] "
	std 	,Y++
	lda 	#'('
	sta 	,Y+
	leax 	1,X 		; skip the space 
	lbsr 	PARAM_COPY
	lda 	#'@'
	sta 	,Y+
	leax 	1,X 		; skip the space 
	lbsr 	PARAM_COPY
	ldd 	#"):"
	std 	,Y++
	lda 	#C$SPAC
	sta 	,Y+
	leax 	2,X 		; skip space and asterix normally found here 
	lbsr 	SKIP_SERVER_MSG_COLON
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_LOGIN
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#'['
	sta 	,Y+
	lbsr 	PARAM_COPY
	ldd 	#"] "
	std 	,Y++
	leax 	1,X 	; skip the space 
	stx 	<serverCmdPtr
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	lbsr 	SKIP_SERVER_MSG_COLON
	lbsr 	STRING_COPY_CR
	lda 	#C$SPAC
	sta 	,Y+
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY	
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_GENERIC
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#'['
	sta 	,Y+
	lbsr 	PARAM_COPY
	ldd 	#"] "
	std 	,Y++
	lbsr 	SKIP_SERVER_MSG_COLON
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_IDLE_SIGNON
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<outputBufferPtr 		; save pointer to nickname in msg 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#'['
	sta 	,Y+
	lbsr 	PARAM_COPY
	ldd 	#"] "
	std 	,Y++	
	leax 	1,X 				; skip expected space 
	lbsr 	CONVERT_EPOCH_ASCII_TO_DWORD
	stx 	<serverCmdPtr 		; save pointer to terminator after idle time epoch value 
	lbsr 	EPOCH_CALCULATE_IDLE_TIME
	leax 	strUserMsgWhoisIdle,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#1 				; ignore leading zeros 
	ldb 	<epochDay 
	lbsr 	COPY_BYTE_TO_STRING
	leax 	strUserMsgWhoisDays,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#1 				; ignore leading zeros 
	ldb 	<epochHour 
	lbsr 	COPY_BYTE_TO_STRING
	leax 	strUserMsgWhoisHours,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#1 				; ignore leading zeros 
	ldb 	<epochMinute 
	lbsr 	COPY_BYTE_TO_STRING
	leax 	strUserMsgWhoisMins,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#1 				; ignore leading zeros 
	ldb 	<epochSecond 
	lbsr 	COPY_BYTE_TO_STRING
	leax 	strUserMsgWhoisSecs,PCR 
	lbsr 	STRING_COPY_RAW
	; now do the signon time 
	ldd 	#cr_lf 
	std 	,Y++
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNotice
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#'['
	sta 	,Y+
	ldx 	<outputBufferPtr
	lbsr 	PARAM_COPY
	ldd 	#"] "
	std 	,Y++	
	leax 	strUserMsgWhoisSignon,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	leax 	1,X 					; skip expected space to point to signon epoch num
	lbsr 	CONVERT_EPOCH_ASCII_TO_DWORD 	; this routine skips whitespace already 
	lbsr 	EPOCH_CALCULATE_DATE_TIME
	lbsr 	COPY_STRING_EPOCH_TIMESTAMP
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_FOURS
	ldd 	1,X 
	cmpd 	#"22"
	lbeq 	PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	cmpd 	#"33"
	lbeq 	PARSE_SERVER_CMD_NICK_IN_USE
	cmpd 	#"01"
	beq 	PARSE_SERVER_CMD_PREFIX_FOURS_NO_SUCH_NICK
	cmpd 	#"03"
	beq 	PARSE_SERVER_CMD_PREFIX_FOURS_NO_SUCH_CHAN
	cmpd 	#"82"
	beq 	PARSE_SERVER_CMD_PREFIX_FOURS_OP_PRIV_NEEDED
	cmpd 	#"67" 			; channel key already set 
	lbeq 	PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	cmpd 	#"71" 			; channel is full 
	lbeq 	PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	cmpd 	#"73" 			; invite only 
	lbeq 	PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	cmpd 	#"74" 			; you are banned 
	lbeq 	PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	cmpd 	#"75" 			; bad channel key 
	lbeq 	PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	cmpd 	#"77" 			; must be registered (+r)
	beq 	PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	lbra 	PARSE_SERVER_CMD_SHOW_RAW_CMD

PARSE_SERVER_CMD_PREFIX_FOURS_NO_SUCH_NICK
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr
	; build output string to print to user 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strErrorNoSuchNick,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_FOURS_NO_SUCH_CHAN
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr
	; build output string to print to user 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	leax 	strErrorNoSuchChannel,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_FOURS_OP_PRIV_NEEDED
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strErrorNoOps,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PREFIX_FOURS_CANNOT_JOIN_GENERIC
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip over chan name 
	lbsr 	SKIP_SERVER_MSG_COLON
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lbsr 	STRING_COPY_CR
	lda 	#C$SPAC 
	sta 	,Y+
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

; if prefix is in 600s, here is where we check which one it is 
PARSE_SERVER_CMD_PREFIX_SIXES
	ldd 	1,X 
	cmpd 	#"71"
	lbeq 	PARSE_SERVER_CMD_PREFIX_THREES_WHOIS_GENERIC
	lbra 	PARSE_SERVER_CMD_SHOW_RAW_CMD 	; DEBUG for now 

PARSE_SERVER_CMD_PING
	; respond with the same message in a PONG 
	leay 	outputBuffer,U 
	ldd 	#"PO"
	std 	,Y++
	ldd 	#"NG"
	std 	,Y++
	lda 	#C$SPAC 
	sta 	,Y+
	leax 	5,X
	; I rewrote this part that originally used STRING_COPY_INCLUDE_CRLF since that routine isnt needed anymore
	; if PING/PONG stops working though for some reason, its prob cuz of this.
	lbsr  	STRING_COPY_CR
	ldd 	#cr_lf 
	std 	,Y++ 
	clr 	,Y 
	leax 	outputBuffer,U 
	lda 	<networkPath 
	lbsr 	WRITE_CRLF_STRING
	lbra 	PARSE_SERVER_CMD_DONE

; this is the KEYWORD version of the topic server command 
PARSE_SERVER_CMD_TOPIC
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the command word 
	leax 	1,X  				; skip expected space 
	lbra 	PARSE_SERVER_CMD_PREFIX_THREES_TOPIC_KEYWORD_ENTRY

PARSE_SERVER_CMD_QUIT
	lbsr 	FIND_NEXT_SPACE_NULL_CR	; skip the command word
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP 	; grab and copy in new timestamp 
	lda 	#colorQuit
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	leax 	strUserMsgQuit,PCR
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
 	lbsr 	SKIP_SERVER_MSG_COLON
 	lda 	,X 
 	cmpa 	#C$CR 
	lbeq 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER
	; if here, we have a QUIT message. copy it into the output string 
	ldd 	#"()"
	sta 	,Y+
	lbsr 	STRING_COPY_CR
	stb 	,Y+
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PART 
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip the keyword command 
	lbsr 	SKIP_SERVER_MSG_COLON 	; skip white space and any potential colon prefix 
	stx 	<serverCmdPtr
	; figure out if it was YOU or someone else parting 
	leay 	serverYourNick,U 
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	COMPARE_PARAM
	bcs 	PARSE_SERVER_CMD_PART_NOT_YOU
	; if here, then it was you who parted a channel 
	ldx 	<serverCmdPtr
	lbsr 	DESTINATION_FIND_ENTRY
	bcs 	PARSE_SERVER_CMD_PART_NO_DEST_ENTRY
	leay 	destArray,U 
	ldx 	#0
	stx 	D,Y
	cmpd 	destOffset,U 
	bne 	PARSE_SERVER_CMD_PART_SKIP_NEXT_DEST
	; if here, active destination was the one they parted, so cycle automatically
	; to the next entry in the array if any 
	lbsr 	COMMAND_NEXT_DESTINATION 	; the routine will auto-update the statusbar
PARSE_SERVER_CMD_PART_SKIP_NEXT_DEST
PARSE_SERVER_CMD_PART_NO_DEST_ENTRY
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgYouParted,PCR
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_PART_NOT_YOU
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgHasParted,PCR 
	lbsr 	STRING_COPY
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_NICK_IN_USE
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strErrorNickInUse1,PCR
	lbsr 	STRING_COPY_RAW
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strErrorNickInUse2,PCR
	lbsr 	STRING_COPY_RAW
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strErrorNickChooseAnother,PCR 
	lbsr 	STRING_COPY_RAW
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING
	lbra 	PARSE_SERVER_CMD_DONE

PARSE_SERVER_CMD_NICKNAME
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip keyword 
	ldd 	,X++
	cmpd 	#" :"
	lbne 	PARSE_SERVER_CMD_ERROR
	stx 	<serverCmdPtr
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	leay 	serverYourNick,U 
	lbsr 	COMPARE_PARAM
	bcs 	PARSE_SERVER_CMD_NICKNAME_NOT_YOU
	; if here, its you that changed your nickname 
	; first update the server variable for your nick. Y should already be pointed
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	leax 	strUserMsgYourNewNick,PCR 
	lbsr 	STRING_COPY
	lda 	#colorYourNick
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	serverYourNick,U 
	lbsr 	STRING_COPY_RAW
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_NICKNAME_NOT_YOU
	; if here, then someone else's nickname changed 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgNickChanged,PCR 
	lbsr 	STRING_COPY
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_MODE 
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip the command keyword 
	leax 	1,X 					; skip expected space 
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leay 	sourceNickname,U 
	lbsr 	COMPARE_PARAM 	; if target nick and source are the same, it's a self-user mode 
	bcs 	PARSE_SERVER_CMD_MODE_CHANNEL_TYPE
	; if here, it's a user mode 
	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip our nickname 
	lbsr 	SKIP_SERVER_MSG_COLON 		; skip white space + colon prefix if exists 
	stx 	<serverCmdPtr
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgUserModeChg,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	STRING_COPY_CR
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_MODE_CHANNEL_TYPE
	; if here, then it's a channel mode 
	stx 	<serverCmdPtr 		; save pointer to chan name 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgSetsMode,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	<serverCmdPtr
	lbsr 	FIND_NEXT_SPACE_NULL_CR 	; skip over chan name for now 
	leax 	1,X 				; skip expected space 
	lbsr 	PARAM_COPY 			; copy mode flags 
	lda 	#C$SPAC 
	sta 	,Y+ 
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	; if next nonspace char is a CR, theres no "target" nickname or hostmask. skip to chan name only
	cmpa 	#C$CR 
	beq 	PARSE_SERVER_CMD_MODE_NO_DESTINATION
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	STRING_COPY_CR
PARSE_SERVER_CMD_MODE_NO_DESTINATION
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgOnChannel,PCR
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<serverCmdPtr
	lbsr 	PARAM_COPY 	; copy over the channel name from the server command 
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_KICK
 	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip command word 
 	leax 	1,X 
 	stx 	<chanPtr 				; save pointer to chan name
 	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip channel name 
 	leax 	1,X 
 	stx 	<nickPtr 				; save pointer to target nick 
 	lbsr 	FIND_NEXT_SPACE_NULL_CR 		; skip target nickname 
 	lbsr 	SKIP_SERVER_MSG_COLON 		; skip whitespace and possible ':' prefix 
 	stx 	<msgPtr 				; save pointer to potential kick message 
 	; now find out if nick being kicked is us or not
 	ldx 	<nickPtr
 	leay 	serverYourNick,U 
 	lbsr 	COMPARE_PARAM
 	bcs 	PARSE_SERVER_CMD_KICK_NOT_YOU
 	; if here, we were kicked. remove that channel from destination list 
 	ldx 	<chanPtr
 	lbsr 	DESTINATION_FIND_ENTRY
	bcs 	PARSE_SERVER_CMD_KICK_NO_DEST_ENTRY
	leay 	destArray,U 
	ldx 	#0
	stx 	D,Y
	cmpd 	destOffset,U 
	bne 	PARSE_SERVER_CMD_KICK_SKIP_NEXT_DEST
	; if here, active destination was the one they were kicked from so cycle automatically
	; to the next entry in the array if any 
	lbsr 	COMMAND_NEXT_DESTINATION 	; the routine will auto-update the statusbar
PARSE_SERVER_CMD_KICK_NO_DEST_ENTRY
PARSE_SERVER_CMD_KICK_SKIP_NEXT_DEST
	; now setup output string for US being kicked 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgYouKicked,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr  	COPY_COLOR_CODE_FOREGROUND
	ldx 	<chanPtr
	lbsr 	PARAM_COPY
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgKickedBy,PCR
	lbsr 	STRING_COPY_RAW
	bra 	PARSE_SERVER_CMD_KICK_CHECK_MSG

PARSE_SERVER_CMD_KICK_NOT_YOU
	; build user output string for when other users are kicked 
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#"* "
	std 	,Y++
	ldx 	<nickPtr 
	lbsr 	PARAM_COPY
	leax 	strUserMsgWasKicked,PCR 
	lbsr 	STRING_COPY_RAW
	lda 	#colorChanName
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldx 	<chanPtr 
	lbsr 	PARAM_COPY
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	leax 	strUserMsgKickedBy,PCR 
	lbsr 	STRING_COPY_RAW
PARSE_SERVER_CMD_KICK_CHECK_MSG
	; finish up copying in the source nick that did the kicking 
	lda 	#colorNickChan
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	lbsr 	GET_NICK_FROM_SOURCE_HOSTMASK
	leax 	sourceNickname,U 
	lbsr 	STRING_COPY_RAW
	ldx 	<msgPtr
	lda 	,X 
	cmpa 	#C$CR 
	beq 	PARSE_SERVER_CMD_KICK_PRINT_RESULT 	; skip kick msg code since none specified
	lda 	#colorJoinPart
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	ldd 	#" ("
	std 	,Y++
	lbsr 	STRING_COPY_CR
	lda 	#')'
	sta 	,Y+
PARSE_SERVER_CMD_KICK_PRINT_RESULT
	lbra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER	

PARSE_SERVER_CMD_PRINT_MSG_BODY_ONLY
	lbsr 	SKIP_COMMAND_AND_NICKNAME
	lbsr 	SKIP_SERVER_MSG_COLON
	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	ldd 	#"* "
	std 	,Y++
	lbsr 	STRING_COPY_CR
	bra 	PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER

PARSE_SERVER_CMD_ERROR
PARSE_SERVER_CMD_IGNORE_WHOLE_THING
	orcc 	#1
	puls 	D,X,Y,PC 

PARSE_SERVER_CMD_SHOW_RAW_CMD
 IFDEF debug_mode
	leax 	serverBuffer,U 
	lda 	<chatlogPath
	lbsr 	WRITE_CRLF_STRING
 ENDC
 	bra 	PARSE_SERVER_CMD_DONE
;	andcc 	#$FE 
	;puls 	D,X,Y,PC

PARSE_SERVER_CMD_TERMINATE_PRINT_OUTPUTBUFFER
	ldd 	#cr_lf 
	std 	,Y++
	clr 	,Y 
PARSE_SERVER_CMD_PRINT_OUTPUTBUFFER
	leax 	outputBuffer,U 
 IFDEF use_word_wrap
 	lbsr 	PRINT_CHATLOG_WITH_WORD_WRAP
 ELSE
	lbsr 	PRINT_CHATLOG_NULL_STRING
 ENDC
PARSE_SERVER_CMD_DONE
	andcc 	#$FE 
	puls 	D,X,Y,PC

; ---------------------------------------------------------------------------
; extract nickname from source hostmask and save to sourceNickname variable 
; if it's not a hostmask, assume its just nickname and stop at SPACE terminator 
; Entry: sourceHostmaskPtr set to hostmask to extract from 
; 	  Y = pointer to where to write nickname and NULL  
; Exit: on success, carry clear, nick copied to string pointed to by Y 
; 	on fail, carry set. cmd_join
; ---------------------------------------------------------------------------
GET_NICK_FROM_SOURCE_HOSTMASK
	pshs 	Y,X,D 

	ldx 	<sourceHostmaskPtr
	leay 	sourceNickname,U 
	; search for "!" character
	ldb 	#max_nick_length
GET_NICK_FROM_SOURCE_HOSTMASK_NEXT
	lda 	,X+
	cmpa 	#'!'
	beq 	GET_NICK_FROM_SOURCE_HOSTMASK_FOUND
	cmpa 	#C$SPAC
	beq 	GET_NICK_FROM_SOURCE_HOSTMASK_NICK_ONLY
	sta 	,Y+
	decb 
	bne 	GET_NICK_FROM_SOURCE_HOSTMASK_NEXT
	; if here, we overflowed max nick size, something went wrong or not a hostmask at all 
	orcc 	#1
	puls 	D,X,Y,PC 

GET_NICK_FROM_SOURCE_HOSTMASK_FOUND
GET_NICK_FROM_SOURCE_HOSTMASK_NICK_ONLY
	clr 	,Y 	; NULL terminator 
	andcc 	#$FE 
	puls 	D,X,Y,PC 

; ---------------------------------------------------------------------------
; copy a nickname from a hostmask if exists. otherwise copy nickname until
; next space 
; Entry: X = pointer to hostmask you extract from 
; 	  Y = pointer to where to write nickname and NULL  
; Exit: on success, carry clear, nick copied to string pointed to by Y 
; 	on fail, carry set. 
; ---------------------------------------------------------------------------
PARAM_COPY_NICK_FROM_HOSTMASK
	pshs 	D 

	; search for "!" character
	ldb 	#max_nick_length
PARAM_COPY_NICK_FROM_HOSTMASK_NEXT
	lda 	,X+
	cmpa 	#'!'
	beq 	PARAM_COPY_NICK_FROM_HOSTMASK_FOUND
	cmpa 	#C$SPAC 
	beq 	PARAM_COPY_NICK_FROM_HOSTMASK_NICK_ONLY
	sta 	,Y+
	decb 
	bne 	PARAM_COPY_NICK_FROM_HOSTMASK_NEXT
	; if here, we overflowed max nick size, something went wrong
	orcc 	#1
	puls 	D,PC 

PARAM_COPY_NICK_FROM_HOSTMASK_FOUND
	; move pointer to the end of hostmask to be ready to handle additional params 
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	clr 	,Y 	; NULL terminator 
	andcc 	#$FE 
	puls 	D,PC 

PARAM_COPY_NICK_FROM_HOSTMASK_NICK_ONLY
	leax 	-1,X 	; undo auto increment to point to space terminator 
	clr 	,Y 	; NULL terminator 
	andcc 	#$FE 
	puls 	D,PC 

; -----------------------------------------------------
; skip keyword/numeric code and nickname and point 
; to first char of content 
; Entry: X = pointer to somewhere inside keyword/number 
; -----------------------------------------------------
SKIP_COMMAND_AND_NICKNAME
	pshs 	A 

	lbsr 	FIND_NEXT_SPACE_NULL_CR
	lda 	,X+
	cmpa 	#C$SPAC 
	bne 	SKIP_COMMAND_AND_NICKNAME_ERROR
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	lda 	,X+
	cmpa 	#C$SPAC
	bne 	SKIP_COMMAND_AND_NICKNAME_ERROR
	; success 
	andcc 	#$FE
	puls 	A,PC

SKIP_COMMAND_AND_NICKNAME_ERROR
	orcc 	#1
	puls 	A,PC  

; ---------------------------------------------------------
; skip over colon in server message content. also skips any 
; spaces before finding colon 
; Entry: X = pointer to string to search through 
; Exit: X is pointing to first character after colon or 
; 	 first non-space character if there was no colon 
; ---------------------------------------------------------
SKIP_SERVER_MSG_COLON
	pshs 	D 

	clrb
SKIP_SERVER_MSG_COLON_SKIP_SPACES
	lda 	,X+ 
	cmpa 	#C$SPAC 
	bne 	SKIP_SERVER_MSG_COLON_FOUND_NONSPACE
	decb 
	bne 	SKIP_SERVER_MSG_COLON_SKIP_SPACES
	; if here, something went horrible wrong. BAIL OUT 
	puls 	D,PC 

SKIP_SERVER_MSG_COLON_FOUND_NONSPACE
	cmpa 	#':'
	beq 	SKIP_SERVER_MSG_COLON_DONE
	leax 	-1,X 		; undo auto increment before bailing 
SKIP_SERVER_MSG_COLON_DONE 
	puls 	D,PC 

; -------------------------------------------------------
; send a CTCP reply
; -------------------------------------------------------
SEND_CTCP_VERSION_REPLY
	pshs 	Y,X,D 

	leay 	outputBuffer,U 
	leax 	strIRCserverNotice,PCR 
	lbsr 	STRING_COPY_RAW
	ldx 	2,S 
	lbsr 	PARAM_COPY
	ldd 	#" :"
	std 	,Y++
	ldd 	#$0120 		; CTCP control code + SPACE 
	sta 	,Y+
	leax 	strVERSIONkeyword,PCR
	lbsr 	STRING_COPY_RAW
	stb 	,Y+
	leax 	userVersionReply,U 
	lbsr 	STRING_COPY_CR
	sta 	,Y+
	ldd 	#cr_lf
	std 	,Y++
	clr 	,Y 
	; send command to network/server 
	lda 	<networkPath
	leax 	outputBuffer,U 
	lbsr 	WRITE_CRLF_STRING

	puls 	D,X,Y,PC 

; ----------------------------------------------------------------------------------
; Attempt to identify with nickserv by sending PRIVMSG NickServ :IDENTIFY <password>
; Entry: X = pointer to password to use to login
; ----------------------------------------------------------------------------------
NICKSERV_SEND_IDENTIFY
	pshs  	Y,X,D 

	; setup server PRIVMDG command 
	leay 	outputBuffer,U 
	leax 	strIRCserverMsg,PCR
	lbsr 	STRING_COPY_RAW
	leax 	strNICKSERVkeyword,PCR  
	lbsr 	STRING_COPY_RAW
	ldd 	#" :"
	std 	,Y++
	leax  	strIDENTIFYkeyword,PCR
	lbsr  	STRING_COPY_RAW
	sta  	,Y+
	ldx 	2,S  		; grab entry pointer to password in X from the stack
	lbsr  	STRING_COPY_RAW
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
	leax  	strUserMsgNickServIDsent,PCR 
	lbsr  	STRING_COPY_RAW
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

	clr  	<nickServLoginPending

	puls  	D,X,Y,PC 