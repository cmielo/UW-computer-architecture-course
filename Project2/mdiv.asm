; Solution for second assignment.
; Implementation of function that performs signed division and returns the remainder.
; First argument is the pointer to the non-empty array of 64-bit numbers that represent the dividend in little-endian.
; Second argument is the size of the array.
; Third argument is the 64-bit divisor.
; Returns the remainder.
; Signature: int64_t mdiv(int64_t *x, size_t n, int64_t y);

global mdiv

section .text

mdiv:
    xor     r10b,   r10b                    ; R10B przechowuje informacje o znakach
    ; Sprawdzamy znaki argumentow
    cmp     qword [rdi + rsi * 8 - 8],  0   ; Zaladuj najbardziej znaczaca liczbe
    jge     .endif_divident                 ; Jezeli dodatnia, to nic nie rob

    inc     r10b                            ; Zapisz informacje, ze dzielna byla ujemna
    jmp     .negate_divident                ; Zaneguj dzielna

.endif_divident:
    test    rdx,    rdx
    jge     .endif_divisor                  ; Zaneguj dzielnik jesli jest ujemny

    add     r10b,   2                       ; Zapisz informacje, ze dzielnik byl ujemny
    neg     rdx

.endif_divisor:
    mov     r9,     rdx                     ; Przechowaj dzielna w R9
    mov     rcx,    rsi                     ; Ustaw licznik
    xor     edx,    edx                     ; Wyzeruj RDX do dzielenia

.divide_loop:
    mov     rax,    [rdi + rcx * 8 - 8]     ; Wez obecny wyraz
    div     r9                              ; Dzielenie obecnego wyrazu
    mov     [rdi + rcx * 8 - 8],    rax     ; Zapisz wynik do pamieci
    loop    .divide_loop                    ; Petla az dojdziemy do konca

.finish_loop:
    ; Teraz naprawiamy znaki 
    test    r10b,   1
    jnz     .negative_divident              ; Dzielna byla ujemna

    test    r10b,   2
    jnz     .negate_divident                ; Dzielnik byl ujemny
    jmp     .epilogue                       ; Nic nie bylo ujemne, konczymy

.negative_divident:
    neg     rdx                             ; Zaneguj reszte

    dec     r10b
    test    r10b,   2
    jz      .negate_divident                ; Dzielnik dodatni, negujemy wynik

    cmp     qword [rdi + rsi * 8 - 8],  0   ; Sprawdz czy wynik jest dodatni
    jge     .epilogue                       ; Jesli jest ujemny, to oznacza
                                            ; ze wystapilo przepelnienie
    div     cl                              ; Podziel przez 0
        
.epilogue:
    mov     rax,    rdx                     ; Zapisz wynik w rax
    ret

; Ten fragment kodu odpowiada za zanegowanie liczby pod adresem [rdi]
.negate_divident:
    mov     al,     1                       ; AL bedzie wskazywac czy będziemy dodawać 1 czy nie
    xor     ecx,    ecx

.negating_loop:                             ; Negujemy liczbę od tyłu, negując jej wyrazy i dodając 1
    inc     rcx
    cmp     rcx,    rsi
    jg      .return                         ; Doszlismy do konca liczby

    not     qword [rdi + rcx * 8 - 8]       ; Flipuj bity
    test    al,     1                       ; Sprawdz czy bylo przeniesienie
    jz      .negating_loop

    add     qword [rdi + rcx * 8 - 8],  1   ; Jesli bylo przeniesienie, dodaj 1
    jc       .negating_loop
    dec     al                              ; Jesli teraz nie bylo przeniesienia to zapisz ta informacje
    jmp     .negating_loop

.return:
    test    r10b,   1                       ; Sprawdz, gdzie masz wrocic
    jnz     .endif_divident
    jmp     .epilogue
