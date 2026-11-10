	LIST p=16f887
	#include <p16f887.inc>
	#include "regdef.asm"
	
	__CONFIG _CONFIG1, _XT_OSC & _WDT_OFF & _PWRTE_OFF & _CP_OFF & _CPD_OFF & _BOR_ON & _LVP_OFF	
	__CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF
	
	ORG	0X0000
	GOTO	setup

	ORG	0X0004
int:	
	MOVWF	temp_w
	SWAPF	temp_w, F 		
	SWAPF	STATUS, W 		
	MOVWF	temp_status		
	MOVF	FSR, W
	MOVWF	temp_fsr
	MOVF	PCLATH, W
	MOVWF	temp_pclath		; guardo contexto

	CALL	com_int

	MOVF	temp_fsr, W
	MOVWF	FSR
	MOVF	temp_pclath, W
	MOVWF	PCLATH
	SWAPF	temp_status, W
	MOVWF	STATUS
	SWAPF	temp_w, W 		; recupero contexto
	
	RETFIE				; regreso de la interrupcion a la direccion del codigo que se estaba ejecutando


	ORG	0X0100
	
setup:

	CALL 	com_setup		

; Configuracion de interrupciones -----------------------------


	CLRF	temp_work_f
	BCF	STATUS, IRP
	
loop:	
	INCF	temp_work_f, F
	MOVF	temp_work_f, W
	ADDLW	data_reg_base
	MOVWF	FSR
	MOVWF	INDF
	BTFSS	temp_work_f, 5
	GOTO	loop

	BANKSEL 0
	MOVLW	.32
	MOVWF	DATAN
	BSF	EVENT, RDATA

	BANKSEL PIE1
	BSF	PIE1, TXIE

	BSF	INTCON, PEIE
        BSF     INTCON, GIE
	
sgen_loop:
	GOTO 	sgen_loop

        #include "com_module.asm"

        END













