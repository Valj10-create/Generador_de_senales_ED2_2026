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

LIST p=16f887
#include <p16f887.inc>

adc_head_ptr EQU 0x30
adc_head_base EQU 0x31
temp_w EQU 0x71
temp_status EQU 0x72

        __CONFIG _CONFIG1, _HS_OSC & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF
        __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

        ORG     0X00
        GOTO    setup

        ORG     0X04
        GOTO    int

        ORG     0X05

;
; Subrutina de interrupción
;

int:
	MOVWF	temp_w
	SWAPF	temp_w, F
	SWAPF	STATUS, W
	MOVWF	temp_status	; guardar contexto

	BANKSEL PIR1
	BTFSC	PIR1, ADIF	; interrupcion causada por adc?
	GOTO 	handle_adc	

	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W	; restablecer contexto

	RETFIE

;
; Manejo de interrupcion por ADC
;

handle_adc:
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

setup:

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
	
; Configuracion de interrupciones -----------------------------

	BSF	INTCON, PEIE	
	BSF	INTCON, GIE
	
	BANKSEL ADCON0
	BSF	ADCON0, GO 	; inicio la conversion
	
	GOTO	main

;
; Punto de entrada del programa, rutina principal
;

main:	
 	GOTO	main
	END
