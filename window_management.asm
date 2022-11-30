***************************************************
* CoCoIRC window/destination management routines 
***************************************************

; -------------------------------------------------
; search the active channel/privmsg list for a  
; particular entry.
; Entry: X = pointer to channel/nick to search for 
; Carry set if it loops through the whole buffer 
; without finding it.
; Carry clear if it finds it. offset returned in D
; --------------------------------------------------
DESTINATION_FIND_ENTRY
	pshs 	Y,X 

	ldd 	destOffset,U 
	leay 	destArray,U 
DESTINATION_FIND_ENTRY_NEXT
	ldx 	D,Y 
	beq 	DESTINATION_FIND_ENTRY_SKIP
	bpl 	DESTINATION_FIND_ENTRY_USED
	; we have rolled-over 
	ldd 	#0
	bra 	DESTINATION_FIND_ENTRY_CHECK_START

DESTINATION_FIND_ENTRY_SKIP
	addd 	#nickChanByteSize		; jump to next entry to check 
DESTINATION_FIND_ENTRY_CHECK_START
	cmpd 	destOffset,U 	; check against original value to see if there are NO open windows 
	bne 	DESTINATION_FIND_ENTRY_NEXT
	; if here, we have checked everything and couldnt find it 
	orcc 	#1
	puls 	X,Y,PC 

DESTINATION_FIND_ENTRY_USED 
	leay 	D,Y 
	ldx 	,S 
	lbsr 	COMPARE_PARAM
	bcc 	DESTINATION_FIND_ENTRY_FOUND	
	leay 	destArray,U 		; reset pointer and skip entry since didnt match 
	bra 	DESTINATION_FIND_ENTRY_SKIP
DESTINATION_FIND_ENTRY_FOUND
	; we found it! GREAT SUCCESS!
	andcc 	#$FE 
	puls 	X,Y,PC 

; -------------------------------------------------
; search the active channel/privmsg list for the 
; first free/empty entry.
; Carry set if it loops through the whole buffer 
; without finding an available entry.
; Carry clear if it finds one. offset returned in D
; --------------------------------------------------
DESTINATION_FIND_EMPTY
	pshs 	Y,X 

	ldd 	destOffset,U 
	leay 	destArray,U 
DESTINATION_FIND_EMPTY_NEXT
	ldx 	D,Y 
	beq 	DESTINATION_FIND_EMPTY_FOUND
	bpl 	DESTINATION_FIND_EMPTY_SKIP
	; we have rolled-over 
	ldd 	#0
	bra 	DESTINATION_FIND_EMPTY_CHECK_START

DESTINATION_FIND_EMPTY_SKIP
	addd 	#nickChanByteSize		; jump to next entry to check 
DESTINATION_FIND_EMPTY_CHECK_START
	cmpd 	destOffset,U 	; check against original value to see if there are NO open windows 
	bne 	DESTINATION_FIND_EMPTY_NEXT
	; if here, we have checked everything and couldnt find it 
	orcc 	#1
	puls 	X,Y,PC 

DESTINATION_FIND_EMPTY_FOUND
	andcc 	#$FE 
	puls 	X,Y,PC 

; -----------------------------------------------------------------------
; add a new destination to the array of channels/nicknames to send 
; messages to 
; Entry: B = 0 to make new destination the active one. non-zero will add 
; 	  to the array without making it active UNLESS there are no other 
; 	  entries active already. 
; 	  X = pointer to name of channel or nickname to add to the array 
; Exit:  Y = pointing to NULL of written destination name in destArray 
; 	  Status bar is updated automatically. 
; -----------------------------------------------------------------------
DESTINATION_ADD_ENTRY
	pshs 	Y,X,D 

	lbsr 	DESTINATION_FIND_EMPTY 	; try to find an available slot 
	bcs 	DESTINATION_ADD_ENTRY_ERROR_FULL
	; if here, we found an available spot 
	tst 	1,S 		; load B off the stack to see if we should set new entry as active 
	beq 	DESTINATION_ADD_ENTRY_MAKE_ACTIVE
	; if there are no active destinations already, make this one active anyways 
	tst 	<activeDestFlag 
	bne 	DESTINATION_ADD_ENTRY_SKIP_ACTIVATING
DESTINATION_ADD_ENTRY_MAKE_ACTIVE
	std 	destOffset,U 
DESTINATION_ADD_ENTRY_SKIP_ACTIVATING
	leay 	destArray,U 	; grab pointer to start of dest array 
	leay 	D,Y 		; move the pointer to the new empty location 
	ldx 	2,S 		; get entry value of X from the stack 
	lbsr 	PARAM_COPY
	lda 	#1
	sta 	<activeDestFlag
	sty 	4,S  		; save position of written NULL on Y in the stack for returning 
	lbsr 	STATUS_BAR_UPDATE 	; update the statusbar in case active destination changed 
	andcc 	#$FE 
	puls 	D,X,Y,PC 

DESTINATION_ADD_ENTRY_ERROR_FULL
	; the array is full so return error 
	orcc 	#1
	puls 	D,X,Y,PC 

; -------------------------------------------------------------------------
; get pointer to currently active nick or channel destination
; Entry: none
; Exit: if no active destinations in the list, carry flag set
; 	 otherise, carry clear, D = offset into array of active destination, 
; 	 X = pointer to destination name
; 	 D and X are always modified either way.
; --------------------------------------------------------------------------
DESTINATION_GET_ACTIVE
	pshs 	Y 

	leax 	destArray,U 
	ldd 	destOffset,U 
	leax 	D,X 
	ldy 	,X 
	beq 	DESTINATION_GET_ACTIVE_NONE
	; if here, we do have an active destination 
	andcc 	#$FE 
	puls 	Y,PC 

DESTINATION_GET_ACTIVE_NONE
	orcc 	#1
	puls 	Y,PC

; ------------------------------------------------------------------
; initialize/setup/erase destination array by writing $0000 to first 
; 2 bytes of each entry 
; ------------------------------------------------------------------
DESTINATION_INITIALIZE_ARRAY
	pshs 	Y,X,D 
	; init the channel/nickname array 
	ldd 	#0
	ldy 	#0
	leax 	destArray,U 
DESTINATION_INITIALIZE_ARRAY_NEXT
	sty 	D,X
	addd 	#nickChanByteSize
	cmpd 	#destArraySz
	blo 	DESTINATION_INITIALIZE_ARRAY_NEXT 
	sty 	destOffset,U 

	puls 	D,X,Y,PC 