
; TP Final - Electronica Digital 2

; Autores:
; 	Camila Abril Dei Rossi
; 	Martina Montovani Castiglia
; 	Valentino Gorordo
; 	Vicente Gauna

; Descripcion ======================================================================================================
;
; Codigo fuente para un generador de señales. Este archivo compila incluyendo todos los modulos para coordinar
; la accion de cada uno. El proyecto consta de 5 módulos: teclado, display, adc, dac y comunicacion serial; 
; cada uno de ellos expone funciones int, setup, deset y task según lo necesario que son llamadas por este archivo
; cuando es necesario.
; Se incluye un archivo adicional regdef que contiene las directivas de precompilador que convierten los alias
; utilizados en todos los archivos a las direcciones de memoria correspondientes. El mapa de memorias se encuentra
; en el archivo "variables_and_registers_definitions.xlsx".
; El funcionamiento de este generador de señales se divide en 2 etapas principales: setup (con teclado y display
; habilitados, para seleccionar forma de onda y frecuencia) y 'generacion' (con teclado deshabilitado y display,
; dac, adc y com habilitados).
; resolver el problema de superposición de uso de puertos y periféricos, el dispositivo se configura durante la
; etapa de setup sin producir salida alguna y luego, al activar la generacion, comienza a producir la señal sin
; posibilidad de modificarla. Para volver al modo setup se deberá inducir un RESET del dispositivo.
; ==================================================================================================================

	LIST p=16f887

	#include <p16f887.inc>
	#include "regdef.asm"
	
	__CONFIG _CONFIG1, _XT_OSC & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF	
	__CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF
	
	ORG	0X0000
	GOTO	setup

	ORG	0X0004
int:	
	MOVWF	temp_w
	SWAPF	temp_w, F 	; guardo w 		
	SWAPF	STATUS, W 		
	MOVWF	temp_status	; guardo status
	MOVF	FSR, W
	MOVWF	temp_fsr 	; guarda el direccionamiento indirecto
	MOVF	PCLATH, W
	MOVWF	temp_pclath	; guarda los 5 bits superiores de la direccion de instruccion

	CALL	display_int	; iterrupcion por display

	BANKSEL 0
	BTFSS	SCON, SENA	; produccion de señal habilitada?
	CALL	keyboard_int	; si, salteo lecturas del teclado, caso contario, atiendo la interrupcion

	BTFSS	SCON, SENA	; produccion de señal habilitada?
	GOTO	int_end 	; salteo todo lo que tiene que ver con la señal
	
	CALL	dac_int		; interrupcion por dac, que actualiza la señal a la salida
	CALL	adc_int		; interrupcion por adc que muestrea la señal producida

	BANKSEL 0
	BTFSS	EVENT, RDATA	; hay datos leidos por el adc?
	GOTO	int_cont	; no, ignoro la parte de comunicacion a la compu

	BANKSEL PIE1
	BSF	PIE1, TXIE	; habilito la interrupcion por TX

int_cont:
	CALL	com_int		; atiendo interrupcion por TX

int_end: 
	MOVF	temp_fsr, W
	MOVWF	FSR		; restauro direccionamiento indireco
	MOVF	temp_pclath, W
	MOVWF	PCLATH		; restauro los 5 bits superiores de pcl
	SWAPF	temp_status, W
	MOVWF	STATUS		; restauro status
	SWAPF	temp_w, W 	; restauro w
	
	RETFIE			; regreso de la interrupcion a la direccion del codigo que se estaba ejecutando
	

	ORG	0X0100
	
key_func:
	MOVWF	temp_work_f	; guardo el argumento que se paso

	MOVLW	0X01
	MOVWF	PCLATH		; seteo los 5 bits ms de pcl, para asegurarme que no salto a cuaquier lado

	MOVF	temp_work_f, W	; recupero el argumento
	ANDLW	b'00001111'	; enmascaro, limito a 16 valores

	MOVWF	temp_work_f
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, W	; roto dos veces para multiplicar por 4, para obtener saltos de a 4 lineas

	ADDWF	PCL, F 		; incremento program counter

; los primeros 4 botones dan el tipo de onda
; 0
	MOVLW 	b'11110011'	; Mask other bits
	ANDWF 	SCON,W		; 
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

; los siguientes 8 botones setean la frecuencia
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

; siguientes 3 botones sin mapear
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
	
; ultimo boton inicia la generacion de señal
; 15
	MOVLW 	b'01111111'	; Mask other bits
	ANDWF 	SCON,W 		; 
	IORLW 	b'10000000'	; Set frec to [111]
	GOTO	key_func_end
	
key_func_end:
	MOVWF 	SCON		; cargo el valor en scon
	RETURN

	ORG	0X0180
	
update_display:
	MOVWF	temp_work_f	; guarda el arg
	
	MOVLW	0X01
	MOVWF	PCLATH		; setea pclath

	MOVF	temp_work_f, W	; recupera el arg

	MOVF	SCON, W
	ANDLW	b'01110000'	
	
	MOVWF	temp_work_f	; muevo a un registro temporal
	BCF	STATUS, C
	RRF	temp_work_f, W	; divido por 2

	ADDWF	PCL, F 		; sumo al pcl para saltar de 8 en 8
	
; 0 (001.0)
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.11 		; equivalente a 1 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 1 (002.5)
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.12		; equivalente a 2 y punto decimal
	MOVWF	DIG2
	MOVLW	.5
	GOTO	update_display_end
; 2 (005.0)
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.15 		; equivalente a 5 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 3 (025.0)
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.2
	MOVWF	DIG1
	MOVLW	.15 		; equivalente a 5 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 4 (050.0)
	MOVLW	.0
	MOVWF	DIG0
	MOVLW	.5
	MOVWF	DIG1
	MOVLW	.10 		; equivalente a 0 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 5 (150.0)
	MOVLW	.1
	MOVWF	DIG0
	MOVLW	.5
	MOVWF	DIG1
	MOVLW	.10 		; equivalente a 0 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 6 (250.0)
	MOVLW	.2
	MOVWF	DIG0
	MOVLW	.5
	MOVWF	DIG1
	MOVLW	.10 		; equivalente a 0 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
; 7 (500.0)
	MOVLW	.5
	MOVWF	DIG0
	MOVLW	.0
	MOVWF	DIG1
	MOVLW	.10 		; equivalente a 0 y punto decimal
	MOVWF	DIG2
	MOVLW	.0
	GOTO	update_display_end
	
update_display_end:
	MOVWF	DIG3	; muevo el ultimo digito que quedo en w
	RETURN
	
setup:
	CALL 	display_setup	; configuro display		
	CALL 	keyboard_setup	; configuro teclado

	BCF	SCON, SENA 	; deshabilito la generacion de señal

; Configuracion de interrupciones -----------------------------

        BSF     INTCON, PEIE
        BSF     INTCON, GIE	; habilito interrupciones global y periferica
	
loop:	
	CALL	keyboard_task	; hace polling del teclado para sacar el boton presionado
		
	MOVF	KBREAD, W	
	XORWF	KBREADL, W 	; comparo el registro de teclado con su latch

	BTFSC	STATUS, Z	; si los botones presionados eran iguales, no hubo cambios
	GOTO 	loop		; ignorar

	MOVF	KBREAD, W	; tomo el numero de boton presionado
	CALL	key_func	; selecciono la funcion según el boton presionado

	MOVF	KBREAD, W	;
	MOVWF	KBREADL 	; cambio el latch de boton al valor actual

	CALL	update_display 	; actualizo el display con los nuevos valores seleccionados
		
	BTFSC	SCON, SENA	; produccion de señal habilitada?
	GOTO	sgen_setup	; sí, cambio a la segunda mitad del programa que genera la señal	

        GOTO    loop		; no, loop

sgen_setup:

        BCF     INTCON, GIE
	BTFSC	INTCON, GIE
	GOTO	$-2		; deshabilito temporalmente las interrupciones
	
	CALL	keyboard_deset	; deshabilito el teclado (porque comparte puerto con el dac)
	CALL 	dac_setup	; configuro dac
	CALL 	adc_setup	; configuro adc
	CALL 	com_setup	; configuro comunicacion con pc

; Configuracion de interrupciones -----------------------------

	CALL	adc_begin	; inicio el muestreo del adc

	BSF	INTCON, PEIE
        BSF     INTCON, GIE	; habilito nuevamente las interrupciones

sgen_loop:
	GOTO 	sgen_loop	; loop de generacion de la señal, no hace nada, espero al reset

	#include "display_module.asm"
	#include "keyboard_module.asm"
	#include "dac_module.asm"
        #include "adc_module.asm"
        #include "com_module.asm"

        END
