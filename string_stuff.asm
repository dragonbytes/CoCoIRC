******************************************************
* coco IRC client string-related and ASCII subroutines 
******************************************************
; ------------------------------------------------
; search ascii string for first space, NULL, or CR 
; Entry: X = pointer to string to search 
; Exit: on success, carry clear, 
; 	 B = number of characters before terminator, X = pointing to terminating char 
; 	 on fail, carry set
; ------------------------------------------------
FIND_NEXT_SPACE_NULL_CR
	pshs 	A 

	clrb 
FIND_NEXT_SPACE_NULL_CR_NEXT
	lda 	,X+
	beq 	FIND_NEXT_SPACE_NULL_CR_END
	cmpa 	#$20
	beq 	FIND_NEXT_SPACE_NULL_CR_END
	cmpa 	#C$CR 
	beq 	FIND_NEXT_SPACE_NULL_CR_END
	incb 
	bne 	FIND_NEXT_SPACE_NULL_CR_NEXT
	orcc 	#1 	; set carry for overflow error
	puls 	A,PC 

FIND_NEXT_SPACE_NULL_CR_END
	leax 	-1,X 
	andcc 	#$FE 	; carry clear for success 
	puls 	A,PC 

; --------------------------------
; find next nonspace char/skip "white space" 
; Entry: X = pointer to string to search 
; Exit:  A = character it found. X = pointing to character it found
; 	carry set if overflow past 256 bytes or NULL is encoutered  
; --------------------------------
FIND_NEXT_NONSPACE_CHAR
	pshs 	B
	clrb 
FIND_NEXT_NONSPACE_CHAR_NEXT
	lda 	,X+
	beq 	FIND_NEXT_NONSPACE_CHAR_FAIL
	cmpa 	#$20
	bne 	FIND_NEXT_NONSPACE_CHAR_DONE
	decb 
	bne 	FIND_NEXT_NONSPACE_CHAR_NEXT
FIND_NEXT_NONSPACE_CHAR_FAIL
	leax 	-1,X 
	orcc 	#1
	puls 	B,PC 

FIND_NEXT_NONSPACE_CHAR_DONE
	leax 	-1,X 
	andcc 	#$FE
	puls 	B,PC 

; -----------------------------------------------------------------------
; find specific character of your choice 
; Entry: A = character to look for. X = pointer to where to start looking
; Exit: B = length of characters until found 
; -----------------------------------------------------------------------
FIND_CUSTOM_CHAR
	pshs 	X,B
	clrb 
FIND_CUSTOM_CHAR_NEXT
	cmpa 	,X+
	beq 	FIND_CUSTOM_CHAR_END
	incb 
	bne 	FIND_CUSTOM_CHAR_NEXT
	orcc 	#1 	; set carry for overflow error
	puls 	B,X,PC 

FIND_CUSTOM_CHAR_END
	leax 	-1,X 
	andcc 	#$FE 	; carry clear for success 
	leas 	1,S 	; skip B on stack 
	puls 	X,PC 

; ---------------------------------------------------------------------------------
; copy a NULL-terminated string to destination 
; Entry: x = source, y = destination
; Exit: Y = pointining to null at the end of copy 
; ---------------------------------------------------------------------------------
STRING_COPY
	pshs 	X,D 
	clrb 
STRING_COPY_NEXT_CHAR
	lda 	,X+
	beq 	STRING_COPY_DONE
	cmpa 	#C$CR 				
	beq 	STRING_COPY_ALLOW_CR_LF 	; exempt CR and LF from the escape code 
	cmpa 	#C$LF  			; filter below 
	beq 	STRING_COPY_ALLOW_CR_LF
	cmpa 	#C$SPAC
	blo 	STRING_COPY_NEXT_CHAR 	; filter out any control codes like BOLD, 
						; ITALICS, etc. maybe support this later
						; with graphic fonts
	cmpa 	#%11000000
	blo 	STRING_COPY_STORE_CHAR
	; if here, we know its an extended UTF-8 sequence. now figure out if its a 2, 3, or 4 byte sequence 
	cmpa 	#%11100000
	bhs 	STRING_COPY_UTF8_CHECK_FOR_TRIPLE
	; if here, its a 2 byte sequence 
	leax 	1,X 				; skip the second byte
	decb 
	lda 	#$D6 				; insert a weird character to represent the unknown UTF8 sequence
	bra  	STRING_COPY_STORE_CHAR

STRING_COPY_UTF8_CHECK_FOR_TRIPLE
	cmpa 	#%11110000
	bhs 	STRING_COPY_UTF8_CHECK_FOR_QUAD
	; if here, its a 3 byte sequence 
	leax 	2,X 
	subb 	#2 
	lda 	#$AB 
	bra  	STRING_COPY_STORE_CHAR

STRING_COPY_UTF8_CHECK_FOR_QUAD
	cmpa  	#%11111000
	bhs  	STRING_COPY_STORE_CHAR 		; some unknown character that doesnt match any UTF-8 format. store it
	; if here, its a 4-byte sequence 
	leax 	3,X 
	subb 	#3
	lda 	#$BF 
STRING_COPY_STORE_CHAR
STRING_COPY_ALLOW_CR_LF
	sta 	,Y+
	decb 
	bne 	STRING_COPY_NEXT_CHAR
	; if here, overflow 
	clr 	,Y 	; mark NULL in destination 
	orcc 	#1
	puls 	D,X,PC 

STRING_COPY_DONE
	clr 	,Y 	; mark NULL in destination 
	andcc 	#$FE 
	puls 	D,X,PC 

; ---------------------------------------------------------------------------------
; copy a CR-terminated string to destination 
; Entry: x = source, y = destination
; Exit: Y = pointining to null at the end of copy 
; ---------------------------------------------------------------------------------
STRING_COPY_CR
	pshs 	X,D 
	clrb 
STRING_COPY_CR_NEXT_CHAR
	lda 	,X+
	cmpa 	#C$CR
	beq 	STRING_COPY_CR_DONE
	cmpa 	#C$SPAC
	blo 	STRING_COPY_CR_NEXT_CHAR 	; filter out any control codes like BOLD, 
						; ITALICS, etc. maybe support this later
						; with graphic fonts
	cmpa 	#%11000000
	blo 	STRING_COPY_CR_STORE_CHAR
	; if here, we know its an extended UTF-8 sequence. now figure out if its a 2, 3, or 4 byte sequence 
	cmpa 	#%11100000
	bhs 	STRING_COPY_CR_UTF8_CHECK_FOR_TRIPLE
	; if here, its a 2 byte sequence 
	leax 	1,X 				; skip the second byte
	decb 
	lda 	#$AB 				; insert a weird character to represent the unknown UTF8 sequence
	bra  	STRING_COPY_CR_STORE_CHAR

STRING_COPY_CR_UTF8_CHECK_FOR_TRIPLE
	cmpa 	#%11110000
	bhs 	STRING_COPY_CR_UTF8_CHECK_FOR_QUAD
	; if here, its a 3 byte sequence 
	leax 	2,X 
	subb 	#2 
	lda 	#$AB 
	bra  	STRING_COPY_CR_STORE_CHAR

STRING_COPY_CR_UTF8_CHECK_FOR_QUAD
	cmpa  	#%11111000
	bhs  	STRING_COPY_CR_STORE_CHAR 		; some unknown character that doesnt match any UTF-8 format. store it
	; if here, its a 4-byte sequence 
	leax 	3,X 
	subb 	#3
	lda 	#$AB 
STRING_COPY_CR_STORE_CHAR
	sta 	,Y+
	decb 
	bne 	STRING_COPY_CR_NEXT_CHAR
	; if here, overflow 
	clr 	,Y 	; mark NULL in destination 
	coma 
	puls 	D,X,PC 
STRING_COPY_CR_DONE
	clr 	,Y 	; mark NULL in destination 
	puls 	D,X,PC 

; --------------------------------------------------------------------------------
; copy a raw string, including control codes, etc until NULL 
; Entry: X = source pointer, Y = Destination Pointer 
; Exit: carry set = fail, carry clear success, Y = pointer to final NULL in dest 
; --------------------------------------------------------------------------------
STRING_COPY_RAW
	pshs 	X,D 
	clrb 
STRING_COPY_RAW_NEXT
	lda 	,X+
	sta 	,Y+
	beq 	STRING_COPY_RAW_DONE
	decb 
	bne 	STRING_COPY_RAW_NEXT
	coma 	; set carry for error 
	puls 	D,X,PC 

STRING_COPY_RAW_DONE
	leay 	-1,Y 		; undo auto-increment 
	; carry already cleared from STA of NULL 
	puls 	D,X,PC 

; ------------------------------------------------------------------------------
; get timestamp and copy it to pointer in Y 
; ------------------------------------------------------------------------------
STRING_COPY_TIMESTAMP
	pshs 	Y,X,D 

	ldb 	<showTimestampFlag
	bne 	STRING_COPY_TIMESTAMP_SHOW_IT
	; if here, hide the timestamp but DO copy the normal color change code 
	lda 	#colorNormal
	lbsr 	COPY_COLOR_CODE_FOREGROUND
	sty 	4,S  		; update value on stack to make it faster to pull/return 
	puls 	D,X,Y,PC 

STRING_COPY_TIMESTAMP_SHOW_IT
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

	leax 	strTimestamp,U 
	ldy 	4,S 

	; now copy resulting string into destination 
	clrb 
STRING_COPY_TIMESTAMP_NEXT
	lda 	,X+
	sta 	,Y+
	beq 	STRING_COPY_TIMESTAMP_DONE
	decb 
	bne 	STRING_COPY_TIMESTAMP_NEXT
	coma 	; set carry for error 
	sty 	4,S  		; update value on stack to make it faster to pull/return 
	puls 	D,X,Y,PC 

STRING_COPY_TIMESTAMP_DONE
	leay 	-1,Y 		; undo auto-increment 
	sty 	4,S  		; update value on stack to make it faster to pull/return 
	puls 	D,X,Y,PC 

; -----------------------------------------------
; searches a string of space-delimitted words for 
; a specific one, ignoring case. 
; Entry: X = string to search, ignoring case.
; 	Y = keyword to find (MUST BE IN CAPS)
; Exit: success, X pointing to character after last matched char 
; -----------------------------------------------
STRING_SEARCH_KEYWORD
	pshs 	Y,D 

STRING_SEARCH_KEYWORD_NEXT_WORD
	ldy 	2,S 		; reset Y from stack 
	lbsr 	FIND_NEXT_NONSPACE_CHAR
	bcs 	STRING_SEARCH_KEYWORD_FAIL
STRING_SEARCH_KEYWORD_NEXT_CHAR
	lda 	,Y 
	beq 	STRING_SEARCH_KEYWORD_MATCHED
	lda 	,X+
	lbsr 	CONVERT_UPPERCASE
	cmpa 	,Y+
	beq 	STRING_SEARCH_KEYWORD_NEXT_CHAR
	; if here, no match. look for another word to test 
	leax 	-1,X 
	lbsr 	FIND_NEXT_SPACE_NULL_CR
	bcs 	STRING_SEARCH_KEYWORD_FAIL
	lda 	,X 
	cmpa 	#C$SPAC 
	beq 	STRING_SEARCH_KEYWORD_NEXT_WORD
STRING_SEARCH_KEYWORD_FAIL
	orcc 	#1
	puls 	D,Y,PC 

STRING_SEARCH_KEYWORD_MATCHED
	andcc 	#$FE
	puls 	D,Y,PC 

; ----------------------------------------------------
; compare a NULL terminated parameter pointed to by Y
; with a CR/SPACE/NULL/CTRLCODE terminated word pointed to by X
; This comparison is NOT case-sensitive!
; ---------------------------------------------------- 
COMPARE_PARAM
	pshs 	Y,X,D 
	clrb 
COMPARE_PARAM_NEXT_CHAR
	lda 	,Y+
	beq 	COMPARE_PARAM_CHECK_PASS
	bsr 	CONVERT_UPPERCASE
	sta 	<tempChar
	lda 	,X+
	bsr 	CONVERT_UPPERCASE
	cmpa 	<tempChar
	bne 	COMPARE_PARAM_FAIL
	decb 
	bne 	COMPARE_PARAM_NEXT_CHAR
	; if here, overflow. oh noes..
COMPARE_PARAM_FAIL
	orcc 	#1
	puls 	D,X,Y,PC 

COMPARE_PARAM_CHECK_PASS
	lda 	,X 
	beq 	COMPARE_PARAM_MATCH
	cmpa 	#C$CR 
	beq 	COMPARE_PARAM_MATCH
	cmpa 	#C$SPAC
	beq  	COMPARE_PARAM_MATCH
	cmpa 	#$01 			; CTCP control code 
	bne 	COMPARE_PARAM_FAIL
COMPARE_PARAM_MATCH
	andcc 	#$FE 
	puls 	D,X,Y,PC 

;---------------------------------
; convert to uppercase 
; Entry: A = character to be converted 
; Exit: A = converted character 
; --------------------------------
CONVERT_UPPERCASE
      ; check and/or convert lowercase to uppercase
      cmpa  #$61        ; $61 is "a"
      blo   CONVERT_UPPERCASE_NO_CONVERSION
      cmpa  #$7A  ; $7A is "z"
      bhi   CONVERT_UPPERCASE_NO_CONVERSION
      suba  #$20  ; convert from lowercase to uppercase 
CONVERT_UPPERCASE_NO_CONVERSION
      rts 

; ----------------------------------------------------------------------
; Convert and copy decimal string number to 8 bit byte
; Entry: X = pointer to null/CR/SPACE terminated ascii number to convert
; 	  Y = pointer to 8 bit variable to write the result to 
; Exit: carry is clear on success and B contains resulting valule. also 
; 	 u8Value contains the result. carry set if ascii chars are not numeric 
; ----------------------------------------------------------------------

COPY_STRING_DEC_TO_BYTE
	pshs 	X,A

	clr 	<u8Value  
COPY_STRING_DEC_TO_BYTE_NEXT_CHAR
	; find last number first
	ldb 	,X+
	beq 	COPY_STRING_DEC_TO_BYTE_FOUND_END
	cmpb 	#C$SPAC 
	beq 	COPY_STRING_DEC_TO_BYTE_FOUND_END
	cmpb 	#C$CR 
	bne 	COPY_STRING_DEC_TO_BYTE_NEXT_CHAR
COPY_STRING_DEC_TO_BYTE_FOUND_END
	leax 	-1,X 		; backup to point to NULL or space 
	ldb 	,-X 
	; check if the character is a valid number first 
	cmpb 	#'9'
	bhi 	COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	cmpb 	#'0'
	blo 	COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	subb 	#$30
	stb 	<u8Value   
	cmpx 	1,S
	beq 	COPY_STRING_DEC_TO_BYTE_DONE
	ldb 	,-X
	; check if the character is a valid number first 
	cmpb 	#'9'
	bhi 	COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	cmpb 	#'0'
	blo 	COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	subb 	#$30
	lda 	#10
	mul 
	addb 	<u8Value  
	stb 	<u8Value   
	cmpx 	1,S
	beq 	COPY_STRING_DEC_TO_BYTE_DONE
	ldb 	,-X 
	; check if the character is a valid number first 
	cmpb 	#'9'
	bhi 	COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	cmpb 	#'0'
	blo 	COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	subb 	#$30
	lda 	#100
	mul 
	addb 	<u8Value   
	stb 	<u8Value 
COPY_STRING_DEC_TO_BYTE_DONE
	andcc 	#$FE
	puls 	A,X,PC 

COPY_STRING_DEC_TO_BYTE_ERROR_INVALID
	orcc 	#1
	puls 	A,X,PC 
; ----------------------------------------------
; copy a parameter word delimitted by a NULL, 
; CR, or SPACE.
; Exit: X = points to ending/terminating character
; 	B = number of bytes written to Y pointer 
; 	Y = pointing to the NULL at end of destination 
; ----------------------------------------------
PARAM_COPY
	pshs 	A 

	clrb 
PARAM_COPY_NEXT_CHAR
	lda 	,X+
	beq 	PARAM_COPY_DONE
	cmpa 	#C$CR 
	beq 	PARAM_COPY_DONE
	cmpa 	#C$SPAC 
	beq 	PARAM_COPY_DONE
	blo 	PARAM_COPY_NEXT_CHAR 	; filter out any control codes like BOLD, 
						; ITALICS, etc. maybe support this later
						; with graphic fonts
	sta 	,Y+
	incb 
	bne 	PARAM_COPY_NEXT_CHAR
	orcc 	#1
	puls 	A,PC 
PARAM_COPY_DONE
	leax 	-1,X 
	clr 	,Y 	; mark NULL in destination 
	andcc 	#$FE
	puls 	A,PC 

; ---------------------------------------------------------------------------
; copy a parameter delimited by NULL, CR, or space and convert result into
; uppercase
; ---------------------------------------------------------------------------
PARAM_COPY_UPPER
	pshs 	A 

	clrb 
PARAM_COPY_UPPER_NEXT_CHAR
	lda 	,X+
	beq 	PARAM_COPY_UPPER_DONE
	cmpa 	#C$CR 
	beq 	PARAM_COPY_UPPER_DONE
	cmpa 	#C$SPAC 
	beq 	PARAM_COPY_UPPER_DONE
	blo 	PARAM_COPY_UPPER_NEXT_CHAR 	; filter out any control codes like BOLD, 
							; ITALICS, etc. maybe support this later
							; with graphic fonts
	lbsr  CONVERT_UPPERCASE
	sta 	,Y+
	incb 
	bne 	PARAM_COPY_UPPER_NEXT_CHAR
	orcc 	#1
	puls 	A,PC 
PARAM_COPY_UPPER_DONE
	leax 	-1,X 
	clr 	,Y 	; mark NULL in destination 
	andcc 	#$FE
	puls 	A,PC 

; ---------------------------------------------------------------------------
; copy a channel name into outputbuffer from either command string or 
; active destination table 
; Entry: X = pointer to command string to search
; 	Y = pointer to where to copy channel name 
; Exit: if channel name found in command string, X points to 
; 	terminating character after the name and B = 0. if copied from active 
; 	destination, then X doesn't change and B = 1.
; 	if no channel found anywhere, X doesnt change either and carry is set 
; --------------------------------------------------------------------------
COPY_CHAN_FROM_CMD_OR_ACTIVE
	pshs 	X,A 

	lbsr 	FIND_NEXT_NONSPACE_CHAR
	cmpa 	#'#'
	beq 	COPY_CHAN_FROM_CMD_OR_ACTIVE_FOUND
	; no chan name found in string. try to use current active destination 
	lbsr 	DESTINATION_GET_ACTIVE 		; get pointer to current destination 
	bcs 	COPY_CHAN_FROM_CMD_OR_ACTIVE_NONE	
	; make sure active destination is a channel 
	lda 	,X 
	cmpa 	#'#'
	bne 	COPY_CHAN_FROM_CMD_OR_ACTIVE_NONE
	lbsr 	PARAM_COPY
	ldb 	#1
	andcc 	#$FE 
	puls 	A,X,PC

COPY_CHAN_FROM_CMD_OR_ACTIVE_FOUND
	lbsr 	PARAM_COPY 		; copy manual chan name over
	stx 	1,S 			; update X value on stack with new position 
	clrb  				; B = 0 means it found the channel in command line 
	andcc 	#$FE 
	puls 	A,X,PC

COPY_CHAN_FROM_CMD_OR_ACTIVE_NONE
	orcc 	#1
	puls 	A,X,PC 

; -----------------------------------------------------------------------
; find CR or NULL and return length 
; Entry: X = pointer to where to start measuring/looking 
; Exit: Y = length of characters until CR or NULL 
; -----------------------------------------------------------------------
FIND_LEN_UNTIL_EOF 
	pshs 	X,A
	ldy 	#0
FIND_LEN_UNTIL_EOF_NEXT
	lda 	,X+
	beq 	FIND_LEN_UNTIL_EOF_END
	cmpa 	#C$CR
	beq 	FIND_LEN_UNTIL_EOF_END
	leay 	1,Y 
	bne 	FIND_LEN_UNTIL_EOF_NEXT
	orcc 	#1 	; set carry for overflow error
	puls 	A,X,PC 

FIND_LEN_UNTIL_EOF_END
	andcc 	#$FE
	puls 	A,X,PC 

; ---------------------------------------------------------------------
; check if a server port was specified with a : and 4 digit port number
; Entry: X = pointer to server name string to search 
; Exit: if colon is found, carry clear and all registers are preserved
; 	if not found, carry set and X points to the terminating char
; 	at the END of the server name string 
; --------------------------------------------------------------------- 
CHECK_FOR_PORT_NUMBER
	pshs 	X,D 

	clrb 
CHECK_FOR_PORT_NUMBER_NEXT_CHAR
	lda 	,X+
	beq 	CHECK_FOR_PORT_NUMBER_NONE
	cmpa 	#C$CR 
	beq 	CHECK_FOR_PORT_NUMBER_NONE
	cmpa 	#C$SPAC 
	beq 	CHECK_FOR_PORT_NUMBER_NONE
	cmpa 	#':'
	beq 	CHECK_FOR_PORT_NUMBER_FOUND
	decb 
	bne 	CHECK_FOR_PORT_NUMBER_NEXT_CHAR
CHECK_FOR_PORT_NUMBER_NONE
	leax 	-1,X 	; undo auto increment 
	ldd 	,S 
	leas 	4,S
	orcc 	#1
	rts 

CHECK_FOR_PORT_NUMBER_FOUND
	andcc 	#$FE 
	puls 	D,X,PC 

; ------------------------------------------------------------------
; convert and copy a byte value to a decimal string 
; Entry: B = number to convert, if A = 0, always show 2 digits.
; 	  if A is non-zero, ignore all leading zeros 
; 	  Y = pointer to address where to write the ASCII string
; Exit:  Y = pointing to null terminator 
; ------------------------------------------------------------------
COPY_BYTE_TO_STRING
	pshs 	D,X

	leax 	strNumeric,U 
	lda 	#$FF 
COPY_BYTE_TO_STRING_INC_100S
	inca 
	subb 	#100 
	bcc 	COPY_BYTE_TO_STRING_INC_100S
	adda 	#$30 	; the magic ASCII number 
	sta 	,X+
	lda 	#$FF 		; reset counter
	addb 	#100
COPY_BYTE_TO_STRING_INC_10S
	inca 
	subb 	#10	
	bcc 	COPY_BYTE_TO_STRING_INC_10S
	adda 	#$30
	sta 	,X+
	addb 	#$3A 	; $30 ASCII '0' + 10 from previous subtraction  
	stb 	,X+ 	; write final number
	clr 	,X 

	leax 	strNumeric,U 
	lda 	,S 	; check for ignore leading zeros flag 
	bne 	COPY_BYTE_TO_STRING_IGNORE_LEADING_ZEROES
	; if here, just show the last 2 digits 
	ldd 	strNumeric+1,U 
	std 	,Y++
	clr 	,Y 
	bra 	COPY_BYTE_TO_STRING_DONE

COPY_BYTE_TO_STRING_IGNORE_LEADING_ZEROES
	clrb 
	lda 	,X
	cmpa 	#$30
	beq 	COPY_BYTE_TO_STRING_SKIP_100S
	sta 	,Y+
	incb 
COPY_BYTE_TO_STRING_SKIP_100S
	lda 	1,X 
	tstb 
	bne 	COPY_BYTE_TO_STRING_WRITE_10S
	cmpa 	#$30
	beq 	COPY_BYTE_TO_STRING_SKIP_10S
COPY_BYTE_TO_STRING_WRITE_10S
	sta 	,Y+
	incb 
COPY_BYTE_TO_STRING_SKIP_10S
	lda 	2,X 
	clrb 
	std 	,Y+
COPY_BYTE_TO_STRING_DONE
	puls 	X,D,PC

; ----------------------------------------------------------------
; convert and copy a word value to decimal form in a string 
; Entry: D = holds value to be converted to decimal ASCII string 
; 	  Y = pointer to address where to write the ASCII string.
; Exit:  Y = pointing to null terminator
; 	  u16Value is destroyed.
; ----------------------------------------------------------------
COPY_WORD_TO_STRING
	pshs 	D,X

	ldx 	#$0000 	; use X as flag to tell if we need to ignore leading zeros 
	std 	<u16Value 
	clr 	<decDigitCounter
COPY_WORD_TO_STRING_INC_10000S
	subd 	#10000 
	blo 	COPY_WORD_TO_STRING_JUMP_1000S
	inc 	<decDigitCounter
	leax 	1,X
	bra 	COPY_WORD_TO_STRING_INC_10000S
COPY_WORD_TO_STRING_JUMP_1000S
	addd 	#10000
	std 	<u16Value
	cmpx 	#$0000
	beq 	COPY_WORD_TO_STRING_SKIP_10000S
	lda 	<decDigitCounter
	adda 	#$30  	; the magic ASCII number 
	sta 	,Y+
COPY_WORD_TO_STRING_SKIP_10000S
	clr 	<decDigitCounter 		; reset counter
	ldd 	<u16Value
COPY_WORD_TO_STRING_INC_1000S
	subd 	#1000
	blo 	COPY_WORD_TO_STRING_JUMP_100S 
	inc 	<decDigitCounter
	leax 	1,X 	
	bra 	COPY_WORD_TO_STRING_INC_1000S
COPY_WORD_TO_STRING_JUMP_100S
	addd 	#1000
	std 	<u16Value
	cmpx 	#$0000
	beq 	COPY_WORD_TO_STRING_SKIP_1000S
	lda 	<decDigitCounter
	adda 	#$30
	sta 	,Y+
COPY_WORD_TO_STRING_SKIP_1000S
	clr 	<decDigitCounter
	ldd 	<u16Value
COPY_WORD_TO_STRING_INC_100S
	subd 	#100
	blo 	COPY_WORD_TO_STRING_JUMP_10S
	inc 	<decDigitCounter
	leax 	1,X
	bra 	COPY_WORD_TO_STRING_INC_100S
COPY_WORD_TO_STRING_JUMP_10S
	addd 	#100
	; we should only need value in B now since we are less than 255
	cmpx 	#$0000
	beq 	COPY_WORD_TO_STRING_SKIP_100S
	lda 	<decDigitCounter
	adda 	#$30
	sta 	,Y+
COPY_WORD_TO_STRING_SKIP_100S
	clr 	<decDigitCounter
COPY_WORD_TO_STRING_INC_10S
	subb 	#10
	blo 	COPY_WORD_TO_STRING_JUMP_1S
	inc 	<decDigitCounter
	leax 	1,X
	bra 	COPY_WORD_TO_STRING_INC_10S
COPY_WORD_TO_STRING_JUMP_1S
	cmpx 	#$0000
	beq 	COPY_WORD_TO_STRING_SKIP_10S
	lda 	<decDigitCounter
	adda 	#$30
	sta 	,Y+
COPY_WORD_TO_STRING_SKIP_10S
	addb 	#$3A 	; $30 ASCII '0' + 10 from previous subtraction 
	stb 	,Y+ 	; write final number
	clr 	,Y 	; write null terminator

	puls 	X,D,PC

;------------------------------------------------
; Scan a CR or NULL terminated string for user's
; current nickname
; -----------------------------------------------
SCAN_YOUR_NICKNAME
	pshs  	Y,X,D  

	leay  	serverYourNickUpper,U 
	lda  	,X+
	beq  	SCAN_YOUR_NICKNAME_CHECK_LAST
	cmpa  	#C$CR 
	beq  	SCAN_YOUR_NICKNAME_CHECK_LAST
	;bsr  	CONVERT_UPPERCASE
	cmpa  	,Y 
	;bne  	SCAN_YOUR_NICKNAME_NEXT_CHAR


SCAN_YOUR_NICKNAME_CHECK_LAST

SCAN_YOUR_NICKNAME_MATCHED_ONE


; ---------------------------------------------
PRINT_CHATLOG_NULL_STRING
	pshs 	Y,X,D

PRINT_CHATLOG_NULL_STRING_NEXT
	lda 	,X+
	bne 	PRINT_CHATLOG_NULL_STRING_NEXT
	; found null terminator 
	tfr 	X,D 
	subd 	#1
	subd 	2,S
	tfr 	D,Y 
	ldx  	2,S 
	lda 	<chatlogPath
	os9 	I$Write

	puls 	D,X,Y,PC 

 IFDEF use_word_wrap
; ---------------------------------------------
PRINT_CHATLOG_WITH_WORD_WRAP
	pshs 	U,Y,X,D

	leau 	wordWrapBuffer,U 
	ldy 	#0 
PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS 
	ldd 	#0
	std 	<wrapSourcePtr
	std 	<wrapDestPtr
PRINT_CHATLOG_WITH_WORD_WRAP_NEXT_CHAR_RESET_COUNTER
	ldb 	#screen_width
PRINT_CHATLOG_WITH_WORD_WRAP_NEXT_CHAR
	lda 	,X+
	beq 	PRINT_CHATLOG_WITH_WORD_WRAP_DONE
	sta 	,U+
	leay 	1,Y 
	cmpa 	#$1B 
	bne 	PRINT_CHATLOG_WITH_WORD_WRAP_NOT_ESCAPE_CODE
	; if we see escape code $1B, assume its a color change code and seperately copy those extra 2 bytes over 
	; without decrementing our column countdown 
	lda 	,X+
	sta 	,U+
	lda 	,X+
	sta 	,U+
	leay 	2,Y 					; add the extra 2 bytes to our total screen output counter 
	bra 	PRINT_CHATLOG_WITH_WORD_WRAP_NEXT_CHAR

PRINT_CHATLOG_WITH_WORD_WRAP_NOT_ESCAPE_CODE
	; check if char is a CR. if so, reset the ptrs and counters since we will be starting on a new line 
	cmpa 	#C$CR 
	beq  	PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS	
	; check if this is a SPACE character. if less than $20, it's a control code and skip counting it
	cmpa 	#C$SPAC 
	blo 	PRINT_CHATLOG_WITH_WORD_WRAP_NEXT_CHAR 	; filter/skip counting any other control codes we encouter 
	bne 	PRINT_CHATLOG_WITH_WORD_WRAP_NOT_SPACE
	; if here, it was a SPACE char so update the pointers to the last known position of a space 
	stx 	<wrapSourcePtr 		; NOTE: pointers are to the char AFTER the space 
	stu 	<wrapDestPtr 
PRINT_CHATLOG_WITH_WORD_WRAP_NOT_SPACE
	decb 
	bne 	PRINT_CHATLOG_WITH_WORD_WRAP_NEXT_CHAR
	cmpa 	#C$SPAC 		; if last char in row is a space, we dont need to do anything so skip ahead 
	beq 	PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS
	; check the next char to be copied. if it is a CR or a space, we dont need to do anything, so skip 
	lda 	,X 
	cmpa 	#C$CR 
	beq 	PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS 
	cmpa 	#C$SPAC
	bne 	PRINT_CHATLOG_WITH_WORD_WRAP_MIDDLE_OF_WORD
	; since word ended evenly on last column and auto-linefeed happens, skip the next space in source string 
	leax 	1,X  
	bra 	PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS

PRINT_CHATLOG_WITH_WORD_WRAP_MIDDLE_OF_WORD
	; if we are here, we seem to be in the middle of a word. check if there was a space earlier on that line 
	ldd 	<wrapSourcePtr
	beq 	PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS 	; no spaces found so ignore wordwrap and reset everything 
	tfr 	X,D 
	subd 	<wrapSourcePtr
	addd 	#1 						; add the space byte we'll be omitting later 
	; convert 16 bit unsigned value to it's negative equivalent
	comb 
	coma 
	addd 	#1
	leay 	D,Y  					; now use that to essentially subtract the value from Y 
	; restore the pointers to where the space was to insert our linebreak 
	ldx 	<wrapSourcePtr
	ldu 	<wrapDestPtr
	; don't undo the auto-increment for X because we want to skip that space anyways when we continue 
	leau 	-1,U 					; undo the auto-increment from earlier 
	; insert our extra CR+LF into wordwrap output buffer and reset ptrs and counter and continue copying 
	ldd 	#cr_lf
	std 	,U++
	; add the 2 new bytes to the total count 
	leay 	2,Y 	
	bra 	PRINT_CHATLOG_WITH_WORD_WRAP_RESET_PTRS

PRINT_CHATLOG_WITH_WORD_WRAP_DONE
	sta 	,U 					; save the final NULL 
	ldu 	<uRegImage
	leax 	wordWrapBuffer,U 
	; Y should already have the number of bytes to write 
	lda 	<chatlogPath
	os9 	I$Write

	puls 	D,X,Y,U,PC 
 ENDC 

; ---------------------------------------------
; write a CR+LF terminated string, including 
; the CRLF, to the path number in A 
; Entry: A = path to write result to 
; ---------------------------------------------
WRITE_CRLF_STRING
	pshs 	Y,X,D 

	clrb 
WRITE_CRLF_STRING_NEXT
	lda 	,X+
	cmpa 	#C$LF 
	beq 	WRITE_CRLF_STRING_WRITE
	incb 
	bne 	WRITE_CRLF_STRING_NEXT
	orcc 	#1
	puls 	D,X,Y,PC 

WRITE_CRLF_STRING_WRITE
	clra 
	addd 	#1 		; add 1 to include the last LF char 
	tfr 	D,Y 
	ldx  	2,S 
	lda 	,S 		; grab destination path from stack 
	os9 	I$Write

	puls 	D,X,Y,PC 

; -----------------------------
; convert 8-bit binary value <100 to ascii decimal
; WARNING: THIS ONLY IS VALID FOR 2 DIGIT DECIMAL NUMBERS 
; Entry: B = value to be printed in decimal ASCII 
;        Y = destination to write result 
; Exit: 	Y = pointing 2 bytes AFTER the last byte written 
; --------------------------------
CONVERT_TIME_BYTE_DEC
      pshs  X,D 

      clra        ; reset counter
CONVERT_TIME_BYTE_DEC_INC_10S
      subb  #10
      blo   CONVERT_TIME_BYTE_DEC_JUMP_1S 
      inca  
      bra   CONVERT_TIME_BYTE_DEC_INC_10S
CONVERT_TIME_BYTE_DEC_JUMP_1S
      adda  #$30
      sta   ,Y+
CONVERT_TIME_BYTE_DEC_SKIP_10S
      addb  #$3A  ; $30 ASCII '0' + 10 from previous subtraction 
      stb   ,Y++

      puls  D,X,PC

; ----------------------------------------------------
; convert epoch time in ascii to actual binary value 
; ----------------------------------------------------
CONVERT_EPOCH_ASCII_TO_DWORD
	pshs 	Y,X,D 

	; clear current counter variable 
	ldd 	#0 
	std 	<u32Value
	std 	<u32Value+2 

	lbsr 	FIND_NEXT_NONSPACE_CHAR 		; skip any leading spaces 
	stx 	<tempPtr 				; mark the beginning of number string 
	; first find end of string 
CONVERT_EPOCH_ASCII_TO_DWORD_NEXT_CHAR
	lda 	,X+
	beq 	CONVERT_EPOCH_ASCII_TO_DWORD_FOUND_END
	cmpa 	#C$SPAC 
	beq 	CONVERT_EPOCH_ASCII_TO_DWORD_FOUND_END
	cmpa 	#C$CR 
	bne 	CONVERT_EPOCH_ASCII_TO_DWORD_NEXT_CHAR
CONVERT_EPOCH_ASCII_TO_DWORD_FOUND_END
	leax 	-1,X  				; undo the auto-increment
	; update value on stack to reflect pointer to terminating char after epoch ascii string 
	stx 	2,S 				
	leay 	epochDigitCounters,PCR  	; setup pointer to the 10s unit counters 
CONVERT_EPOCH_ASCII_TO_DWORD_NEXT_DIGIT
	lda 	,-X 
	suba 	#$30 		; convert ascii digit to binary value 
	beq 	CONVERT_EPOCH_ASCII_TO_DWORD_SKIP_ASCII_ZERO
CONVERT_EPOCH_ASCII_TO_DWORD_ADD_LOOP
	bsr 	ADD_32BIT 	; add the appropriate 10 base counter to u32Value pointed to by Y 
	deca 
	bne 	CONVERT_EPOCH_ASCII_TO_DWORD_ADD_LOOP
CONVERT_EPOCH_ASCII_TO_DWORD_SKIP_ASCII_ZERO
	leay 	4,Y 		; move pointer to next 32bit denomination of 10s
	; check if that was our final digit (and the beginning of the string)
	cmpx 	<tempPtr 
	bne 	CONVERT_EPOCH_ASCII_TO_DWORD_NEXT_DIGIT
	; if here, we have processed each digit successfully! 

	puls 	D,X,Y,PC 

 ;---------------------------------------------------
 ; 32 bit addition 
 ; --------------------------------------------------
ADD_32BIT
      pshs  D 
      ldd   <u32Value+2 
      addd  2,Y 
      std   <u32Value+2 
      ldd   <u32Value  
      adcb  1,Y 
      adca  ,Y 
      std   <u32Value  

      bne   ADD_32BIT_NOT_ZERO
      ldd   <u32Value+2 
      andcc #%11110111
ADD_32BIT_NOT_ZERO
      puls  D,PC 

; -------------------------------------------------
; 32 bit subtraction 
; 
; -------------------------------------------------
SUBTRACT_32BIT
      pshs  D
      ldd   <u32Value+2
      subd  2,Y 
      std   <u32Value+2 
      ldd   <u32Value 
      sbcb  1,Y 
      sbca  ,Y 
      std   <u32Value  

      ; carry should be set properly now from subtract, now make sure zero flag works too
      ;ldd   ,X   ; not needed cuz previous instruction was STD ,X which already sets the Z and N flags 
      bne   SUBTRACT_32BIT_NOT_ZERO
      ldd   <u32Value+2
      andcc #%11110111 
SUBTRACT_32BIT_NOT_ZERO
      puls  D,PC 

; ----------------------------------------------------
; u32Value should contain a copy of the epoch time 
EPOCH_CALCULATE_DATE_TIME
	pshs 	Y,X,D 
	; sample epoch number: 1342139995

	; zero out all the epoch date/time variables in a row 
	ldd 	#0
	std 	<epochYear 
	std 	<epochYear+2
	std 	<epochYear+4
	; start at 1973 offset since thats first year after a leap year 
	leay 	epochConstOffset,PCR 
	lbsr 	SUBTRACT_32BIT

EPOCH_CALCULATE_DATE_TIME_RESET_LEAPYEAR
	lda 	#4				; leap year counter 
EPOCH_CALCULATE_DATE_TIME_RESET_YEAR
	clrb 					; month counter (0-11)
	leay 	epochMonthTable,PCR 		; start at january 
EPOCH_CALCULATE_DATE_TIME_MONTH_LOOP
	cmpa 	#1 				; is this a leap year?
	bne 	EPOCH_CALCULATE_DATE_TIME_MONTH_NOT_LEAPYEAR
	cmpb  	#2 				; did we pass through feb 29th into march?
	bne 	EPOCH_CALCULATE_DATE_TIME_MONTH_NOT_MARCH_YET
	; if here, we have crossed through feb into march on leapyear. subtract extra day 
	leay 	epochConstDay,PCR
	lbsr 	SUBTRACT_32BIT
	bcs 	EPOCH_CALCULATE_DATE_TIME_OVERFLOW
	leay 	epochMonthTable+8,PCR 	; reset pointer to march constant to continue
EPOCH_CALCULATE_DATE_TIME_MONTH_NOT_MARCH_YET
EPOCH_CALCULATE_DATE_TIME_MONTH_NOT_LEAPYEAR
	lbsr 	SUBTRACT_32BIT
	bcs 	EPOCH_CALCULATE_DATE_TIME_OVERFLOW
	leay 	4,Y 
	incb 
	cmpb 	#11 
	bls 	EPOCH_CALCULATE_DATE_TIME_MONTH_LOOP
	inc 	<epochYear 
	deca 
	bne 	EPOCH_CALCULATE_DATE_TIME_RESET_YEAR
	bra 	EPOCH_CALCULATE_DATE_TIME_RESET_LEAPYEAR 	; reset leap year counter 
	
EPOCH_CALCULATE_DATE_TIME_OVERFLOW
	lbsr 	ADD_32BIT
	stb 	<epochMonth 
	; now we have the year and month. now divide out the remaining days 
	leay 	epochConstDay,PCR 
	clrb  
EPOCH_CALCULATE_DATE_TIME_DAYS_DIVIDE_LOOP
	incb
	lbsr 	SUBTRACT_32BIT 
	bcc 	EPOCH_CALCULATE_DATE_TIME_DAYS_DIVIDE_LOOP 
	stb 	<epochDay

	lbsr 	ADD_32BIT 		; get back remainder 
	; calculate hours 
	ldb 	#$FF 
	leay 	epochConstHour,PCR 
EPOCH_CALCULATE_DATE_TIME_HOURS_DIVIDE_LOOP
	incb 
	lbsr 	SUBTRACT_32BIT
	bcc 	EPOCH_CALCULATE_DATE_TIME_HOURS_DIVIDE_LOOP
	stb 	<epochHour 

	lbsr 	ADD_32BIT 		; get back remainder 
	lda 	#$FF 
	sta 	<epochMinute  
 	ldd 	<u32Value+2
EPOCH_CALCULATE_DATE_TIME_MINS_DIVIDE_LOOP
	inc 	<epochMinute
 	subd 	#60
 	bcc 	EPOCH_CALCULATE_DATE_TIME_MINS_DIVIDE_LOOP
 	addd 	#60 		; get remainder back 
 	stb 	<epochSecond

	puls 	D,X,Y,PC 

; -------------------------------------------------------
; copy epoch time stamp in human-readable form. epoch 
; variables must be pre-populated from conversion routine 
; Entry: Y = pointer to where to write output string 
; -------------------------------------------------------
COPY_STRING_EPOCH_TIMESTAMP
	pshs 	X,D 

	ldb 	<epochMonth
	lslb 
	leax 	strEpochMonthPtrs,PCR 
	ldd 	B,X 
	leax 	0,PCR
	leax 	D,X 
	lbsr 	STRING_COPY_RAW
	lda 	#C$SPAC
	sta 	,Y+
	clra 	; don't ignore leading zeros 
	ldb 	<epochDay
	lbsr 	COPY_BYTE_TO_STRING
	ldd 	#", "
	std 	,Y++
	clra 
	ldb 	<epochYear
	addd 	#1973
	lbsr 	COPY_WORD_TO_STRING
	lda 	#C$SPAC 
	sta 	,Y+
	ldb 	<epochHour
	clra 	; don't ignore leading zeros 
	lbsr 	COPY_BYTE_TO_STRING
	lda 	#':'
	sta 	,Y+
	clra 	; don't ignore leading zeros 
	ldb 	<epochMinute
	lbsr 	COPY_BYTE_TO_STRING
	lda 	#':'
	sta 	,Y+
	clra 	; don't ignore leading zeros 
	ldb 	<epochSecond
	lbsr 	COPY_BYTE_TO_STRING
	ldd 	#" U"
	std 	,Y++
	ldd 	#"TC"
	std 	,Y++
	clr 	,Y 
	
	puls 	D,X,PC 

; ----------------------------------------------------
EPOCH_CALCULATE_IDLE_TIME
	pshs 	Y,X,D 

	leay 	epochConstDay,PCR 
	ldb 	#$FF   
EPOCH_CALCULATE_IDLE_TIME_DAYS_DIVIDE_LOOP
	incb
	lbsr 	SUBTRACT_32BIT 
	bcc 	EPOCH_CALCULATE_IDLE_TIME_DAYS_DIVIDE_LOOP 
	stb 	<epochDay

	lbsr 	ADD_32BIT 		; get back remainder 
	; calculate hours 
	ldb 	#$FF 
	leay 	epochConstHour,PCR 
EPOCH_CALCULATE_IDLE_TIME_HOURS_DIVIDE_LOOP
	incb 
	lbsr 	SUBTRACT_32BIT
	bcc 	EPOCH_CALCULATE_IDLE_TIME_HOURS_DIVIDE_LOOP
	stb 	<epochHour 

	lbsr 	ADD_32BIT 		; get back remainder 
	lda 	#$FF 
	sta 	<epochMinute  
 	ldd 	<u32Value+2
EPOCH_CALCULATE_IDLE_TIME_MINS_DIVIDE_LOOP
	inc 	<epochMinute
 	subd 	#60
 	bcc 	EPOCH_CALCULATE_IDLE_TIME_MINS_DIVIDE_LOOP
 	addd 	#60 		; get remainder back 
 	stb 	<epochSecond

 	puls 	D,X,Y,PC 

; ----------------------------------------------------
; encrypt the user's nickserv password before writing
; to config file. encryption is simple and consists of
; adding a key character in sequence to each password
; char, and then inverting all the bits. this is just
; meant to prevent clear-text passwords floating around
; on people's filesystems. better safe than sorry ^.^
; Exit: B = length of password
;  	 Y = pointer to 1 byte after the last copied byte
; ----------------------------------------------------
COPY_ENCRYPT_NICKSERV_PASS
	pshs 	U,X,A  

	clrb 
	leax  	userNickservPass,U 
	sty  	<tempPtr
	leay  	1,Y  	; skip 1 byte to make room for password length value
	leau  	encryptionKey,PCR 
COPY_ENCRYPT_NICKSERV_PASS_NEXT_CHAR
	lda  	,X+
	beq  	COPY_ENCRYPT_NICKSERV_PASS_END
	adda  	,U+
	coma 
	sta  	,Y+
	incb 
	lda  	,U 
	bne  	COPY_ENCRYPT_NICKSERV_PASS_NO_KEY_WRAP
	; if here, we reached end of key word. wrap back to first char
	leau  	encryptionKey,PCR
COPY_ENCRYPT_NICKSERV_PASS_NO_KEY_WRAP
	cmpb  	#userNickservPassSz 
	blo  	COPY_ENCRYPT_NICKSERV_PASS_NEXT_CHAR
	; overflow. something went horrible wrong
	orcc  	#1
	puls  	A,X,U,PC 

COPY_ENCRYPT_NICKSERV_PASS_END
	ldu  	<uRegImage  		; restore os9 pointer to data area
	ldx  	<tempPtr		; grab Y's original value from tempPtr
	stb  	,X  			; save password length prefix byte 

	andcc 	#$FE  		; succuess
	puls  	A,X,U,PC 

; ----------------------------------------------------
; decrypt nickserv password and copy to userNickservPass
; variable
; Entry: X = ptr to length byte and encrypted pass
; Exit: X = 1 byte after end of encrypted pass
; ----------------------------------------------------
COPY_DECRYPT_NICKSERV_PASS
	pshs  	U,Y,D 

	ldb  	,X+ 	; first grab the length of password to descramble
	cmpb  	#userNickservPassSz 
	bhs  	COPY_DECRYPT_NICKSERV_PASS_ERROR 	; something is corrupt so abort
	leay 	userNickservPass,U 
	leau  	encryptionKey,PCR 
COPY_DECRYPT_NICKSERV_PASS_NEXT_CHAR
	lda  	,X+
	coma 
	suba  	,U+
	sta  	,Y+
	lda  	,U 
	bne  	COPY_DECRYPT_NICKSERV_PASS_NO_KEY_WRAP
	leau  	encryptionKey,PCR 
COPY_DECRYPT_NICKSERV_PASS_NO_KEY_WRAP
	decb 
	bne  	COPY_DECRYPT_NICKSERV_PASS_NEXT_CHAR
	clr  	,Y 
	andcc 	#$FE 
	puls  	D,Y,U,PC 

COPY_DECRYPT_NICKSERV_PASS_ERROR
	orcc 	#1 
	puls  	D,Y,U,PC 

; ----------------------------------------------------
PRINT_FIXED_WIDTH
	pshs 	U,Y,X,D 

	leau 	strFixedOutput,U 
	ldb 	<columnWidth
	ldx 	#0 
PRINT_FIXED_WIDTH_COPY_NEXT
	lda 	,Y+
	beq 	PRINT_FIXED_WIDTH_DONE
	sta 	,U+
	leax 	1,X 
	decb  
	cmpb 	<columnSpacing
	bhi 	PRINT_FIXED_WIDTH_COPY_NEXT
	; string is greater than single column width allows so skip the next 
	; entry to make room for it by adding an empty column worth of chars to count 
	addb 	<columnWidth
	bra 	PRINT_FIXED_WIDTH_COPY_NEXT

PRINT_FIXED_WIDTH_DONE
	lda 	#C$SPAC 
PRINT_FIXED_WIDTH_PADDING_NEXT
	sta 	,U+
	leax 	1,X 
	decb 
	bne 	PRINT_FIXED_WIDTH_PADDING_NEXT

	clr 	,U 	; mark end with null 
	ldu 	<uRegImage 		; restore data area pointer 
	tfr 	X,Y 
	leax 	strFixedOutput,U 
	lda 	,S 			; grab destination path from A in stack 
	; Y should have the length of bytes to write to screen 
	os9 	I$Write 

	puls 	D,X,Y,U,PC 


; ---------------------------------------------------------------
; print a null-terminated string to chatlog including timestamp
; Entry: X = pointer to null-terminated string to print 
; ---------------------------------------------------------------
PRINT_INFO_ERROR_MESSAGE
	pshs 	Y,X 

	leay 	outputBuffer,U 
	lbsr 	STRING_COPY_TIMESTAMP
	lbsr 	STRING_COPY_RAW
	leax 	outputBuffer,U 
	lbsr 	PRINT_CHATLOG_NULL_STRING

	puls 	X,Y,PC 

; ---------------------------------------------------------------
; copy control codes into destination buffer along with new color
; Entry: A = color value to chnage to 
; 	  Y = pointer to destination buffer to copy to
; Exit : Y = points to terminating null 
; --------------------------------------------------------------- 
COPY_COLOR_CODE_FOREGROUND
	pshs 	D 

	ldd 	#$1B32 	; foreground color change codes  
	std 	,Y++
	lda 	,S 
	clrb 
	std 	,Y+

	puls 	D,PC 

***************************************************************************
; debug routines section
 IFDEF debug_mode
; --------------------------------
; print hex byte value 
; --------------------------------
PRINT_BYTE_HEX
      pshs  U,Y,X,D

      ldu   <uRegImage

      leay  asciiHexList,PCR
     ;lda   #$20
     ; sta   <strNumeric 
      lda   asciiHexPrefix,PCR 
      sta   <strNumeric  
   
      lda   <u8Value
      lsra 
      lsra
      lsra
      lsra
      lda   A,Y
      sta   <strNumeric+1              ; store first digit

      lda   <u8Value 
      anda  #$0F
      lda   A,Y 
      sta   <strNumeric+2              ; store second digit

      lda   #$20
      sta   <strNumeric+3

      lda   <chatlogPath
      ldy   #4
      leax  strNumeric,U 
      os9   I$Write
      nop 
      nop 
      puls  D,X,Y,U,PC 

; -----------------------------
; Print 16 bit value in hex store in u16Value
; Entry: D  = contains 16 bit value to be printed
; ------------------------------
PRINT_WORD_HEX
	pshs 	U,Y,X,D

	ldu 	<uRegImage 
	leax 	asciiHexList,PCR
	leay 	strNumeric,U 
	lda 	#'$'
	sta 	,Y

	lda 	,S 
	lsra 
	lsra
	lsra
	lsra
	lda 	A,X
	sta 	1,Y
	lda 	,S
	anda 	#$0F 
	lda 	A,X 
	sta 	2,Y
	lda 	1,S
	lsra 
	lsra
	lsra
	lsra
	lda 	A,X
	sta 	3,Y
	lda 	1,S
	anda 	#$0F 
	lda 	A,X 
	ldb 	#C$SPAC
	std 	4,Y 

	lda 	<chatlogPath
	leax 	strNumeric,U 
	ldy 	#6
	os9 	I$Write

	puls 	D,X,Y,U,PC
 ENDC 