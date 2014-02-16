/*------------------------------------------------
                   start.c
-------------------------------------------------*/

#include "type.h"
#include "const.h"
#include "protect.h"
#include "string.h"
#include "proto.h"
#include "global.h"
#include "process.h"

PUBLIC void cstart()
{
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n-----\"cstart\" begins-----\n");

	/*将Loader中的GDT复制到新的GDT*/
	memcpy(&gdt,  /* new GDT */
			(void*)(*((u32*)(&gdt_ptr[2]))), /*Base of old GDT*/
			*((u16*)(&gdt_ptr[0]))+1 );  /*Limit of old GDT*/

	/*gdt_ptr[6]共 6 个字节：0~15:limit   16~47:Base  用作sgdt/lgdt的参数*/
    u16* p_gdt_limit = (u16*)(&gdt_ptr[0]);
	u32* p_gdt_base = (u32*)(&gdt_ptr[2]);
	*p_gdt_limit = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*p_gdt_base =(u32)&gdt;
    
	/* idt_ptr[6] 共6个字节：0~15:Limit  16~47:Base */
    u16* p_idt_limit = (u16*)(&idt_ptr[0]);
	u32* p_idt_base  = (u32*)(&idt_ptr[2]);
	*p_idt_limit = IDT_SIZE * sizeof(GATE) - 1;
	*p_idt_base = (u32)&idt;

	init_prot(); //初始化 8259A，异常，及中断

	disp_str("-----\"cstart\" ends-----");
}

