; TP Final - Electronica Digital 2 - DAC Module
 
; Autores:
;	Camila Abril Dei Rossi
;	Martina Montovani Castiglia
;	Valentino Gorordo
;	Vicente Gauna

; Descripcion ================================================================================================
; 
; El módulo DAC produce señales de 1 de 4 tipos posibles: cuadrada, triangular, sinusoidal y diente de sierra
; en una de 8 posibles frecuencias: 2Hz, 5Hz, 10Hz, 50Hz, 100Hz, 300Hz, 700Hz, 1000Hz.
; La selección de la forma de onda y la frecuencia se harán a traves del registro SCON (Signal Configuration)
; en 0x75, al igual que la señal de inicio/stop.
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
; Se usa un cristal oscilador externo de 8MHz
;
; Nota: el hardware utilizado produce un techo en la velocidad de frecuencias que se pueden generar, como
; 	los ciclos de instruccion del controlador tienen una frecuencia de 2 MHz, es imposible producir
;	una señal de salida que varie mas rapidamente. Es por esto que establecemos un limite en 1kHz, que
;	nos deja una ventana de 63 instrucciones entre cambios en la salida.
;
; Usaremos las interrupciones por TIMER1 para controlar la frecuencia de las señales. En cada interrupción
; aumentamos el contador de instantes de tiempo y buscamos el valor correspondiente en las tablas
; precalculadas, pasamos ese valor a PORTB y esperamos a la proxima interrupcion.
;
; 
; (ver excel)
; 
; ============================================================================================================

LIST p=16f887
#include <p16f887.inc>

tmr1_preload_l EQU 0X20
tmr1_preload_h EQU 0X21

temp_work_f EQU	0x70
temp_w EQU 0x71
temp_status EQU 0x72
time_instant_counter EQU 0x73

SCON 	EQU 	0X75
STYP0 	EQU 	1
STYP1 	EQU 	2
SFRC0 	EQU 	3
SFRC1 	EQU 	4
SFRC2 	EQU 	5
SENA	EQU	7



        __CONFIG _CONFIG1, _HS_OSC & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF
        __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

        ORG     0X00
        GOTO    setup

        ORG     0X04
        GOTO    int

        ORG     0X05

get_tmr1_prel_l:
	RETURN
	ANDWF	b'00000111', W	; enmascaro para limitar a 8 valores
	ADDWF	PCL, F 		; incremento program counter
	RETLW	0XD5
	RETLW	0X13
	RETLW	0X7D
	RETLW	0X05
	RETLW	0X76
	RETLW	0X16
	RETLW	0X8D
	RETLW	0XA8
	
	
get_tmr1_prel_h:
	ANDWF	b'00000111', W	; enmascaro para limitar a 8 valores
	ADDWF	PCL, F 		; incremento program counter
	RETLW	0X85
	RETLW	0XCF
	RETLW	0XE7
	RETLW	0XFB
	RETLW	0XFD
	RETLW	0XFF
	RETLW	0XFF
	RETLW	0XFF

;
; Devuelve un valor entre 0-255 que corresponde a una funcion cuadrada, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = | 0   si  x < 16
;	 | 255 si  x >= 16
;

get_squr_value:

	ANDLW	b'00011111'	; mascara para el argumento, solo me interesan los primeros 32 valores
	ANDLW	b'00010000'	; enmascaro el 5to bit
	BTFSS	STATUS, Z	; si W fue cero, entonces el numero era menor a 16
	RETLW	.0
	RETLW	.255		; else el numero era mayor


;
; Devuelve un valor entre 0-255 que corresponde a una funcion triangular, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = |  16x  si  x < 16
;	 | -16x  si  x >= 16
;
	
get_trng_value:

	ANDLW	b'00011111'	; mascara para el argumento, solo me interesan los primeros 32 valores
	MOVWF	temp_work_f
	ANDLW	b'00010000'	; enmascaro el 5to bit
	BTFSC	STATUS, Z	; si W fue cero, entonces el numero era menor a 16
	GOTO	get_trng_value_dn

get_trng_value_up:

	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F

	MOVF	temp_work_f, W
	
	RETURN
	
get_trng_value_dn:
	
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F

	COMF	temp_work_f, F
	INCF	temp_work_f, F
	MOVLW	.255
	ADDWF	temp_work_f, W

	RETURN
	
;
; Devuelve un valor entre 0-255 que corresponde a una funcion diente de sierra, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = 8x
;

get_swth_value:
	ANDLW	b'00011111'	; mascara para el argumento, solo me interesan los primeros 32 valores

	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	BCF	STATUS, C
	RLF	temp_work_f, F
	
	RETURN			; es directamente el valor del contador
	
;
; Devuelve un valor entre 0-255 que corresponde a una funcion seno, dado
; un x [0-32] pasado como argumento (a traves de w).
;
; f(x) = 127.5 + 127.5·sin(2πx/32)
;

get_sine_value:
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

;
; Subrutina de interrupción
;

int:
	MOVWF	temp_w
	SWAPF	temp_w, F
	SWAPF	STATUS, W
	MOVWF	temp_status	; guardar contexto

	BANKSEL PIR1
	BTFSC	PIR1, TMR1IF	; interrupcion causada por timer1?
	GOTO	tmr1_handle

	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W	; restablecer contexto

	RETFIE

;
; Manejo de interrupcion por timer1
;

tmr1_handle:

	BANKSEL PIE1
	BTFSS	PIE1, TMR1IE	; interrupciones por timer1 habilitadas?
	RETURN			; no, ignorar

	CALL	reset_timer1

	INCF	time_instant_counter, F
	MOVF	time_instant_counter, W	; incremento el contador de intervalos de tiempo en 1
	
	CALL	get_func_value		; llamo a la tabla correspondiente para obtener el valor de la funcion

	BANKSEL PORTB
	MOVWF	PORTB		; coloco el valor a la salida de portb

	RETURN	

;
; Elige de que tabla de valores sacar segun la configuracion y devuelve
; el valor indicado segun la cuenta actual que se pase como argumento
;

get_func_value:
	MOVWF	temp_work_f
	MOVLW	b'00001100'	; enmascaro bits que me dan el tipo de onda
	ANDWF	SCON, W		; obtengo la onda seleccionada

	; como no roto los valores, hare saltos de a 4 instrucciones, esto me conviene
	; para llamar las funciones, agregar un return despues de cada una y mover el 
	; valor a w antes de la llamada
	
	ADDWF	PCL, F 		; busco en la tabla indicada el valor

	MOVF	temp_work_f, W	; 0
	CALL	get_squr_value	
	RETURN
	NOP
	
	MOVF	temp_work_f, W	; 4
	CALL	get_trng_value	
	RETURN
	NOP
	
	MOVF	temp_work_f, W	; 8
	CALL	get_swth_value
	RETURN
	NOP
	
	MOVF	temp_work_f, W	; 12
	CALL	get_sine_value
	RETURN
	
;
; Subrutina que restablece el valor de precarga del timer y lo reinicia
;

reset_timer1:

	BCF	T1CON, TMR1ON	; apago el timer momentaneamente

	BANKSEL 0
	
	MOVF	tmr1_preload_l, W	
	MOVWF	TMR1L
	MOVF	tmr1_preload_h, W
	MOVWF	TMR1H		; reinicio el timer con su respectiva precarga

	BSF	T1CON, TMR1ON	; enciendo el timer

	RETURN	
;
; Punto de entrada del programa, configuración
;

setup:	

; Configuración de la señal ------------------------------------------

	CLRF	SCON

	BCF	SCON, STYP0
	BCF	SCON, STYP1	; forma de onda cuadrada seleccionada

	BCF	SCON, SFRC0
	BCF	SCON, SFRC1
	BCF	SCON, SFRC2	; frecuencia de 1Hz seleccionada

	MOVLW	b'00111000'	; enmascaro bits que me dan la frecuencia
	ANDWF	SCON, W		; obtengo frecuencia seleccionada
	MOVWF	temp_work_f	; muevo a un registro temporario
	RRF	temp_work_f, F 	; roto dos veces para mover los bits de interes
	RRF	temp_work_f, F 	; al nibble inferior del byte
	RRF	temp_work_f, F 	; al nibble inferior del byte
	
	MOVF	temp_work_f, W	
	CALL	get_tmr1_prel_l	; consigo el valor de precarga para el byte bajo de tmr1
	MOVWF	tmr1_preload_l	; cargo el valor
	MOVF	temp_work_f, W	
	CALL	get_tmr1_prel_h	; consigo el valor de precarga para el byte alto de tmr1
	MOVWF	tmr1_preload_h	; cargo el valor
	
; Configuración de puertos ------------------------------------------

	BANKSEL PORTB
	CLRF	PORTB		; limpio el puerto
	
	BANKSEL ANSELH
	CLRF	ANSELH		; todos los pines del puerto B digitales
	CLRF	TRISB		; todos los pines del puerto B como salida
	
; Configuración del timer1 ------------------------------------------

	BANKSEL T1CON

	BCF	T1CON, TMR1GE	; timer no se rige por gate
	BSF	T1CON, T1CKPS1	
	BSF	T1CON, T1CKPS0	; [11] Prescaler 8
	BCF	T1CON, T1OSCEN	; oscilador LP apagado
	BCF	T1CON, TMR1CS	; usa clock interno
	BCF	T1CON, TMR1ON	; timer apagado

	
	CLRF	TMR1H
	CLRF	TMR1L		; limpio contadores del timer

	BANKSEL PIR1
	BCF	PIR1, TMR1IF	; bajo la bandera de interrupción
	BANKSEL PIE1
	BSF	PIE1, TMR1IE	; interrupciones por timer1 habilitadas

; Inicializacion de variables --------------------------------------

	CLRF	time_instant_counter

; Configuración de interrupciones ----------------------------------

	BSF	INTCON, PEIE
	BSF	INTCON, GIE

	GOTO	main

;
; Punto de entrada del programa, rutina principal
;

main: 	GOTO	main
	END
