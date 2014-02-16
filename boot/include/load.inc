BaseOfLoader	    equ	 09000h	; LOADER.BIN 被加载到的位置 ----  段地址
OffsetOfLoader	    equ	  0100h	; LOADER.BIN 被加载到的位置 ---- 偏移地址

BaseOfLoaderPhyAddr equ	BaseOfLoader*10h ; LOADER.BIN 被加载到的位置 ---- 物理地址

BaseOfKernel        equ	 08000h	; KERNEL.BIN 被加载到的位置 ----  段地址
OffsetOfKernel      equ	     0h	; KERNEL.BIN 被加载到的位置 ---- 偏移地址

BaseOfKernelPhyAddr   equ  BaseOfKernel * 10h
KernelEntryPointPhyAddr   equ  030400h  ;注意1.必须与makefile中参数-Ttext的值相等
                                        ;2.这是地址而非偏移

PageDirBase   equ  200000h  ;页目录开始地址 2M
PageTblBase   equ  201000h  ;页表开始地址   2M + 4K
