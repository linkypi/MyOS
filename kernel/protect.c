/*                protect.c                       */

#include "type.h"
#include "const.h"
#include "protect.h"
#include "global.h"
#include "proto.h"
#include "process.h"
/*文件内函数声明*/
PRIVATE void init_idt_desc(unsigned char  vector , u8  desc_type,
		int_handler  handler,unsigned char  privilege);

PRIVATE void init_descriptor(DESCRIPTOR *p_desc,u32 base,u32 limit,u16 attr);



/*异常处理函数 定义在kernel.asm中 */
void   divide_error();                                                                     
void   single_step_exception();                                                            
void   nmi();                                                                              
void   breakpoint_exception();                                                             
void   overflow();                                                                         
void   bounds_check();                                                                     
void   inval_opcode();                                                                     
void   copr_not_available();
void   double_fault();                                                                     
void   copr_seg_overrun();                                                                 
void   inval_tss();                                                                        
void   segment_not_present();                                                              
void   stack_exception();                                                                  
void   general_protection();                                                               
void   page_fault();                                                                       
void   copr_error(); 

/*中断处理函数  定义在kernel.asm中 */
void  hint00();
void  hint01();
void  hint02();
void  hint03();
void  hint04();
void  hint05();
void  hint06();
void  hint07();
void  hint08();
void  hint09();
void  hint10();
void  hint11();
void  hint12();
void  hint13();
void  hint14();
void  hint15();
/*=======================================================
                 init_prot()
 ========================================================*/
PUBLIC void init_prot()
{
	init_8259A();

	//初始化异常  （中断门  没有陷阱门）
	init_idt_desc( INT_VECTOR_DIVIDE, DA_386IGate, divide_error, PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_DEBUG,  DA_386IGate, single_step_exception,  PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_NMI,     DA_386IGate, nmi,  PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_BREAKPOINT, DA_386IGate,  breakpoint_exception, PRIVILEGE_USER);
    init_idt_desc( INT_VECTOR_OVERFLOW,  DA_386IGate , overflow,   PRIVILEGE_USER);
    init_idt_desc( INT_VECTOR_BOUNDS,    DA_386IGate,  bounds_check,  PRIVILEGE_KRNL);
	init_idt_desc( INT_VECTOR_INVAL_OP,  DA_386IGate,  inval_opcode,  PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_COPROC_NOT, DA_386IGate,  copr_not_available,   PRIVILEGE_KRNL);
	init_idt_desc( INT_VECTOR_DOUBLE_FAULT,  DA_386IGate,  double_fault,   PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_COPROC_SEG,    DA_386IGate,  copr_seg_overrun,  PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_INVAL_TSS, DA_386IGate,  inval_tss,    PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_SEG_NOT,   DA_386IGate,  segment_not_present,  PRIVILEGE_KRNL);
	init_idt_desc( INT_VECTOR_STACK_FAULT,   DA_386IGate,   stack_exception,    PRIVILEGE_KRNL);
	init_idt_desc( INT_VECTOR_PROTECTION,    DA_386IGate,   general_protection,   PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_PAGE_FAULT,    DA_386IGate,  page_fault,   PRIVILEGE_KRNL);
    init_idt_desc( INT_VECTOR_COPROC_ERR,    DA_386IGate,  copr_error,  PRIVILEGE_KRNL);
  
	 /*初始化中断*/
	 init_idt_desc(INT_VECTOR_IRQ0 + 0, DA_386IGate , hint00 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 1, DA_386IGate , hint01 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 2, DA_386IGate , hint02 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 3, DA_386IGate , hint03 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 4, DA_386IGate , hint04 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 5, DA_386IGate , hint05 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 6, DA_386IGate , hint06 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ0 + 7, DA_386IGate , hint07 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 0, DA_386IGate , hint08 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 1, DA_386IGate , hint09 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 2, DA_386IGate , hint10 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 3, DA_386IGate , hint11 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 4, DA_386IGate , hint12 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 5, DA_386IGate , hint13 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 6, DA_386IGate , hint14 , PRIVILEGE_KRNL);
	 init_idt_desc(INT_VECTOR_IRQ8 + 7, DA_386IGate , hint15 , PRIVILEGE_KRNL);


	 /* 填充 GDT 中的 TSS */
	 memset(&tss,0,sizeof(tss));
     tss.ss0 = SELECTOR_KERNEL_DS;
	 init_descriptor(&gdt[INDEX_TSS],
			 vir2phys(seg2phys(SELECTOR_KERNEL_DS),&tss),
			 sizeof(tss) - 1, DA_386TSS);

	 tss.iobase = sizeof(tss); /*没有I/O许可位图*/

	 /*填充 GDT 中进程的 LDT的描述符 */
	 init_descriptor(&gdt[INDEX_LDT_FIRST],
			 vir2phys(seg2phys(SELECTOR_KERNEL_DS),proc_table[0].ldts),
			 LDT_SIZE * sizeof(DESCRIPTOR) - 1, DA_LDT);
}


/*====================================================================
  init_idt_desc   初始化 386 中断门
 =====================================================================*/
PRIVATE void init_idt_desc(unsigned char vector,u8 desc_type,
		        int_handler handler,unsigned char privilege)
{ 
	GATE* p_gate = &idt[vector];
	u32 base = (u32)handler;
	p_gate->offset_low = base & 0xFFFF;
	p_gate->selector = SELECTOR_KERNEL_CS;
	p_gate->dcount = 0;
	p_gate->attr = desc_type | (privilege << 5);
	p_gate->offset_hight = (base>>16) & 0xFFFF;
}


/*================================================================
   seg2phys   由段名求绝对地址
 ================================================================*/
PUBLIC u32 seg2phys(u16 seg)
{
	DESCRIPTOR* p_desc = &gdt[ seg >> 3];
	return (p_desc->base_high << 24 | p_desc->base_mid << 16 | p_desc->base_low);
}

/*================================================================
   init_descriptor   初始化段描述符
 ================================================================*/
PRIVATE void inito_descriptor(DESCIPRTOR* p_desc,u32 base ,u32 limit,u16 attr)
{
	p_desc->limit_low = limit & 0x0FFFF;
	p_desc->base_low  = base & 0x0FFFF;
	p_desc->base_mid  = (base>>16) & 0x0FF;
	p_desc->attr1     = attr & 0xFF;
	p_desc->limit_high_attr2 = ((limit>>16)&0x0F)|(attr>>8)&0xF0;
	p_desc->base_high = (base>>24) & 0x0FF;
}

PUBLIC void exception_handler(int vec_no,int err_code,int eip,int cs,int eflags)
{
	    int i;
	    int text_color = 0x74; /* 灰底红字 */

		char * err_msg[] = {
        			"#DE Divide Error",
			        "#DB RESERVED",
			        "--  NMI Interrupt",
			        "#BP Breakpoint",
		            "#OF Overflow",
				    "#BR BOUND Range Exceeded",
					"#UD Invalid Opcode (Undefined Opcode)",
					"#NM Device Not Available (No Math Coprocessor)",
					"#DF Double Fault",
					"    Coprocessor Segment Overrun (reserved)",
					"#TS Invalid TSS",
					"#NP Segment Not Present",
					"#SS Stack-Segment Fault",
					"#GP General Protection",
					"#PF Page Fault",
					"--  (Intel reserved. Do not use.)",
					"#MF x87 FPU Floating-Point Error (Math Fault)",
					"#AC Alignment Check",
					"#MC Machine Check",
					"#XF SIMD Floating-Point Exception"
		};

		/* 通过打印空格的方式清空屏幕的前五行，并把 disp_pos 清零 */
		disp_pos = 0;
		for(i=0;i<80*5;i++){
			disp_str(" ");
		 }
		disp_pos = 0;

		disp_color_str("Exception! --> ", text_color);
		disp_color_str(err_msg[vec_no], text_color);
		disp_color_str("\n\n", text_color);
		disp_color_str("EFLAGS:", text_color);
		disp_int(eflags);
		disp_color_str("CS:", text_color);
		disp_int(cs);
		disp_color_str("EIP:", text_color);
		disp_int(eip);
        
		if(err_code != 0xFFFFFFFF){
        	disp_color_str("Error code:", text_color);
        	disp_int(err_code);
    	}
}

