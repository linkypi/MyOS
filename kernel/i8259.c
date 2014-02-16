/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/
/*                       i8259.c                             */
/*+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"

PUBLIC void init_8259A()
{
	/* Master 8259, ICW1  */
    out_byte(INT_M_CTL,0x11);

	/* Slaves 8259, ICW1 .*/
	out_byte(INT_S_CTL,0x11);

	/* Master 8259, ICW2 *设置主8259的中断入口地址为0x20**/
	out_byte(INT_M_CTLMASK,INT_VECTOR_IRQ0);

	/* Slave 8259 ICW2 设置从8259的中断入口地址为0x28*/
	out_byte(INT_S_CTLMASK,INT_VECTOR_IRQ8); 

	/* Master 8259 ICW3 IR2对应从8259 */
	out_byte(INT_M_CTLMASK,0x4);

	/* Slave 8259  ICW3 对应主8259的 IR2 */
    out_byte(INT_S_CTLMASK,0x2);

	/*Master 8259 ICW4 */
	out_byte(INT_M_CTLMASK,0x1);

	/*Slave 8269 ICW4 */
	out_byte(INT_S_CTLMASK,0x1);

	/* Master 8259 OCW1*/
	out_byte(INT_M_CTLMASK,0xFD);  //仅打开键盘中断

	/*Slave 8259 OCW1 */
	out_byte(INT_S_CTLMASK,0xFF);

}

PUBLIC void intrpt_handler(int irq)
{
	disp_str("Interrupt Request, Num: ");
	disp_int(irq);
	disp_str("\n");
}
