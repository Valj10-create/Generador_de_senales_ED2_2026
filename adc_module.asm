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
; La amplitud de la señal esta dada por un medio externo que se indica en el pin V_ref+ para tener en
; cuenta a la hora de la conversión. Se usa un cristal externo oscilador de 8MHz.
; ============================================================================================================

;
; Subrutina de interrupción
;

adc_int:
	BANKSEL PIR1
	BTFSC	PIR1, ADIF	; interrupcion causada por adc?
	GOTO 	adc_handle	

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
	
	MOVF	adc_head_ptr, W
	ANDLW	b'00011111'	; tomo los primeros 32 valores
	ADDWF	adc_head_base, W	; sumo el contador a la direccion base del registro
	MOVWF	FSR		; muevo el valor para direccionamiento indirecto
	MOVF	ADRESH, W	; tomo los 8 bits mas significativos de la conversion
	MOVWF	INDF		; escribo el valor de la conversion en el buffer rotativo
	INCF	adc_head_ptr, F	; incremento el apuntador del buffer
	
	; escribir el resultado de la conversion a un buffer rotativo de x cantidad de bytes

	RETURN

;
; Punto de entrada del programa, configuración
;

adc_setup:

; Configuracion de puertos ----------------------------------

	BANKSEL ANSEL
	MOVLW	b'01000000'	; configuro puerto AN6 como analogico
	MOVWF	ANSEL

	BANKSEL TRISA
	MOVLW	b'00000010'	; puerto RE1 (compartido con AN6 como entrada)
	
; Configuracion del ADC -------------------------------------

	BANKSEL ADCON1

	BCF	ADCON1, ADFM		; formateo de salida, justifico a la izquierda en ADRESH
	BCF	ADCON1, VCFG1		; referencia negativa en V_ss
	BSF	ADCON1, VCFG0		; referencia positiva externa en pin V_ref+

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

	BANKSEL ANSEL		; se encuentran en el mismo banco que el registro ansel por practicidad
	
	MOVLW	0X40
	MOVWF	adc_head_base	; define el registro inicial de un buffer rotativo de 32 bytes

	CLRF	adc_head_ptr 	; el contador para el apuntador arranca en 0
	
	RETURN
