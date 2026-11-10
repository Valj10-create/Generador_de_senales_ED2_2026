; TP Final - Electronica Digital 2 - COM Module
 
; Autores:
;	Camila Abril Dei Rossi
;	Martina Montovani Castiglia
;	Valentino Gorordo
;	Vicente Gauna

; Descripcion ================================================================================================
; 
; ============================================================================================================

	ORG	0X0700
;
; Subrutina de interrupción
;

com_int:

	BANKSEL PIR1
	BTFSC	PIR1, TXIF	; interrupcion por TX vacio?
	CALL	com_tx_handle	; si
	
	RETURN

;
; Manejador de evento de salida Tx vacía
;

com_tx_handle:

	BANKSEL PIE1
	BTFSS	PIE1, TXIE	; interrupcion habilitada?
	RETURN

	BANKSEL 0
	MOVF	DATAN, W
	BTFSC	STATUS, Z
	RETURN			; si datan dice que no hay datos no sigo

	BANKSEL 0
	BCF	STATUS, IRP	; direccionamiento indirecto en bancos 1 y 2
	
	MOVF	com_head_ptr, W
	ANDLW	b'00011111'	; limito la cuenta a 32
	ADDLW	data_reg_base	; sumo la direccion inicial del registro rotativo
	MOVWF	FSR
	
	BANKSEL TXREG

	MOVF	INDF, W		; muevo el dato actual apuntado
	MOVWF	TXREG		; al registro tx

	BANKSEL 0
	INCF	com_head_ptr, F ; incremento el apuntador
	DECFSZ	DATAN, F	; decremento la cuenta de datos por enviar
	RETURN

	BCF	EVENT, RDATA 	; bajo la bandera

	BANKSEL PIE1
	BCF	PIE1, TXIE	; deshabilito las interrupciones por TX

	RETURN

;
; Punto de entrada del programa, configuración
;

com_setup:

; Configuracion de puertos - ------------------------------------

	BANKSEL TRISC
	BSF	TRISC, 7
	BSF	TRISC, 6	; puertos como entrada

; Configuracion de baud rate ------------------------------------

	BANKSEL	BAUDCTL
	BSF	BAUDCTL, BRG16

	BANKSEL TXSTA	
	BSF	TXSTA, BRGH
	
	BANKSEL SPBRG 	
	CLRF	SPBRGH
	MOVLW	.51
	MOVWF	SPBRG 		; inicio el generador de baudios a 19231

; Configuracion de la transmision -------------------------------

	BANKSEL	TXSTA
	BSF	TXSTA, TXEN	; habilito TX
	BCF	TXSTA, SYNC	; comunicacion asincrona
	BCF	TXSTA, TX9	; no uso 9no bit
	
	BANKSEL RCSTA
	BSF	RCSTA, SPEN	; habilito puerto

	BANKSEL PIE1
	BCF	PIE1, TXIE 	; interrupciones por TX inicialmente deshabilitadas

; Inicializacion de variables --- -------------------------------

	BANKSEL 0
	CLRF	com_head_ptr

	RETURN
