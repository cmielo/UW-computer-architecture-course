; Solution for the third assignment.
; The program computes the CRC of a given file. The supposed file consists of blocks of data and breaks between them.
; First argument of the program is name of the file.
; Second argument of the program is the CRC polynomial that described by 0's and 1's.
; Prints the CRC to the standard output.

global _start

SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_OPEN    equ 2
SYS_CLOSE   equ 3
SYS_LSEEK   equ 8
SYS_EXIT    equ 60
STDOUT      equ 1
MAXLEN      equ 64                              ; Max length of CRC polynomial
READ_BUFF_LEN       equ 65539                   ; Length of buffer 2^16 + 3 bytes
WORKING_BUFFER_LEN  equ 9

section .bss

FILE_DESCRIPTOR:    resb 4
READ_BUFFER:        resb READ_BUFF_LEN
WORKING_BUFFER:     resb WORKING_BUFFER_LEN

section .text

; rcx - index of current byte in read buffer
; r8  - size of CRC
; r9  - register to keep CRC
; r10 - current block size

; HELPER FUNCTIONS
; =================================================================================================

; Calls sys_read(), number of bytes to be read must be passed in RDX
read_from_file:
    mov     eax,    SYS_READ
    mov     edi,    [rel FILE_DESCRIPTOR]
    mov     rsi,    READ_BUFFER
    syscall
    ret

; Calls read_from_file() until it reads expected number of bytes passed in RDX, or until it returns error
force_read:
    call    read_from_file
    cmp     eax,    0
    jle     .return                             ; If sys_read() returned error or end of file, cancel
    sub     edx,    eax
    jg      force_read

.return:
    ret


; Reads two bytes from the file to get the length of a block, then reads that amount of bytes
load_new_block:
    push    rdi
    push    rsi                                 ; Preserve registers

; Read first two bytes to check the lenght of a block
    mov     edx,    2                           ; Length of size of a block
    call    force_read

    cmp     eax,    0
    jle     .return

; Block size will be stored in r10
    xor     r10d,   r10d
    mov     r10w,   word [rel READ_BUFFER]
    add     r10d,   4                           ; Adjust the length so that the offset value will be read

; Now read the contents of a block
    mov     edx,    r10d                        ; Size of block
    call    force_read
    cmp     eax,    0
    jle     .return

    xor     ecx,    ecx                         ; Reset the counter
    sub     r10d,   4                           ; Restore the correct value, offset does not account to the block

.return:
    pop     rsi
    pop     rdi                                 ; Restore registers
    ret


; Reads the 4-byte offset value. When this function is called READ_BUFFER + RCX points to the first byte of the offset
read_offset_and_jump:
    push    rdi
    push    rsi
    push    rcx                                 ; Preserve registers

; RAX will hold offset value
    lea     rdx,    [rel READ_BUFFER]
    movsx   rax,    dword [rdx + rcx]           ; Extend sign

; Perform a check whether we are finished
    lea     r11,    [rax + r10 + 6]
    test    r11,    r11                         ; Check whether offset points to the same block

    jne     .lseek
    mov     eax,    1                           ; If yes, return 1, no need to call lseek()
    jmp     .return

.lseek:
    mov     edi,    dword [rel FILE_DESCRIPTOR] ; File descriptor
    mov     rsi,    rax                         ; Load offset
    mov     edx,    1                           ; Relative to the last position
    mov     eax,    SYS_LSEEK
    syscall                                     ; Change position in file by lseek()

    test    eax,    eax
    js      .return                             ; Return negative value if lseek() signalled error
    xor     eax,    eax                         ; 0 indicates that the function call was successful

.return:
    pop     rcx
    pop     rsi
    pop     rdi                                 ; Restore registers
    ret


; Shifts the working buffer by one bit. Returns 1 if most significant bit was on, 0 otherwise
shift_memory_one_bit:
    xor     eax,    eax
    shl     qword [rsi],    1
    jnc     .second_shift
    inc     eax                                 ; If most significant bit was one, save this information

.second_shift:
    shl     byte [rsi + 8],     1               ; Shift second segment of working buffer (1 byte)
    adc     qword [rsi],    0                   ; If there was a carry, add 1 to the first segment
    ret


; Calls shift_memory_one_bit() 8 times
shift_memory_one_byte:
    mov     r11b,   8
.shifting:
    call    shift_memory_one_bit
    dec     r11b
    test    r11b,   r11b
    jnz     .shifting
    ret


; Performs XOR operation on 8 most significant bytes of working buffer and R9 register
xor_one_byte:
    mov     r11b,   8

.shifting:
    dec     r11b
    test    r11b,   r11b
    js      .finished
    call    shift_memory_one_bit
    test    eax,    eax
    jz      .shifting                           ; Most significant bit was one, so perform XOR
    ; mov   rdx,    qword [rel WORKING_BUFFER]
    ; xor   rdx,    r9
    ; mov   qword [rel WORKING_BUFFER],     rdx
    xor     qword [rel WORKING_BUFFER],     r9
    jmp     .shifting

.finished:
    ret


; MAIN
; =================================================================================================
_start:
    mov     rcx,    [rsp]                       ; Save to RCX how many arguments there are
    mov     rdi,    [rsp + 16]                  ; Load the pointer to file name
    mov     rsi,    [rsp + 24]                  ; Load the pointer to CRC

    cmp     rcx,    3
    jne     .exit_with_error                    ; Exit if the number of arguments is not 3

    xor     ecx,    ecx                         ; Initialize the counter
    xor     r9,     r9                          ; CRC will be stored in R9

.crc_conversion:
    mov     al,     byte [rsi + rcx]
    cmp     al,     0
    je      .crc_conversion_finish
    shl     r9,     1

    sub     al,     '0'                         ; Check whether 0 or 1
    jz      .next
    cmp     al,     1
    jne     .exit_with_error                    ; CRC contains wrong characters
    inc     r9b

.next:
    inc     ecx
    cmp     ecx,    MAXLEN + 1
    je      .exit_with_error                    ; CRC was too long
    jmp     .crc_conversion

.crc_conversion_finish:
    cmp     ecx,    0
    je      .exit_with_error                    ; CRC is a constant, abort
    mov     r8d,    ecx                         ; Save the length of CRC to R8
    mov     cl,     64
    sub     cl,     r8b
    shl     r9,     cl                          ; Shift CRC to the left of register

.open_file:
    mov     eax,    SYS_OPEN
    xor     esi,    esi                         ; Read only
    syscall
    test    eax,    eax
    js      .exit_with_error                    ; Failed to open the file
    mov     dword [rel FILE_DESCRIPTOR],    eax ; Save the file descriptor

    xor     ebx,    ebx                         ; Initialize counter
        
; cx - counter for current block
; bx - counter for buffer
.fill_working_buffer:
    call    load_new_block
    test    eax,    eax
    jle     .exit                               ; Read failed
    
    lea     rdi,    [rel READ_BUFFER] 
    lea     rsi,    [rel WORKING_BUFFER]        ; Load addresses of buffers

.inner_loop:    
    cmp     ecx,    r10d                        ; Check if end of current block
    jge     .next_block
    cmp     bl,     WORKING_BUFFER_LEN          ; if (bx >= working_buffer_len) break;
    jge     .buffer_filled

    call    shift_memory_one_byte                           ; Shift working buffer to make place for another byte
    mov     al,     byte [rdi + rcx]
    mov     byte [rsi + WORKING_BUFFER_LEN - 1],    al      ; Move bytes from file to working buffer
    inc     cl
    inc     bl
    jmp     .inner_loop

.next_block:
    call    read_offset_and_jump
    test    eax,    eax                         ; Check the result of lseek()
    js      .exit                               ; lseek() returned error
    jnz     .buffer_not_filled                  ; Last block

    call    load_new_block
    test    eax,    eax
    jle     .exit                               ; Read failed

    jmp     .inner_loop

; First case    
.buffer_filled:
    cmp     ecx,    r10d
    jge     .end_of_block
        
    call    xor_one_byte
    mov     al,     byte [rdi + rcx]
    mov     byte [rsi + WORKING_BUFFER_LEN - 1],    al      ; Move new byte to the end of working buffer

    inc     ecx
    jmp     .buffer_filled

.end_of_block:
    call    read_offset_and_jump                ; Change position in file
    test    eax,    eax
    js      .exit                               ; lseek() returned error
    jnz     .end_of_file_normal                 ; This was last block
        
    call    load_new_block
    test    eax,    eax
    jle     .exit

    jmp     .buffer_filled

.end_of_file_normal:
    mov     edi,    WORKING_BUFFER_LEN          ; RDI now holds how many bytes are left
    jmp     .computing_crc


; Second case
.buffer_not_filled:
    mov     edi,    WORKING_BUFFER_LEN
    sub     edi,    ebx
    jz      .buffer_shifted

.working_buffer_shifting:
    call    shift_memory_one_byte               ; Adjust the data in a buffer to the left
    dec     dil
    test    dil,    dil
    jnz     .working_buffer_shifting

.buffer_shifted:
    mov     edi,    ebx                         ; RDI holds how many bytes were loaded (previously kept in RBX)

.computing_crc:                                 ; XOR until the end of data
    call    xor_one_byte
    dec     dil
    test    dil,    dil
    jnz     .computing_crc

.print_result:
    mov     rax,    qword [rel WORKING_BUFFER]
    xor     ecx,    ecx
                                                ; R8 holds the lenght of CRC
    sub     rsp,    r8                          ; Make room on the stack for the string
    dec     rsp

.next_digit:
    mov     dl,     '0'
    shl     rax,    1
    jnc     .push_value
    inc     dl

.push_value:
    mov     byte [rsp + rcx],  dl
    inc     cl
    cmp     cl,     r8b
    jl      .next_digit

    mov     byte [rsp + rcx],   byte `\n`       ; Last character

    mov     eax,    SYS_WRITE                   ; Pass arguments for SYS_WRITE
    mov     edi,    STDOUT
    lea     rsi,    [rsp]                       ; Buffer with string is on stack.
    mov     edx,    r8d                         ; Length of CRC
    inc     dl                                  ; +1 for printing \n
    syscall

    lea     rsp,    [rsp + r8 + 1]              ; Fix the stack

.exit:
    push    rax                                 ; Preserve syscall return value

    mov     eax,    SYS_CLOSE
    mov     edi,    dword [rel FILE_DESCRIPTOR]
    syscall                                     ; Close the file

    test    eax,    eax
    pop     rax
    js      .exit_with_error                    ; Failed to close the file

    test    eax,    eax                         ; Check last syscall return value
    jle     .exit_with_error

    mov     eax,    SYS_EXIT
    xor     edi,    edi
    syscall                                     ; Exit with code 0

.exit_with_error:
    mov     eax,    SYS_EXIT
    mov     edi,    1
    syscall                                     ; Exit with code 1