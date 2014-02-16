/*====================================================
                 klib.c 
 ====================================================*/

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "string.h"
#include "global.h"
#include "process.h"
/*==================================================
  itoa   将数字转为16进制数字符  数字前面的0不显示     
  ==================================================*/
PUBLIC char* itoa(char* str,int num )
{
	char* p= str;
	char ch;
	int i;
	int flag=0;

	*p++='0';
	*p++='x';

	if(num==0)
	{
		*p++ = '0';
	}
	else
	{
		for(i=28;i>=0;i-=4)
		{
			ch= (num>>i) & 0xF;
			if(flag||(ch>0))
			{
				flag = 1;
				ch  += '0';
				if(ch > '9'){
				  ch += 7;
				}
				*p++ = ch;
			}
		}
	}
	*p = 0;
	return str;
}

/*====================================================
                     disp_int
 =====================================================*/
PUBLIC void disp_int(int input)
{
	char output[16];
	itoa(output,input);
	disp_str(output);
}


/*====================================================
                     delay
 =====================================================*/
PUBLIC void delay(int time)
{
	int i,j,k;
	for(k=0;k<time;k++){
	    for(i=0;i<10;i++){
		   for(j=0;j<10000;j++){}
		}
	}
}

