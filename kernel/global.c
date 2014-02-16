
//===================      global.c          ===============
#define GLOBAL_VARIABLES_HERE

#include "type.h"
#include "const.h"
#include "protect.h"
#include "proto.h"
#include "process.h"
#include "global.h"

PUBLIC   char    task_stack[STACK_SIZE_TOTAL];

PUBLIC PROCESS   proc_table[MAX_TASKS];
