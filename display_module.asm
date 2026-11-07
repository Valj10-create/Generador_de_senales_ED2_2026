

; TP Final - Electronica Digital 2 - Display Module

; Autores:
; 	Camila Abril Dei Rossi
; 	Martina Montovani Castiglia
; 	Valentino Gorordo
; 	Vicente Gauna

; Descripcion ======================================================================================================
;
; Se tiene un display de 7 segmentos de 4 digitos para mostrar la configuración actual del dispositivo.
; Este programa asume que los segmentos del display corresponden a los bits del puerto D como sigue:
;	 --	-> 0
;	|  |	-> 1,2
;	 --	-> 3
;	|  |	-> 4,5
;	 --  .	-> 6,7
; Para conectar debo corroborar con la hoja de datos del display para asegurarme que mapeo correctamente
; a los pines correspondientes del display.
;
; Todo el tiempo estoy multiplexando entre los displays cada 5ms (20ms para una vuelta), controlando a través
; de los pines del puerto c, osea:
;
; 	C0	C1	C2	C3
; 	1 	0 	0 	0
; 	0 	1 	0 	0
; 	0 	0 	1 	0
; 	0 	0 	0 	1
;
; El multiplexado se produce periodicamente a traves de interrupcion por timer0.
; En 4 registros DIG0, DIG1, DIG2, DIG3 almacenamos los valores decimales que debe tomar cada uno de los displays
; Quiero esperar 5ms entre multiplexaciones de los digitos del display (como hay 4 digitos y quiero 
; que se refresque completamente cada 20ms). El TIMER0 debe tirar interrupcion cada 5000 instrucciones,
; que con un clock de 4MHz son 5ms.
; Voy a usar prescaler de 1:32 y cuento 156, lo que me da un tiempo de aprox 4.992ms entre multiplexaciones
; close enough. Para contar hasta 156 tengo que setear el TIMER0 a (255 - 156 + 2)=101 cada vez que lo resetee
; por interrupción, el +2 está porque el timer tarda dos ciclos de instrucción en empezar a contar. 
; 
; ==================================================================================================================

;
; Tabla de traduccion de numero a digitos encendidos en el display de 7 segmentos	
;
	ORG	0X0200

display_table:
	MOVWF	temp_work_f
	MOVLW	0X02
	MOVWF	PCLATH
	MOVF	temp_work_f, W
	ANDLW	b'00001111'	; limito w a 16 bits, para evitar errores de aumento en el PCL
	ADDWF	PCL, F		; sumar el numero en w al program counter, esto selecciona el numero que mostraremos
				; en el display de 7 segmentos
	RETLW	b'01110111'	; 0
	RETLW	b'00100100'	; 1
	RETLW	b'01011101'	; 2
	RETLW	b'01101101'	; 3
	RETLW	b'00101110'	; 4
	RETLW	b'01101011'	; 5
	RETLW	b'01111011'	; 6
	RETLW	b'00100101'	; 7
	RETLW	b'01111111'	; 8
	RETLW	b'01101111'	; 9
	RETLW	b'00111111'	; A
	RETLW	b'01111010'	; B
	RETLW	b'01010011'     ; C
	RETLW	b'01111100'     ; D
	RETLW	b'01011011'     ; E
	RETLW	b'00011011'     ; F

;
; Traduce el número de iteracion a la multiplexación del display correspondiente
;
	ORG	0X0220
	
display_number_to_onehot:
	MOVWF	temp_work_f
	MOVLW	0X02
	MOVWF	PCLATH
	MOVF	temp_work_f, W
	ANDLW	b'00000011'	; limito a 4 posibilidades
;	CLRF	PCLATH
	ADDWF	PCL, F
	
	RETLW	b'00000001'
	RETLW	b'00000010'
	RETLW	b'00000100'
	RETLW	b'00001000'


display_tmr0_preload EQU .101

;
; Subrutina de interrupcion
;

display_int:

	BTFSC	INTCON, T0IF		; interrupcion por timer0?
	CALL	display_tmr0_handle	; si

	RETURN

;	
; Manejador de interrupcion por TIMER0
;

display_tmr0_handle:

	BTFSS	INTCON, T0IE		; interrupcion habilitada?
	RETURN				; no, ignoro

	BCF	INTCON, T0IF		; bajo la bandera
	
	CALL	display_tmr0_reset	; reinicio el timer	

	BANKSEL 0 
	BCF	STATUS, IRP		; direccionamiento indirecto en los bancos 0 y 1
	CLRF	PORTC			; limpio el puerto de multiplexado para evitar ghosting del dígito	

	MOVF	display_head_ptr, W 	
	ANDLW	b'00000011' 		; limito el conteo a 4
	ADDWF	display_head_base, W 	; computo la direcion del digito actual a mostrar

	MOVWF	FSR
	MOVF	INDF, W			; saco el valor del digito a mostrar por direccionamiento indirecto
	CALL 	display_table 		; traduzco el valor de un número a la combinacion de leds que lo muestra en el display

	BANKSEL PORTD
	MOVWF	PORTD			; seteo el dígito actual
	
	MOVF	display_head_ptr, W 	
	CALL	display_number_to_onehot; consigo el valor para multiplexar al display indicado
	BANKSEL PORTC
	MOVWF	PORTC			; cambio al siguiente display 

	INCF	display_head_ptr, F 	; incremento el puntero a la dirección de memoria del siguiente dígito
	
	RETURN	

;
; Reestablece la precarga del timer0
;
display_tmr0_reset:

	BANKSEL 0
	MOVLW	display_tmr0_preload
	MOVWF	TMR0			; coloco la precarga

	RETURN
	


display_setup:

; Configuracion de puertos --------------------------------------

	BANKSEL PORTC
	CLRF	PORTC		; limpio salidas
	CLRF	PORTD
	
	BANKSEL TRISC
	MOVLW	b'11110000'
	MOVWF	TRISC		; PORTC 4 LSB como salida de multiplexado del display

	CLRF    TRISD           ; PORTD salida de digitos del display
	
; Configuracion de timer0 ---------------------------------------

	BCF	OPTION_REG, T0CS	; Timer0 en modo timer
	BCF	OPTION_REG, PSA		; Prescaler se usará para timer y no para watchdog
	BSF	OPTION_REG, PS2 	; 
	BCF	OPTION_REG, PS1		; 
	BCF	OPTION_REG, PS0		; [001] prescaler a opción 5: PS=101 (1:32)

	BSF	INTCON, T0IE		; Interrupciones por TIMER0 habilitadas

; Inicializacion de variables ----------------------------------

	BANKSEL 0

	MOVLW	DIG0
	MOVWF	display_head_base

	CLRF	display_head_ptr

; Configuracion de interrupciones -------------------------------

	CALL	display_tmr0_reset

	RETURN













