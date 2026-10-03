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
    xor rax, rax          
.loop:
    cmp byte [rdi + rax], 0 
    je .done              
    inc rax              
    jmp .loop             
.done:
    ret

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:
    push rdi

    call string_length
    
    mov rdx, rax
    pop rsi

    mov rax, 1
    mov rdi, 1
    syscall
    
    ret

; Принимает код символа и выводит его в stdout
print_char:
    push rdi
    
    mov rdi, 1
    mov rax, 1
    mov rsi, rsp
    mov rdx, 1
    syscall
    
    pop rax
    xor rax, rax

    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, 0xA
    call print_char
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    mov rax, rdi
    mov r8, 10
       
    push 0      
    mov r9, rsp  
    sub rsp, 24       
.loop_div:
    xor rdx, rdx
    div r8
    add rdx, 0x30

    dec r9
    mov [r9], dl

    cmp rax, 0
    jnz .loop_div
    mov rdi, r9
  
    call print_string
    
    add rsp, 24
    pop rax
.done:
    ret


; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    cmp rdi, 0
    jge print_uint

    push rdi
    
    mov rdi, 0x2D
    call print_char
    
    pop rdi
    neg rdi
    jmp print_uint
    
; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:
    xor rcx, rcx
.loop:
    mov al, [rdi+rcx] 
    cmp al, [rsi+rcx]
    jne .not_equal

    inc rcx

    cmp al, 0
    jne .loop

    mov rax, 1
    ret
.not_equal:
    mov rax, 0
    ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    sub rsp, 8

    mov rax, 0
    mov rdi, 0
    mov rsi, rsp
    mov rdx, 1
    syscall
    
    cmp rax, 0
    jle .eof
    
    movzx rax, byte [rsp] 
    jmp .done

.eof:
    xor rax, rax
.done:
    add rsp, 8
    ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push r12         
    push r13
    push r14
    
    mov r12, rdi     
    mov r13, rsi       
    xor r14, r14  
.skip_loop:
    call read_char      
    cmp rax, 0
    je .error           
   
    cmp rax, 0x20
    je .skip_loop
    cmp rax, 0x9
    je .skip_loop
    cmp rax, 0xA
    je .skip_loop
.word_loop:
    mov r8, r13
    dec r8              
    cmp r14, r8
    jge .overflow      

    mov [r12 + r14], al 
    inc r14            

    call read_char      
   
    cmp rax, 0
    je .success
    cmp rax, 0x20
    je .success
    cmp rax, 0x9
    je .success
    cmp rax, 0xA
    je .success

    jmp .word_loop
.success:
    mov byte [r12 + r14], 0 
    mov rax, r12        
    mov rdx, r14       
    jmp .exit

.overflow:
.error:
    xor rax, rax      
    xor rdx, rdx

.exit:
    pop r14             
    pop r13
    pop r12
    ret

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax 
    xor rdx, rdx
    xor rcx, rcx
.loop:
    mov cl, [rdi+rdx]
    
    cmp cl, 0x30
    jl .end
    cmp cl, 0x39
    jg .end
    
    sub cl, 0x30
    imul rax, 10
    add rax, rcx
    inc rdx

    jmp .loop 
.end:
    ret

; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:
    mov al, [rdi]
    cmp al, 0x2D
    je .neg

    cmp al, 0x2B
    je .pos
    jmp parse_uint
.neg:
    push rdi
    inc rdi
    call parse_uint
    pop rdi
    
    cmp rdx, 0
    je .error

    neg rax
    inc rdx
    ret
.pos:
    push rdi
    inc rdi
    call parse_uint
    pop rdi
    
    cmp rdx, 0
    je .error

    inc rdx
    ret
.error:
    xor rdx, rdx
    ret

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rcx, rcx
    xor rax, rax
.loop:
    cmp rcx, rdx
    jge .error

    mov al, [rdi+rcx]
    mov [rsi + rcx], al    
   
    cmp al, 0
    je .success

    inc rcx            
    jmp .loop
.error:
    mov rax, 0
    ret
.success:
    mov rax, rcx
    ret
    























