;==============  显示字符串  ============
 badClus:         ;显示Loader.bin中存在坏簇
     mov ax,msg_bad
     mov cx,8
     call dispstr
     jmp $
 
 badFAT:
     mov ax,msg_badfat
     mov cx,14
     call dispstr
     jmp $
 
 dispstr:       ;调用时需指定ax字符串,cx长度
     ;call clear
     mov bp,ax  ;es:bp 
     mov ax,1301h ; AH = 13  AL = 01H
     mov bx,000ch ;页号为0 黑底红字 BL=0ch
     mov dl,35    ;列数
     mov dh,12    ;行数
     int 10h
     ;call delay
     ret
 

