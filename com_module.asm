; TP Final - Electronica Digital 2 - COM Module
 
; Autores:
;	Camila Abril Dei Rossi
;	Martina Montovani Castiglia
;	Valentino Gorordo
;	Vicente Gauna

; Descripcion ================================================================================================
; 
; ============================================================================================================

;
; Subrutina de interrupción
;

com_int:
	BANKSEL PIR1
	BTFSC	PIR1, TXIF
	CALL	com_tx_handle
	RETURN

;
; Manejador de evento de salida Tx vacía
;

com_tx_handle:
	BANKSEL PIE1
	BTFSC	PIE1, TXIE	; interrupcion habilitada?
	RETURN

	BTFSC	EVENT, DATA	; hay datos nuevos para transmitir?

	MOVF	com_head_ptr, W
	ANDLW	b'00011111'	; limito la cuenta a 32
	ADDWF	com_head_base	; sumo la direccion inicial del registro rotativo

	BANKSEL TXREG

	MOVF	INDF, W
	MOVWF	TXREG	

	BANKSEL 0
	INCF	com_head_ptr, F ; incremento el apuntador
	DECFSZ	DATAN		; decremento la cuenta de datos por enviar
	RETURN

	BCF	EVENT, DATA 	; bajo la bandera
	RETURN

;
; Punto de entrada del programa, configuración
;

com_setup:

; Configuracion de baud rate ------------------------------------

	BANKSEL	BAUDCTL
	BCF	BAUDCTL, BRG16

	BANKSEL TXSTA	
	BCF	TXSTA, BRGH
	
	BANKSEL SPBRG 	
	CLRF	SPBRGH
	MOVLW	.5
	MOVWF	SPBRG 		; inicio el generador de baudios a 10417

; Configuracion de la transmision -------------------------------

	BANKSEL	TXSTA
	BSF	TXSTA, TXEN	; habilito TX
	BCF	TXSTA, SYNC	; comunicacion asincrona
	BCF	TXSTA, TX9	; no uso 9no bit
	
	BANKSEL RCSTA
	BSF	RCSTA, SPEN	; habilito puerto

	BANKSEL PIE1
	BSF	PIE1, TXIE 	; habilito interrupciones por TX

	RETURN
