
//global.h	

#ifdef GLOBAL_VARIABLES_HERE
#undef  EXTERN
#define EXTERN
#endif



EXTERN    int          disp_pos;
EXTERN    u8           gdt_ptr[6]; /* 0 ~15: Limit (2 bytes ) 
									  16~47: Base  (4 bytes ) */
EXTERN    DESCRIPTOR   gdt[GDT_SIZE];
EXTERN    u8           idt_ptr[6]; /* 0～15:Limit 16~47:Base */
EXTERN    GATE         idt[IDT_SIZE];

EXTERN    TSS       tss;
EXTERN    PROCESS*  p_proc_ready;
extern    PROCESS   proc_table[];
extern    char      task_stack[];
