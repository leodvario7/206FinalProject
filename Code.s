;|Final Project
;|-----------------------------
;|Created By:   Brennan Laing
;|Class:        ITSC 204
;|Date:         04/04/2023 
;|      x86-64, NASM
;|-----------------------------

; struct for the socket
struc sockaddr_in_type

    .sin_family:        resw 1
    .sin_port:          resw 1
    .sin_addr:          resd 1
    .sin_zero:          resd 2              
endstruc
; struct used for nanosleep
struc timespec

    .tv_sec             resb 1          ; seconds
    .tv_nsec            resb 1          ; nanoseconds
endstruc

global _start
section .text ; Stores instructions for the computer to follow

_start:

    call _connection.socket_created     ; creates socket to be connected to server
    call _connection.connect            ; connects socket to server socket

    call _read_message_from_socket      ; reads text sent by the server (asking how many random bytes the client wants)
    call _write_text_to_screen          ; writes text from server to screen

    call _read_from_user                ; reads input from user (how many random bytes they want)
    call _write_to_socket               ; sends input to server via socket
    
    call _extend_arr                    ; extends the array to the length inputted by the user
    ;call _sleep                         ; sleeps for 3 seconds before reading the bytes sent by the server
    ;call _read_from_user 
    call _read_bytes_from_socket        ; reads bytes from server and inputs them into array
    call _print_arr                     ; prints array

    call _connection.close              ; closes connection to server

; reads welcome and request messages sent by the server and stores them in msg_buf
_read_message_from_socket:
    mov rax, 0x00                       ; read syscall
    mov rdi, qword [sock_fd]            ; socket fd
    mov rsi, msg_buf                    ; buffer pointer where message will be saved
    mov rdx, 1024                       ; message buffer size
    syscall

    cmp rax, -1                         ; if this syscall returns -1 it indicates a failed read and therefore jumps to failed read message and exits.
    je _messages.failed_read            ; jumps to fail message

    ret
; writes welcome message caught by _read_message_from_socket
_write_text_to_screen:
    mov rax, 0x1                        ; write syscall
    mov rdi, 0x1                        ; stdout code
    mov rsi, msg_buf                    ; buffer pointer where message is saved
    mov rdx, 1024                       ; message buffer size
    syscall

    ret
; writes the input of the user to the socket to get transfered to the server
_write_to_socket:
    mov rax, 0x1                        ; write syscall
    mov rdi, qword [sock_fd]            ; socket fd
    mov rsi, user_input                 ; stored user input
    mov rdx, 0x4                        ; buffer size
    syscall

    ret
; reads input from user about how many bytes to request
_read_from_user:
    mov rax, 0x0                        ; read syscall
    mov rdi, 0x0                        ; stdin code
    mov rsi, user_input                 ; storing the user input
    mov rdx, 0x4                        ; buffer size
    syscall

    ret
; reads the random bytes sent by the server, uses the users input to get exactly what the user requested
_read_bytes_from_socket:

    mov rax, 0x2d
    mov rdi, [sock_fd]
    mov rsi, arra
    mov dx, [byte_num]
    mov r10, 0x100
    mov r8, 0x0
    mov r9, 0x0
    syscall


    ; xor r10, r10
    ; .loop:
    ;     mov rax, 0x0                    ; read syscall
    ;     mov rdi, qword [sock_fd]        ; socket fd
    ;     lea rsi, [arra + r10]          ; buffer pointer where message will be saved
    ;     mov rdx, 0x1                    ; message buffer size from user input
    ;     syscall

    ;     cmp rax, -1                         ; if this syscall returns -1 it indicates a failed read and therefore jumps to failed read message and exits.
    ;     je _messages.failed_read            ; jumps to fail message
    ;     inc r10
    ;     cmp r10, [byte_num]
    ;     jle _read_bytes_from_socket.loop

    ret
; extends the array to the length specified by the user
_extend_arr:
    push qword [sock_fd]
    push user_input
    call _ascii_to_hex                  ; gets length requested using the users own input
    mov [byte_num], rax                 ; moves output of _ascii_to_hex into byte_num var
    add rsp, 0x10                       ; clean up
   
    mov si, ax                        ; moves output from ascii to hex to rsi (size of array)
    mov rax, 0x9                        ; mmap syscall
    mov rdi, 0x00                       ; NULL
    mov rdx, 0x01                       ; PROT_READ
    or  rdx, 0x02                       ; PROT_WRITE
    or  rdx, 0x04                       ; PROT_EXEC
    mov r10, 0x20                       ; MAP_ANONYMOUS
    or  r10, 0x02                       ; MAP_PRIVATE
    mov  r9, 0x0
    mov  r8, 0x0
    syscall
    mov [arra], rax

    ret
; prints pre-sorted array into terminal
_print_arr:
    mov rax, 0x1                        ; write syscall
    mov rdi, 0x1                        ; stdin code
    mov rsi, arra                       ; stored array of random bytes
    mov dx,  [byte_num]                   ; length of array
    syscall

    ret

; deals with opening an closing a connection to the server
_connection:
    ; creates socket thats used to connect to the server
    .socket_created:
        mov rax, 0x29                       ; socket syscall
        mov rdi, 0x02                       ; int domain - AF_INET = 2, AF_LOCAL = 1
        mov rsi, 0x01                       ; int type - SOCK_STREAM = 1
        mov rdx, 0x00                       ; int protocol is 0
        syscall
        
        cmp rax, -1                         ; checks if syscall returns -1 indicating a failure
        je _messages.socket_failed          ; jumps to failure message
        mov qword [sock_fd], rax            ; takes the return of socket syscall (fd) and stores it in sock_fd 

        ret
    ; connects to the server using the connect syscall with the socket created
    .connect:
        mov rax, 0x2A                       ; connect syscall
        mov rdi, qword [sock_fd]            ; file discriptor of the socket created in .socket_created
        mov rsi, sockaddr_in                ; struct for connection
        mov rdx, sockaddr_in_l              ; length of struct
        syscall

        cmp rax, 0x0                        ; if RAX is not 0 then the connection has failed
        jne _messages.failed_connection     ; jumps to failure message
        ret
    ; closes connection when program is complete
    .close:    
        mov rax, 0x3                        ; close syscall
        mov rdi, qword [sock_fd]            ; socket fd
        mov rsi, 0x2                        ; shuwdown RW
        syscall
        cmp rax, 0x0
        jne _end
        call _messages.socket_closed

_messages:
    .socket_failed:
        push socket_failed_l   
        push socket_failed_msg
        call _print
        jmp _end  

    .failed_connection:
        push failed_connection_l
        push failed_connection_msg
        call _print
        jmp _end

    .failed_read:
        push failed_read_l
        push failed_read_msg
        call _print
        jmp _end

    .socket_closed:
        push socket_closed_l   
        push socket_closed_msg
        call _print
        jmp _end

      

_print:
    ; prologue
    push rbp
    mov rbp, rsp
    push rdi
    push rsi

    mov rax, 0x1
    mov rdi, 0x1
    mov rsi, [rbp + 0x10]
    mov rdx, [rbp + 0x18]
    syscall

    ; epilogue
    pop rsi
    pop rdi
    pop rbp
    ret 0x10                                ; clean up the stack upon return - not strictly following C Calling Convention

_ascii_to_hex:
    ; takes the first 8 bytes of the buffer in ascii form
    ; returns hex representation in RAX
    ; follows C Call Convention

    ; prologue
    push rbp
    mov rbp, rsp
    push rdi
    push rsi

    ; [rbp + 0x10] -> buffer pointer
    ; [rbp + 0x18] -> buffer length
    
    xor rbx, rbx        ; clear counter
    xor rcx, rcx        ; clear rcx
    .loop:
        mov rdx, qword [rbp + 0x10]
        mov al, byte [rdx + rbx] ; load ascii payload
        ; skip conversion if loaded less than 0x30 (non ASCII)
        cmp rax, 0x30
        jl .end_loop
        ; if letter, subtract 0x37
        cmp rax, 0x40
        jg .letter 
        sub rax, 0x30
        jmp .end_bias
    .letter:
        sub rax, 0x37
        jmp .end_bias

    .end_bias:
        or rcx, rax
        shl rcx, 0x04
    .end_loop:
        inc rbx
        cmp rbx, 0x08
        jnz .loop

        shr rcx, 0x4
        mov rax, rcx

    ; epilogue
    pop rsi
    pop rdi
    pop rbp

    ret
; has the program wait 3 seconds before contiuing
_sleep:
    mov rax, 0x23                                               ; nanosleep syscall
    mov rdi, timespec_i                                         ; time struct
    syscall
    
    ret

_end:
    mov rax, 0x3C
    mov rdi, 0x00
    syscall

section .data ; Where you declare and store data, static
    sockaddr_in: 
        istruc sockaddr_in_type 

            at sockaddr_in_type.sin_family,  dw 0x02            ;AF_INET -> 2 
            at sockaddr_in_type.sin_port,    dw 0x901F          ;(DEFAULT, passed on stack) port in hex and big endian order, 8080 -> 0x901F
            at sockaddr_in_type.sin_addr,    dd 0x00            ;(DEFAULT) 00 -> any address, address 127.0.0.1 -> 0x0100007F

        iend
    sockaddr_in_l: equ $ - sockaddr_in

    timespec_i:
        istruc timespec
            at timespec.tv_sec,     db 0x3                      ; time in seconds       
            at timespec.tv_nsec,    db 0x0                      ; time in nano-seconds
        iend

    ; messages
    socket_failed_msg: db "Socket creation failed.", 0xA, 0x0
    socket_failed_l: equ $ - socket_failed_msg
    failed_connection_msg: db "Failed to connect to server.", 0xA, 0x0
    failed_connection_l: equ $ - failed_connection_msg
    failed_read_msg: db "Failed to read from server.", 0xA, 0x0
    failed_read_l: equ $ - failed_connection_msg
    socket_closed_msg: db 0xA, "Closed socket.", 0xA, 0x0
    socket_closed_l: equ $ - socket_closed_msg

    ;Code for the algorithm
    arr db 5, 2, 4, 1, 3 ; the arr to be sorted
    arr_len equ $ - arr ; the length of the arr

section .bss
    sock_fd resq 1       ; file discriptor of the socket
    msg_buf resb 1024
    user_input resb 4
    byte_num resb 4
    arra resb 1