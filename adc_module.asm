; TP Final - Electronica Digital 2 - ADC Module
 
; Autores:
;	Camila Abril Dei Rossi
;	Martina Montovani Castiglia
;	Valentino Gorordo
;	Vicente Gauna

; Descripcion ================================================================================================
; 
; 
; ============================================================================================================

LIST p=16f887
#include <p16f887.inc>

temp_w EQU 0x71
temp_status EQU 0x72

        __CONFIG _CONFIG1, _XT_OSC & _WDT_OFF & _PWRTE_OFF & _MCLR_ON & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF
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
	SWAPF	temp_w
	SWAPF	STATUS, W
	MOVWF	temp_status	; guardar contexto

	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W	; restablecer contexto

	RETLW

;
; Punto de entrada del programa, configuración
;

setup:	GOTO	main

;
; Punto de entrada del programa, rutina principal
;

main: 	GOTO	main
