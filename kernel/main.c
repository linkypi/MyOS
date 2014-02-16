
/*=================================================
                   main.c
 =================================================*/

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "process.h"
#include "global.h"



/*=================================================
                  kernel_main
 ==================================================*/

PUBLIC int kernel_main()
{
	disp_str("--------\"kernel_main\"---------");

	PROCESS* p_proc = proc_table;

	p_proc->ldt_sel = SELECTOR_LDT_FIRST;
	/*为简化起见，ldt有两个描述符，分别被初始化
	  为内核代码段和内核数据段 */
	memcpy(&p_proc->ldts[0],&gdt[SELECTOR_KERNEL_CS>>3],sizeof(DESCRIPTOR));
    p_proc->ldt[0].attr1 = DA_C | PRIVILEGE << 5;//改变描述符特权级

	memcpy(&p_proc->ldts[1],&gdt[SELECTOR_KERNEL_DS>>3],sizeof(DESCRIPTOR));
    p_proc->ldt[1].attr1 = DA_DRW | PRIVILEGE << 5;//改变描述符特权级

    /*先将RPL，TI屏蔽 之后将个寄存器（即选择子）设置TI=1（LDT），RPL=1 */ 
    p_proc->regs.cs = (0 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
    p_proc->regs.ds = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
    p_proc->regs.es = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
    p_proc->regs.fs = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
    p_proc->regs.ss = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
    p_proc->regs.gs = (SELECTOR_KERNEL_GS & SA_RPL_MASK) | RPL_TASK;
	p_proc->regs.eip = (u32)TestA;
	p_proc->regs.esp = (u32)task_stack + STACK_SIZE_TOTAL;
	p_proc->regs.eflags = 0x1202; // IF=1  IOPL=1  bit 2 is always 1. 

	p_proc_ready = proc_table;
	restart();

	while(1){}
}

void TestA()
{
   int i=0;
   while(1){
     disp_str("A");
	 disp_int(i++);
	 disp_str(".");
	 delay(1);
   }
}

