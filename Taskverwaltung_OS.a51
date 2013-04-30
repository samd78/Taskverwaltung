$NOMOD51
#include<REG517a.inc>

EXTRN CODE (ConsolenProzess)
EXTRN CODE (pruefeEmpfangenC)
PUBLIC mystack
PUBLIC prozessA
PUBLIC prozessB
PUBLIC prozessConsole
PUBLIC Timerinterrupt




;Datenbereich für Tabelleneinträge
	Speichertabelle 		SEGMENT DATA
							RSEG Speichertabelle
	;für Register 10 Byte reservieren
	data_scheduler:			DS 10
	data_ProzessConsole: 	DS 10
	data_ProzessA: 			DS 10
	data_ProzessB: 			DS 10
	
	
	Prozesstabelle  		SEGMENT DATA
							RSEG Prozesstabelle
	;Byte 1 für hat gerade CPU
	;Byte 2 Zeitscheibe L
	;Byte 3 Zeitscheibe H
	;Byte 4 gerade aktiv
	prozessConsole:			DS 5
	prozessA:				DS 5
	prozessB:				DS 5


;Stack festlegen

DSEG AT 0x21	
mystack:
;5 pro Prozess (Scheduler, Console, A, B)
DS 20

;mystack SEGMENT DATA
;		RSEG mystack
;		org 0x21
;		DS 20

;Interruptroutine an die richtige Stelle legen
CSEG
ORG 0x1B
JMP Timerinterrupt

;CodeSegment beginnt
ORG 0
LJMP startOS


Main 		SEGMENT CODE
			RSEG Main
startOS:
MOV SP, #mystack-1


;Einstellungen für serielle Schnittstelle
CLR SM0
SETB SM1
SETB BD
SETB REN0

;Einstellungen für Timer
SETB EAL
SETB ET1
ORL TMOD, #00000001b
MOV TH1, #0
MOV TL1, #0


;Timerstart
SETB TR1

;Speichern der Prozessumgebung
;Reihenfolge: A, PSW, DPH, DPL, SP, B
MOV data_scheduler, A
MOV data_scheduler+1, PSW
MOV data_scheduler+2, DPH
MOV data_scheduler+3, DPL
MOV data_scheduler+4, SP
MOV data_scheduler+5, B

;Initialisierung Prozesstabelle
	;ConsolenProzess
	MOV	prozessConsole, #0xFF
	MOV prozessConsole+1, #0
	MOV prozessConsole+2,#0
	MOV prozessConsole+3, #0xFF
	;ProzessA
	MOV	prozessA, #0x00
	MOV prozessA+1, #10
	MOV prozessA+2,#0
	MOV prozessA+3, #0
	;ProzessB
	MOV	prozessB, #0x00
	MOV prozessB+1, #100
	MOV prozessB+2,#0
	MOV prozessB+3, #0

;Aufruf von Consolenprozess
JMP Consolenprozess
JMP startOS

	

Timerinterrupt:
	;Umschalten auf Bank 0 für Scheduler
	CLR RS1
	CLR RS0
	;Sichern
	;Wenn Console unterbrochen und B aktiv, B nächster Prozess sonst A, wenn beide nicht Console
	;Wenn A unterbrochen und B aktiv, B nächster Prozess sonst Console
	;Wenn B unterbrochen und A aktiv, A nächster Prozess sonst Console
		;Herausfinden des Prozesses der die CPU hat
		MOV A, prozessConsole
		CJNE A, #0xFF, AhatCPU
		
		;ConsolenProzess hatte CPU
		;Umgebung sichern
		MOV data_ProzessConsole, A
		MOV data_ProzessConsole+1, PSW
		MOV data_ProzessConsole+2, DPH
		MOV data_ProzessConsole+3, DPL
		MOV data_ProzessConsole+4, SP
		MOV data_ProzessConsole+5, B
		;Byte für hat gerade CPU zurücksetzten
		MOV prozessConsole, #0
		MOV R0, ProzessB+3
		CJNE R0,#0xFF, pruefeAistaktiv
		JMP ProzessBwirdaktiv
		
		pruefeAistaktiv:
		MOV R0, ProzessA+3
		CJNE R0, #0xFF, defaultProzess
		JMP ProzessAwirdaktiv
	
		AhatCPU:
			MOV A, prozessA
			CJNE A, #0xFF, BhatCPU
			;ProzessA whatte al
			;Umgebung von A sichern
			MOV data_ProzessA, A
			MOV data_ProzessA+1, PSW
			MOV data_ProzessA+2, DPH
			MOV data_ProzessA+3, DPL
			MOV data_ProzessA+4, SP
			MOV data_ProzessA+5, B
			;Byte für hat gerade CPU zurücksetzten
			MOV prozessA, #0
			MOV R0, prozessB+3
			CJNE R0, #0xFF, defaultProzess
			JMP ProzessBwirdaktiv
			
				
		BhatCPU:
			;ProzessA war als letztes aktiv
			;Umgebung von A sichern
			MOV data_ProzessB, A
			MOV data_ProzessB+1, PSW
			MOV data_ProzessB+2, DPH
			MOV data_ProzessB+3, DPL
			MOV data_ProzessB+4, SP
			MOV data_ProzessB+5, B
			;Byte für hat gerade CPU zurücksetzten
			MOV prozessB, #0
			MOV R0, prozessA+3
			CJNE R0, #0xFF, defaultProzess
			;A ist aktiv, wähle A als nächsten Prozess
			JMP ProzessAwirdaktiv
			
			defaultProzess:
				MOV A, data_ProzessConsole
				MOV PSW, data_ProzessConsole+1
				MOV DPH, data_ProzessConsole+2
				MOV DPL, data_ProzessConsole+3
				MOV SP, data_ProzessConsole+4
				MOV B, data_ProzessConsole+5
				MOV prozessConsole,#0xFF
				;setze Zeitscheibe
				MOV TL1, prozessConsole+1
				MOV TH1, prozessConsole+2
				;wechsle Registerbank
				SETB RS1
				CLR RS0
				JMP endeInterrupt
			
			ProzessAwirdaktiv:
				MOV A, data_ProzessA
				MOV PSW, data_ProzessA+1
				MOV DPH, data_ProzessA+2
				MOV DPL, data_ProzessA+3
				MOV SP, data_ProzessA+4
				MOV B, data_ProzessA+5
				MOV prozessA, #0xFF
				;Zeitscheibe setzten
				MOV TL1, prozessA+1
				MOV TH1, prozessA+2
				;wechsle Registerbank
				SETB RS1
				CLR RS0
				JMP endeInterrupt
				
			ProzessBwirdaktiv:
				MOV A, data_ProzessB
				MOV PSW, data_ProzessB+1
				MOV DPH, data_ProzessB+2
				MOV DPL, data_ProzessB+3
				MOV SP, data_ProzessB+4
				MOV B, data_ProzessB+5
				MOV prozessB, #0xFF
				;Zeitscheibe setzen
				MOV TL1, prozessB+1
				MOV TH1, prozessB+2
				;wechsle Registerbank
				SETB RS0
				SETB RS1
				JMP endeInterrupt

	endeInterrupt:

	RETI


END