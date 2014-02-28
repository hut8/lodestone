;;; lodestone - x86 asm/javascript refrigerator door emulator

%include "nasmx.inc"
%include "libc.inc"
%include "syscall.inc"
	;; libc externals
	extern printf
	extern fprintf
	extern strncmp
	extern sscanf
	extern stderr
	;; crappy condition var implementation
	extern condition_broadcast
	extern condition_wait
;;; ;;;; ;;;
;;; DATA ;;;
;;; ;;;; ;;;

	SECTION .data
	;; Query string
qs_env:		db "QUERY_STRING="
qs_env_l:	equ $-qs_env

	;; Content-type HTTP headers
contenttype_html:	db "Content-type: text/html",13,10,13,10
contenttype_html_l:	equ $-contenttype_html
contenttype_js:		db "Content-type: application/javascript",13,10,13,10
contenttype_js_l:	equ $-contenttype_js
	;; Apache log templates
invoke_logmsg:	db "efridge invoked with [%s]",10,0
	;; Javascript templates
obj_up_fmt_s:	db "renderMagnets([",0
comma_fmt:	db ",",0
obj_up_fmt_e:	db "]);",0
	;; serial: hex 4-byte object id, 1-byte letter, 3-byte color, 2-byte x, 2-byte y
obj_ser_fmt:	db "[%d,'%c','#%02hx%02hx%02hx',%hd,%hd]",0
	;; move: object_id, new_x, new_y
obj_mov_fmt:	db "M(%d,%d,%d)",0
	;; deserial: character, r, g, b, x, y
obj_deser_fmt:	db "P(%c,%hd,%hd,%hd,%hd,%hd)",0
obj_del_fmt:	db "D(%d)",0
	;; Filenames (NULL TERMINATED)
page_fn:	db "efridge.html",0
data_fn:	db "efridge.db",0
	;; Error messages
filefailmsg:	db "<h1>fatal error: could not open file</h1>",10
filefailmsg_l:	equ $-filefailmsg
err_invop_msg:	db "invalid operation",10,0
err_io_r_msg:	db "read io error - %d returned",10,0
err_io_w_msg:	db "write io error - %d returned",10,0
errmsg_db:	db "Database error on open: eax=%d",10,0
errmsg_db_w:	db "Database error on write: eax=%d",10,0
errmsg_load_db_w:	db "Could not load database: fatal error during reading: eax=%d",10,0
errmsg_load_db_o:	db "Could not load database: fatal error during opening: eax=%d",10,0
errmsg_deser_err:	db "alert('Deserialization error');",10,0
errmsg_outofrange:	db "alert('No such object - out of range') ;",10,0
errmsg_del_parse:	db "alert('Could not determine object ID for deletion from query string') ;",10,0
errmsg_objdb_full:	db "alert('Object database full.  Delete an object and try again.');",10,0
errmsg_comdb_o:	db "fatal error while commiting database: cannot open database for writing.",10,0
errmsg_comdb_o_l:	equ $-errmsg_comdb_o
errmsg_comdb_w:	db "fatal error while commiting database: cannot write open database.",10,0
errmsg_comdb_w_l:	equ $-errmsg_comdb_w
errmsg_load_db_eof:	db "fatal error while reading database: unexpected end of file. please reset.", 10
errmsg_load_db_eof_l:	equ $-errmsg_load_db_eof
blank_obj:	dd 0xffffffff

;;; ;;; ;;;
;;; BSS ;;;
;;; ;;; ;;;
SECTION .bss
objdb:	resb 0x2000		; The entire object database (1024*8 bytes)
working_filename:	resd 0x1 ; pointer to argv[0]

;;; ;;;; ;;;
;;; CODE ;;;
;;; ;;;; ;;;
	SECTION .text
	global main
	;; warning: i have no idea how to program asm
main:
	mov ebx, [esp+12] 	; save environment in ebx
	mov eax, [esp+8]
	mov eax, [eax]
	mov [working_filename], eax
	push ebp
	mov ebp, esp
	;; main() locals:
	;;   ebp-4 = pointer to query_string
	sub esp, 4

;;; Find query string in environment variables
ienv:				; iterate to next environment var
	mov eax, [ebx]		; load char *ebx into eax for testing
	test eax, eax		; is *ebx null?
	jz render_html  	; render HTML if web server does not set QUERY_STRING

	;; Compare to correct string
	invoke strncmp, dword [ebx], dword qs_env, dword qs_env_l
	test eax, eax		; we found it if zero
	jz proc_qs		; process query string

	;; missed it, next try!
	add ebx, 4		; go to next env variable
	jmp ienv		; loop
proc_qs:
	mov eax, [ebx]		; char *eax = *ebx         (ebx was char**)
	add eax, dword qs_env_l	; add size of QUERY_STRING=
	mov [ebp-4], eax	; store address of query string value in stack
	;; Print invocation parameters (query string) to FILE * stderr
	invoke fprintf, dword[stderr],invoke_logmsg, dword[ebp-4]

	;; Determine correct operation - the first letter is the
	;; "function" name
	mov eax, dword[ebp-4]	; load pointer to query string
	mov eax, dword[eax]	; dereference pointer, loading first four characters
	and eax, 0xff		; only consider first character (function name)

	test eax, eax		; is there no query string? (null terminator at first character)
	jz render_html		; render regular html page

	;; Notify of change
	cmp eax, 0x4E		; test N
	je ._notify_change	; wait for signal then render objects

	;; Get magnets
	cmp eax, 0x47		; test G
	je ._render_objects

	;; Place new magnet
	cmp eax, 0x50		; test P
	je ._place_object	; make a new magnet

	;; Reset all magnets
	cmp eax, 0x52		; test R
	je ._init_db		; zero-out database

	;; Update magnet location
	cmp eax, 0x4D		; test M
	je ._move_object

	;; Delete magnet
	cmp eax,dword 0x44	; test D
	je ._delete_object

	jmp invalid_op

._notify_change:
	invoke condition_wait	; wait to be signaled
	jmp ._render_objects	; then render

._render_objects:
	invoke load_database	; load all objects into memory
	invoke render_objects	; serialize to client
	jmp exit

._place_object:
	invoke load_database		     ; load all objects into memory
	invoke place_object, dword[ebp-4] ; generate object based on query string
	invoke render_objects		     ; serialize to client
	invoke condition_broadcast, dword [working_filename]
	jmp exit
._init_db:
	syscall write, STDOUT_FILENO, contenttype_js, contenttype_js_l
	invoke printf, obj_up_fmt_s ; quick render objects
	invoke printf, obj_up_fmt_e ; end of render objects
	invoke init_db		    ; blank out database
	invoke condition_broadcast, dword[working_filename] ; notify everyone of changes
	jmp exit
._move_object:
	invoke load_database	; load all objects into memory
	invoke move_object, dword[ebp-4] ; move object, passing query string
	invoke condition_broadcast, dword[working_filename]	 ; notify everyone of changes
	jmp exit			 ; return from program
._delete_object:
	invoke load_database		   ; load all objects into memory
	invoke delete_object, dword[ebp-4] ; delete object specified by query string
	invoke render_objects		   ; serialize to client
	invoke condition_broadcast, dword[working_filename]	   ; notify everyone of changes
	jmp exit			   ; return from program

;;; ;;;;;;;;;;;;;;;;;;; ;;;
;;; OPERATIONS ROUTINES ;;;
;;; ;;;;;;;;;;;;;;;;;;; ;;;

	;; When no other operation is given, simply send to browser HTML document
	;; from filename so the javascript may contact this program
render_html:
	;; HTML Header output
	syscall write, STDOUT_FILENO, contenttype_html, contenttype_html_l
	;; Open HTML file
	syscall open, page_fn, dword 0x0 ; 0x0 = O_RDONLY
	test eax, eax			 ; test open success
	js page_err			; jump if page_fd < 0
	mov dword[ebp-4], eax		; page_fd = open() rv
	;; Allocate lots of space
	sub esp, 2048+4
	mov dword[ebp-8], ebp
	sub dword[ebp-8], 2048

	syscall read, dword[ebp-4], dword[ebp-8], dword 2048
	test eax, eax
	js .read_fail

	syscall write, dword 0x1, dword[ebp-8], eax
	test eax, eax
	js .write_fail

	;; Now we're done
	syscall close, dword[ebp-4]
	jmp exit

.read_fail:
	pop ebx
	invoke printf, err_io_r_msg, eax
	jmp exit
.write_fail:
	invoke printf, err_io_w_msg, eax
	jmp exit


render_objects:
	push ebp		; save old base pointer
	mov ebp, esp		; establish new stack frame
	;; Stack
	;;   [ebp-4] = address of end of objdb
	sub esp, 4

	syscall write, STDOUT_FILENO, contenttype_js, contenttype_js_l ; render Content-type header

	invoke printf, obj_up_fmt_s
	;; Loop through objects
	xor ecx, ecx   ; zero counter
	mov eax, objdb		; eax is pointer to beginning of integer we want
	mov dword[ebp-4], eax	; to tell when to end the loop
	add dword[ebp-4], 0x2000 ; 8192 bytes from where we started
._render_core:
	;; check to see if done
	cmp dword[ebp-4], eax
	je ._end_render_objects

	;; check if we should print this
	movzx ebx, byte[eax]
	cmp ebx, 0xff
	je ._next_record

	;; see if comma is needed
	cmp eax, objdb
	je ._render_object
	push eax
	push ecx
	invoke printf, comma_fmt
	pop ecx
	pop eax

	;; render a single object
._render_object:
	;; begin constructing printf data
	push eax       ; save db address from clobbering
	push ecx       ; save counter from clobbering

	movzx ebx, word [eax+6] ; load coordinate record into register
	push ebx		; coordinate integer (short)

	movzx ebx, word [eax+4] ; load coordinate record into register
	push ebx		; coordinate integer (shorts)

	movzx ebx, byte [eax+3]	; load color 'B' byte as short
	push ebx		; push short onto stack

	movzx ebx, byte [eax+2]	; load color 'G' byte as short
	push ebx		; push short onto stack

	movzx ebx, byte [eax+1]	; load color 'R' byte as short
	push ebx		; push short onto stack

	movzx ebx, byte [eax]	; load magnet character as char
	push ebx		; push char

	push ecx		; push dword object id
	push obj_ser_fmt	; format string
	call printf

	add esp, 32		; take printf args off stack
	pop ecx			; unclobber counter
	pop eax			; unclobber address

._next_record:
	inc ecx			; object id now increased
	add eax, 8 		; move to next object
	jmp ._render_core	; loop

._end_render_objects:
	invoke printf, obj_up_fmt_e
	mov esp, ebp
	pop ebp
	ret

move_object:
	push ebp
	mov ebp, esp
	;; Stack
	;;   [ebp-4] = y coordinate
	;;   [ebp-8] = x coordinate
	;;   [ebp-12]= object id
	sub esp, 12

	;; parse input string
	lea eax, [ebp-4]	; load pointer to ebp-4
	push eax		; move to stack
	lea eax, [ebp-8]	; load pointer to ebp-8
	push eax		; move to stack
	lea eax, [ebp-12]	; load pointer to ebp-12
	push eax		; move to stack
	push obj_mov_fmt	; push pointer to format string
	push dword [ebp+8]	; push source string
	call sscanf		; sscanf
	add esp, 20		; restore stack from sscanf
	cmp eax, 0x3		; ensure correct parsing
	jne ._mov_parse_err	; if not, jump ship
	;; parsing succeeded
	mov esi, dword[ebp-12]	; get object id
	cmp esi, 0x3ff		; make sure its < 1024
	ja ._outofrange		; if < 0 || > 1023
	lea esi, [objdb+esi*8]	; scoot up to record in memory

	mov dx, word[ebp-8]	; load x position
	mov word[esi+4], dx	; move number
	mov dx, word[ebp-4]	; load y position
	mov word[esi+6], dx	; move number

	invoke commit_database	; save results
	invoke render_objects	; show changes

	jmp ._mov_end		; jump over errors
._mov_parse_err:
	invoke printf, errmsg_deser_err
	jmp ._mov_end
._outofrange:
	invoke printf, errmsg_outofrange
._mov_end:
	mov esp, ebp
	pop ebp
	ret

place_object:
	push ebp		; save old base pointer
	mov ebp, esp		; establish new stack frame
	;; Stack
	;;   [ebp-4] = y coordinate
	;;   [ebp-8] = x coordinate
	;;   [ebp-12] = b
	;;   [ebp-16] = g
	;;   [ebp-20] = r
	;;   [ebp-24] = %c
	sub esp, 24

	mov esi, objdb		; esi = &objdb
	mov edi, objdb		; edi = &objdb
	add edi, 0x2000		; edi += 8192 (1024 8 byte records)

._find_null_obj:		; start of loop to find
	cmp esi, edi
	je ._objdb_full		; ran off end

	mov eax, [esi]		; load our record
	mov ebx, eax		; copy for checking
	and ebx, 0xff000000	; only consider high bit

	cmp ebx, 0xff000000	; ff magic number for 'no object here'
	je ._fill_null		; found it!

	add esi, 8		; next record
	jmp ._find_null_obj
._fill_null:
	;; esi contains object id
	;; [ebp+8] = query string
	mov eax, ebp
	;; y coordinate
	sub eax, 4
	push eax
	;; x coordinate
	sub eax, 4
	push eax
	;; b
	sub eax, 4
	push eax
	;; g
	sub eax, 4
	push eax
	;; r
	sub eax, 4
	push eax
	;; character
	sub eax, 4
	push eax
	;; format string
	push obj_deser_fmt
	;; source string
	mov eax, dword[ebp+8]
	push eax
	call sscanf
	cmp eax, 6
	jne ._deser_fmt_err
	;; scanf succeeded - update record
	add esp, 8		; take format and source strings from stack

	pop eax			; delicious cake
	movzx eax, byte[eax]	; dereference character
	mov byte[esi], al	; put the character in the database

	pop eax			; delicious cake
	movzx eax, byte[eax]	; dereference R
	mov byte[esi+1], al	; put the color in the database

	pop eax			; delicious cake
	movzx eax, byte[eax]	; dereference G
	mov byte[esi+2], al	; put the color in the database

	pop eax			; delicious cake
	movzx eax, byte[eax]	; dereference B
	mov byte[esi+3], al	; put the color in the database

	pop eax
	movzx eax, word[eax] 	; dereference Y
	mov word[esi+4], ax	; put y coordinate in database

	pop eax
	movzx eax, word[eax] 	; dereference X
	mov word[esi+6], ax	; put X coordinate in database

	;; save
	invoke commit_database

	jmp ._end_generate_object ; skip over errors
._deser_fmt_err:
	add esp, 32
	invoke printf, errmsg_deser_err
	jmp ._end_generate_object
._objdb_full:
	invoke printf, errmsg_objdb_full
._end_generate_object:
	mov esp, ebp
	pop ebp
	ret

delete_object:
	push ebp
	mov ebp, esp
	;; Stack
	;;   [ebp-4] = object_id
	sub esp, 4		; allocate stack
	lea eax,[ebp-4]		; load address of itself for sscanf
	mov dword[ebp-4], eax
	;; parse object_id
	invoke sscanf, dword[ebp+8], obj_del_fmt, dword[ebp-4]
	cmp eax, 0x1		; check sscanf for parse error
	jne ._parse_err		; did not find correct parameters
	mov esi, dword[ebp-4]	; load offset into register
	cmp esi, 0x3ff		; make sure it's in bounds
	ja ._oor		; if not, jump ship
	lea esi, [objdb+esi*8]	; load address to delete
	mov dword[esi], 0xffffffff	; zero out word 1
	mov dword[esi+4], 0xffffffff	; zero out word 2
	invoke commit_database
	jmp ._end		; skip errors
._oor:
	invoke printf, errmsg_outofrange
	jmp ._end
._parse_err:
	invoke printf, errmsg_del_parse
._end:
	mov esp, ebp
	pop ebp
	ret

invalid_op:
	invoke printf, err_invop_msg
	jmp exit


;;; ;;;;;;;;;;;;;;;;;;;
;;; DATABASE OPERATIONS
;;; ;;;;;;;;;;;;;;;;;;;

;;; Initially create blank database
;;; Overwrites corrupt database as well

init_db:
	push ebp
	mov ebp, esp
	;; Stack:
	;;   [ebp-4] = db file descriptor
	;;   [ebp-8] = address of blank record
	sub esp, 8
	syscall open, data_fn, 0x241 ; O_WRONLY | O_CREAT | O_TRUNC
	test eax, eax		    ; db file descriptor < 0
	js ._init_db_error

	mov [ebp-4], eax

	;; Allocate 1024 blank pairs
	;; 1 B - letter, 3 B - RGB color, 2 B X coord, 2 B Y coord)
	mov ecx, 1024
._writecycle:
	test ecx, ecx
	jz ._end_init_db

	push ecx
	syscall write, dword[ebp-4], blank_obj, 0x4
	syscall write, dword[ebp-4], blank_obj, 0x4
	pop ecx
	test eax, eax
	js ._init_db_error_w

	dec ecx
	jmp ._writecycle
._init_db_error:
	invoke printf, errmsg_db, eax
	jmp ._end_init_db
._init_db_error_w:
	invoke printf, errmsg_db_w, eax
	jmp ._end_init_db
._end_init_db:
	;; Restore stack and return
	mov esp, ebp
	pop ebp
	ret

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;
;;; Loads all data into objdb in .bss ;;;
;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;
load_database:
	push ebp
	mov ebp, esp
	sub esp, 8
	;; Stack:
	;;   [ebp-4] = data_fd
	;;   [ebp-8] = data index

	;; open database for reading
	syscall open, data_fn, dword 0x0 ; 0x0 = O_RDONLY
	test eax, eax			 ; test open success
	js ._load_db_err_o		; jump if data_fd < 0
	mov dword[ebp-4], eax		; data_fd = open() rv

	;; initialize loop data
	mov dword[ebp-8], objdb	; offset from start of objdb
	mov ecx, 0x2000		; total size = 8192 bytes
	;; copy contents of file into objdb
._load_db_read_cycle:
	push ecx
	syscall read, dword [ebp-4], dword[ebp-8], ecx ; read as much as possible
	test eax, eax			      ; check return value from read
	js ._load_db_err_w		      ; negative indicates failure
	jz ._ue_eof			      ; unexpected end of file

	;; success here
	pop ecx		   ; restore clobbered register from read()
	sub ecx, eax		; subtract actual bytes read from remaining
	test ecx, ecx		; if no db remains to be read
	jz ._end_load_db	; finish this function
	add dword[ebp-8], eax	; update offset
	jmp ._load_db_read_cycle
._ue_eof:
	syscall write, dword 0x2, errmsg_load_db_eof, errmsg_load_db_eof_l
	jmp ._end_load_db
._load_db_err_w:
	invoke printf, errmsg_load_db_w, eax
	jmp ._end_load_db
._load_db_err_o:
	invoke printf, errmsg_load_db_o, eax
	jmp ._end_load_db
._end_load_db:
	syscall close, dword[ebp-4] ; close database
	mov esp, ebp
	pop ebp
	mov eax, 0
	ret

commit_database:
	push ebp		; save base
	mov ebp, esp		; enter new stack frame
	;; Stack
	;;   [ebp-4] = data_fd
	;;   [ebp-8] = pointer to record position
	;;   [ebp-12] = ending position
	sub esp, 12
	syscall open, data_fn, dword 0x201 ; O_WRONLY|O_TRUNC
	test eax, eax			 ; test open success
	js ._commit_db_open_err		; jump if data_fd < 0
	mov dword [ebp-4], eax		; file descriptor
	mov eax, objdb			; initial write position
	mov dword [ebp-8], eax		; put it on stack
	add eax, 0x2000			; end of write position
	mov dword [ebp-12], eax		; put it on stack
._write_cycle:
	mov eax, dword[ebp-8]
	cmp eax, dword[ebp-12]	; see if we're at end of objdb
	je ._end_commit_db	; if so, return
	;; write eight bytes starting at record position
	syscall write, dword[ebp-4], dword[ebp-8], 0x8
	test eax, eax		; check for error
	js ._commit_db_write_err
	add dword[ebp-8], 8	; next record
	jmp ._write_cycle	; loop
._commit_db_write_err:
	syscall write, dword 0x2, errmsg_comdb_w, errmsg_comdb_w_l
	jmp ._end_commit_db	; don't print out next error
._commit_db_open_err:
	syscall write, dword 0x2, errmsg_comdb_o, errmsg_comdb_o_l
._end_commit_db:
	syscall close, dword[ebp-4] ; close (even if not open; whatever)
	mov esp, ebp		    ; restore old stack pointer
	pop ebp			    ; restore old base pointer
	ret			    ; jump to return address

;;; ;;;;;;;;;;;;;;;;;;;; ;;;
;;; FATAL ERROR ROUTINES ;;;
;;; ;;;;;;;;;;;;;;;;;;;; ;;;
page_err:
	syscall write, STDOUT_FILENO, filefailmsg, filefailmsg_l
exit:
	;; Take down our stack frame
	mov esp, ebp
	pop ebp
	mov eax, 0		; return(0)
	ret
