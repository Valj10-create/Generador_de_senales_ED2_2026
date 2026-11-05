
; TP Final - Electronica Digital 2 - Modulo keyboard

; Autores:
; 	Camila Abril Dei Rossi
; 	Martina Montovani Castiglia
; 	Valentino Gorordo
; 	Vicente Gauna

; Descripcion ======================================================================================================
;
; Se tiene un teclado matricial 4x4 para la configuración inicial del dispositivo. Los botones del teclado
; permiten seleccionar la forma de onda y la frecuencia de la señal, asi como tambien iniciar el generador.
; El dispositivo sigue produciendo una señal en la salida hasta que se produzca un reseteo.
;
; Ponemos RB0-RB3 a LOW (0), y escuchamos el puerto B donde esta el teclado para interrupcion por cambio producidas
; en RB4-RB7.
; Dentro de la rutina de interrupcion realizamos un barrido entre RB0-RB3 para ver que fila y columna se pulsó, y
; llevamos a cabo la operacion respectiva.
;
; MAPA DEL TECLADO
;
;	RB0	RB1	RB2	RB3
; RB4	SIG1	SIG2	SIG3	SIG4	
; RB5	FRC1	FRC2	FRC3	FRC4
; RB6	FRC5	FRC6	FRC7	FRC8
; RB7				STRT
;
; ==================================================================================================================

LIST p=16f887
#include <p16f887.inc>

CBLOCK 0X20
	row
	column
	rows
	columns
	memory_initial_address
	memory_total_spaces
	display_pointer
	display_positions_count
	keyboard_pointer
	keyboard_positions_count
ENDC

CBLOCK 0X70
	temp_w
	temp_status
	cx
	cy
ENDC

	__CONFIG _CONFIG1, _XT_OSC & _WDT_OFF & _PWRTE_OFF & _MCLR_ON & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF	
	__CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF
	
	ORG	0X00
	GOTO	setup

	ORG	0X04
	GOTO	int

	ORG	0X05

;
; Rutina de interrupcion
;

int:	MOVWF	temp_w
	SWAPF	temp_w, F 		; movf altera banderas de STATUS, estoy modificando la info sin querer
	SWAPF	STATUS, W 		; por eso uso swapf
	MOVWF	temp_status		; guardo contexto, noto que me quedó swapeado, voy a tener que darlo vuelta cuando lo restaure

	BANKSEL 0 			; En la rutina de interrupción trabajo con el banco 0
	BCF	STATUS, IRP
	
	BTFSC	INTCON, RBIF		; El puerto B cambió?
	CALL 	button_handle		; Si

	BANKSEL PIR1
	BTFSC	PIR1, TMR1IF		; El timer 1 lanzo interrupción?
	CALL	timer1_handle
	
	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W 		; recupero contexto
	
	RETFIE				; regreso de la interrupcion a la direccion del codigo que se estaba ejecutando

;
; Manejador de interrupcion por TIMER1
;

timer1_handle:

	BANKSEL PIE1
	BTFSS	PIE1, TMR1IE		; la interrupcion por timer estaba habilitada?
	RETURN				; no, ignoro

	BANKSEL PIR1
	BCF	PIR1, TMR1IF
	
	BANKSEL T1CON
	BCF	T1CON, TMR1ON		; apago el timer
	BANKSEL PIE1
	BCF	PIE1, TMR1IE

	GOTO	cont_button_handle	

	RETURN

;	
; Manejador de interrupcion por TIMER0
;

timer0_handle:
	BTFSS	INTCON, T0IE		; el timer estaba habilitado?
	RETURN				; no, no reacciono

	BCF	INTCON, T0IF		; handled, bajo la bandera

	CLRF	PORTC
	
	MOVF	display_pointer, W 	; dirección del digito actual que se va a mostrar
	MOVWF	FSR
	MOVF	INDF, W			; saco el valor del digito a mostrar por direccionamiento indirecto
	CALL 	table 			; traduzco el valor de un número a la combinacion de leds que lo muestra en el display
	MOVWF	PORTD			; seteo el dígito actual
	
	MOVF	memory_initial_address, W
	SUBWF	display_pointer, W	; W = display_pointer - memory_initial_address
	CALL	number_to_onehot
	MOVWF	PORTC			; cambio al siguiente display 

	CALL	reset_timer0
	
	INCF	display_pointer, F 	; incremento el puntero a la dirección de memoria del siguiente dígito
	DECFSZ	display_positions_count, F ; decremento el contador de iteraciones, si me pasé de las 4 iteraciones:
	RETURN
	CALL	reset_display_pointer	; reseteo el puntero y el contador
	
	RETURN	

reset_display_pointer:
	MOVF	memory_total_spaces, W 	; cantidad de dígitos (iteraciones)
	MOVWF	display_positions_count	; reinicio el contador
	MOVF	memory_initial_address, W; dirección del primer lugar en la memoria
	MOVWF	display_pointer		; reinicio el puntero a la primera posición
	RETURN

number_to_onehot:
	ANDLW	b'00000011'
	ADDWF	PCL, F
	RETLW	b'00000001'
	RETLW	b'00000010'
	RETLW	b'00000100'
	RETLW	b'00001000'
	
; -----------------------------------------------------------

; -------------------- INTERRUPCION POR TECLADO -------------

button_handle:
	BTFSS	INTCON, RBIE	; Interrupción por botón habilitada?
	RETURN			; No, ignorar

	MOVF	PORTB, W 
	BCF	INTCON, RBIF 	; Handled, bajo la bandera

	BCF	INTCON, RBIE	; dejo de escuchar interrupcion por boton

	BANKSEL TMR1H
	CLRF	TMR1H
	CLRF	TMR1L		; arranca el timer desde cero

	BANKSEL T1CON
	BSF	T1CON, TMR1ON	; enciendo el timer que me da 50ms de debounce

	BANKSEL PIE1
	BSF	PIE1, TMR1IE

	BANKSEL 0
	
	RETURN			; devuelvo para esperar a que el timer lance interupcion

cont_button_handle:

	BSF	INTCON, RBIE	; interrupcion por boton habilitada otra vez
	BANKSEL 0
; barrido por el teclado

	MOVLW	.4 		; inicio el contador de filas
	MOVWF	rows
	
	MOVLW	b'00000001'	; inicio la fila actual
	MOVWF	row

next_row:
	COMF	row, W 		;
	ANDLW	b'00001111'	; seteo a 0 sólo la fila actual, las demas permanecen en 1
	MOVWF	PORTB	 	; 

	MOVLW	.4 		; inicio el contador de columnas
	MOVWF	columns
	
	MOVLW	b'00010000'	; inicio la columna actual
	MOVWF	column

next_column:
	MOVF	column, W	;
	ANDWF	PORTB, W 	; enmascaro el valor lógico del pin que corresponde a la columna que quiero revisar

	BTFSC	STATUS, Z	; si el numero fue 0 significa que el botón estaba presionado, son las fila y columna seleccionadas
	GOTO	found		; botón encontrado

	BCF	STATUS, C 	; limpio carry por las dudas
	RLF	column, F 	; no, siguiente columna

	DECFSZ	columns, F
	GOTO	next_column

	BCF	STATUS, C
	RLF	row, F 		; siguiente fila
	
	DECFSZ	rows, F
	GOTO	next_row

	GOTO	scan_end

found:
	MOVF	keyboard_pointer, W 	; apunto al registro actual
	MOVWF	FSR 

	MOVF	row, W  		; row es como: 0000 xxxx
	CALL	onehot_to_number	; convierte la fila aun numero binario entre 0 y 3	
	MOVWF	row 			; lo devuelva a row

	SWAPF	column, W 		; lo mismo con la columna, solo que hago swap primero porque los nibbles estan intercambiados
	CALL 	onehot_to_number
	MOVWF	column
	
	BCF	STATUS, C 		; limpio carry por las dudas
	RLF	row, F
	RLF	row, F 			; multiplico row por 4
	MOVF	column, W
	ADDWF	row, W 			; sumo (row * 4 + column) = nro boton

	MOVWF	INDF 			; escribo el valor en el registro

	INCF	keyboard_pointer, F 	; incremento el puntero
	DECFSZ	keyboard_positions_count, F ; decremento el contador de posiciones de memoria
	GOTO	scan_end
	CALL	reset_keyboard_pointer	; si agoté las posiciones del cursor lo reestablezco a su posicion inicial

scan_end:
	; dejo todas las filas en 0 para que la próxima pulsación vuelva a generar la interrupción
	CLRF	PORTB
	NOP
	MOVF	PORTB, W	; leo PORTB para terminar el mismatch causado por el barrido
	BCF	INTCON, RBIF	; y bajo la bandera
	RETURN
	
onehot_to_number:
	ANDLW	b'00001111'
	ADDWF	PCL, F
	RETLW	0X00	;0000 0000 <- invalido
	RETLW	0X00	;0000 0001
	RETLW	0X01	;0000 0010
	RETLW	0X00	;0000 0011 <- invalido
	RETLW	0X02	;0000 0100
	RETLW	0X00	;0000 0101 <- invalido
	RETLW	0X00	;0000 0110 <- invalido
	RETLW	0X00	;0000 0111 <- invalido
	RETLW	0X03	;0000 1000
	RETLW	0X00	;0000 1001 <- invalido
	RETLW	0X00	;0000 1010 <- invalido
	RETLW	0X00	;0000 1011 <- invalido
	RETLW	0X00	;0000 1100 <- invalido
	RETLW	0X00	;0000 1101 <- invalido
	RETLW	0X00	;0000 1110 <- invalido
	RETLW	0X00	;0000 1111 <- invalido

reset_keyboard_pointer:
	MOVF	memory_initial_address, W
	MOVWF	keyboard_pointer
	MOVF	memory_total_spaces, W
	MOVWF	keyboard_positions_count
	RETURN

reset_timer0:
	MOVLW	.101
	MOVWF	TMR0
	RETURN
	
setup:

; ----------------------PORTS SETUP---------------------------------

	BANKSEL ANSEL
	CLRF	ANSEL
	CLRF	ANSELH

	BANKSEL PORTB
	CLRF	PORTB	
	CLRF	PORTC		; limpio salidas
	CLRF	PORTD
	
	BANKSEL TRISB
	MOVLW	b'11110000'	
	MOVWF	TRISB		; PORTB teclado matricial
				; 		RB0	RB1	RB2	RB3
				; 		C0	C1	C2	C3
				; RB4 F0	0 	1 	2 	3
				; RB5 F1	4 	5 	6 	7
				; RB6 F2	8 	9 	10 	11
				; RB7 F3	12 	13 	14 	15
				;
				; filas son salidas y las columnas son entradas

	MOVLW	b'11110000'
	MOVWF	TRISC		; PORTC 4 LSB como salida de multiplexado del display

	CLRF    TRISD           ; PORTD salida de digitos del display

	BANKSEL PORTC
	MOVLW	b'00010001'
	MOVWF	PORTC
; ------------------------------------------------------------------

; ----------------------PULL UPS------------------------------------

	BANKSEL OPTION_REG
	BCF	OPTION_REG, 7 	; habilita WBPU weak b pull-ups 

	BANKSEL WPUB
	MOVLW	b'11110000'
	MOVWF	WPUB		; activo las pull ups de las entradas, cuando el boton está soltado
				; muestran 1 y si se presiona muestran 0

; ------------------------------------------------------------------
	
; ------------------------------INT RB------------------------------

	BSF	INTCON, RBIE
	
	BANKSEL IOCB
	MOVLW	b'11110000'
	MOVWF	IOCB
	
; ------------------------------------------------------------------

; ---------------------------INT TIMER0-----------------------------


; quiero esperar 5ms entre multiplexaciones de los digitos del display (como hay 4 digitos y quiero 
; que se refresque completamente cada 20ms). El TIMER0 debe tirar interrupcion cada 5000 instrucciones,
; que con un clock de 4MHz son 5ms.
; Voy a usar prescaler de 1:32 y cuento 156, lo que me da un tiempo de aprox 4.992ms entre multiplexaciones
; close enough. Para contar hasta 156 tengo que setear el TIMER0 a (255 - 156 + 2)=101 cada vez que lo resetee
; por interrupción, el +2 está porque el timer tarda dos ciclos de instrucción en empezar a contar. 


	BANKSEL OPTION_REG
	BCF	OPTION_REG, T0CS	; Timer0 sigue al clock interno
	BSF	INTCON, T0IE		; Interrupciones por TIMER0 habilitadas

;	prescaler a opción 5: PS=101 (1:32)
	BANKSEL OPTION_REG
	BCF	OPTION_REG, PSA		; Prescaler se usará para timer y no para watchdog
	BCF	OPTION_REG, PS0	; 0
	BCF	OPTION_REG, PS1	; 0
	BSF	OPTION_REG, PS2 ; 1

	BANKSEL 0
	BCF	STATUS, IRP	; direccionamiento indirecto en bancos 0 y 1
	CALL	reset_timer0

	BSF	INTCON, PEIE
	BSF	PIE1, TMR1IE
	BCF	PIR1, TMR1IF

; -------------------------------------------------------------

; ----------------------INT TIMER1-----------------------------
	BANKSEL T1CON
	BCF	T1CON, TMR1GE	; gate enable
	BSF	T1CON, T1CKPS0
	BCF	T1CON, T1CKPS1	; 01 opcion de prescaler = 2
	BCF	T1CON, T1OSCEN
	
	BCF	T1CON, TMR1CS	; clock source es FOSC/4
	BCF	T1CON, TMR1ON	; apago el timer para que no arranque a contar

	CLRF	TMR1H
	CLRF	TMR1L
	
	BANKSEL PIE1
	BSF	PIE1, TMR1IE	; Habilito interrupciones por timer 1

	BANKSEL PIR1
	BCF	PIR1, TMR1IF	; bajo el flag
; -------------------------------------------------------------

; ----------------------REGISTERS SETUP------------------------
	BANKSEL 0
	CLRF	row		; teclado matricial: fila actual 
	CLRF	column		; teclado matricial: columna actual
	CLRF	rows		; teclado matricial: indice de fila
	CLRF	columns		; teclado matricial: indice de columna

	CLRF	0X40
	CLRF	0X41
	CLRF	0X42
	CLRF	0X43
	
	MOVLW	0x40
	MOVWF	memory_initial_address
	MOVLW	.4
	MOVWF	memory_total_spaces
	CALL	reset_keyboard_pointer
	CALL 	reset_display_pointer

	BSF	INTCON, PEIE	; habilito interrupciones de perifericos
	BSF	INTCON, GIE	; habilito interrupciones
		
main:	
 	  
	GOTO	main
	END
