;将镜像加载到内存，每次加载一个扇区，为的是从中找到Loader.bin文件
;找到后将其加载到内存的指定位置
;最后跳转到该位置 将控制权交给Loader.bin
org 07c00h     ;bios 可将引导扇区加载到0:7c00 处 并开始执行

;宏定义   编译阶段宏会被删除  
BaseOfStack       equ  07c00h  ; 堆栈基地址(栈底, 从这个位置向低地址生长)
BaseOfLoader      equ  09000h
OffsetOfLoader    equ  0100h

;========================================================
jmp short startx		; Start to boot.
	nop				; 这个 nop 不可少

%include "fat12hdr.inc"
%include "common.inc"
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

;显示Booting...
;mov ax,msg_boot
;mov cx,10
;call dispstr

; 软驱复位
xor ah,ah
xor dl,dl
int 13h  


    mov byte [secnum],SecNumOfRootDir     ;保存根目录起始扇区号19
    mov byte [SecLoopCount],RootDirSecCount  ;循环读取扇区次数 14
Read: 
	cmp byte [SecLoopCount],0   
	jz finish                    ;若读完14个扇区仍未找到則显示磁盘中没有Loader.bin文件     
	dec byte [SecLoopCount]

	;准备存放缓冲区 es:bx
	mov ax,BaseOfLoader
	mov es,ax
	mov bx,OffsetOfLoader  

    movzx ax,byte [secnum]              ; 起始扇区号
	mov cl,1                     ; 每次读取一个扇区
    call ReadSector              ;

    cld                          ;将 DF 置为0 使得di  si按增量方式增长   
    mov dx,0x10                  ;共读取16遍一个扇区512字节  
	;显示Finding...
	;mov ax,msg_find
	;mov cx,18
	;call dispstr

	;mov ax,BaseOfLoader
	;mov es,ax
    mov di,OffsetOfLoader    
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
    add di,0x20  ;每个目录文件大小为32字节
    jmp findFile

finish:
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
	jz jmptoloader
    push ax          ;保存fat值
    sub ax,2         ;头两个fat值不使用
	add ax,SecNumOfRootDir   ;根目录开始扇区号   19
	add ax,RootDirSecCount   ;根目录占用的扇区数 14
	add bx,[BPB_BytsPerSec]  ;每加载完一个扇区則向前移动一个扇区
    jmp Goon_Loading
;======================================================================   
;==========================  获取fat值  ===============================   
;======================================================================   

GetFat:
    push es
	push bx
	push ax
	mov ax,es
	sub ax,0x100  ;取出4K空间用来加载fat表中的数据
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
	;push ax
	ret

;===========================================================================================
;=================================  加载Loader到内存   =====================================
;===========================================================================================
jmptoloader:
    mov ax,0
	mov es,ax
	mov ax,msg_finded
	mov cx,6
	call dispstr

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

	;将控制权交给Loader
    jmp  BaseOfLoader:OffsetOfLoader     


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



;delay:     ;在虚拟机下执行60000*600次循环
           ;相当于6秒钟，而实际情况可能会快2-3倍
 ;   mov dx,60000
;	.for1:
;	;mov ax,10
;	;.for2:
 ;   mov cx,400  
;	.go:
;	   dec cx
 ;      cmp cx,0
;	   jnz .go
;
;	;dec ax
;	;cmp ax,0
;	;jnz .for2
;
 ;   dec dx
  ;  cmp dx,0
   ; jnz .for1
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

;若将字符串放在开头則计算机会将字符串视为指令来执行
filename          db   "LOADER  BIN",0   ;文件名为11字节
msg_nofind        db   "No Loader",0
msg_finded        db   "Ready!",0
;msg_boot         db   "Booting...",0
msg_bad           db   "Bad clus",0
msg_badfat        db   "Fat damaged...",0
secnum            db   0             ;扇区号
SecLoopCount      db   14            ;根目录所占扇区数
odd               db   0

times  510-($-$$)  db  0 ; 填充剩下的空间 使生成的二进制代码恰好为512字节
dw     0xaa55            ;引导扇区结束标志


