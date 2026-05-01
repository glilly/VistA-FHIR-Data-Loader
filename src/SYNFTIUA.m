SYNFTIUA ;ven/gpl - TIU note intake analysis ;2026-05-01
 ;;0.7;VISTA SYN DATA LOADER;;Mar 18, 2025
 ;
 ; Read-only analysis for fhir-intake note payloads that have not reached TIU.
 q
 ;
EN(MAX) ; Print missing TIU opportunity report
 n OUT,I
 d RUN(.OUT,$g(MAX))
 w !,"FHIR intake TIU note opportunity report"
 w !,"patients=",OUT("patients")
 w !,"patientsWithSourceNotes=",OUT("patientsWithSourceNotes")
 w !,"patientsWithMissingNotes=",OUT("patientsWithMissingNotes")
 w !,"sourceNotes=",OUT("sourceNotes")
 w !,"missingNotes=",OUT("missingNotes")
 w !,"missingEncounterNotes=",OUT("missingEncounterNotes")
 w !,"missingDocumentReferences=",OUT("missingDocumentReferences"),!
 w !,"IEN^DFN^ICN^PATIENT^SOURCE^ENTRY^VISIT^TITLE^REASON^PREVIEW"
 s I=0
 f  s I=$o(OUT("rows",I)) q:+I=0  d
 . w !,OUT("rows",I)
 q
 ;
INV(MAX) ; Print resource inventory for fhir-intake note-bearing resources
 n OUT
 d INVENT(.OUT,$g(MAX))
 w !,"FHIR intake resource inventory"
 w !,"patients=",OUT("patients")
 w !,"resources=",OUT("resources")
 w !,"encounters=",OUT("Encounter")
 w !,"encountersWithNote=",OUT("Encounter.note")
 w !,"documentReferences=",OUT("DocumentReference")
 w !,"documentReferencesWithContent=",OUT("DocumentReference.content")
 w !,"documentReferencesWithTextPlain=",OUT("DocumentReference.textPlain"),!
 q
 ;
FIX(MAX,DRY) ; Repair missing fhir-intake notes by filing visit-linked TIU docs
 n OUT
 s DRY=$s($g(DRY)="":1,1:+DRY)
 d REPAIR(.OUT,$g(MAX),DRY)
 w !,$s(DRY:"FHIR intake TIU note repair dry run",1:"FHIR intake TIU note repair")
 w !,"patients=",OUT("patients")
 w !,"sourceNotes=",OUT("sourceNotes")
 w !,"candidates=",OUT("candidates")
 w !,"filed=",OUT("filed")
 w !,"alreadyFiled=",OUT("alreadyFiled")
 w !,"alreadyMatched=",OUT("alreadyMatched")
 w !,"skippedNoVisit=",OUT("skippedNoVisit")
 w !,"errors=",OUT("errors"),!
 q
 ;
RUN(OUT,MAX) ; Build report in OUT
 n ROOT,IEN,ROWS
 k OUT
 s MAX=+$g(MAX) i MAX<1 s MAX=999999
 s ROOT=$$ROOT^SYNFTIUA
 s (IEN,ROWS)=0
 f  s IEN=$o(@ROOT@(IEN)) q:+IEN=0  d
 . d PAT(.OUT,ROOT,IEN,.ROWS,MAX)
 s OUT("patients")=+$g(OUT("patients"))
 s OUT("patientsWithSourceNotes")=+$g(OUT("patientsWithSourceNotes"))
 s OUT("patientsWithMissingNotes")=+$g(OUT("patientsWithMissingNotes"))
 s OUT("sourceNotes")=+$g(OUT("sourceNotes"))
 s OUT("missingNotes")=+$g(OUT("missingNotes"))
 s OUT("missingEncounterNotes")=+$g(OUT("missingEncounterNotes"))
 s OUT("missingDocumentReferences")=+$g(OUT("missingDocumentReferences"))
 q
 ;
PAT(OUT,ROOT,IEN,ROWS,MAX) ; Scan one fhir-intake patient graph
 n DFN,HAS,MISS
 s OUT("patients")=+$g(OUT("patients"))+1
 s DFN=$$ien2dfn^SYNFUTL(IEN)
 s (HAS,MISS)=0
 d ENCS(.OUT,ROOT,IEN,DFN,.ROWS,MAX,.HAS,.MISS)
 d DOCS(.OUT,ROOT,IEN,DFN,.ROWS,MAX,.HAS,.MISS)
 i HAS s OUT("patientsWithSourceNotes")=+$g(OUT("patientsWithSourceNotes"))+1
 i MISS s OUT("patientsWithMissingNotes")=+$g(OUT("patientsWithMissingNotes"))+1
 q
 ;
REPAIR(OUT,MAX,DRY) ; Build repair counts and optionally file TIU notes
 n ROOT,IEN
 k OUT
 s MAX=+$g(MAX) i MAX<1 s MAX=999999
 s ROOT=$$ROOT^SYNFTIUA
 s IEN=0
 f  s IEN=$o(@ROOT@(IEN)) q:+IEN=0  d
 . d RPT(.OUT,ROOT,IEN,MAX,+$g(DRY))
 d COUNTS(.OUT)
 q
 ;
RPT(OUT,ROOT,IEN,MAX,DRY) ; Repair one patient graph
 n DFN
 s OUT("patients")=+$g(OUT("patients"))+1
 s DFN=$$ien2dfn^SYNFUTL(IEN)
 d RENC(.OUT,ROOT,IEN,DFN,MAX,DRY)
 d RDOC(.OUT,ROOT,IEN,DFN,MAX,DRY)
 q
 ;
RENC(OUT,ROOT,IEN,DFN,MAX,DRY) ; Repair Encounter.note payloads
 n JROOT,ZI,NI,TXT,ENC,VISIT,TITLE,TR,JLOG
 s JROOT=$na(@ROOT@(IEN,"json"))
 s ZI=0
 f  s ZI=$o(@JROOT@("entry",ZI)) q:+ZI=0  d
 . q:$g(@JROOT@("entry",ZI,"resource","resourceType"))'="Encounter"
 . s NI=0
 . f  s NI=$o(@JROOT@("entry",ZI,"resource","note",NI)) q:+NI=0  d
 . . s TXT=$g(@JROOT@("entry",ZI,"resource","note",NI,"text")) q:TXT=""
 . . s OUT("sourceNotes")=+$g(OUT("sourceNotes"))+1
 . . i $g(@ROOT@(IEN,"load","encounters",ZI,"tiu",NI,"status"))="filed" s OUT("alreadyFiled")=+$g(OUT("alreadyFiled"))+1 q
 . . s ENC=$g(@JROOT@("entry",ZI,"resource","id"))
 . . s VISIT=$g(@ROOT@(IEN,"load","encounters",ZI,"visitIen"))
 . . i +VISIT<1 s VISIT=$$visitIen^SYNFENC(IEN,ENC)
 . . i +VISIT<1 s OUT("skippedNoVisit")=+$g(OUT("skippedNoVisit"))+1 q
 . . i $$HASFILE^SYNFTIUA(VISIT,TXT) s OUT("alreadyMatched")=+$g(OUT("alreadyMatched"))+1 q
 . . s OUT("candidates")=+$g(OUT("candidates"))+1
 . . q:DRY
 . . q:+$g(DFN)<1
 . . s TITLE=$$TIUTITLE^SYNFTIU(JROOT,ZI,NI,TXT)
 . . s JLOG=$na(@ROOT@(IEN,"load","encounters",ZI))
 . . s TR=$$FHIRNOTE2TIU^SYNFTIU(DFN,VISIT,TXT,JLOG,TITLE)
 . . i +TR>0 d  q
 . . . s @JLOG@("tiu",NI,"status")="filed"
 . . . s @JLOG@("tiu",NI,"ien")=+TR
 . . . s @JLOG@("tiu",NI,"title")=TITLE
 . . . s @JLOG@("tiu",NI,"visitIen")=VISIT
 . . . s @JLOG@("tiu",NI,"result")=TR
 . . . s OUT("filed")=+$g(OUT("filed"))+1
 . . s @JLOG@("tiu",NI,"status")="notFiled"
 . . s @JLOG@("tiu",NI,"result")=TR
 . . s OUT("errors")=+$g(OUT("errors"))+1
 q
 ;
RDOC(OUT,ROOT,IEN,DFN,MAX,DRY) ; Repair DocumentReference text/plain payloads
 n JROOT,ZI,TXT,ENC,VISIT
 s JROOT=$na(@ROOT@(IEN,"json"))
 s ZI=0
 f  s ZI=$o(@JROOT@("entry",ZI)) q:+ZI=0  d
 . q:$g(@JROOT@("entry",ZI,"resource","resourceType"))'="DocumentReference"
 . s TXT=$$DOCTEXT^SYNFTIU(JROOT,ZI) q:TXT=""
 . s OUT("sourceNotes")=+$g(OUT("sourceNotes"))+1
 . i $g(@ROOT@(IEN,"load","documentReferences",ZI,"status","loadstatus"))="loaded" s OUT("alreadyFiled")=+$g(OUT("alreadyFiled"))+1 q
 . s ENC=$$DOCENC^SYNFTIU(JROOT,ZI)
 . s VISIT=$$visitIen^SYNFENC(IEN,ENC)
 . i +VISIT<1 s OUT("skippedNoVisit")=+$g(OUT("skippedNoVisit"))+1 q
 . i $$HASFILE^SYNFTIUA(VISIT,TXT) s OUT("alreadyMatched")=+$g(OUT("alreadyMatched"))+1 q
 . s OUT("candidates")=+$g(OUT("candidates"))+1
 . q:DRY
 . q:+$g(DFN)<1
 . n BEFORE,AFTER,JLOG
 . s JLOG=$na(@ROOT@(IEN,"load","documentReferences",ZI))
 . s BEFORE=+$g(@ROOT@(IEN,"load","documentReferences","status","loaded"))
 . d DOCREF1^SYNFTIU(IEN,ZI,DFN,JROOT,$na(@ROOT@(IEN,"load")),.OUT)
 . s AFTER=+$g(@ROOT@(IEN,"load","documentReferences","status","loaded"))
 . i AFTER>BEFORE s OUT("filed")=+$g(OUT("filed"))+1 q
 . s OUT("errors")=+$g(OUT("errors"))+1
 q
 ;
ENCS(OUT,ROOT,IEN,DFN,ROWS,MAX,HAS,MISS) ; Scan Encounter.note payloads
 n JROOT,TROOT,ZI,NI,TXT,ENC,VISIT,TITLE,WHY
 s JROOT=$na(@ROOT@(IEN,"json"))
 s TROOT=$na(@JROOT@("entry"))
 s ZI=0
 f  s ZI=$o(@TROOT@(ZI)) q:+ZI=0  d
 . q:$g(@JROOT@("entry",ZI,"resource","resourceType"))'="Encounter"
 . s NI=0
 . f  s NI=$o(@JROOT@("entry",ZI,"resource","note",NI)) q:+NI=0  d
 . . s TXT=$g(@JROOT@("entry",ZI,"resource","note",NI,"text")) q:TXT=""
 . . s HAS=1,OUT("sourceNotes")=+$g(OUT("sourceNotes"))+1
 . . s ENC=$g(@JROOT@("entry",ZI,"resource","id"))
 . . s VISIT=$g(@ROOT@(IEN,"load","encounters",ZI,"visitIen"))
 . . i +VISIT<1 s VISIT=$$visitIen^SYNFENC(IEN,ENC)
 . . i $g(@ROOT@(IEN,"load","encounters",ZI,"tiu",NI,"status"))="filed" q
 . . s TITLE=$$TIUTITLE^SYNFTIU(JROOT,ZI,NI,TXT)
 . . s WHY=$s(+VISIT<1:"no visit",$$HASFILE(VISIT,TXT):"",1:"no matching TIU")
 . . q:WHY=""
 . . s MISS=1,OUT("missingNotes")=+$g(OUT("missingNotes"))+1
 . . s OUT("missingEncounterNotes")=+$g(OUT("missingEncounterNotes"))+1
 . . d ROW(.OUT,IEN,DFN,"Encounter.note",ZI,+VISIT,TITLE,WHY,TXT,.ROWS,MAX)
 q
 ;
DOCS(OUT,ROOT,IEN,DFN,ROWS,MAX,HAS,MISS) ; Scan note-like DocumentReference payloads
 n JROOT,TROOT,ZI,TXT,ENC,VISIT,TITLE,WHY
 s JROOT=$na(@ROOT@(IEN,"json"))
 s TROOT=$na(@JROOT@("entry"))
 s ZI=0
 f  s ZI=$o(@TROOT@(ZI)) q:+ZI=0  d
 . q:$g(@JROOT@("entry",ZI,"resource","resourceType"))'="DocumentReference"
 . s TXT=$$DOCTEXT^SYNFTIU(JROOT,ZI) q:TXT=""
 . s HAS=1,OUT("sourceNotes")=+$g(OUT("sourceNotes"))+1
 . i $g(@ROOT@(IEN,"load","documentReferences",ZI,"status","loadstatus"))="loaded" q
 . s ENC=$$DOCENC^SYNFTIU(JROOT,ZI)
 . s VISIT=$$visitIen^SYNFENC(IEN,ENC)
 . s TITLE=$$DOCREFTITLE^SYNFTIU(JROOT,ZI,TXT)
 . s WHY=$s(ENC="":"missing encounter",+VISIT<1:"no visit",$$HASFILE(VISIT,TXT):"",1:"no matching TIU")
 . q:WHY=""
 . s MISS=1,OUT("missingNotes")=+$g(OUT("missingNotes"))+1
 . s OUT("missingDocumentReferences")=+$g(OUT("missingDocumentReferences"))+1
 . d ROW(.OUT,IEN,DFN,"DocumentReference",ZI,+VISIT,TITLE,WHY,TXT,.ROWS,MAX)
 q
 ;
ROW(OUT,IEN,DFN,SRC,ZI,VISIT,TITLE,WHY,TXT,ROWS,MAX) ; Add one report row
 n ICN,NAME,PRE
 s U="^"
 i ROWS'<+$g(MAX) q
 s ROWS=ROWS+1
 s ICN=$s(+DFN>0:$$dfn2icn^SYNFUTL(DFN),1:"")
 s NAME=$s(+DFN>0:$p($g(^DPT(DFN,0)),U),1:"")
 s PRE=$$PREV(TXT)
 s OUT("rows",ROWS)=IEN_U_DFN_U_ICN_U_NAME_U_SRC_U_ZI_U_VISIT_U_TITLE_U_WHY_U_PRE
 q
 ;
HASFILE(VISIT,TXT) ; True if stripped note text appears in visit-linked TIU
 n SNIP,TIU,FOUND
 i +$g(VISIT)<1 q 0
 s SNIP=$$SNIP(TXT) i SNIP="" q 0
 s (TIU,FOUND)=0
 f  s TIU=$o(^TIU(8925,"V",VISIT,TIU)) q:+TIU=0  d  q:FOUND
 . s FOUND=$$TXTHAS(TIU,SNIP)
 q FOUND
 ;
TXTHAS(TIU,SNIP) ; True if TIU TEXT contains snippet
 n I,LINE
 s I=0
 f  s I=$o(^TIU(8925,TIU,"TEXT",I)) q:+I=0  d  q:$g(LINE)
 . i $g(^TIU(8925,TIU,"TEXT",I,0))[SNIP s LINE=1
 q +$g(LINE)
 ;
SNIP(TXT) ; First useful text snippet after Document header stripping
 n STR,I,LINE
 s STR=$$STRIPDOC^SYNFTIU($g(TXT))
 f I=1:1:$l(STR,$c(10)) d  q:$l($g(LINE))>12
 . s LINE=$$TRIM^SYNFTIU($p(STR,$c(10),I))
 i $l($g(LINE))<1 q ""
 q $e(LINE,1,40)
 ;
PREV(TXT) ; Short display preview
 n X
 s X=$$SNIP($g(TXT))
 q $tr($e(X,1,60),U," ")
 ;
ROOT() ; fhir-intake graph payload root without creating null-subscript paths
 n R,WR,WG,SIEN,WIEN
 s WG="^"_$c(37)_"wd(17.040801)"
 s WIEN=$o(@WG@("B","fhir-intake",0))
 i +WIEN>0 d  i $d(@WR)>1 q WR
 . s WR=$na(@WG@(WIEN))
 s SIEN=$o(^SYNGRAPH(2002.801,"B","fhir-intake",0))
 i +SIEN>0 d  i $d(@R)>1 q R
 . s R=$na(^SYNGRAPH(2002.801,SIEN))
 s R=$$setroot^SYNWD("fhir-intake")
 i R["^SYNGRAPH" s R=$na(@R@("graph"))
 q R
 ;
INVENT(OUT,MAX) ; Count note-related resource shapes
 n ROOT,IEN,ZI,RES,TYP,CTYPE
 k OUT
 s MAX=+$g(MAX) i MAX<1 s MAX=999999
 s ROOT=$$ROOT^SYNFTIUA
 s IEN=0
 f  s IEN=$o(@ROOT@(IEN)) q:+IEN=0  d
 . s OUT("patients")=+$g(OUT("patients"))+1
 . s ZI=0
 . f  s ZI=$o(@ROOT@(IEN,"json","entry",ZI)) q:+ZI=0  d
 . . s OUT("resources")=+$g(OUT("resources"))+1
 . . s RES=$na(@ROOT@(IEN,"json","entry",ZI,"resource"))
 . . s TYP=$g(@RES@("resourceType"))
 . . i TYP'="" s OUT(TYP)=+$g(OUT(TYP))+1
 . . i TYP="Encounter",$d(@RES@("note")) s OUT("Encounter.note")=+$g(OUT("Encounter.note"))+1
 . . i TYP="DocumentReference",$d(@RES@("content")) d
 . . . s OUT("DocumentReference.content")=+$g(OUT("DocumentReference.content"))+1
 . . . s CTYPE=$$LOW^XLFSTR($g(@RES@("content",1,"attachment","contentType")))
 . . . i CTYPE["text/plain" s OUT("DocumentReference.textPlain")=+$g(OUT("DocumentReference.textPlain"))+1
 s OUT("patients")=+$g(OUT("patients"))
 s OUT("resources")=+$g(OUT("resources"))
 s OUT("Encounter")=+$g(OUT("Encounter"))
 s OUT("Encounter.note")=+$g(OUT("Encounter.note"))
 s OUT("DocumentReference")=+$g(OUT("DocumentReference"))
 s OUT("DocumentReference.content")=+$g(OUT("DocumentReference.content"))
 s OUT("DocumentReference.textPlain")=+$g(OUT("DocumentReference.textPlain"))
 q
 ;
COUNTS(OUT) ; Normalize repair counters
 s OUT("patients")=+$g(OUT("patients"))
 s OUT("sourceNotes")=+$g(OUT("sourceNotes"))
 s OUT("candidates")=+$g(OUT("candidates"))
 s OUT("filed")=+$g(OUT("filed"))
 s OUT("alreadyFiled")=+$g(OUT("alreadyFiled"))
 s OUT("alreadyMatched")=+$g(OUT("alreadyMatched"))
 s OUT("skippedNoVisit")=+$g(OUT("skippedNoVisit"))
 s OUT("errors")=+$g(OUT("errors"))
 q
 ;
