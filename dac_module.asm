; TP Final - Electronica Digital 2 - DAC Module
 
; Autores:
;	Camila Abril Dei Rossi
;	Martina Montovani Castiglia
;	Valentino Gorordo
;	Vicente Gauna

; Descripcion ================================================================================================
; 
; El módulo DAC produce señales de 1 de 4 tipos posibles: cuadrada, triangular, sinusoidal y diente de sierra
; en una de 8 posibles frecuencias: 1Hz, 2.5Hz, 5Hz, 25Hz, 50Hz, 150Hz, 250Hz, 500Hz.
; La selección de la forma de onda y la frecuencia se harán a traves del registro SCON (Signal Configuration)
; al igual que la señal de inicio/stop.
;
; - SCON [0x75] ------------------------------------------------------------
;	bit7	bit6	bit5	bit4	bit3	bit2	bit1	bit0
;	ENA	SFRC2	SFRC1	SFRC0	STYP1	STYP0	-	-
; --------------------------------------------------------------------------
;
; Cada señal produce una salida que se mapea entre 0 (valor mínimo) y 255 (valor máximo), los valores se
; encuentran precalculados para cada tipo de señal.
; La salida se produce a través del PORTB, donde se encuentran conectados los pines de un DAC R2R, desde
; RB0 (LSB) hasta RB7 (MSB).
; Se usa un cristal oscilador externo de 4MHz
;
; Nota: el hardware utilizado produce un techo en la velocidad de frecuencias que se pueden generar, como
; 	los ciclos de instruccion del controlador tienen una frecuencia de 1 MHz, es imposible producir
;	una señal de salida que varie mas rapidamente. Es por esto que establecemos un limite en 500Hz, que
;	nos deja una ventana considerable de instrucciones entre cambios en la salida.
;
; Usaremos las interrupciones por TIMER1 para controlar la frecuencia de las señales. En cada interrupción
; aumentamos el contador de instantes de tiempo y buscamos el valor correspondiente en las tablas
; precalculadas, pasamos ese valor a PORTB y esperamos a la proxima interrupcion.
;
; ============================================================================================================

	ORG	0X0400
;
; Devuelve el valor de precarga para el byte menos significativo del timer1
; según la frecuencia seleccionada
;

dac_get_tmr1_prel_l:

	MOVWF	temp_work_f	; guardo el argumento
	MOVLW	0X04
	MOVWF	PCLATH		; me aseguro que pclath esta en la direcion correcta

	MOVF	temp_work_f, W	; devuelvo el argumento
	ANDLW	b'00000111'	; enmascaro para limitar a 8 valores
	ADDWF	PCL, F 		; incremento program counter

	RETLW	0X11	; 0
	RETLW	0X4F	; 1
	RETLW	0XB9	; 2 	
	RETLW	0X41	; 3
	RETLW	0XB2	; 4
	RETLW	0X52	; 5
	RETLW	0XC9	; 6
	RETLW	0XE4	; 7

	ORG	0X0410
;
; Devuelve el valor de precarga para el byte mas significativo del timer1
; según la frecuencia seleccionada
;

dac_get_tmr1_prel_h:

	MOVWF	temp_work_f	; guardo el argumento
	MOVLW	0X04
	MOVWF	PCLATH		; me aseguro que pclath esta en la direcion correcta

	MOVF	temp_work_f, W	; devuelvo el argumento
	ANDLW	b'00000111'	; enmascaro para limitar a 8 valores
	ADDWF	PCL, F 		; incremento program counter
	
	RETLW	0X86
	RETLW	0XCF
	RETLW	0XE7
	RETLW	0XFB
	RETLW	0XFD
	RETLW	0XFF
	RETLW	0XFF
	RETLW	0XFF

	ORG	0X0420
;
; Devuelve un valor entre 0-255 que corresponde a una funcion triangular, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = |  16x  si  x < 16
;	 | -16x  si  x >= 16
;
	
dac_get_trng_value:

	MOVWF	temp_work_f	; guardo el argumento
	MOVLW	0X04
	MOVWF	PCLATH		; me aseguro que pclath esta en la direcion correcta

	MOVF	temp_work_f, W	; devuelvo el argumento
	ANDLW	b'00011111'	; mask the index to 0..31
	ADDWF	PCL, F

	RETLW	.0		; x=0   0x00
	RETLW	.16		; x=1   0x10
	RETLW	.32		; x=2   0x20
	RETLW	.48		; x=3   0x30
	RETLW	.64		; x=4   0x40
	RETLW	.80		; x=5   0x50
	RETLW	.96		; x=6   0x60
	RETLW	.112		; x=7   0x70
	RETLW	.128		; x=8   0x80
	RETLW	.143		; x=9   0x8F
	RETLW	.159		; x=10  0x9F
	RETLW	.175		; x=11  0xAF
	RETLW	.191		; x=12  0xBF
	RETLW	.207		; x=13  0xCF
	RETLW	.223		; x=14  0xDF
	RETLW	.239		; x=15  0xEF
	RETLW	.255		; x=16  0xFF
	RETLW	.239		; x=17  0xEF
	RETLW	.223		; x=18  0xDF
	RETLW	.207		; x=19  0xCF
	RETLW	.191		; x=20  0xBF
	RETLW	.175		; x=21  0xAF
	RETLW	.159		; x=22  0x9F
	RETLW	.143		; x=23  0x8F
	RETLW	.128		; x=24  0x80
	RETLW	.112		; x=25  0x70
	RETLW	.96		; x=26  0x60
	RETLW	.80		; x=27  0x50
	RETLW	.64		; x=28  0x40
	RETLW	.48		; x=29  0x30
	RETLW	.32		; x=30  0x20
	RETLW	.16		; x=31  0x10

	ORG	0X0450

;
; Devuelve un valor entre 0-255 que corresponde a una funcion seno, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = 127.5 + 127.5·sin(2πx/32)
;

dac_get_sine_value:
	MOVWF	temp_work_f	; guardo el argumento
	MOVLW	0X04
	MOVWF	PCLATH		; me aseguro que pclath esta en la direcion correcta

	MOVF	temp_work_f, W	; devuelvo el argumento
	ANDLW	b'00011111'	; mascara para el argumento, solo me interesan los primeros 32 valores
	ADDWF	PCL, F

	RETLW   .128		; x=0   0x80
	RETLW   .152		; x=1   0x98
	RETLW   .176		; x=2   0xB0
	RETLW   .198		; x=3   0xC6
	RETLW   .218		; x=4   0xDA
	RETLW   .234		; x=5   0xEA
	RETLW   .245		; x=6   0xF5
	RETLW   .253		; x=7   0xFD
	RETLW   .255		; x=8   0xFF
	RETLW   .253		; x=9   0xFD
	RETLW   .245		; x=10  0xF5
	RETLW   .234		; x=11  0xEA
	RETLW   .218		; x=12  0xDA
	RETLW   .198		; x=13  0xC6
	RETLW   .176		; x=14  0xB0
	RETLW   .152		; x=15  0x98
	RETLW   .128		; x=16  0x80
	RETLW   .103		; x=17  0x67
	RETLW   .79 		; x=18  0x4F
	RETLW   .57 		; x=19  0x39
	RETLW   .37 		; x=20  0x25
	RETLW   .21 		; x=21  0x15
	RETLW   .10 		; x=22  0x0A
	RETLW   .2  		; x=23  0x02
	RETLW   .0  		; x=24  0x00
	RETLW   .2  		; x=25  0x02
	RETLW   .10 		; x=26  0x0A
	RETLW   .21 		; x=27  0x15
	RETLW   .37 		; x=28  0x25
	RETLW   .57 		; x=29  0x39
	RETLW   .79 		; x=30  0x4F
	RETLW   .103		; x=31  0x67

	ORG	0X0480
;
; Elige de que tabla de valores sacar segun la configuracion y devuelve
; el valor indicado segun la cuenta actual que se pase como argumento
;

dac_get_func_value:

	MOVWF	temp_work_f	; guardo el argumento
	MOVLW	0X04
	MOVWF	PCLATH		; me aseguro que pclath esta en la direcion correcta

	MOVF	temp_work_f, W	; devuelvo el argumento
	MOVLW	b'00001100'	; enmascaro bits que me dan el tipo de onda
	ANDWF	SCON, W		; obtengo la onda seleccionada

	; como no roto los valores, hare saltos de a 4 instrucciones, esto me conviene
	; para llamar las funciones, agregar un return despues de cada una y mover el 
	; valor a w antes de la llamada
	
	ADDWF	PCL, F 		; busco en la tabla indicada el valor

	MOVF	temp_work_f, W	; 0
	CALL	dac_get_squr_value	
	RETURN
	NOP
	
	MOVF	temp_work_f, W	; 4
	CALL	dac_get_trng_value	
	RETURN
	NOP
	
	MOVF	temp_work_f, W	; 8
	CALL	dac_get_swth_value
	RETURN
	NOP
	
	MOVF	temp_work_f, W	; 12
	CALL	dac_get_sine_value
	RETURN

	ORG	0X04A0
;
; Devuelve un valor entre 0-255 que corresponde a una funcion cuadrada, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = | 0   si  x < 16
;	 | 255 si  x >= 16
;

dac_get_squr_value:

	ANDLW	b'00011111'	; mascara para el argumento, solo me interesan los primeros 32 valores
	ANDLW	b'00010000'	; enmascaro el 5to bit
	BTFSC	STATUS, Z	; si W fue cero, entonces el numero era menor a 16
	RETLW	.0
	RETLW	.255		; else el numero era mayor

;
; Devuelve un valor entre 0-255 que corresponde a una funcion diente de sierra, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = 8x
;

dac_get_swth_value:
	ANDLW	b'00011111'	; mascara para el argumento, solo me interesan los primeros 32 valores

	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, W
	
	RETURN			; es directamente el valor del contador
	
;
; Subrutina de interrupción
;

dac_int:

	BANKSEL PIR1
	BTFSC	PIR1, TMR1IF	; interrupcion causada por timer1?
	CALL	dac_tmr1_handle

	RETURN

;
; Manejo de interrupcion por timer1
;

dac_tmr1_handle:

	BANKSEL PIE1
	BTFSS	PIE1, TMR1IE	; interrupciones por timer1 habilitadas?
	RETURN			; no, ignorar

	BANKSEL PIR1
	BCF	PIR1, TMR1IF	; bajo la bandera

	CALL	dac_tmr1_reset

	INCF	INST, F
	MOVF	INST, W		; incremento el contador de intervalos de tiempo en 1
	
	CALL	dac_get_func_value		; llamo a la tabla correspondiente para obtener el valor de la funcion

	BANKSEL PORTB
	MOVWF	PORTB		; coloco el valor a la salida de portb

	RETURN	

;
; Subrutina que restablece el valor de precarga del timer y lo reinicia
;

dac_tmr1_reset:

	BANKSEL T1CON
	BCF	T1CON, TMR1ON	; apago el timer momentaneamente

	BANKSEL 0
	
	MOVF	dac_tmr1_preload_l, W	
	MOVWF	TMR1L
	MOVF	dac_tmr1_preload_h, W
	MOVWF	TMR1H		; reinicio el timer con su respectiva precarga

	BANKSEL T1CON
	BSF	T1CON, TMR1ON	; enciendo el timer

	RETURN	
;
; Punto de entrada del programa, configuración
;

dac_setup:	

; Configuración de la señal ------------------------------------------

	MOVLW	b'01110000'	; enmascaro bits que me dan la frecuencia
	ANDWF	SCON, W		; obtengo frecuencia seleccionada
	MOVWF	temp_work_f	; muevo a un registro temporario
	BCF	STATUS, C
	RRF	temp_work_f, F 	; roto dos veces para mover los bits de interes
	BCF	STATUS, C
	RRF	temp_work_f, F 	; al nibble inferior del byte
	BCF	STATUS, C
	RRF	temp_work_f, F 	; al nibble inferior del byte
	BCF	STATUS, C
	RRF	temp_work_f, F 	; al nibble inferior del byte
	
	MOVF	temp_work_f, W	
	CALL	dac_get_tmr1_prel_l	; consigo el valor de precarga para el byte bajo de tmr1
	MOVWF	dac_tmr1_preload_l	; cargo el valor
	MOVF	temp_work_f, W	
	CALL	dac_get_tmr1_prel_h	; consigo el valor de precarga para el byte alto de tmr1
	MOVWF	dac_tmr1_preload_h	; cargo el valor
	
; Configuración de puertos ------------------------------------------

	BANKSEL PORTB
	CLRF	PORTB		; limpio el puerto
	
	BANKSEL ANSELH
	CLRF	ANSELH		; todos los pines del puerto B digitales
	CLRF	TRISB		; todos los pines del puerto B como salida

; Configuración del timer1 ------------------------------------------

	BANKSEL T1CON

	BCF	T1CON, TMR1GE	; timer no se rige por gate
	BCF	T1CON, T1CKPS1	
	BCF	T1CON, T1CKPS0	; [00] Prescaler 1
	BCF	T1CON, T1OSCEN	; oscilador LP apagado
	BCF	T1CON, TMR1CS	; usa clock interno
	BCF	T1CON, TMR1ON	; timer apagado
	
	CLRF	TMR1H
	CLRF	TMR1L		; limpio contadores del timer

	BANKSEL PIR1
	BCF	PIR1, TMR1IF	; bajo la bandera de interrupción
	BANKSEL PIE1
	BSF	PIE1, TMR1IE	; interrupciones por timer1 habilitadas

	CALL	dac_tmr1_reset
	
; Inicializacion de variables --------------------------------------

	CLRF	INST

	RETURN
