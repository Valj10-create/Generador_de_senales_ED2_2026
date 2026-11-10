; TP Final - Electronica Digital 2 - ADC Module
 
; Autores:
;	Camila Abril Dei Rossi
;	Martina Montovani Castiglia
;	Valentino Gorordo
;	Vicente Gauna

; Descripcion ================================================================================================
; 
; Modulo ADC para el generador de señales. Toma una señal analogica en la entrada por pin AN6. La muestrea
; según 2 veces la frecuencia maxima que podemos mostrar (por teorema de Nyquist) y escribe el resultado a
; un registro comun.
; La amplitud de la señal esta dada por V_DD. Se usa un cristal externo oscilador de 4MHz.
; El muestreo del ADC es controlado por interrupciones por Timer2, el ultimo timer disponible del chip.
; Usamos una frcuencia de muestreo que corresponde al doble de frecuencia de la señal mayor, por teorema
; de Nyquist. Por lo tanto necesitamos una frecuencia de muestreo de 1kHz, equivalente a muestrear cada 
; 1ms. Configuramos Timer2 con prescaler 1:4, periodo 250 y postcaler 1:1. 1000 instrucciones en total,
; que con Fosc/4, Fosc=4Mhz equivalen a 1ms.
; ============================================================================================================

	ORG 0X0600
;
; Subrutina de interrupción
;

adc_int:
	BANKSEL PIR1
	BTFSC	PIR1, ADIF	; interrupcion causada por adc?
	GOTO 	adc_handle	

	BTFSC	PIR1, TMR2IF	; interrupcion causada por timer?
	GOTO	timer_handle	;
	
	RETURN

;
; Manejo de interrupcion por ADC
;

adc_handle:

	BANKSEL PIE1
	BTFSS	PIE1, ADIE	; interrupcion por ADC habilitada ?
	RETURN

	BANKSEL PIR1
	BCF	PIR1, ADIF	; bajo la bandera

	BANKSEL ADRESH
	BCF	STATUS, IRP	; direccionamiento indirecto en bancos 0 y 1

	BTFSC	DATAN, 5	; si el 5to bit esta set, hay mas de 32 valores, hubo overflow
	RETURN
		
	MOVF	adc_head_ptr, W
	ANDLW	b'00011111'	; tomo los primeros 32 valores
	ADDLW	data_reg_base	; sumo el contador a la direccion base del registro
	MOVWF	FSR		; muevo el valor para direccionamiento indirecto
	MOVF	ADRESH, W	; tomo los 8 bits mas significativos de la conversion
	MOVWF	INDF		; escribo el valor de la conversion en el buffer rotativo
	INCF	adc_head_ptr, F	; incremento el apuntador del buffer
	INCF	DATAN, F 	; incremento la cuenta de datos disponibles
	
	BANKSEL 0
	BSF	EVENT, RDATA	; datos disponibles

	
	RETURN

timer_handle:
	BANKSEL PIE1
	BTFSS	PIE1, TMR2IE	; las interrupciones estaban habilitadas?
	RETURN			; no, ignoro

	BANKSEL PIR1
	BCF	PIR1, TMR2IF	; bajo la bandera
	
	BANKSEL ADCON0
	BSF	ADCON0, GO	; leo el proximo valor

	RETURN
;
; Punto de entrada del programa, configuración
;

adc_setup:

; Configuracion de puertos ----------------------------------

	BANKSEL ANSEL
	MOVLW	b'01000000'	; configuro puerto AN6 como analogico
	MOVWF	ANSEL

	BANKSEL TRISE
	BSF	TRISE, 1	; puerto RE1 (compartido con AN6 como entrada)
		
; Configuracion del Timer2 ----------------------------------

	BANKSEL	T2CON
	BCF	T2CON, TOUTPS3
	BCF	T2CON, TOUTPS2
	BCF	T2CON, TOUTPS1
	BCF	T2CON, TOUTPS0	; postcaler 1:1
	BCF	T2CON, TMR2ON	; apagoo el timer	
	BCF	T2CON, T2CKPS1
	BSF	T2CON, T2CKPS0	; [01] prescaler 1:4

	BANKSEL PR2
	MOVLW	.249
	MOVWF	PR2		; seteo el periodo del timer a 250
	
	BANKSEL PIE1
	BSF	PIE1, TMR2IE	; habilito interrupciones por timer2

	BANKSEL PIR1
	BCF	PIR1, TMR2IF	; bajo la bandera

; Configuracion del ADC -------------------------------------

	BANKSEL ADCON1

	BCF	ADCON1, ADFM		; formateo de salida, justifico a la izquierda en ADRESH
	BCF	ADCON1, VCFG1		; referencia negativa en V_ss
	BCF	ADCON1, VCFG0		; referencia positiva en V_dd

	BANKSEL ADCON0

	BCF	ADCON0, CHS3
	BSF	ADCON0, CHS2
	BSF	ADCON0, CHS1
	BCF	ADCON0, CHS0		; [0110] selecciono canal analógico 6

	BSF	ADCON0, ADCS1
	BCF	ADCON0, ADCS0		; [10] Fosc/32 que me da 4us TAD

	BSF	ADCON0, ADON		; enciendo el ADC
	
	BANKSEL PIR1
	BCF	PIR1, ADIF	; bajo la bandera del ADC

	BANKSEL PIE1
	BSF	PIE1, ADIE	; activo interrupciones por ADC

; Inicializacion de variables ---------------------------------
	BANKSEL 0
	CLRF	adc_head_ptr 	; el contador para el apuntador arranca en 0
	CLRF	DATAN
	BCF	EVENT, RDATA	
	RETURN

adc_begin:
	BANKSEL ADCON0
	BSF	ADCON0, GO 	; inicio conversiones por adc

	BANKSEL T2CON
	BSF	T2CON, TMR2ON	; inicio timer

	BANKSEL PIR1
	BCF	PIR1, ADIF	; bajo la bandera del adc
	BCF	PIR1, TMR2IF	; bajo la bandera del timer

	RETURN
