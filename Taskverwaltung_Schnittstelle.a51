$NOMOD51
#include<REG517a.inc>


	
	PUBLIC ConsolenProzess
	PUBLIC pruefeEmpfangenC
	EXTRN DATA (mystack)
	EXTRN DATA (prozessA)
	EXTRN DATA (prozessB)
	EXTRN DATA (prozessConsole)
	


;CodeSegment beginnt
codeSegment SEGMENT CODE
RSEG codeSegment
start:
CALL schnittstelle


JMP start
;Serielle Schnittstelle
schnittstelle:



;Einstellungen für serielle Schnittstelle
; CLR SM0
; SETB SM1
; SETB BD
; SETB REN0



Consolenprozess:
;Stackpointer auf Consolenbereich setzten
MOV SP, #mystack+4
;wechsle zu Registerbank 1 für Consolenprozess
CLR RS1
SETB RS0

;Einstellungen für Timer
SETB EAL
; SETB ET0
; Modus 1 für 16 Bit Zählmodus (somit Softwarezähler maximal 30)
ORL TMOD, #00000001b


pruefeEmpfangenC:
JBC RI0, leseEmpfangen
SETB WDT
SETB SWDT
JMP pruefeEmpfangenC


leseempfangen:
MOV A, S0BUF
CJNE A, #0x61, notA
JMP startA

notA:
CJNE A, #0x62, notB
JMP stopA

notB:
CJNE A, #0x63, pruefeEmpfangenC
JMP startB

startA:
	;Initialisierung des Datenbereichs
	MOV SP, #mystack+9
	;wechsle zu Registerbank2 für Prozess A
	SETB RS1
	CLR RS0
	;setze A in Prozesstabelle auf aktiv
	MOV prozessA+3, #0xFF
	
	senden:
	MOV S0BUF, #0x61
	JMP pruefeGesendetA
	
	;Zeitscheiben Interrupt ausstelen, damit a gesendet werden kann
	CLR ET1
	pruefeGesendetA:
		JBC TI0, timerStarten
		SETB WDT
		SETB SWDT
		JMP pruefeGesendetA

	;Timer starten
	timerStarten:
	SETB ET1
	;R1 zurücksetzten damit Timerschleife richtig
	SETB TR0
	MOV R1, #0
	MOV TH0, #0x00
	
	counting:
	JBC TF0, setSoftwarezaehler
	SETB WDT
	SETB SWDT
	JMP counting
	
	
	setSoftwarezaehler:
	CLR TF0
	MOV TH0, #00000000b
	MOV TL0, #0
	
	INC R1
	CJNE R1, #30, counting
	
	JMP senden
	
	
	;JMP pruefeEmpfangen

stopA:
	CLR	TR0
	MOV prozessA+3, #0

startB:
	;Setze Stackpointer auf Stackbereich von B
	MOV SP, #mystack+14
	SETB RS0
	SETB RS1
	MOV prozessB+3, #0xFF
	;Timer starten
	;Initialisierung des Datenbereichs
	MOV R0, #5
	schleife:
	MOV A, R0
	ADD A, #48
	MOV S0BUF, A
	pruefeGesendetB:
		JBC TI0, sendeNaechsteTeil
		SETB WDT
		SETB SWDT
		JMP pruefeGesendetB
		
	sendeNaechsteTeil:	
		DJNZ R0, schleife
		
	pruefeEmpfangenB:
	JBC RI0, leseEmpfangen
	SETB WDT
	SETB SWDT
	JMP pruefeEmpfangenB	
	MOV prozessB+3, #0	
	
	;Prozess B fertig, wechsle zu scheduler um nächsten Prozess auszuwählen
	
	



JMP start
END