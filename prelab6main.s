/*	
    Archivo:		prelab6main.S
    Dispositivo:	PIC16F887
    Autor:		Jorge Cerón 20288
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		TMR1 y contador en PORTC con incrementos cada 1000mS
			
    Hardware:		2 Contadores 7 segmentos en puerto C

    Creado:			1/02/22
    Última modificación:	2/02/22	
*/
PROCESSOR 16F887
#include <xc.inc>

; configuracion 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscillador Interno sin salidas
  CONFIG  WDTE = OFF            // WDT (Watchdog Timer Enable bit) disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = ON            // PWRT enabled (Power-up Timer Enable bit) (espera de 72 ms al iniciar)
  CONFIG  MCLRE = OFF           // El pin de MCL se utiliza como I/O
  CONFIG  CP = OFF              // Sin proteccion de codigo
  CONFIG  CPD = OFF             // Sin proteccion de datos
  
  CONFIG  BOREN = OFF           // Sin reinicio cunado el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = ON              // programación en bajo voltaje permitida

; configuracion  2
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivada
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V = 2.1V)

PSECT udata_bank0
    MITADSEGUNDO:   DS 1
    SEGUNDOS:	    DS 1
    BANDERADISP:    DS 1
    NIBBLES:	    DS 2
    DISPLAY:	    DS 2
;----------------MACROS--------------- Macro para reiniciar el valor del Timer0
RESETTIMER0 MACRO
    BANKSEL TMR0	// Direccionamiento al banco 00
    MOVLW   250		// Cargar literal en el registro W
    MOVWF   TMR0	// Configuración completa para que tenga 1.5ms de retardo
    BCF	    T0IF	// Se limpia la bandera de interrupción
    
    ENDM

RESETTIMER1 MACRO TMR1_H, TMR1_L
    BANKSEL TMR1H	// Direccionamiento al banco
    MOVLW   TMR1_H	// Cargar literal en el registro W
    MOVWF   TMR1H	// Cargar literal en TMR1H
    MOVLW   TMR1_L	// Cargar literal en el registro W
    MOVWF   TMR1L	// Cargar literal en TMR1L
    // Configuración completa para que tenga 500ms de retardo
    BCF	    TMR1IF	// Se limpia la bandera de interrupción
    ENDM
    
; Status para interrupciones
PSECT udata_shr			// Variables globales en memoria compartida
    WTEMP:	    DS 1	// 1 byte
    STATUSTEMP:	    DS 1	// 1 byte
     
PSECT resVect, class=CODE, abs, delta=2
;----------------vector reset----------------
ORG 00h				// Posición 0000h para el reset
resVect:
    PAGESEL	main		//Cambio de página
    GOTO	main

;----------------vector interrupcion---------------
ORG 04h				// Posición 0004h para las interrupciones
PUSH:				
    MOVWF   WTEMP		// Se mueve W a la variable WTEMP
    SWAPF   STATUS, W		// Swap de nibbles del status y se almacena en W
    MOVWF   STATUSTEMP		// Se mueve W a la variable STATUSTEMP
ISR:				// Rutina de interrupción
    BTFSC   T0IF		// Analiza la bandera de cambio del TMR0 si esta encendida (si no lo está salta una linea)
    CALL    INT_TMR0		// Se llama la rutina de interrupción del TMR0
    
    BTFSC   TMR1IF		// Analiza la bandera de cambio del TMR1 si esta encendida (si no lo está salta una linea)
    CALL    INT_TMR1		// Se llama la rutina de interrupción del TMR1
POP:				// Intruccion movida de la pila al PC
    SWAPF   STATUSTEMP, W	// Swap de nibbles de la variable STATUSTEMP y se almacena en W
    MOVWF   STATUS		// Se mueve W a status
    SWAPF   WTEMP, F		// Swap de nibbles de la variable WTEMP y se almacena en WTEMP 
    SWAPF   WTEMP, W		// Swap de nibbles de la variable WTEMP y se almacena en w
    
    RETFIE

PSECT code, abs, delta=2   
;----------------configuracion----------------
ORG 100h
main:
    CALL    CONFIGIO	    // Se llama la rutina configuración de entradas y salidas
    CALL    CONFIGRELOJ	    // Se llama la rutina configuración del reloj
    CALL    CONFIGTIMER0    // Se llama la rutina configuración del TMR0
    CALL    CONFIGTMR1	    // Se llama la rutina configuración del TMR1
    CALL    CONFIGINTERRUP  // Se llama la rutina configuración de interrupciones
    BANKSEL PORTA
    
loop:
    CALL    OBTENER_NIBBLES // Se llama la rutina para guardar nibble alto y bajo de CONT1
    CALL    SET_DISPLAY	    // Se llama la rutina para guardar los valores a enviar en PORTC en hex
    GOTO    loop	    // Regresa a revisar
    
CONFIGIO:
    BANKSEL ANSEL	    // Direccionar al banco 11
    CLRF    ANSEL	    // I/O digitales
    CLRF    ANSELH	    // I/O digitales
    
    BANKSEL TRISA	    // Direccionar al banco 01
    CLRF    TRISC	    // PORTC como salida
    CLRF    TRISD	    // PORTD como salida
    
    BANKSEL PORTA	    // Direccionar al banco 00
    CLRF    PORTC	    // Se limpia PORTC
    CLRF    PORTD	    // Se limpia PORTD
    RETURN

INT_TMR0:
    RESETTIMER0			// Se reinicia TMR0 para 1.5ms  
    CALL    MOSTRAR_VALOR	// Se llama subrutina para la configuracion de encedido/apago de 7SEG
    
    RETURN
    
MOSTRAR_VALOR:
    BCF	    PORTD, 0		// Se limpia display de nibble alto
    BCF	    PORTD, 1		// Se limpia display de nibble bajo
    BTFSC   BANDERADISP, 0	// Se verifica bandera
    GOTO    DISPLAY_1	

DISPLAY_0:			
    MOVF    DISPLAY, W		// Se mueve display a W
    MOVWF   PORTC		// Se mueve valor de tabla a PORTC
    BSF	    PORTD, 1		// Se enciende display de nibble bajo
    BSF	    BANDERADISP, 0	// Cambio de bandera para cambiar el otro display en la siguiente interrupción
    
    RETURN

DISPLAY_1:
    MOVF    DISPLAY+1, W	// Se mueve display+1 a W
    MOVWF   PORTC		// Se mueve valor de tabla a PORTC
    BSF	    PORTD, 0		// Se enciende display de nibble alto
    BCF	    BANDERADISP, 0	// Cambio de bandera para cambiar el otro display en la siguiente interrupción
    
    RETURN

OBTENER_NIBBLES:			
    // Obtención de nibble bajo
    MOVLW   0x0F		// Se mueve valor 0000 1111 
    ANDWF   SEGUNDOS, W		// Solo se dejan pasar los primero 4 bits con AND
    MOVWF   NIBBLES		// Pasan los 4 bits anteriores a una nueva variable	
    // Obtención de nibble alto
    MOVLW   0xF0		// Se mueve valor 1111 0000
    ANDWF   SEGUNDOS, W		// Solo se dejan pasar los últimos 4 bits con AND
    MOVWF   NIBBLES+1		// Pasan los 4 bits anteriores aL 2do byte de la variable
    SWAPF   NIBBLES+1, F	// Se hace un swap de nibbles para que este, almacenado en los últimos 4 bits, pase a los primeros 4 bits
    RETURN
    
SET_DISPLAY:
    MOVF    NIBBLES, W		// Se mueve nibble bajo a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY		// Se guarda en nueva variable display
    
    MOVF    NIBBLES+1, W	// Se mueve nibble alto a W
    CALL    TABLA		// Se busca valor a cargar en PORTC
    MOVWF   DISPLAY+1		// Se guarda en variable display en el 2do byte
    RETURN

INT_TMR1:
    RESETTIMER1 0x0B, 0xDC
    INCF    MITADSEGUNDO	// Incrementa en 1 la variable MITADSEGUNDOS
    BTFSS   MITADSEGUNDO, 1	// Si el 2 bit de MITADSEGUNDOS es 1 saltar a la siguiente linea
    RETURN			// Si no es 1 regresar a interrupcion
    CLRF    MITADSEGUNDO	// Limpiar la variable usada para la repetición de 2 equivalente a 1 Seg
    INCF    SEGUNDOS		// Se incrementa en 1 la variable SEGUNDOS
    RETURN

CONFIGRELOJ:
    BANKSEL OSCCON	    // Direccionamiento al banco 01
    BSF	    OSCCON, 0	    // SCS en 1, se configura a reloj interno
    BSF	    OSCCON, 6	    // bit 6 en 1
    BSF	    OSCCON, 5	    // bit 5 en 1
    BCF	    OSCCON, 4	    // bit 4 en 0
    // Frecuencia interna del oscilador configurada a 4MHz
    RETURN
    
CONFIGTIMER0:
    BANKSEL OPTION_REG	// Direccionamiento al banco 01
    BCF OPTION_REG, 5	// TMR0 como temporizador
    BCF OPTION_REG, 3	// Prescaler a TMR0
    BSF OPTION_REG, 2	// bit 2 en 1
    BSF	OPTION_REG, 1	// bit 1 en 1
    BSF	OPTION_REG, 0	// bit 0 en 1
    // Prescaler en 256
    // Sabiendo que N = 256 - (T*Fosc)/(4*Ps) -> 256-(0.0015*4*10^6)/(4*256) = 250.14 (250 aprox)
    RESETTIMER0
    
    RETURN    

CONFIGTMR1:		    // Configuración de Timer1
    BANKSEL INTCON
    BCF	    TMR1CS	    // Se habilita reloj interno
    BCF	    T1OSCEN	    // Se apaga LP
    
    BSF	    T1CKPS1	    
    BSF	    T1CKPS0	  
    // Prescaler de 1:8
    BCF	    TMR1GE	    // TMR1 siempre esté contando
    BSF	    TMR1ON	    // Encendemos TMR1
    // Configuración de TMR1 cuenta 500 mS
    RESETTIMER1 0x0B, 0xDC
    RETURN
    
CONFIGINTERRUP:
    BANKSEL PIE1
    BSF	    TMR1IE	    // Habilita interrupciones del TMR1
    
    BANKSEL INTCON
    BSF	    GIE		    // Habilita interrupciones globales
    BSF	    PEIE	    // Habilita interrupciones de periféricos
    BSF	    T0IE	    // Habilita interrupciones de TMR0
    BCF	    T0IF	    // Se limpia la banderda de TMR0
    BCF	    TMR1IF	    // Se limpia la banderda de TMR1
    
    RETURN

ORG 200h
TABLA:
    CLRF    PCLATH	// Se limpia el registro PCLATH
    BSF	    PCLATH, 1	
    ANDLW   0x0F	// Solo deja pasar valores menores a 16
    ADDWF   PCL		// Se añade al PC el caracter en ASCII del contador
    RETLW   00111111B	// Return que devuelve una literal a la vez 0 en el contador de 7 segmentos
    RETLW   00000110B	// Return que devuelve una literal a la vez 1 en el contador de 7 segmentos
    RETLW   01011011B	// Return que devuelve una literal a la vez 2 en el contador de 7 segmentos
    RETLW   01001111B	// Return que devuelve una literal a la vez 3 en el contador de 7 segmentos
    RETLW   01100110B	// Return que devuelve una literal a la vez 4 en el contador de 7 segmentos
    RETLW   01101101B	// Return que devuelve una literal a la vez 5 en el contador de 7 segmentos
    RETLW   01111101B	// Return que devuelve una literal a la vez 6 en el contador de 7 segmentos
    RETLW   00000111B	// Return que devuelve una literal a la vez 7 en el contador de 7 segmentos
    RETLW   01111111B	// Return que devuelve una literal a la vez 8 en el contador de 7 segmentos
    RETLW   01101111B	// Return que devuelve una literal a la vez 9 en el contador de 7 segmentos
    RETLW   01110111B	// Return que devuelve una literal a la vez A en el contador de 7 segmentos
    RETLW   01111100B	// Return que devuelve una literal a la vez b en el contador de 7 segmentos
    RETLW   00111001B	// Return que devuelve una literal a la vez C en el contador de 7 segmentos
    RETLW   01011110B	// Return que devuelve una literal a la vez d en el contador de 7 segmentos
    RETLW   01111001B	// Return que devuelve una literal a la vez E en el contador de 7 segmentos
    RETLW   01110001B	// Return que devuelve una literal a la vez F en el contador de 7 segmentos
END