
; TP Final - Electronica Digital 2

; Autores:
; 	Camila Abril Dei Rossi
; 	Martina Montovani Castiglia
; 	Valentino Gorordo
; 	Vicente Gauna

; Descripcion ======================================================================================================
;
; Codigo fuente para un generador de señales. Este archivo compila incluyendo todos los modulos para coordinar
; la accion de cada uno. La funcion principal es realizar un intercambio de modulos cuando se pasa del modo
; 'configuracion' del dispositivo (con teclado y display habilitados, para seleccionar forma de onda y frecuencia)
; al modo 'generacion' (con teclado deshabilitado y display, dac, adc y com habilitados).
; ==================================================================================================================

	LIST p=16f887
	#include <p16f887.inc>
	#include "regdef.asm"
	
	__CONFIG _CONFIG1, _XT_OSC & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF	
	__CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF
	
	ORG	0X00
	GOTO	setup

	ORG	0X04
	GOTO	int
	
	ORG	0X05
int:	
	MOVWF	temp_w
	SWAPF	temp_w, F 		
	SWAPF	STATUS, W 		
	MOVWF	temp_status		
	;MOVF	FSR, W
	;MOVWF	temp_fsr
	;MOVF	PCLATH, W
	;MOVWF	temp_pclath		; guardo contexto

	CALL	display_int
	CALL	keyboard_int

;	BTFSS	SCON, SENA		; produccion de señal habilitada?
;	GOTO	int_end 		; salteo todo lo que tiene que ver con la señal
;	
;	CALL	dac_int
;	CALL	adc_int
;	CALL	com_int

int_end:
	;MOVF	temp_fsr, W
	;MOVWF	FSR
	;MOVF	temp_pclath, W
	;MOVWF	PCLATH
	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W 		; recupero contexto
	
	RETFIE				; regreso de la interrupcion a la direccion del codigo que se estaba ejecutando

setup:
	CALL 	display_setup		
	CALL 	keyboard_setup		
	;CALL 	dac_setup		
	;CALL 	adc_setup		
	;CALL 	com_setup		

; Configuracion de interrupciones -----------------------------

        BSF     INTCON, PEIE
        BSF     INTCON, GIE

;        BANKSEL ADCON0
;        BSF     ADCON0, GO      ; inicio la conversion


loop:	
	
	CALL	keyboard_task
	
	MOVF	KBREAD, W
	XORWF	KBREADL, W 	; comparo el registro de teclado con su latch

	BTFSS	STATUS, Z	; si los numeros eran iguales, no hubo cambios
	GOTO 	loop		; ignorar

	MOVF	KBREAD, W
	CALL	key_func	; selecciono la funcion según el boton presionado

	MOVF	KBREAD, W
	MOVWF	KBREADL 	; cambio el latch al valor actual

	CALL	update_display
		
;	BTFSC	SCON, SENA		; produccion de señal habilitada?
	
        ;CALL    com_task
        GOTO    loop

key_func:
	ANDLW	b'00001111'	; limito a 16 valores
	MOVWF	temp_work_f

	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, W	; multiplico por 4

	ADDWF	PCL, F 		; incremento program counter

; first 4 buttons set wave type
; 0
	MOVLW 	b'11110011'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00000000'	; Set type to [00]
	GOTO	key_func_end
; 1
	MOVLW 	b'11110011'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00000100'	; Set type to [01]
	GOTO	key_func_end
; 2
	MOVLW 	b'11110011'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00001000'	; Set type to [10]
	GOTO	key_func_end
; 3
	MOVLW 	b'11110011'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00001100'	; Set type to [11]
	GOTO	key_func_end

; next 8 buttons set frequencies
; 4
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00000000'	; Set frec to [000]
	GOTO	key_func_end
; 5
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00010000'	; Set frec to [001]
	GOTO	key_func_end
; 6
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00100000'	; Set frec to [010]
	GOTO	key_func_end
; 7
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'00110000'	; Set frec to [011]
	GOTO	key_func_end
; 8
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'01000000'	; Set frec to [100]
	GOTO	key_func_end
; 9
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'01010000'	; Set frec to [101]
	GOTO	key_func_end
; 10
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'01100000'	; Set frec to [110]
	GOTO	key_func_end
; 11
	MOVLW 	b'10001111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'01110000'	; Set frec to [111]
	GOTO	key_func_end

; next 3 buttons unmapped
; 12
	MOVF	SCON, W
	GOTO	key_func_end
	NOP
	NOP
; 13
	MOVF	SCON, W
	GOTO	key_func_end
	NOP
	NOP
; 14
	MOVF	SCON, W
	GOTO	key_func_end
	NOP
	NOP
	
; last button signals function gen start
; 15
	MOVLW 	b'01111111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'10000000'	; Set frec to [111]
	GOTO	key_func_end
	
key_func_end:
	MOVWF 	SCON		;
	RETURN

update_display:

	MOVF	SCON, W
	ANDLW	b'01110000'	
	MOVWF	temp_work_f
	BCF	STATUS, C
	RRF	temp_work_f, W

	ADDWF	PCL, F
; 0
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.0
	MOVWF	DIG2
	MOVLW	.2
	GOTO	update_display_end
; 1
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.0
	MOVWF	DIG2
	MOVLW	.5
	GOTO	update_display_end
; 2
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.1
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 3
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.5
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 4
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.1
	MOVWF	DIG1
	MOVLW	.0
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 5
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.3
	MOVWF	DIG1
	MOVLW	.0
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 6
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.5
	MOVWF	DIG1
	MOVLW	.0
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 7
	MOVLW	.1
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.0
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
	
update_display_end:
	MOVWF	DIG3
	RETURN
	
 ;       #include "dac_module.asm"
;        #include "adc_module.asm"
        #include "keyboard_module.asm"
        #include "display_module.asm"
;        #include "com_module.asm"

        END
