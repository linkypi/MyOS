
;=========================================================
                    ;kernel.asm
;=========================================================

%include "sconst.inc"


;导入函数
extern cstart
extern kernel_main
extern exception_handler
extern intrpt_handler

;导入全局变量
extern gdt_ptr
extern idt_ptr
extern disp_pos
extern tss
extern p_proc_ready

[section .bss]
StackSpace   resb  2 * 1024  ;resb用于声明未初始化的存储空间 resw  resd  resq
StackTop:    ;栈顶   堆栈内容向低地址扩展

[section .text]


global _start

global restart

;导出异常函数
global divide_error
global single_step_exception
global nmi
global breakpoint_exception
global overflow
global bounds_check
global inval_opcode
global copr_not_available
global double_fault
global copr_seg_overrun
global inval_tss
global segment_not_present
global stack_exception
global general_protection
global page_fault
global copr_error


;导出中断函数  Hard Interrupt
global  hint00
global  hint01
global  hint02
global  hint03
global  hint04
global  hint05
global  hint06
global  hint07
global  hint08
global  hint09
global  hint10
global  hint11
global  hint12
global  hint13
global  hint14
global  hint15



_start:

    ;把esp从loader挪到kernel 
    mov esp,StackTop

	mov dword [disp_pos],0

	sgdt [gdt_ptr]   ;sgdt 用于获取GDT的虚拟地址
	call cstart      ;在此函数中改变gdt_ptr,让他指向新的GDT
	lgdt [gdt_ptr]   ;使用新的GDT
    
    lidt [idt_ptr]

    jmp SELECTOR_KERNEL_CS:csinit
csinit:

    ;ud2
    ;jmp 0x40:0

	;sti   ;设置IF位
	;hlt

    xor eax,eax
	mov ax , SELECTOR_TSS
	ltr ax

    jmp  kernel_main 


;=================================================
;                   切换进程
;=================================================
restart:
    mov  esp, [p_proc_ready]
    lldt [esp+P_LDT_SEL]
	lea  eax,[esp+P_STACKTOP]
	mov  dword [tss+TSS3_S_SP0],eax

	pop gs
	pop fs
	pop es
	pop ds
	popad
	add esp , 4
	iretd 

;中断处理
%macro int_master  1
       push   %1
	   call   intrpt_handler
	   add    esp,4
	   hlt
%endmacro

ALIGN  16
hint00:             ; irq 0 --> the clock
      iret
      ;int_master   0

ALIGN  16
hint01:             ; irq 1 --> keyboard
       int_master   1

ALIGN  16
hint02:             ; irq 2 --> cascade
       int_master   2

ALIGN  16
hint03:             ; irq 3 --> second serial
       int_master   3

ALIGN  16
hint04:             ; irq 4 --> first serial
       int_master   4

ALIGN  16
hint05:             ; irq 5 --> XT winchester
       int_master   5

ALIGN 16
hint06:             ; irq 6 --> floppy
       int_master   6

ALIGN  16       
hint07:             ; irq 7 --> printer
       int_master   7

;--------------------------------
%macro int_slave    1
       push  %1
       call intrpt_handler
	   add  esp , 4
	   hlt
%endmacro
;--------------------------------

ALIGN  16
hint08:             ; irq 8 --> realtime clock
       int_slave  8

ALIGN  16
hint09:             ; irq 9 --> irq 2 redirected
       int_slave  9

ALIGN  16
hint10:             ; irq 10 
       int_slave  10

ALIGN 16
hint11:             ; irq 11
       int_slave  11

ALIGN  16
hint12:             ; irq 12
       int_slave  12

ALIGN  16
hint13:             ; irq 13 --> FPU Exception
       int_slave  13

ALIGN  16
hint14:             ; irq 14 --> AT winchester
       int_slave  14

ALIGN  16
hint15:              ; irq 15
       int_slave  15


;异常处理 
divide_error:
    push  0xFFFFFFFF ;no error code
	push  0          ;vector_no=0
	jmp   exception

single_step_exception:
    push  0xFFFFFFFF ;no error code
	push  1          ;vector_no=1
	jmp   exception

nmi:
    push  0xFFFFFFFF
	push  2          ;vector_no=2
	jmp   exception

breakpoint_exception:
    push  0xFFFFFFFF 
	push  3
	jmp   exception

overflow:
    push  0xFFFFFFFF
	push  4
	jmp   exception

bounds_check:
    push  0xFFFFFFFF
	push  5
	jmp   exception

inval_opcode:
    push  0xFFFFFFFF
	push  6
	jmp   exception

copr_not_available:
    push  0xFFFFFFFF
	push  7
	jmp   exception
	 
double_fault:
    push  8
	jmp   exception

copr_seg_overrun:
    push  0xFFFFFFFF
	push  9
	jmp   exception

inval_tss:
    push  10  ;vector_no = A
	jmp   exception

segment_not_present:
    push  11
	jmp   exception

stack_exception:
    push  12
	jmp   exception

general_protection:
    push  13
	jmp   exception

page_fault:
    push  14
	jmp   exception

copr_error:
    push  0xFFFFFFFF
	push  16
	jmp   exception

exception:
    call  exception_handler
	add   esp,4*2      ;让栈顶指向EIP，中断发生是参数入栈顺序
	                   ;为 eflags , cs , eip
	hlt
