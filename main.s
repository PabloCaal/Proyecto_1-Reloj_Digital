    ; Archivo:	    main.s
    ; Proyecto:	    Reloj Digital
    ; Dispositivo:  PIC16F887
    ; Autor:	    Pablo Caal
    ; Compilador:   pic-as (v2.30), MPLABX V5.40
    ; Programa:	Reloj Digital con modo hora, fecha, temporizador y alarma
    ; Hardware:	PORTA: Salida para LED's indicadores del modo seleccionado del reloj
    ;		PORTB: Entrada digital para pulsadores a utilizar
    ;		PORTC: Salida de 8 bits conecatada a seis displays de 7 segmentos 
    ;		PORTD: Salida de 6 bits para seleccionar al display activo
    ; Creado: 04 mar, 2022
    ; Última modificación: 22 mar, 2022
    
    PROCESSOR 16F887
    #include <xc.inc>
    ; CONFIG1
	CONFIG  FOSC = INTRC_NOCLKOUT	; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
	CONFIG  WDTE = OFF		; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
	CONFIG  PWRTE = OFF		; Power-up Timer Enable bit (PWRT enabled)
	CONFIG  MCLRE = OFF		; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
	CONFIG  CP = OFF		; Code Protection bit (Program memory code protection is disabled)
	CONFIG  CPD = OFF		; Data Code Protection bit (Data memory code protection is disabled)
	CONFIG  BOREN = OFF		; Brown Out Reset Selection bits (BOR disabled)
	CONFIG  IESO = OFF		; Internal External Switchover bit (Internal/External Switchover mode is disabled)
	CONFIG  FCMEN = OFF		; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
	CONFIG  LVP = OFF		; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)
    ; CONFIG2
	CONFIG  BOR4V = BOR40V		; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
	CONFIG  WRT = OFF		; Flash Program Memory Self Write Enable bits (Write protection off)
	
    ;------------------------------- MACROS ------------------------------------
    ; MACRO PARA TIMER0
    RESET_TIMER0 MACRO VALOR_TIMER
	BANKSEL TMR0		    ; Direccionamiento de banco
	MOVLW   VALOR_TIMER	    ; Almacenamiento de literal en registro W
	MOVWF   TMR0		    ; Carga del valor del resgitro W al registro TMR0
	BCF	T0IF		    ; Limpieza de bandera
	ENDM
    ; MACRO PARA TIMER1
    RESET_TIMER1 MACRO TMR1_H, TMR1_L	 
	BANKSEL TMR1H		    ; Direccionamiento de banco
	MOVLW   TMR1_H		    ; Almacenamiento de primer literal en registro W 
	MOVWF   TMR1H		    ; Cargar el valor del resgitro W al registro TMR1H
	MOVLW   TMR1_L		    ; Almacenamiento de segundo literal en registro W 
	MOVWF   TMR1L		    ; Carga del valor del resgitro W al registro TMR1L
	BCF	TMR1IF		    ; Limpieza de bandera
	ENDM
    ; MACRO PARA ACCIONAR LOS DISPLAYS SEGUN MODO
    ACCION MACRO VALOR0, VALOR1, VALOR2, VALOR3, VALOR4, VALOR5
	MOVF	VALOR0, W	    ; Enviar VALOR0 a W (Correspondiente a primer display)
	MOVWF	VALOR		    ; Cargar W al byte 0 de la variable VALOR
	MOVF	VALOR1, W	    ; Enviar VALOR1 a W (Correspondiente a segundo display)
	MOVWF	VALOR+1		    ; Cargar W al byte 1 de la variable VALOR
	MOVF	VALOR2, W	    ; Enviar VALOR2 a W (Correspondiente a tercer display)
	MOVWF	VALOR+2		    ; Cargar W al byte 2 de la variable VALOR
	MOVF	VALOR3, W	    ; Enviar VALOR3 a W (Correspondiente a cuarto display)
	MOVWF	VALOR+3		    ; Cargar W al byte 3 de la variable VALOR
	MOVF	VALOR4, W	    ; Enviar VALOR4 a W (Correspondiente a quinto display)
	MOVWF	VALOR+4		    ; Cargar W al byte 4 de la variable VALOR
	MOVF	VALOR5, W	    ; Enviar VALOR5 a W (Correspondiente a sexto display)
	MOVWF	VALOR+5		    ; Cargar W al byte 5 de la variable VALOR
	ENDM
    ; MACRO PARA COLOCAR LOS VALORES INICIALES DE CADA MODO
    CARGAR_VALOR MACRO REGISTRO, VALOR
	MOVLW	VALOR		    ; Enviar literal a registro W
	MOVWF	REGISTRO	    ; Cargar valor de W al registro indicado
	ENDM
    ;------------------------- VALORES EN MEMORIA ------------------------------
    ; Variables de almacenamiento temporal de registros W y STATUS durante interrupciones
    PSECT udata_shr		    ; Memoria compartida
	W_TEMP:		DS 1	    ; Almacenamiento temporal del registro W
	STATUS_TEMP:	DS 1	    ; Almacenamiento temporal del registro STATUS
    ; Variables globales
    PSECT udata_bank0	    ; Memoria común
    ; Variables para configuración general
	BANDERA_D:	DS 1	    ; Bandera de selección de display
	DISPLAY:	DS 6	    ; Almacenamiento del valor en binario a mostrar en display
	VALOR:		DS 6	    ; Almacenamiento del valor en decimal a mostrar en display
	MODO:		DS 1	    ; Indicador del modo activo
	BANDERA_M:	DS 1	    ; Bandera de selección de acción en cada modo
	DISPLAY_EDIT:	DS 1	    ; Indicador de display en edición
    ; Variables para configurar los distintos modos
	CONT_HORA:	DS 6	    ; Almacenamiento del valor de la hora
	BANDERA_H:	DS 1	    ; Bandera para funciones de la hora
	CONT_FECHA:	DS 6	    ; Almacenamiento del valor de la fecha
	BANDERA_F:	DS 1	    ; Bandera para funciones de la fecha
	CONT_TEMP:	DS 6	    ; Almacenamiento del valor del temporizador
	BANDERA_T:	DS 1	    ; Bandera para funciones del temporizador
	DURACION:	DS 1
	CONT_CRONO:	DS 6	    ; Almacenamiento del valor de la cronómetro
	BANDERA_C:	DS 1	    ; Bandera para funciones de cronómetro
    ;-------------------------- VECTOR RESET -----------------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h			    ; Posición 0000h para el reset
    resetVec:
        PAGESEL main		    ; Cambio de pagina
        goto    main
    ;-------------------- SUBRUTINAS DE INTERRUPCION ---------------------------
    PSECT intVect, class=CODE, abs, delta=2
    ORG 04h			    ; Posición 0004h para las interrupciones
    PUSH:			
	MOVWF   W_TEMP		    ; Almacenamiento temporal del registro W
	SWAPF   STATUS, W	    ; SWAP de nibbles de registro STATUS y almacenamiento en W
	MOVWF   STATUS_TEMP	    ; Almacenamiento temporal del registro STATUS
    ISR:
	; Interrupción por TIMER0
	BTFSC	T0IF		    ; Verificación de interrupción en el TIMER0
	CALL	INT_TMR0	    ; Subrutina INT_TMR0
	; Interrupción por TIMER1
	BTFSC   TMR1IF		    ; Verificación de interrupción en el TIMER1
	CALL    INT_TMR1	    ; Subrutina INT_TMR1
	; Interrupción por TIMER2
	BTFSC   TMR2IF		    ; Verificación de interrupción en el TIMER2
	CALL    INT_TMR2	    ; Subrutina INT_TMR2
	; Interrupción por PORTB
	BTFSC   RBIF		    ; Verificación de interrupción por cambio de valor en PORTB
	CALL    INT_B		    ; Subrutina INT_B
    POP:				
	SWAPF   STATUS_TEMP, W	    ; SWAP de nibbles del valor temporal del registro STATUS
	MOVWF   STATUS		    ; Recuperación del valor temporal almacenado para el registro STATUS
	SWAPF   W_TEMP, F	    ; SWAP de nibbles del valor temporal del registro W
	SWAPF   W_TEMP, W	    ; SWAP de nibbles y recuperación del valor temporal del registro W
	RETFIE
	
    ;------------------------ RUTINAS PRINCIPALES ------------------------------
    PSECT code, delta=2, abs
    ORG 100h	; posición 100h para el codigo
    main:		
	CALL	CONFIG_IO	    ; Configuración de puertos	
	CALL	CONFIG_CLK	    ; Configuración de oscilador	
	CALL	CONIFG_INTERRUPT    ; Configuración de interrupciones	
	CALL	CONFIG_INT_PORTB    ; Configuración de interrupción en PORTB (Verificar utilidad)
	CALL	CONFIG_TIMER0	    ; Configuración de TMR0
	CALL	CONFIG_TIMER1	    ; Configuración de TMR1
	CALL	CONFIG_TIMER2	    ; Configuración de TMR2
	BANKSEL PORTA		    ; Direccionamiento de banco
	CALL	LIMPIEZADEVARIABLES ; Subrutina para la limpieza de variables
	BSF	MODO, 0		    ; Activación de bit 0 (Inicio de modo reloj automático)
	CALL	INT_B		    ; Iniciación de reloj en modo HORA
	BCF	PORTA, 5
	; CONFIGURACIÓN DE VALORES INICIALES A LOS CONTADORES
	CARGAR_VALOR   CONT_HORA, 0
	CARGAR_VALOR   CONT_HORA+1, 0
	CARGAR_VALOR   CONT_HORA+2, 0
	CARGAR_VALOR   CONT_HORA+3, 0
	CARGAR_VALOR   CONT_HORA+4, 0
	CARGAR_VALOR   CONT_HORA+5, 0
	CARGAR_VALOR   CONT_FECHA, 0
	CARGAR_VALOR   CONT_FECHA+1, 0
	CARGAR_VALOR   CONT_FECHA+2, 0
	CARGAR_VALOR   CONT_FECHA+3, 0
	CARGAR_VALOR   CONT_FECHA+4, 0
	CARGAR_VALOR   CONT_FECHA+5, 0
	CARGAR_VALOR   CONT_TEMP, 0
	CARGAR_VALOR   CONT_TEMP+1, 0
	CARGAR_VALOR   CONT_TEMP+2, 0
	CARGAR_VALOR   CONT_TEMP+3, 0
	CARGAR_VALOR   CONT_TEMP+4, 0
	CARGAR_VALOR   CONT_TEMP+5, 0
	CARGAR_VALOR   CONT_CRONO, 0
	CARGAR_VALOR   CONT_CRONO+1, 0
	CARGAR_VALOR   CONT_CRONO+2, 0
	CARGAR_VALOR   CONT_CRONO+3, 0
	CARGAR_VALOR   CONT_CRONO+4, 0
	CARGAR_VALOR   CONT_CRONO+5, 0

    loop:
	; Verificación de bandera de modo
	BTFSC   BANDERA_M, 0	    ; Verificación de bit 0 de BANDERA_M (Modo hora)
	CALL	ACCION_HORA	    ; Subrutina para accionar el modo hora
	BTFSC   BANDERA_M, 1	    ; Verificación de bit 1 de BANDERA_M (Modo fecha)
	CALL	ACCION_FECHA	    ; Subrutina para accionar el modo fecha
	BTFSC   BANDERA_M, 2	    ; Verificación de bit 2 de BANDERA_M (Modo temporizador)
	CALL	ACCION_TEMPORIZADOR ; Subrutina para accionar el modo temporizador
	BTFSC   BANDERA_M, 3	    ; Verificación de bit 3 de BANDERA_M (Modo cronómetro)
	CALL	ACCION_CRONOMETRO   ; Subrutina para accionar el modo cronómetro
	CALL	DIVISION_CRONOMETRO ; Subrutina de divisiones del modo cronómetro
	; INSTRUCCIONES PARA LA CONFIGURACIÓN DEL MODO HORA
	BTFSC   BANDERA_M, 4	    ; Verificación de bit 4 de BANDERA_M (Modo hora)
	GOTO	$+3
	CALL	DIVISION_HORA	    ; Subrutina de divisiones del modo hora
	GOTO	$+3
	CALL	EDICION_RELOJ
	CALL	ACCION_HORA	    ; Subrutina para accionar el modo hora
	; INSTRUCCIONES PARA LA CONFIGURACIÓN DEL MODO FECHA
	BTFSC   BANDERA_M, 5	    ; Verificamos bandera 4
	GOTO	$+3
	CALL	DIVISION_FECHA	    ; Subrutina de divisiones del modo fecha
	GOTO	$+3
	CALL	EDICION_FECHA
	CALL	ACCION_FECHA	    ; Subrutina para accionar el modo fecha
	; INSTRUCCIONES PARA LA CONFIGURACIÓN DEL MODO TEMPORIZADOR
	BTFSC   BANDERA_M, 6	    ; Verificamos bandera 4
	GOTO	$+3
	CALL	DIVISION_TEMPORIZADOR	; Subrutina de divisiones del modo temporizador
	GOTO	$+3
	CALL	EDICION_TEMPORIZADOR
	CALL	ACCION_TEMPORIZADOR ; Subrutina para accionar el modo temporizador
	CALL	PREPARAR	    ; Subrutina que prepara los valores a mostrar en los displays
	GOTO	loop		    ; Direccionar de nuevo al loop (ciclo infinito)
	
    ;------------------ SUBRUTINAS DE ACCIONES DE MODOS ------------------------
    ACCION_HORA:
	ACCION	CONT_HORA, CONT_HORA+1, CONT_HORA+2, CONT_HORA+3, CONT_HORA+4, CONT_HORA+5
    RETURN
    ACCION_FECHA:
	ACCION	CONT_FECHA, CONT_FECHA+1, CONT_FECHA+2, CONT_FECHA+3, CONT_FECHA+4, CONT_FECHA+5
    RETURN
    ACCION_TEMPORIZADOR:
	ACCION	CONT_TEMP, CONT_TEMP+1, CONT_TEMP+2, CONT_TEMP+3, CONT_TEMP+4, CONT_TEMP+5
    RETURN
    ACCION_CRONOMETRO:
	ACCION CONT_CRONO, CONT_CRONO+1, CONT_CRONO+2, CONT_CRONO+3, CONT_CRONO+4, CONT_CRONO+5
    RETURN
    ;--------------------- SUBRUTINAS DE FSM DE MODOS --------------------------
    MODO_HORA:			
	BTFSC   PORTB, 4	    ; ANTIREBOTE - BOTÓN 4 - CAMBIO DE MODO
	GOTO	$+3
	BSF	MODO, 1			; Activar bit de MODO_FECHA
	BCF	MODO, 0			; Desactivar bit de MODO_HORA
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - EDICIÓN 
	GOTO	$+4
	BSF	MODO, 4			; Activar bit de MODO_CONFIGURAR_HORA
	BCF	MODO, 0			; Desactivar bit de MODO_HORA
	BSF	DISPLAY_EDIT, 0		; Activar bit 0 del registro indicador de display a editar
	BCF	RBIF			; Limpieza de la bandera de interrupción	
	CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 0		; Activación del bit 0 del registro BANDERA_M
	BSF	PORTA, 0		; Encender bit 0 del PORTA (Salida de LEDS)
	BCF	PORTA, 1		; Apagar bit 1 del PORTA (Salida de LEDS)
	BCF	PORTA, 2		; Apagar bit 2 del PORTA (Salida de LEDS)
	BCF	PORTA, 3		; Apagar bit 3 del PORTA (Salida de LEDS)
	BCF	PORTA, 4		; Apagar bit 4 del PORTA (Salida de LEDS)
    RETURN
    MODO_FECHA:
	BTFSC   PORTB, 4	    ; ANTIREBOTE - BOTÓN 4 - CAMBIO DE MODO
	GOTO	$+3
	BSF	MODO, 2			; Activar bit de MODO_FECHA
	BCF	MODO, 1			; Desactivar bit de MODO_HORA
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - EDICIÓN 
	GOTO	$+4
	BSF	MODO, 5			; Activar bit de MODO_CONFIGURAR_FECHA
	BCF	MODO, 1			; Desactivar bit de MODO_FECHA
	BSF	DISPLAY_EDIT, 0
	BCF	RBIF			; Limpiamos bandera de interrupción
	CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 1		; Activación del bit 1 del registro BANDERA_M
	BCF	PORTA, 0		; Apagar bit 0 del PORTA (Salida de LEDS)
	BSF	PORTA, 1		; Encender bit 1 del PORTA (Salida de LEDS)
	BCF	PORTA, 2		; Apagar bit 2 del PORTA (Salida de LEDS)
	BCF	PORTA, 3		; Apagar bit 3 del PORTA (Salida de LEDS)
	BCF	PORTA, 4		; Apagar bit 4 del PORTA (Salida de LEDS)
    RETURN
    
    MODO_TEMPORIZADOR:
	BTFSC   PORTB, 4	    ; ANTIREBOTE - BOTÓN 4 - CAMBIO DE MODO
	GOTO	$+3
	BSF	MODO, 3			; Activar bit de MODO_ALARMA
	BCF	MODO, 2			; Desactivar bit de MODO_TEMPORIZADOR
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - EDICIÓN 
	GOTO	$+6
	BTFSC	BANDERA_T, 5
	GOTO	$+4
	BSF	MODO, 6			; Activar bit de MODO_CONFIGURAR_TEMPORIZADOR
	BCF	MODO, 2			; Desactivar bit de MODO_TEMPORIZADOR	
	BSF	DISPLAY_EDIT, 0
	
	BTFSC   PORTB, 3	    ; ANTIREBOTE - BOTÓN 2 - INICIAR/DETENER
	GOTO	$+6
	BTFSC	BANDERA_T, 5	    ; Verificar bandera de habilitación de decremento
	GOTO	$+3
	BSF	BANDERA_T, 5	    ; Habilitar decremento
	GOTO	$+2
	BCF	BANDERA_T, 5	    ; Deshabilitar decremento
	
	BTFSC   PORTB, 0	    ; ANTIREBOTE - BOTÓN 0 - DETENER ALARMA
	GOTO	$+7
	BTFSS	BANDERA_T, 6	    ; Verificar bandera de habilitación de decremento
	GOTO	$+5
	BCF	BANDERA_T, 6
	BCF	PORTA, 5
	MOVLW	0
	MOVWF	DURACION
	
	BCF	RBIF			; Limpiamos bandera de interrupción
	CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 2		; Activación del bit 2 del registro BANDERA_M
	BCF	PORTA, 0		; Apagar bit 0 del PORTA (Salida de LEDS)
	BCF	PORTA, 1		; Apagar bit 1 del PORTA (Salida de LEDS)
	BSF	PORTA, 2		; Encender bit 2 del PORTA (Salida de LEDS)
	BCF	PORTA, 3		; Apagar bit 3 del PORTA (Salida de LEDS)
	BCF	PORTA, 4		; Apagar bit 4 del PORTA (Salida de LEDS)
    RETURN
    MODO_CRONOMETRO:
	BTFSC   PORTB, 4	    ; ANTIREBOTE - BOTÓN 4 - CAMBIO DE MODO
	GOTO	$+3
	BSF	MODO, 0			; Activar bit de MODO_HORA
	BCF	MODO, 3			; Desactivar bit de MODO_CRONOMETRO
	BTFSC   PORTB, 3		; Verificación del bit 3 del PORTB (Boton de inicio)
	GOTO	$+6
	BTFSC	BANDERA_C, 0
	GOTO	$+3
	BSF	BANDERA_C, 0
	GOTO	$+2
	BCF	BANDERA_C, 0	
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - REINICIO
	GOTO	$+10
	BTFSC	BANDERA_C, 0
	GOTO	$+8
	MOVLW	0
	MOVWF	CONT_CRONO	; Limpieza del contador del cronómetro
	MOVWF   CONT_CRONO+1
	MOVWF   CONT_CRONO+2
	MOVWF   CONT_CRONO+3
	MOVWF   CONT_CRONO+4
	MOVWF   CONT_CRONO+5
	BCF	RBIF			; Limpiamos bandera de interrupción
	CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 3		; Activación del bit 4 del registro BANDERA_M
	BCF	PORTA, 0		; Apagar bit 0 del PORTA (Salida de LEDS)
	BCF	PORTA, 1		; Apagar bit 1 del PORTA (Salida de LEDS)
	BCF	PORTA, 2		; Apagar bit 2 del PORTA (Salida de LEDS)
	BSF	PORTA, 3		; Apagar bit 3 del PORTA (Salida de LEDS)
	BCF	PORTA, 4		; Apagar bit 4 del PORTA (Salida de LEDS)
    RETURN
    
    MODO_CONFIGURACION_HORA:
	BTFSC   PORTB, 0	    ; ANTIREBOTE - BOTÓN 0 - UP 
	GOTO	$+2
	BSF	BANDERA_H, 0
	BTFSC   PORTB, 1	    ; ANTIREBOTE - BOTÓN 1 - DOWN 
	GOTO	$+2
	BSF	BANDERA_H, 1
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - ACEPTAR 
	GOTO	$+2
	INCF	DISPLAY_EDIT
	BCF	RBIF			; Limpiamos bandera de interrupción	
        CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 4		; Activación del bit 5 del registro BANDERA_M
	BSF	PORTA, 4		; Encender bit 5 del PORTA (Salida de LEDS)
    RETURN
    
    MODO_CONFIGURACION_FECHA:
	BTFSC   PORTB, 0	    ; ANTIREBOTE - BOTÓN 0 - UP 
	GOTO	$+2
	BSF	BANDERA_F, 0
	BTFSC   PORTB, 1	    ; ANTIREBOTE - BOTÓN 1 - DOWN 
	GOTO	$+2
	BSF	BANDERA_F, 1
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - ACEPTAR
	GOTO	$+2
	INCF	DISPLAY_EDIT
	BCF	RBIF			; Limpiamos bandera de interrupción	
        CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 5		; Activación del bit 6 del registro BANDERA_M
	BSF	PORTA, 4		; Encender bit 5 del PORTA (Salida de LEDS)
    RETURN
    
    MODO_CONFIGURACION_TEMPORIZADOR:
	BTFSC   PORTB, 0	    ; ANTIREBOTE - BOTÓN 0 - UP 
	GOTO	$+2
	BSF	BANDERA_T, 0
	BTFSC   PORTB, 1	    ; ANTIREBOTE - BOTÓN 1 - DOWN 
	GOTO	$+2
	BSF	BANDERA_T, 1
	BTFSC   PORTB, 2	    ; ANTIREBOTE - BOTÓN 2 - ACEPTAR 
	GOTO	$+2
	INCF	DISPLAY_EDIT
	BCF	RBIF			; Limpiamos bandera de interrupción	
        CLRF	BANDERA_M		; Limpieza del registro BANDERA_M
	BSF	BANDERA_M, 6		; Activación del bit 7 del registro BANDERA_M
	BSF	PORTA, 4		; Encender bit 5 del PORTA (Salida de LEDS)
    RETURN
    
    ;--------------------- SUBRUTINAS DE INTERRUPCIONES ------------------------
    INT_TMR0:			    ; SUBRUTINA DE INTERRUPCIÓN DEL TIMER0
	RESET_TIMER0 254	    ; Ingreso a Macro con valor 254 para configurar retardo de 2 ms
	CALL	MOSTRAR		    ; Subrutina que muestra los valores en los displays (cada 2 ms)
	RETURN
	
    INT_TMR1:			    ; SUBRUTINA DE INTERRUPCIÓN DEL TIMER1
	BTFSS   BANDERA_M, 4	    ; Verificación de bandera de modo CONFIGURAR_HORA
	INCF	CONT_HORA	    ; Incremento del contador hora (cada 1s)
	BTFSC   BANDERA_T, 5	    ; Verificación de bandera de modo TEMPORIZADOR
	DECF	CONT_TEMP	    ; Decremento del contador temporizador (cada 1s)
	BTFSC	BANDERA_C, 0	    ; Verificación de bandera de modo CRONOMETRO
	INCF	CONT_CRONO	    ; Incremento del contador cronómetro (cada 1s)
	
	BTFSS   BANDERA_T, 6	    ; Verificación de bandera de modo TEMPORIZADOR
	GOTO	$+7
	BSF	PORTA, 5
	INCF	DURACION
	BCF	ZERO
	MOVLW	61
	SUBWF	DURACION, W
	BTFSS	ZERO
	GOTO	$+5
	BCF	BANDERA_T, 6
	BCF	PORTA, 5
	MOVLW	0
	MOVWF	DURACION
	
	
	RESET_TIMER1 0xC2, 0xF7	    ; Macro para configurar el TIMER1 (Retardo cada segundo)
	RETURN
	
    INT_TMR2:			    ; SUBRUTINA DE INTERRUPCIÓN DEL TIMER2
	BCF	TMR2IF		    ; Limpieza de la bandera de TMR2
	BTFSC	PORTA, 6	    ; Verificación de bit 6 del PORTA
	GOTO	$+3
	BSF	PORTA, 6	    ; Activación de bit 6 del PORTA
	GOTO	$+2
	BCF	PORTA, 6	    ; Desactivación de bit 6 del PORTA
	RETURN
	
    INT_B:			    ; SUBRUTINA DE INTERRUPCIÓN POR CAMBIO DEL PORTB
	BTFSC   MODO, 0				    ; Verificar indicador de MODO HORA
	GOTO    MODO_HORA			    ; Direccionamiento
	BTFSC   MODO, 1				    ; Verificar indicador de MODO FECHA
	GOTO    MODO_FECHA			    ; Direccionamiento
	BTFSC   MODO, 2				    ; Verificar indicador de MODO TEMPORIZADOR
	GOTO    MODO_TEMPORIZADOR		    ; Direccionamiento
	BTFSC   MODO, 3				    ; Verificar indicador de MODO CONFIGURACIÓN HORA
	GOTO    MODO_CRONOMETRO			    ; Direccionamiento
	BTFSC   MODO, 4				    ; Verificar indicador de MODO CONFIGURACIÓN HORA
	GOTO    MODO_CONFIGURACION_HORA		    ; Direccionamiento
	BTFSC   MODO, 5				    ; Verificar indicador de MODO CONFIGURACIÓN FECHA
	GOTO    MODO_CONFIGURACION_FECHA	    ; Direccionamiento
	BTFSC   MODO, 6				    ; Verificar indicador de MODO CONFIGURACIÓN TEMPORIZADOR
	GOTO    MODO_CONFIGURACION_TEMPORIZADOR	    ; Direccionamiento
	BCF	RBIF				    ; Limpiar la bandera de cambio del PORTB
	RETURN	 
	
    ;---------------- SUBRUTINAS DE CONFIGURACIÓN DE DIPLAYS -------------------
    EDICION_RELOJ:
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	1		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_H, 0	    ; Control de overflow en segundos
	INCF	CONT_HORA
	CALL	OVERFLOW_SEGUNDOS
	BCF	BANDERA_H, 0	    
	BTFSC	BANDERA_H, 1	    ; Control de underflow en segundos
	DECF	CONT_HORA
	CALL	UNDERFLOW_SEGUNDOS
	BCF	BANDERA_H, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	2		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO   
	GOTO	$+9
	BTFSC	BANDERA_H, 0	    ; Control de overflow en minutos
	INCF	CONT_HORA+2
	CALL	OVERFLOW_MINUTOS
	BCF	BANDERA_H, 0
	BTFSC	BANDERA_H, 1	    ; Control de underflow en minutos
	DECF	CONT_HORA+2
	CALL	UNDERFLOW_MINUTOS
	BCF	BANDERA_H, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	3		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO  
	GOTO	$+9
	BTFSC	BANDERA_H, 0	    ; Control de overflow en horas
	INCF	CONT_HORA+4
	CALL	OVERFLOW_HORAS
	BCF	BANDERA_H, 0
	BTFSC	BANDERA_H, 1	    ; Control de undeflow en horas
	DECF	CONT_HORA+4
	CALL	UNDERFLOW_HORAS
	BCF	BANDERA_H, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	4		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+4
	BSF	MODO, 0		    ; Activar bit de MODO_HORA
	BCF	MODO, 4		    ; Desactivar bit de MODO_CONFIGURACION_HORA
	CLRF	DISPLAY_EDIT
	RETURN

    EDICION_FECHA:
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	1		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_F, 0	    ; Control de overflow en años
	INCF	CONT_FECHA
	CALL	OVERFLOW_ANUAL
	BCF	BANDERA_F, 0
	BTFSC	BANDERA_F, 1	    ; Control de underflow en años
	DECF	CONT_FECHA
	CALL	UNDERFLOW_ANUAL
	BCF	BANDERA_F, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	2		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_F, 0	    ; Control de overflow en meses
	INCF	CONT_FECHA+2
	CALL	OVERFLOW_MESES	    
	BCF	BANDERA_F, 0
	BTFSC	BANDERA_F, 1	    ; Control de underflow en meses
	DECF	CONT_FECHA+2
	CALL	UNDERFLOW_MESES
	BCF	BANDERA_F, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	3		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_F, 0	    ; Control de overflow en días
	INCF	CONT_FECHA+4
	CALL	OVERFLOW_DIAS
	BCF	BANDERA_F, 0
	BTFSC	BANDERA_F, 1	    ; Control de underflow en días
	DECF	CONT_FECHA+4
	CALL	UNDERFLOW_DIAS
	BCF	BANDERA_F, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	4		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+4
	BSF	MODO, 1		    ; Activar bit de MODO_FECHA
	BCF	MODO, 5		    ; Desactivar bit de MODO_CONFIGURACION_FECHA
	CLRF	DISPLAY_EDIT
	RETURN
	
    EDICION_TEMPORIZADOR:
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	1		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_T, 0	    ; Control de overflow en segundos para temporizador
	INCF	CONT_TEMP
	CALL	OVERFLOW_SEGUNDOS_T
	BCF	BANDERA_T, 0
	BTFSC	BANDERA_T, 1	    ; Control de underflow en segundos para temporizador
	DECF	CONT_TEMP
	CALL	UNDERFLOW_SEGUNDOS_T
	BCF	BANDERA_T, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	2		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_T, 0	    ; Control de overflow en minutos para temporizador
	INCF	CONT_TEMP+2
	CALL	OVERFLOW_MINUTOS_T
	BCF	BANDERA_T, 0
	BTFSC	BANDERA_T, 1	    ; Control de underflow en minutos para temporizador
	DECF	CONT_TEMP+2
	CALL	UNDERFLOW_MINUTOS_T
	BCF	BANDERA_T, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	3		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+9
	BTFSC	BANDERA_T, 0	    ; Control de overflow en horas para temporizador
	INCF	CONT_TEMP+4
	CALL	OVERFLOW_HORAS_T
	BCF	BANDERA_T, 0
	BTFSC	BANDERA_T, 1	    ; Control de undeflow en horas para temporizador
	DECF	CONT_TEMP+4
	CALL	UNDERFLOW_HORAS_T
	BCF	BANDERA_T, 1
	
	BCF	ZERO		    ; Reseteo de bandera ZERO
	MOVLW	4		    ; Verificación de indicador de display
	SUBWF	DISPLAY_EDIT, W	    ;
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+4
	BSF	MODO, 2		    ; Activar bit de MODO_TEMPORIZADOR
	BCF	MODO, 6		    ; Desactivar bit de MODO_CONFIGURACION_TEMPORIZADOR
	CLRF	DISPLAY_EDIT
	RETURN
	
    DIVISION_HORA:		    ; Subrutina de control de overlflow en conteo de modo HORA
	CALL	OVERFLOW_SEGUNDOS
	CALL	OVERFLOW_MINUTOS
	CALL	OVERFLOW_HORAS
	RETURN
    DIVISION_FECHA:		    ; Subrutina de control de overlflow en conteo de modo FECHA
	CALL	OVERFLOW_DIAS
	CALL	OVERFLOW_MESES
	CALL	OVERFLOW_ANUAL
	RETURN    	
    DIVISION_CRONOMETRO:	    ; Subrutina de control de overlflow en conteo de modo CRONOMETRO
	CALL	OVERFLOW_SEGUNDOS_C
	CALL	OVERFLOW_MINUTOS_C
	CALL	OVERFLOW_HORAS_C
	RETURN
    DIVISION_TEMPORIZADOR:	    ; Subrutina de control de underflow  en conteo de modo TEMPORIZADOR
	CALL	UNDERFLOW_SEGUNDOS_T
	CALL	UNDERFLOW_MINUTOS_T
	CALL	UNDERFLOW_HORAS_T
	RETURN
	
    OVERFLOW_DIAS:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+3
	INCF	CONT_FECHA+5	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	; SI ES FEBRERO (28 DÍAS)
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	2		    ; Colocar el valor de 2 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	2		    ; Colocar el valor de 2 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	9		    ; Colocar el valor de 9 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+7
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	CLRF	CONT_FECHA+5
	INCF	CONT_FECHA+4	    ; Incrementar variable de decenas de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA+2	    
	RETURN
	
	; SI ES ABRIL, JUNIO, SEPTIEMBRE O NOVIEMBRE (30 DÍAS)
	; ABRIL
	BCF	ZERO
	MOVLW	4		    ; Colocar el valor de 4 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	3		    ; Colocar el valor de 3 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+7
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	CLRF	CONT_FECHA+5
	INCF	CONT_FECHA+4	    ; Incrementar variable de decenas de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA+2	    ; Incrementar variable de decenas de segundos
	RETURN
	; JUNIO
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar 
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	3		    ; Colocar el valor de 3 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+7
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	CLRF	CONT_FECHA+5
	INCF	CONT_FECHA+4	    ; Incrementar variable de decenas de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA+2	    ; Incrementar variable de decenas de segundos
	RETURN
	; SEPTIEMBRE
	BCF	ZERO
	MOVLW	9		    ; Colocar el valor de 9 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	3		    ; Colocar el valor de 3 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar 
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+7
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	CLRF	CONT_FECHA+5
	INCF	CONT_FECHA+4	    ; Incrementar variable de decenas de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA+2	    ; Incrementar variable de decenas de segundos
	RETURN
	;NOVIEMBRE
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	3		    ; Colocar el valor de 3 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+7
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	CLRF	CONT_FECHA+5
	INCF	CONT_FECHA+4	    ; Incrementar variable de decenas de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA+2	    ; Incrementar variable de decenas de segundos
	RETURN
	; SI ES CUALQUIER OTRO MES (31 DÍAS)
	BCF	ZERO
	MOVLW	3		    ; Colocar el valor de 3 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	2		    ; Colocar el valor de 2 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	RETURN
	CLRF	CONT_FECHA+4	    ; Reiniciar variable de unidades de segundos
	CLRF	CONT_FECHA+5
	INCF	CONT_FECHA+4	    ; Incrementar variable de decenas de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA+2	    ; Incrementar variable de decenas de segundos
	RETURN
	
    UNDERFLOW_DIAS:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+4
	DECF	CONT_FECHA+5	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_FECHA+4
	
	; OVERFLOW DECENAS
	; SI ES FEBRERO (28 DÍAS)
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	2		    ; Colocar el valor de 2 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+6
	MOVLW	2
	MOVWF	CONT_FECHA+5
	MOVLW	8
	MOVWF	CONT_FECHA+4
	RETURN
	; SI ES ABRIL, JUNIO, SEPTIEMBRE O NOVIEMBRE (30 DÍAS)
	; ABRIL
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	4		    ; Colocar el valor de 4 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+6
	MOVLW	3
	MOVWF	CONT_FECHA+5
	MOVLW	0
	MOVWF	CONT_FECHA+4
	RETURN
	; JUNIO
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar 
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+6
	MOVLW	3
	MOVWF	CONT_FECHA+5
	MOVLW	0
	MOVWF	CONT_FECHA+4
	RETURN
	; SEPTIEMBRE
	BCF	ZERO
	MOVLW	9		    ; Colocar el valor de 9 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar 
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+6
	MOVLW	3
	MOVWF	CONT_FECHA+5
	MOVLW	0
	MOVWF	CONT_FECHA+4
	RETURN
	;NOVIEMBRE
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+6
	MOVLW	3
	MOVWF	CONT_FECHA+5
	MOVLW	0
	MOVWF	CONT_FECHA+4
	RETURN
	; SI ES CUALQUIER OTRO MES (31 DÍAS)
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	MOVLW	3
	MOVWF	CONT_FECHA+5
	MOVLW	1
	MOVWF	CONT_FECHA+4
	RETURN
	
    UNDERFLOW_MESES:
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+4
	DECF	CONT_FECHA+3	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_FECHA+2
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	1
	MOVWF	CONT_FECHA+3	
	MOVLW	2
	MOVWF	CONT_FECHA+2
	RETURN
	
    UNDERFLOW_ANUAL:
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_FECHA, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	DECF	CONT_FECHA+1	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_FECHA
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_FECHA+1, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	9
	MOVWF	CONT_FECHA+1	
	RETURN
	RETURN
	
    OVERFLOW_MESES:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+3
	INCF	CONT_FECHA+3	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_FECHA+2	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	1		    ; Colocar el valor de 1 en W
	SUBWF	CONT_FECHA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	BCF	ZERO
	MOVLW	3		    ; Colocar el valor de 3 en W
	SUBWF	CONT_FECHA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_FECHA+2	    ; Reiniciar variable de unidades de segundos
	BSF	CONT_FECHA+2, 0
	CLRF	CONT_FECHA+3	    ; Reiniciar variable de unidades de segundos
	BTFSS	BANDERA_M, 5
	INCF	CONT_FECHA	    ; Incrementar variable de decenas de segundos
	RETURN

    OVERFLOW_ANUAL:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_FECHA, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_FECHA+1	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_FECHA	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_FECHA+1, W	    ; Restar a contador para verficar 
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_FECHA+1	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_FECHA	    ; Reiniciar variable de unidades de segundos
	RETURN

    ; CONFIGURACIÓN DE DISPLAYS DEL RELOJ
    OVERFLOW_SEGUNDOS:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_HORA, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_HORA+1	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_HORA	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_HORA+1, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_HORA+1	    ; Reiniciar variable de unidades de segundos
	BTFSS   BANDERA_M, 4	    ; Verificamos bandera 4
	INCF	CONT_HORA+2	    ; Incrementar variable de decenas de segundos
	RETURN

    UNDERFLOW_SEGUNDOS:    
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_HORA, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	DECF	CONT_HORA+1	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_HORA
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_HORA+1, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	5
	MOVWF	CONT_HORA+1	
	RETURN
	
    OVERFLOW_MINUTOS:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_HORA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_HORA+3	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_HORA+2	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_HORA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_HORA+3	    ; Reiniciar variable de unidades de segundos
	BTFSS   BANDERA_M, 4	    ; Verificamos bandera 4
	INCF	CONT_HORA+4	    ; Incrementar variable de decenas de segundos
	RETURN

    UNDERFLOW_MINUTOS:    
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_HORA+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	DECF	CONT_HORA+3	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_HORA+2
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_HORA+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	5
	MOVWF	CONT_HORA+3	
	RETURN
	
    OVERFLOW_HORAS:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_HORA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+3
	INCF	CONT_HORA+5	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_HORA+4	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	2		    ; Colocar el valor de 2 en W
	SUBWF	CONT_HORA+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	BCF	ZERO
	MOVLW	4		    ; Colocar el valor de 4 en W
	SUBWF	CONT_HORA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_HORA+4
	CLRF	CONT_HORA+5	    ; Reiniciar variable de unidades de segundos
	BTFSS   BANDERA_M, 4	    ; Verificamos bandera 4
	INCF	CONT_FECHA+4
	RETURN

    UNDERFLOW_HORAS:    
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_HORA+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	0		    ; Colocar el valor de 0 en W
	SUBWF	CONT_HORA+5, W	    ; Restar a contador para verficar
	BTFSC	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+5
	MOVLW	9
	MOVWF	CONT_HORA+4
	DECF	CONT_HORA+5
	return	
	MOVLW	3
	MOVWF	CONT_HORA+4
	MOVLW	2
	MOVWF	CONT_HORA+5	
	RETURN
	
    ; CONFIGURACIÓN DE DISPLAYS DEL TEMPORIZADOR
    OVERFLOW_SEGUNDOS_T:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_TEMP, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_TEMP+1	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_TEMP	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_TEMP+1, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_TEMP+1	    ; Reiniciar variable de unidades de segundos
	RETURN

    UNDERFLOW_SEGUNDOS_T:    
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_TEMP, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	DECF	CONT_TEMP+1	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_TEMP
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_TEMP+1, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	5
	MOVWF	CONT_TEMP+1
	BTFSS   BANDERA_M, 6	    ; Verificamos bandera 4
	DECF	CONT_TEMP+2	    ; Incrementar variable de decenas de segundos
	RETURN
	
    OVERFLOW_MINUTOS_T:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_TEMP+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_TEMP+3	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_TEMP+2	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_TEMP+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_TEMP+3	    ; Reiniciar variable de unidades de segundos
	RETURN

    UNDERFLOW_MINUTOS_T:    
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_TEMP+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	DECF	CONT_TEMP+3	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_TEMP+2
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_TEMP+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	5
	MOVWF	CONT_TEMP+3
	BTFSS   BANDERA_M, 6	    ; Verificamos bandera 4
	DECF	CONT_TEMP+4	    ; Incrementar variable de decenas de segundos
	RETURN
	
    OVERFLOW_HORAS_T:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_TEMP+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_TEMP+5	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_TEMP+4	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 6 en W
	SUBWF	CONT_TEMP+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_TEMP+5	    ; Reiniciar variable de unidades de segundos
	RETURN
	
    UNDERFLOW_HORAS_T:    
	; UNDERFLOW UNIDADES	
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_TEMP+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	DECF	CONT_TEMP+5	    ; Incrementar variable de decenas de segundos
	MOVLW	9
	MOVWF	CONT_TEMP+4
	; UNDERFLOW DECENAS
	BCF	ZERO
	MOVLW	-1		    ; Colocar el valor de -1 en W
	SUBWF	CONT_TEMP+5, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	MOVLW	9
	MOVWF	CONT_TEMP+5
	BTFSC   BANDERA_M, 6	    ; Verificamos bandera 6
	GOTO	$+10
	BCF	BANDERA_T, 5
	INCF	CONT_TEMP
	CALL	OVERFLOW_SEGUNDOS_T
	INCF	CONT_TEMP+2
	CALL	OVERFLOW_MINUTOS_T
	INCF	CONT_TEMP+4
	CALL	OVERFLOW_HORAS_T
	BSF	BANDERA_T, 6
	BCF	BANDERA_T, 5
	RETURN
	
    OVERFLOW_SEGUNDOS_C:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_CRONO, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_CRONO+1	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_CRONO	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_CRONO+1, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_CRONO+1	    ; Reiniciar variable de unidades de segundos
	INCF	CONT_CRONO+2	    ; Incrementar variable de decenas de segundos
	RETURN
	
    OVERFLOW_MINUTOS_C:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_CRONO+2, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	INCF	CONT_CRONO+3	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_CRONO+2	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	6		    ; Colocar el valor de 6 en W
	SUBWF	CONT_CRONO+3, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_CRONO+3	    ; Reiniciar variable de unidades de segundos
	INCF	CONT_CRONO+4	    ; Incrementar variable de decenas de segundos
	RETURN
	
    OVERFLOW_HORAS_C:
	; OVERFLOW UNIDADES
	BCF	ZERO
	MOVLW	10		    ; Colocar el valor de 10 en W
	SUBWF	CONT_CRONO+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	GOTO	$+3
	INCF	CONT_CRONO+5	    ; Incrementar variable de decenas de segundos
	CLRF	CONT_CRONO+4	    ; Reiniciar variable de unidades de segundos
	; OVERFLOW DECENAS
	BCF	ZERO
	MOVLW	2		    ; Colocar el valor de 2 en W
	SUBWF	CONT_CRONO+5, W	    ;; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	BCF	ZERO
	MOVLW	4		    ; Colocar el valor de 4 en W
	SUBWF	CONT_CRONO+4, W	    ; Restar a contador para verficar
	BTFSS	ZERO		    ; Verificar bandera de ZERO
	return
	CLRF	CONT_CRONO+4
	CLRF	CONT_CRONO+5	    ; Reiniciar variable de unidades de segundos
	RETURN
	
    PREPARAR:
	MOVF    VALOR, W	    ; Colocamos el valor de NIBBLES (posición 0) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY		    ; Guardamos en variable DISPLAY
	MOVF    VALOR+1, W	    ; Colocamos el valor de NIBBLES (posición 1) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+1	    ; Guardamos en variable DISPLAY+1
	MOVF    VALOR+2, W	    ; Colocamos el valor de NIBBLES (posición 0) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+2	    ; Guardamos en variable DISPLAY2
	MOVF    VALOR+3, W	    ; Colocamos el valor de NIBBLES (posición 1 en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+3	    ; Guardamos en variable DISPLAY2+1
	MOVF    VALOR+4, W	    ; Colocamos el valor de NIBBLES (posición 0) en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+4	    ; Guardamos en variable DISPLAY2
	MOVF    VALOR+5, W	    ; Colocamos el valor de NIBBLES (posición 1 en W
	CALL    TABLA		    ; Transformamos el valor a enviar a display
	MOVWF   DISPLAY+5	    ; Guardamos en variable DISPLAY2+1
	RETURN
	
    MOSTRAR:
	CLRF	PORTD
	; Lógica de condicionales para verificar que display encender cada 2 ms
	BTFSC   BANDERA_D, 0	    ; Verificamos bandera 2
	GOTO    DISPLAY_0
	BTFSC   BANDERA_D, 1	    ; Verificamos bandera 1
	GOTO    DISPLAY_1
	BTFSC   BANDERA_D, 2	    ; Verificamos bandera 2
	GOTO    DISPLAY_2
	BTFSC   BANDERA_D, 3	    ; Verificamos bandera 3
	GOTO    DISPLAY_3
	BTFSC   BANDERA_D, 4	    ; Verificamos bandera 4
	GOTO    DISPLAY_4
	BTFSC   BANDERA_D, 5	    ; Verificamos bandera 5
	GOTO    DISPLAY_5
	DISPLAY_0:			
	    MOVF    DISPLAY, W	    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C
	    BSF	    PORTD, 0	    ; Activamos el primer display
	    BCF	    BANDERA_D, 0	    
	    BSF	    BANDERA_D, 1	    
	RETURN
	DISPLAY_1:
	    MOVF    DISPLAY+1, W    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto C
	    BSF	    PORTD, 1	    ; Activamos el segundo display
	    BCF	    BANDERA_D, 1	    
	    BSF	    BANDERA_D, 2	    
	RETURN
	DISPLAY_2:			
	    MOVF    DISPLAY+2, W    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 2	    ; Activamos el primer display
	    BCF	    BANDERA_D, 2	    
	    BSF	    BANDERA_D, 3	    
	RETURN
	DISPLAY_3:
	    MOVF    DISPLAY+3, W    ; Colocamos el valor de variable DISPLAY en W
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 3	    ; Activamos el segundo display
	    BCF	    BANDERA_D, 3	    
	    BSF	    BANDERA_D, 4	    
	RETURN
	DISPLAY_4:			
	    MOVF    DISPLAY+4, W    ; Colocamos el valor de variable DISPLAY en W
	    ;XORLW   0xFF
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 4	    ; Activamos el primer display
	    BCF	    BANDERA_D, 4	    
	    BSF	    BANDERA_D, 5	    
	RETURN
	DISPLAY_5:
	    MOVF    DISPLAY+5, W    ; Colocamos el valor de variable DISPLAY en W
	    ;XORLW   0xFF
	    MOVWF   PORTC	    ; Colocamos el valor de W en Puerto D
	    BSF	    PORTD, 5	    ; Activamos el segundo display
	    BCF	    BANDERA_D, 5	    
	    BSF	    BANDERA_D, 0	    
	RETURN
		
    ;--------------------- SUBRUTINAS DE CONFIGURACIÓN -------------------------
    CONFIG_TIMER0:
	BANKSEL OPTION_REG	    ; Redireccionamos de banco
	BCF	T0CS		    ; Configuramos al timer0 como temporizador
	BCF	PSA		    ; Configurar el Prescaler para el timer0 (No para el Wathcdog timer)
	BSF	PS2
	BSF	PS1
	BCF	PS0		    ; PS<2:0> -> 110 (Prescaler 1:128)
	; Cálculo del valor a ingresar al TIMER1 para que tenga retardo de 1.5 ms
	; N = 256 - (Temp/(4 x Tosc x Presc))
	; N = 256 - (2 ms/(4 x (1/500 kHz) x 128))
	; N = 254
	RESET_TIMER0 254	    ; Reiniciamos la bandera interrupción
	RETURN

    CONFIG_TIMER1:
	BANKSEL T1CON		    ; Direccionamos al banco correcto
	BCF	TMR1CS		    ; Activamos el uso de reloj interno
	BCF	T1OSCEN		    ; Apagamos LP
	BSF	T1CKPS1		    ; Prescaler 1:8
	BSF	T1CKPS0
	BCF	TMR1GE		    ; Mantenemos al TMR1 siempre contando
	BSF	TMR1ON		    ; Activamos al TMR1
	; Cálculo del valor a ingresar al TIMER1 para que tenga retardo de 1 s
	; N = 65536 - (Td/(Pre x Ti))
	; N = 65536 - ((1)/(8 x (1/(500 kHz)/4)))
	; N = 49911
	; TMR1H: 11000010 = 0xC2
	; TMR1L: 11110111 = 0xF7
	RESET_TIMER1 0xC2, 0xF7	    ; Macro para configurar el TIMER1
	RETURN
	
    CONFIG_TIMER2:
    	BANKSEL T2CON		    ; Direccionamos al banco correcto
	BSF	T2CKPS1		    ; Prescaler 1:16
	BSF	T2CKPS0
	BSF	TOUTPS3		    ; Postscaler 1:16
	BSF	TOUTPS2
	BSF	TOUTPS1
	BSF	TOUTPS0
	BSF	TMR2ON		    ; Activamos al TMR1
	; Cálculo del valor a ingresar al TIMER2 para que tenga retardo de 500 ms
	; PR2 = (Ttmr2)/(Pres*Postc*(4/Fosc))
	; PR2 = (0.5)/(16*16*(4/500*10^3))
	; PR2 = 244
	BANKSEL PR2		    ; Direccionamos al banco correcto
	MOVLW   244		    ; Valor necesario para retardo de 500 ms
	MOVWF   PR2		    ; Cargamos litaral al bit PR2
	RETURN
	
    CONFIG_CLK:			    ; Rutina de configuración de oscilador
	BANKSEL OSCCON	    
	BSF	OSCCON, 0
	BSF	OSCCON, 4
	BSF	OSCCON, 5
	BCF	OSCCON, 6	    ; Oscilador con reloj de 500 kHz
	RETURN
	
    CONFIG_INT_PORTB:
	BANKSEL	INTCON
	BSF	RBIE		    ; 
	BCF	RBIF		    ; Limpieza de la bandera de interrupción por cambio RBIF
	BANKSEL IOCB		
	BSF	IOCB0		    ; Habilitamos int. por cambio de estado en RB0
	BSF	IOCB1		    ; Habilitamos int. por cambio de estado en RB1
	BSF	IOCB2		    ; Habilitamos int. por cambio de estado en RB2
	BSF	IOCB3		    ; Habilitamos int. por cambio de estado en RB3
	BSF	IOCB4		    ; Habilitamos int. por cambio de estado en RB4
	BSF	IOCB5		    ; Habilitamos int. por cambio de estado en RB4
	RETURN
	
    CONIFG_INTERRUPT:
	BANKSEL	INTCON		    ; Redireccionamos de banco
	BSF	GIE		    ; Habilitamos a todas las interrupciones
	BSF	PEIE		    ; Habilitamos interrupciones en periféricos
	BSF	T0IE		    ; Habilitamos la interrupción del TMR0
	BCF	T0IF		    ; Limpieza de la bandera de TMR0
	BANKSEL PIE1		    ; Redireccionamos de banco
	BSF	TMR1IE		    ; Habilitamos la interrupción del TMR1
	BSF	TMR2IE		    ; Habilitamos la interrupción del TMR2
	BANKSEL	PIR1
	BCF	TMR1IF		    ; Limpieza de la bandera de TMR1
	BCF	TMR2IF		    ; Limpieza de la bandera de TMR2
	RETURN
	
    CONFIG_IO:
	BANKSEL ANSEL		    ; Direccionamos de banco
	CLRF    ANSEL		    ; Configurar como digitales
	CLRF    ANSELH		    ; Configurar como digitales
	BANKSEL TRISA		    ; Direccionamos de banco
	CLRF	TRISA		    ; Habilitamos al PORTA como salida
	CLRF	TRISC		    ; Habilitamos al PORTC como salida
	CLRF	TRISD
	MOVLW	0xFF
	MOVWF	TRISB
	BCF	OPTION_REG, 7	    ; Habilitar las resistencias pull-up (RPBU)
	BSF	WPUB, 0		    ; Habilita el registro de pull-up en RB0 
	BSF	WPUB, 1		    ; Habilita el registro de pull-up en RB1
	BSF	WPUB, 2		    ; Habilita el registro de pull-up en RB2 
	BSF	WPUB, 3		    ; Habilita el registro de pull-up en RB3
	BSF	WPUB, 4		    ; Habilita el registro de pull-up en RB4
	BSF	WPUB, 5		    ; Habilita el registro de pull-up en RB4
	BANKSEL PORTA		    ; Direccionar de banco
	CLRF    PORTA		    ; Limpieza de PORTA
	CLRF	PORTB		    ; Limpieza de PORTB
	CLRF	PORTC		    ; Limpieza de PORTC
	CLRF	PORTD		    ; Limpieza de PORTD
	RETURN
    
    LIMPIEZADEVARIABLES:
	CLRF	BANDERA_D
	CLRF	DISPLAY
	CLRF	MODO
	CLRF	BANDERA_M
	CLRF	DISPLAY_EDIT
	CLRF	BANDERA_H
	CLRF	BANDERA_F
	CLRF	BANDERA_T
	MOVLW	0
	MOVWF	DURACION
	CLRF	BANDERA_C
	RETURN
    ;------------------------------- TABLAS ------------------------------------
    ORG 50h
    TABLA:
	ANDLW   0x0F		; Limitar saltos a tamaño de la tabla
	ADDWF   PCL		; Apuntamos el PC a caracter en ASCII de CONT
	RETLW   00111111B	; 0
	RETLW   00000110B	; 1
	RETLW   01011011B	; 2
	RETLW   01001111B	; 3
	RETLW   01100110B	; 4
	RETLW   01101101B	; 5
	RETLW   01111101B	; 6
	RETLW   00000111B	; 7
	RETLW   01111111B	; 8
	RETLW   01101111B	; 9
	RETLW   01110111B	; A
	RETLW   01111100B	; b
	RETLW   00111001B	; C
	RETLW   01011110B	; d
	RETLW   01111001B	; E
	RETLW   01110001B	; F
    END