
; TP Final - Electronica Digital 2

; Autores:
; 	Camila Abril Dei Rossi
; 	Martina Montovani Castiglia
; 	Valentino Gorordo
; 	Vicente Gauna

; Descripcion ======================================================================================================
;
; Codigo fuente para un generador de señales.
; ==================================================================================================================

	LIST p=16f887
	#include <p16f887.inc>

temp_w EQU 0x70
temp_status EQU 0x71
temp_pclath EQU 0x72
temp_fsr EQU 0x73

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
	MOVF	FSR, W
	MOVWF	temp_fsr
	MOVF	PCLATH, W
	MOVWF	temp_pclath		; guardo contexto

	CALL	display_int
	CALL	keyboard_int
	CALL	dac_int
	CALL	adc_int
;	CALL	com_int
	
	MOVF	temp_fsr, W
	MOVWF	FSR
	MOVF	temp_pclath, W
	MOVWF	PCLATH
	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W 		; recupero contexto
	
	RETFIE				; regreso de la interrupcion a la direccion del codigo que se estaba ejecutando

setup:
	;CALL 	keyboard_setup		
	;CALL 	display_setup		
	;CALL 	dac_setup		
	;CALL 	adc_setup		
	;CALL 	com_setup		

; Configuracion de interrupciones -----------------------------

        BSF     INTCON, PEIE
        BSF     INTCON, GIE

        BANKSEL ADCON0
        BSF     ADCON0, GO      ; inicio la conversion


loop:   ;CALL    keyboard_task
        ;CALL    com_task
        GOTO    loop

        #include "dac_module.asm"
        #include "adc_module.asm"
        #include "keyboard_module.asm"
        #include "display_module.asm"
        #include "com_module.asm"

        END
