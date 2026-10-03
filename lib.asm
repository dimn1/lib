section .text

global exit
global string_length
global print_string
global print_char
global print_newline
global print_uint
global print_int
global string_equals
global read_char
global read_word
global parse_uint
global parse_int
global string_copy
 
 
; Принимает код возврата и завершает текущий процесс
exit: 
    mov rax, 60
    xor rdi, rdi
    syscall

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax                ; put 0 into rax to start count 
.loop:                          ; while pointer doesn't reach the end {
    cmp byte [rdi + rax], 0     ; if the current byte is equal to 0
    je .done                    ; then go to .done
    inc rax                     ; increase counter by one
    jmp .loop                   ; }
.done:
    ret                         ; end

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:
    push rdi                    ; put the pointer on the string onto stack

    call string_length          ; put the string length into rax
    
    mov rdx, rax                ; move the string length into rdx
    pop rsi                     ; get the pointer on the string from stack 

    mov rax, 1                  ; move syscall number into rax
    mov rdi, 1                  ; move fd number into rdi
    syscall
    
    ret                        

; Принимает код символа и выводит его в stdout
print_char:
    push rdi                    ; put the code of the symbol onto stack
    
    mov rdi, 1                  ; move fd number into rdi
    mov rax, 1                  ; move syscall number into rax
    mov rsi, rsp                ; move the pointer on the char into rdx
    mov rdx, 1                  ; move the string length into rdx
    syscall             
    
    pop rax                     ; clean the stack
    xor rax, rax                ; clean rax

    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, 0xA                ; put the code of the new line symbol in rdi
    call print_char             ; print the symbol
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    mov rax, rdi                ; move the nubmer into rax
    mov r8, 10                  ; move divider into r8 register
       
    push 0                      ; push onto stack null terminator
    mov r9, rsp                 ; move the stack pointer into r9
    sub rsp, 32                 ; allocate space on the stack
.loop_div:
    xor rdx, rdx                ; make rdx equal to 0
    div r8                      ; divide result by 10
    add rdx, 0x30               ; turn into ASCII symbol

    dec r9                      ; decrease stack pointer
    mov [r9], dl                ; push the remainder of division on stack

    cmp rax, 0                  ; if number!=0
    jnz .loop_div               ; then go to .loop_div
    mov rdi, r9                 ; else move the stack pointer into the string pointer
    
    call print_string           ; print number
    
    add rsp, 32                 ; 
    pop rax                     ; fix the stack
.done:
    ret


; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    cmp rdi, 0                  ; if number>=0
    jge print_uint              ; then print_uint

    push rdi                    ; else push the number onto stack
    
    mov rdi, 0x2D               ;
    call print_char             ; print the "-" char
    
    pop rdi                     ; get the number from stack
    neg rdi                     ; make it negative
    jmp print_uint              ; print it
    
; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:
    xor rcx, rcx                ; clear rcx
.loop:                          ; while char from the first string and from the second string are equal {
    mov al, [rdi+rcx]           ; move char from the first string
    cmp al, [rsi+rcx]           ; if char1 != char2
    jne .not_equal              ; go to .not_equal

    inc rcx

    cmp al, 0                   ; check if current character is null
    jne .loop                   ; }
.success:
    mov rax, 1                  ; return 1
    ret
.not_equal:
    mov rax, 0                  ; return 0
    ret                         

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    sub rsp, 8                  ; allocate the space on stack

    mov rax, 0                  ; syscall number in rax
    mov rdi, 0                  ; fd in rdi
    mov rsi, rsp                ; pointer on the stack in rsi
    mov rdx, 1                  ; length in rdx
    syscall                     ; read
    
    cmp rax, 0                  ; if rax==0
    jle .eof                    ; then go to .eof
    
    movzx rax, byte [rsp]       ; move char without extention into rax
    jmp .done                   ; go to .done

.eof:
    xor rax, rax                ;clear rax
.done:
    add rsp, 8                  ; fix the stack
    ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push r12                    ; memorize callee-save registers
    push r13                    ;
    push r14                    ;
    
    mov r12, rdi                ; pointer on the buffer in r12
    mov r13, rsi                ; buffer's size in r13
    xor r14, r14                ; clear r14    
.skip_loop:                     ; while not whitespace {
    call read_char              ; read char from fd
    cmp rax, 0                  ; check if eof
    je .error                   ; if eof go to .error
   
    cmp rax, 0x20               ; checks on whitespaces
    je .skip_loop
    cmp rax, 0x9
    je .skip_loop
    cmp rax, 0xA
    je .skip_loop               ; }
.word_loop:                     ; while not null {
    mov r8, r13                 ; buffer's size in r8
    dec r8                      ; buffer's size - 1
    cmp r14, r8                 ; if buffer's size <= pointer
    jge .overflow               ; go to .overflow

    mov [r12 + r14], al         ; al in buffer's char
    inc r14                     ; pointer ++

    call read_char              ; read char
   
    cmp rax, 0                  ; if char==whitespace: go to .success
    je .success
    cmp rax, 0x20
    je .success
    cmp rax, 0x9
    je .success
    cmp rax, 0xA
    je .success

    jmp .word_loop              ; }
.success:
    mov byte [r12 + r14], 0     ; null terminator in the end of the string
    mov rax, r12                ; r12 in rax
    mov rdx, r14                ; r14 in rdx
    jmp .exit                   ; go to exit

.overflow:
.error:
    xor rax, rax                ; clear rax
    xor rdx, rdx                ; clear rdx

.exit:
    pop r14                     ; fix callee-save registers
    pop r13
    pop r12
    ret

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax                ; clear result
    xor rdx, rdx                ; clear counter
    xor rcx, rcx                ; clear number's char              
.loop:                          ; while char in range(0x30, 0x39){
    mov cl, [rdi+rdx]
    
    cmp cl, 0x30                ; checks on range
    jl .end
    cmp cl, 0x39
    jg .end
    
    sub cl, 0x30                ; from ASCII to numbers
    imul rax, 10                ; rax*10 in rax
    add rax, rcx                ; rax + rcx in rax
    inc rdx                     ; rdx++

    jmp .loop                   ; }
.end:
    ret

; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:
    mov al, [rdi]               ; put the first byte of the string
    cmp al, 0x2D                ; if char=="-"
    je .neg                     ; then go to .neg

    cmp al, 0x2B                ; if char=="+"
    je .pos                     ; then go to .pos
    jmp parse_uint              ; else go to parse_uint
.neg: 
    push rdi                    ; push pointer on stack
    inc rdi                     ; pointer++
    call parse_uint             ; parse string
    pop rdi                     ; pop ponter from stack into rdi
    
    cmp rdx, 0                  ; if string's length == 0
    je .error                   ; then go to .error

    neg rax                     ; else make number negative 
    inc rdx                     ; add minus
    ret
.pos:
    push rdi                    ; push pointer on stack
    inc rdi                     ; pointer++     
    call parse_uint             ; parse string
    pop rdi                     ; pop ponter from stack into rdi
    
    cmp rdx, 0                  ; if string's length == 0
    je .error                   ; then go to .error

    inc rdx                     ; add plus
    ret
.error:
    xor rdx, rdx                ; 0 in rdx
    ret

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rcx, rcx                ; clear counter
    xor rax, rax                ; clear char  
.loop:                          ; while True {
    cmp rcx, rdx                ; if counter=>buffer's length
    jge .error                  ; then go to .error

    mov al, [rdi+rcx]           ; the string's char in al
    mov [rsi + rcx], al         ; al in buffer
   
    cmp al, 0                   ; if al==0
    je .success                 ; go to .success

    inc rcx                     ; rsx++    
    jmp .loop                   ; }
.error:
    mov rax, 0                  ; 0 in rax
    ret
.success:
    mov rax, rcx                ; string's length in rax
    ret
    













