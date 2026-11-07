
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
; El teclado comparte el modulo timer1 y el puerto b con el DAC, lo cual no es un problema pues estan pensados
; para trabajar a destiempo, el teclado en la fase de configuracion y el dac en la fase de produccion de la
; señal
;
; MAPA DEL TECLADO
; filas son salidas y las columnas son entradas
;
;	RB0	RB1	RB2	RB3
; RB4	SIG1	SIG2	SIG3	SIG4	
; RB5	FRC1	FRC2	FRC3	FRC4
; RB6	FRC5	FRC6	FRC7	FRC8
; RB7				STRT
;
; ==================================================================================================================

keyboard_timer1_prel_l EQU .0
keyboard_timer1_prel_h EQU .0

;
; Rutina de interrupcion
;

keyboard_int:
	
	BTFSC	INTCON, RBIF		; interrupcion por rb?
	CALL 	keyboard_btn_handle

	BANKSEL PIR1
	BTFSC	PIR1, TMR1IF		; interrupción por timer1?
	CALL	keyboard_tmr1_handle
	
	RETURN

;
; Inicia el timer1 con la precarga necesaria para generar el debounce deseado
;

keyboard_tmr1_deb:

	BANKSEL T1CON
	BCF	T1CON, TMR1ON	; apago el timer

	MOVF	keyboard_timer1_prel_h, W
	MOVWF	TMR1H
	MOVF	keyboard_timer1_prel_l, W
	MOVWF	TMR1L		; precarga el timer

	BCF	PIR1, TMR1IF	; me aseguro que la bandera este baja

	BANKSEL PIE1
	BSF	PIE1, TMR1IE	; habilito interrupciones por timer

	BANKSEL T1CON
	BSF	T1CON, TMR1ON	; enciendo el timer

	RETURN

;
; Manejador de interrupcion por cambio en RB0
;

keyboard_btn_handle:

	BTFSS	INTCON, RBIE	; interrupción por botón habilitada?
	RETURN			; no, ignorar

	BANKSEL PORTB
	MOVF	PORTB, W 	; leo portb para habilitar bajar la bandera 
	BCF	INTCON, RBIF 	; handled, bajo la bandera

	BCF	INTCON, RBIE	; dejo de escuchar interrupcion por boton

	CALL 	keyboard_tmr1_deb
		
	RETURN			; devuelvo para esperar a que el timer lance interupcion

;
; Manejador de interrupcion por TIMER1
;

keyboard_tmr1_handle:

	BANKSEL PIE1
	BTFSS	PIE1, TMR1IE	; la interrupcion por timer estaba habilitada?
	RETURN			; no, ignoro

	BANKSEL PIR1
	BCF	PIR1, TMR1IF	; bajo la bandera
	
	BCF	T1CON, TMR1ON	; apago el timer
	
	BANKSEL PIE1
	BCF	PIE1, TMR1IE	; deshabilito la interrupcion

	BSF	EVENT, KBPOL	; poll needed

	BANKSEL PORTB
	CLRF	PORTB		; dejo todas las filas en 0 para que la próxima pulsación vuelva a generar la interrupción
	MOVF	PORTB, W	; leo PORTB para terminar el mismatch causado por el barrido
	
	BCF	INTCON, RBIF	; bajo la bandera
	BSF	INTCON, RBIE	; interrupcion por boton habilitada otra vez

	RETURN

;
; Realiza un barrido por el teclado y devuelve el indice de boton presionado
;

keyboard_poll:

	BANKSEL 0
				; barrido por el teclado
	MOVLW	.4 		; inicio el contador de filas
	MOVWF	keyboard_rows
	
	MOVLW	b'00000001'	; inicio la fila actual
	MOVWF	keyboard_row

keyboard_next_row:
	COMF	keyboard_row, W 
	ANDLW	b'00001111'	; seteo a 0 sólo la fila actual, las demas permanecen en 1
	MOVWF	PORTB	 	; 

	MOVLW	.4 		; inicio el contador de columnas
	MOVWF	keyboard_columns
	
	MOVLW	b'00010000'	; inicio la columna actual
	MOVWF	keyboard_column

keyboard_next_column:
	MOVF	keyboard_column, W
	ANDWF	PORTB, W 	; enmascaro el valor lógico del pin que corresponde a la columna que quiero revisar

	BTFSC	STATUS, Z	; si el numero fue 0 significa que el botón estaba presionado, son las fila y columna seleccionadas
	GOTO	keyboard_found	; botón encontrado

	BCF	STATUS, C 	; limpio carry por las dudas
	RLF	keyboard_column, F 	; no, siguiente columna

	DECFSZ	keyboard_columns, F
	GOTO	keyboard_next_column

	BCF	STATUS, C
	RLF	keyboard_row, F 		; siguiente fila
	
	DECFSZ	keyboard_rows, F
	GOTO	keyboard_next_row

	RETLW	0x80		; si no encontre nada devuelvo un valor absourdo

keyboard_found:
	MOVF	keyboard_row, W  		; row es como: 0000 xxxx
	CALL	keyboard_onehot_to_number	; convierte la fila aun numero binario entre 0 y 3	
	MOVWF	keyboard_row 			; lo devuelva a row

	SWAPF	keyboard_column, W 		; lo mismo con la columna, solo que hago swap primero porque los nibbles estan intercambiados
	CALL 	keyboard_onehot_to_number
	MOVWF	keyboard_column
	
	BCF	STATUS, C 		; limpio carry por las dudas
	RLF	keyboard_row, F
	RLF	keyboard_row, F 			; multiplico row por 4
	MOVF	keyboard_column, W
	ADDWF	keyboard_row, W 			; sumo (row * 4 + column) = nro boton

	RETURN
	
keyboard_onehot_to_number:
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
	
keyboard_setup:

; Configuracion de puertos -----------------------------------------------

	BANKSEL ANSELH
	CLRF	ANSELH		; puerto b como io digital

	BANKSEL PORTB
	CLRF	PORTB		; limpio salidas
	
	BANKSEL TRISB
	MOVLW	b'11110000'	
	MOVWF	TRISB		; configuro entradas y salidas		

; Configuracion de pull-ups ----------------------------------------------

	BANKSEL OPTION_REG
	BCF	OPTION_REG, 7 	; habilita WBPU weak b pull-ups 

	BANKSEL WPUB
	MOVLW	b'11110000'
	MOVWF	WPUB		; activo las pull ups de las entradas, cuando el boton está soltado
				; muestran 1 y si se presiona muestran 0

; Configuracion de interrupcion por cambio en rb -------------------------

	BSF	INTCON, RBIE
	
	BANKSEL IOCB
	MOVLW	b'11110000'
	MOVWF	IOCB

; Configuracion de timer1 ------------------------------------------------

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
	BCF	PIE1, TMR1IE	; Habilito interrupciones por timer 1

	BANKSEL PIR1
	BCF	PIR1, TMR1IF	; bajo el flag

; Inicializacion de variables -------------------------------------------

	BANKSEL 0
	CLRF	keyboard_row		; teclado matricial: fila actual 
	CLRF	keyboard_column		; teclado matricial: columna actual
	CLRF	keyboard_rows		; teclado matricial: indice de fila
	CLRF	keyboard_columns	; teclado matricial: indice de columna

	RETURN

;
; Corre en el loop principal del programa, hace polling en el teclado
; cuando se detecta un cambio en el valor
;

keyboard_task:
	BANKSEL 0
	BTFSS	EVENT, KBPOL		; poll needed?
	RETURN				; no	

	CALL	keyboard_poll	

	BANKSEL 0
	MOVWF	KBREAD
	BCF	EVENT, KBPOL	

	RETURN











