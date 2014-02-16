;找到Kernel.bin文件
;找到后将其加载到内存的指定位置
;最后跳转到该位置 将控制权交给Kernel.bin
org 0100h    

;宏定义   编译阶段宏会被删除  
BaseOfStack       equ  0100h  ; 堆栈基地址(栈底, 从这个位置向低地址生长)

;========================================================
jmp startx		; Start to boot.

%include "fat12hdr.inc"
%include "pm.inc"
%include "load.inc"
%include "common.inc"
;  GDT
;                        段地址     段界限     属性
GDT:          Descriptor   0,          0,       0      ;空描述符
Desc_Flag_c:  Descriptor   0,      0fffffh,  DA_CR|DA_32|DA_LIMIT_4K  ;  0-4G
Desc_Flag_rw: Descriptor   0,      0fffffh,  DA_DRW|DA_32|DA_LIMIT_4K ;  0-4G
Desc_Video:   Descriptor 0B8000h,  0ffffh ,  DA_DRW|DA_DPL3       ;显存首地址

GdtLen   equ  $ - GDT 
GdtPtr   dw   GdtLen - 1                  ;段界限
         dd   BaseOfLoaderPhyAddr + GDT   ;基地址

;GDT 选择子
SltFlagC   equ  Desc_Flag_c - GDT
SltFlagRW  equ  Desc_Flag_rw - GDT
SltVideo   equ  Desc_Video - GDT + SA_RPL3


startx:
mov ax,cs
mov ds,ax
mov es,ax
mov ss,ax
mov sp,BaseOfStack

;清屏
mov ah,6
mov al,0
mov cl,0
mov ch,0
mov dh,24
mov dl,79
mov bh,7
int 10h


   ;得到内存数
   mov ebx,0    ;ebx=后续值 开始时需为0
   mov di,_MemChkBuf   ;es:di 指向一个地址范围描述符结构ARDS
.MemChkLoop:
   mov eax, 0E820h     ; eax = 0000E820h
   mov ecx, 20         ; ecx = 地址范围描述符结构的大小
   mov edx, 0534D4150h     ; edx = 'SMAP'
   int 15h         ; int 15h
   jc  .MemChkFail
   add di, 20
   inc dword [_dwMCRNumber]    ; dwMCRNumber = ARDS 的个数
   cmp ebx, 0
   jne .MemChkLoop
   jmp .MemChkOK
.MemChkFail:
   mov dword [_dwMCRNumber], 0
.MemChkOK:

;============ 在A盘根目录下寻找KERNEL.BIN ===========

	; 软驱复位
	xor ah,ah
	xor dl,dl
	int 13h  


    mov byte [secnum],SecNumOfRootDir     ;保存根目录起始扇区号
    mov byte [SecLoopCount],RootDirSecCount  ;循环读取扇区次数
Read: 
	cmp byte [SecLoopCount],0   
	jz finish                    ;若读完14个扇区仍未找到則显示磁盘中没有Loader.bin文件     
	dec byte [SecLoopCount]

	;准备存放缓冲区 es:bx
	mov ax,BaseOfKernel
	mov es,ax
	mov bx,OffsetOfKernel  

    movzx ax,byte [secnum]              ; 起始扇区号
	mov cl,1                     ; 每次读取一个扇区
    call ReadSector              ;

    cld                          ;将 DF 置为0 使得di  si按增量方式增长   
    mov dx,0x10                   ;每个文件目录的大小为32字节，
                                 ;一个扇区512字节  共读取16遍
	;显示Finding...
	;mov ax,msg_find
	;mov cx,18
	;call dispstr

	;mov ax,BaseOfKernel
	;mov es,ax
    mov di,OffsetOfKernel    
findFile:                        ;开始查找
    
    mov si,filename
	mov cx,11
cmpfilename:    ;比较文件名称 lodsb --> si 自增或自减
    lodsb       ;ds:si 
	cmp al,byte [es:di]
	jnz nextfile
    inc di
	loop cmpfilename
    jmp finded

nextfile:       ;转到下一个文件
    dec dx
	cmp dx,0
	jz  Read
    add di,0x20
    jmp findFile

finish:
    mov ax,0
	mov es,ax
    mov ax,msg_nofind
	mov cx,9
	call dispstr
    jmp $

finded: 
    mov dx,0

    mov cx,word [es:di+26-11]         ;获取文件开始簇号 偏移为26
	                                  ;而文件名偏移为0占用11 byte
	mov ax,cx
    push ax          ;保存fat值
    sub ax,2         ;头两个fat值不使用
	add ax,SecNumOfRootDir   ;根目录开始扇区号   19
	add ax,RootDirSecCount   ;根目录占用的扇区数 14

Goon_Loading:
	mov cl,1
    call ReadSector  ;每次读取1个扇区 
    pop ax
    call GetFat
    cmp ax,0xFFF
	jz jmptokernel
    push ax          ;保存fat值
    sub ax,2         ;头两个fat值不使用
	add ax,SecNumOfRootDir   ;根目录开始扇区号   19
	add ax,RootDirSecCount   ;根目录占用的扇区数 14
	add bx,[BPB_BytsPerSec]  ;每加载完毕一个扇区則向前移动一个扇区
    jmp Goon_Loading
;======================================================================   
;==========================  获取fat值  ===============================   
;======================================================================   

GetFat:
    push es
	push bx
	push ax
	mov ax,es
	sub ax,0x100
	mov es,ax

    pop ax      ;文件开始簇号
	mov bx,3
	mul bx
	mov bx,2
	div bx      ;计算出fat值在fat表中的相对位置
                ;ax 为商   dx为余数
	mov byte [odd] ,0
	cmp dx,0
    jz   Get 
	mov byte [odd],1  ;若是第奇数项則标记
Get:
    xor dx,dx   ;这步不能少 做除法时先清空余数？待解决
	mov bx,[BPB_BytsPerSec]
    div bx      ;使用ax除以每个扇区的容量512 即可得到
	            ;下一个fat值可以从哪个扇区读取
    push dx     ;保存fat值在扇区中的偏移
	mov bx,0
	add ax,1    ;fat表从第二个扇区开始，1+ax 即是
	            ;当前fat值所在的扇区
	mov cl,2    ;每次读取2个扇区  避免在边界发生错误
	call ReadSector
   
    pop bx      ;获取fat值在扇区中的偏移
	mov ax,[es:bx]   ;获取下一个fat值
    cmp byte [odd],1 
	jnz label        ;若是奇数项(注意是从0开始，所以第一项为0 应该算偶数项)則取后三位 and ax,0x0FFF
	shr ax,4         ;若是偶数项則取前三位
label:
    and ax,0x0FFF
	pop bx
	pop es
	ret

;===========================================================================================
;=================================  加载Loader到内存   =====================================
;===========================================================================================
jmptokernel:

    call KillMotor

    mov ax,0
	mov es,ax
	mov ax,msg_finded
	mov cx,7
	call dispstr

	;停顿几秒
	mov dx,30000
	.for1:
	mov cx,400
	.go:
	   dec cx
	   cmp cx,0
	   jnz .go
	dec dx
	cmp dx,0
	jnz .for1

	;下面准备跳入保护模式
	lgdt   [GdtPtr]
    
	;关中断
	cli 

	;打开A20地址线
	in al,92h
	or al,00000010b
	out 92h,al

	;准备切换到保护模式
	mov eax,cr0
	or eax,1
	mov cr0,eax

	;真正进入保护模式
    jmp dword SltFlagC:(BaseOfLoaderPhyAddr+LABEL_PM_START)


;===========================================================================================
;=================================    显示字符串   =========================================
;===========================================================================================

;badClus:         ;显示Loader.bin中存在坏簇
    ;mov ax,msg_bad
	;mov cx,8
	;call dispstr
    ;jmp $

;badFAT:
    ;mov ax,msg_badfat
	;mov cx,14
	;call dispstr
    ;jmp $

;dispstr:       ;调用时需指定ax字符串,cx长度
    ;;call clear
    ;mov bp,ax  ;es:bp 
	;mov ax,1301h ; AH = 13  AL = 01H
	;mov bx,000ch ;页号为0 黑底红字 BL=0ch
	;mov dl,35    ;列数
	;mov dh,12    ;行数
	;int 10h
    ;;call delay
	;ret


;===========================================================================================
;=================================    读取扇区     =========================================
;===========================================================================================
ReadSector: ;读取磁盘  从第AX个扇区开始 将cl个扇区读入到ES：BX中
	;扇区号为X
	;                      |柱面号 = y >> 1
	;      X         |商 y |
	;-------------=>-|     |磁头号 = y & 1 
	;                |
	;                |余 z => 起始扇区号 = z + 1
    push bp
	mov bp,sp
	sub esp,2    ;劈出两个字节的堆栈区保存要读的扇区数：byte [bp-2]

	mov byte [bp-2],cl
	push bx  
	mov bl,[BPB_SecPerTrk] ; bl是除数  BPB_SecPerTrk=每磁道扇区数
    div bl    ;低8位为商  高8位为余数
	inc ah    ;余数+1
	mov cl,ah ;cl->起始扇区号
	mov dh,al

	shr al,1  
	mov ch,al ;柱面号
    and dh,1  ;磁头号
	pop bx    
    ;至此  柱面号，起始扇区，磁头号 全部就绪
	mov dl,[BS_DrvNum]  ;驱动器号
.goon:
    mov ah,2            ;读
	mov al,byte [bp-2]  ;读 al 个扇区
	int 13h
	jc .goon            ;如果读取错误 CF 会被置为 1，这时会不停的读 直到正确为止

	add esp,2
	pop bp

	ret
;============ 关闭马达 =========
KillMotor:
    push dx
	mov dx,03F2h
	mov al,0
	out dx,al
	pop dx
	ret

	
;若将字符串放在开头則计算机会将字符串视为指令来执行
filename          db   "KERNEL  BIN",0   ;文件名为11字节
msg_nofind        db   "No kernel",0
msg_finded        db   "Kernel!",0
;msg_boot         db   "Booting...",0
msg_bad           db   "Bad clus",0
msg_badfat        db   "Fat damaged...",0
secnum            db   0             ;扇区号
SecLoopCount      db   14            ;根目录所占扇区数
odd               db   0


;进入保护模式
	[SECTION .s32]
	ALIGN   32
	
	[BITS   32]
	
	LABEL_PM_START:
	    mov ax, SltVideo
	    mov gs, ax
	
	    mov ax, SltFlagRW
	    mov ds, ax
	    mov es, ax
	    mov fs, ax
	    mov ss, ax
	    mov esp, TopOfStack
	
	    push    szMemChkTitle
	    call    DispPMStr
	    add esp, 4
	
	    call    DispMemInfo
	    call    SetupPaging
	
	    ;mov ah, 0Fh             ; 0000: 黑底    1111: 白字
	    ;mov al, 'P'
	    ;mov [gs:((80 * 0 + 39) * 2)], ax    ; 屏幕第 0 行, 第 39 列
	   
		call InitKernel

		;正式进入内核   
		jmp SltFlagC:KernelEntryPointPhyAddr    
	
;%include "lib.inc"  ;因为在保护模式下显示内存使用情况
                    ;所以这段显示的函数必须放在32位代码段中


; ------------------------------------------------------------------------
; 显示 AL 中的数字
; ------------------------------------------------------------------------
DispAL:
	 push    ecx
	 push    edx
	 push    edi

	 mov edi,dword [dwDispPos]

	 mov ah, 0Fh         ; 0000b: 黑底    1111b: 白字
	 mov dl, al
	 shr al, 4
	 mov ecx, 2
.begin:
	 and al, 01111b
	 cmp al, 9
	 ja  .1
	 add al, '0'
	 jmp .2
 .1:
	 sub al, 0Ah
	 add al, 'A'
 .2:
	 mov [gs:edi], ax
	 add edi, 2

	 mov al, dl
	 loop    .begin
	 ;add    edi, 2
 
	 mov [dwDispPos], edi

	 pop edi
	 pop edx
	 pop ecx
 
	 ret
; DispAL 结束-------------------------------------------------------------

;-------------------------------------------------------------------------
;换行
;-------------------------------------------------------------------------
DispReturn:
	 push szReturn
	 call DispPMStr
	 add esp,4
	 ret


; ------------------------------------------------------------------------
; 显示一个整形数
; ------------------------------------------------------------------------
DispInt:
	 mov eax, [esp + 4]
	 shr eax, 24
	 call    DispAL

	 mov eax, [esp + 4]
	 shr eax, 16
	 call    DispAL

	 mov eax, [esp + 4]
	 shr eax, 8
	 call    DispAL

	 mov eax, [esp + 4]
	 call    DispAL

	 mov ah, 07h         ; 0000b: 黑底    0111b: 灰字
	 mov al, 'h'
	 push    edi
	 mov edi, [dwDispPos]
	 mov [gs:edi], ax
	 add edi, 4
	 mov [dwDispPos], edi
	 pop edi
	
	 ret
; DispInt 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 显示一个字符串
; ------------------------------------------------------------------------
DispPMStr:
	 push    ebp
	 mov ebp, esp
	 push    ebx
	 push    esi
	 push    edi
	 
	 mov esi, [ebp + 8]  ; pszInfo
	 mov edi, [dwDispPos]
	 mov ah, 0Fh
 .1:
	 lodsb
	 test    al, al
	 jz  .2
	 cmp al, 0Ah ; 是回车吗?
	 jnz .3
	 push    eax
	 mov eax, edi
	 mov bl, 160
	 div bl
	 and eax, 0FFh
	 inc eax
	 mov bl, 160
	 mul bl
	 mov edi, eax
	 pop eax
	 jmp .1
  .3:
	mov [gs:edi], ax
	add edi, 2
	jmp .1

  .2:
		mov [dwDispPos], edi
	
		pop edi
		pop esi
		pop ebx
		pop ebp
		ret
	; DispPMStr 结束------------------------------------------------------------



;-------------------------------------------------
;InitKernel
;-------------------------------------------------
;将kernel.bin的内容经过整理对齐后放到行的位置
;首先取得ELF文件中program header的个数 
;然后根据个数来遍历加载Program header
;-------------------------------------------------
    InitKernel:
        xor esi,esi
		mov cx,word [BaseOfKernelPhyAddr+2ch] ;在ELF Header中取得Program header的个数
        movzx ecx,cx
		mov esi,[BaseOfKernelPhyAddr+ 1Ch] ; program header开始的地址偏移 e_poff
		add esi,BaseOfKernelPhyAddr        ;将指针指向第一个Program header
	.begin:
	    mov eax,[esi+0]
		cmp eax,0
		jz .null
		push dword [esi+010h] ;size
		mov eax,[esi+04h]     ;取得第一个字节在文件中的偏移
		add eax,BaseOfKernelPhyAddr
        push eax              ;src
		push dword [esi+08h]  ;dst 第一个字节在内存中的虚拟地址
		call MemCpy
		add esp,12            ;3个参数入栈执行复制函数完毕后将栈指针复原
     .null:
	    add esi,020h          ;每个Program Header大小为32 Bytes
        dec cx
		jnz .begin
		ret

;----------------------------------------------------
;内存拷贝  仿memcpy
;----------------------------------------------------
;void* MemCpy(void* es:pDest,void* ds:pSrc,int iSize);
;----------------------------------------------------
    MemCpy:
        push ebp
		mov ebp,esp

		push esi
	    push edi
		push ecx

		mov edi,[ebp+8] ;Destination
		mov esi,[ebp+12];Source
		mov ecx,[ebp+16];counter
	.1:
	    cmp ecx,0
		jz .2
		mov al,[ds:esi]
		inc esi

		mov byte [es:edi],al
		inc edi

		dec ecx
		jmp .1
	.2:
	    mov eax,[ebp+8] ;返回值

		pop ecx
		pop edi
		pop esi
		mov esp,ebp
		pop ebp

		ret

	; 显示内存信息 --------------------------------------------------------------
	DispMemInfo:
	    push    esi
	    push    edi
	    push    ecx
	
	    mov esi, MemChkBuf
	    mov ecx, [dwMCRNumber];for(int i=0;i<[MCRNumber];i++)//每次得到一个ARDS
	.loop:                ;{
	    mov edx, 5        ;  for(int j=0;j<5;j++)//每次得到一个ARDS中的成员
	    mov edi, ARDStruct    ;  {//依次显示:BaseAddrLow,BaseAddrHigh,LengthLow
    .1:               ;               LengthHigh,Type
	    push    dword [esi]   ;
		call    DispInt       ;    DispInt(MemChkBuf[j*4]); // 显示一个成员
		pop eax       ;
		stosd             ;    ARDStruct[j*4] = MemChkBuf[j*4];
		add esi, 4        ;
		dec edx       ;
		cmp edx, 0        ;

        jnz .1        ;  }
        call    DispReturn    ;  printf("\n");
        cmp dword [dwType], 1 ;  if(Type == AddressRangeMemory)
	    jne .2        ;  {
	    mov eax, [dwBaseAddrLow];
	    add eax, [dwLengthLow];
	    cmp eax, [dwMemSize]  ;    if(BaseAddrLow + LengthLow > MemSize)
	    jb  .2        ;
	    mov [dwMemSize], eax  ;    MemSize = BaseAddrLow + LengthLow;
	.2:               ;  }
	    loop    .loop         ;}
	                  ;
	    call    DispReturn    ;printf("\n");
	    push    szRAMSize     ;
	    call    DispPMStr       ;printf("RAM size:");
	    add esp, 4        ;
	                  ;
	    push    dword [dwMemSize] ;
	    call    DispInt       ;DispInt(MemSize);
	    add esp, 4        ;
	
	    pop ecx
	    pop edi
	    pop esi
	    ret
	; ---------------------------------------------------------------------------
	
	; 启动分页机制 --------------------------------------------------------------
	SetupPaging:
	    ; 根据内存大小计算应初始化多少PDE以及多少页表
	    xor edx, edx
	    mov eax, [dwMemSize]
	    mov ebx, 400000h    ; 400000h = 4M = 4096 * 1024, 一个页表对应的内存大小
	    div ebx
	    mov ecx, eax    ; 此时 ecx 为页表的个数，也即 PDE 应该的个数
	    test    edx, edx
	    jz  .no_remainder
	    inc ecx     ; 如果余数不为 0 就需增加一个页表
	.no_remainder:
	    push    ecx     ; 暂存页表个数
	
	    ; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.
	
	    ; 首先初始化页目录
	    mov ax, SltFlagRW
	    mov es, ax
	    mov edi, PageDirBase    ; 此段首地址为 PageDirBase
	    xor eax, eax
	    mov eax, PageTblBase | PG_P  | PG_USU | PG_RWW
	.1:
	    stosd
	    add eax, 4096       ; 为了简化, 所有页表在内存中是连续的
	    loop    .1

           ; 再初始化所有页表
	    pop eax         ; 页表个数
	    mov ebx, 1024       ; 每个页表 1024 个 PTE
	    mul ebx
	    mov ecx, eax        ; PTE个数 = 页表个数 * 1024
	    mov edi, PageTblBase    ; 此段首地址为 PageTblBase
	    xor eax, eax
	    mov eax, PG_P  | PG_USU | PG_RWW
	.2:
	    stosd
	    add eax, 4096       ; 每一页指向 4K 的空间
	    loop    .2
	
	    mov eax, PageDirBase
	    mov cr3, eax
	    mov eax, cr0
	    or  eax, 80000000h
	    mov cr0, eax
	    jmp short .3
	.3:
	    nop
	
	    ret
	; 分页机制启动完毕 ----------------------------------------------------------
	
	
	; SECTION .data1 之开始 ---------------------------------------------------------------------------------------------
	[SECTION .data1]
	
	ALIGN   32
	
	LABEL_DATA:
	; 实模式下使用这些符号
	; 字符串
	_szMemChkTitle: db "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
	_szRAMSize: db "RAM size:", 0
	_szReturn:  db 0Ah, 0
	;; 变量
	_dwMCRNumber:   dd 0    ; Memory Check Result
	_dwDispPos: dd (80 * 6 + 0) * 2 ; 屏幕第 6 行, 第 0 列
	_dwMemSize: dd 0
	_ARDStruct: ; Address Range Descriptor Structure
	  _dwBaseAddrLow:       dd  0
	  _dwBaseAddrHigh:      dd  0
	  _dwLengthLow:         dd  0
	  _dwLengthHigh:        dd  0
	  _dwType:          dd  0
	_MemChkBuf: times   256 db  0
	;
	;; 保护模式下使用这些符号
	szMemChkTitle       equ BaseOfLoaderPhyAddr + _szMemChkTitle
	szRAMSize       equ BaseOfLoaderPhyAddr + _szRAMSize
	szReturn        equ BaseOfLoaderPhyAddr + _szReturn
	dwDispPos       equ BaseOfLoaderPhyAddr + _dwDispPos
	dwMemSize       equ BaseOfLoaderPhyAddr + _dwMemSize
    dwMCRNumber     equ BaseOfLoaderPhyAddr + _dwMCRNumber
    ARDStruct       equ BaseOfLoaderPhyAddr + _ARDStruct
        dwBaseAddrLow   equ BaseOfLoaderPhyAddr + _dwBaseAddrLow
        dwBaseAddrHigh  equ BaseOfLoaderPhyAddr + _dwBaseAddrHigh
        dwLengthLow equ BaseOfLoaderPhyAddr + _dwLengthLow
        dwLengthHigh    equ BaseOfLoaderPhyAddr + _dwLengthHigh
        dwType      equ BaseOfLoaderPhyAddr + _dwType
    MemChkBuf       equ BaseOfLoaderPhyAddr + _MemChkBuf


    ; 堆栈就在数据段的末尾
    StackSpace: times   1024    db  0
    TopOfStack  equ BaseOfLoaderPhyAddr + $ ; 栈顶
    ; SECTION .data1 之结束 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^




