SYNFTIU  ;ven/gpl - fhir loader utilities ;2018-08-17  3:27 PM
 ;;0.3;VISTA SYNTHETIC DATA LOADER;;Jul 01, 2019;Build 13
 ;
 ; Authored by George P. Lilly 2017-2018
 ;
 ; Encounter TIU note utilities (graph-store lines under load,encounters,rien,note)
 ; FHIR Encounter.note intake: INGESTFHIR^SYNFTIU (graph + optional ^TIU via MAKE^TIUSRVP)
 q
 ;
INTROOT() ; fhir-intake root - must match SYNFHIR/SYNFCP (SYNWD routes to %wd or SYNGRAF)
 n r
 i $l($t(+0^SYNWD)) s r=$$setroot^SYNWD("fhir-intake")
 e  s r=$$setroot^%wd("fhir-intake")
 q r
 ;
CANDS(enc,ary) ; candidate PSO index keys for Encounter (same subject as setIndex^SYNFHIR purl)
 n n,u
 k ary
 q:$g(enc)=""
 s n=1,ary(1)=enc
 i enc["urn:uuid:" d  ;
 . s u=$p(enc,"urn:uuid:",2)
 . i u'="" s n=n+1,ary(n)=u s n=n+1,ary(n)="Encounter/"_u
 i enc["Encounter/" d  ;
 . s u=$p(enc,"Encounter/",2)
 . i u'="" s n=n+1,ary(n)=enc s n=n+1,ary(n)="urn:uuid:"_u s n=n+1,ary(n)=u
 e  i enc'["/",enc'["urn" d  ;
 . s n=n+1,ary(n)="Encounter/"_enc
 . s n=n+1,ary(n)="urn:uuid:"_enc
 q
 ;
TONOTE(ien,enc,line) ; insert a line to the note associated with encounter enc
 ; enc is a pointer to the encounter
 ; ien identifies the patient graph
 ;
 n nroot s nroot=$$NOTEPTR^SYNFTIU(ien,enc)
 q:nroot=""
 ;w !,"add to note: ",line
 i $l(line)>80 d  ;
 . n tline s tline(0)=line
 .
 . d WRAP^DIKCU2(.tline,80)
 . ; ZWR tline
 . n zi
 . f zi=0:1:$o(tline(" "),-1) d  ;
 . . s @nroot@($o(@nroot@(" "),-1)+zi)=tline(zi)
 e  s @nroot@($o(@nroot@(" "),-1)+1)=line
 q
 ;
NOTEPTR(ien,enc) ; returns a global pointer to the note for this encounter
 ; ien is the patient graph
 n root,groot,encien,ci,cand,cands
 s root=$$INTROOT^SYNFTIU
 s groot=$na(@root@(ien))
 d CANDS^SYNFTIU($g(enc),.cands)
 s encien=""
 f ci=1:1 q:'$d(cands(ci))  q:encien'=""  d  ;
 . s cand=$g(cands(ci)) q:cand=""
 . s encien=$o(@groot@("PSO","rien",cand,""))
 q:encien="" ""
 n nroot s nroot=$na(@groot@("load","encounters",encien,"note"))
 q nroot
 ;
KILLNOTE(ien,enc) ; kill the note for this encounter
 ; used for testing
 n knote s knote=$$NOTEPTR^SYNFTIU(ien,enc)
 q:'$d(@knote)
 k @knote
 q
 ;
KILLNOTEZI(ien,zi) ; kill graph note for load,encounters,zi (by bundle entry index)
 n r s r=$$INTROOT^SYNFTIU
 k @r@(ien,"load","encounters",zi,"note")
 q
 ;
TONOTEZI(ien,zi,line) ; append one line to @fhir-intake@(ien,"load","encounters",zi,"note")
 n r,nroot,zi,tline
 s r=$$INTROOT^SYNFTIU
 s nroot=$na(@r@(ien,"load","encounters",zi,"note"))
 q:'$l($g(line))
 i $l(line)>80 d  q
 . s tline(0)=line
 . d WRAP^DIKCU2(.tline,80)
 . n zj
 . f zj=0:1:$o(tline(" "),-1) d
 . . s @nroot@($o(@nroot@(" "),-1)+zj)=tline(zj)
 e  s @nroot@($o(@nroot@(" "),-1)+1)=line
 q
 ;
TITLEIEN() ; Default TIU document definition (8925.1) for FHIR-imported notes
 n y
 s y=$$FIND1^DIC(8925.1,,"QX","PROGRESS NOTES","B")
 i y'>0 s y=$$FIND1^DIC(8925.1,,"QX","PRIMARY CARE NOTE","B")
 q +y
 ;
FHIRNOTE2TIU(dfn,vsit,txt,jlog) ; One Encounter.note -> MAKE^TIUSRVP (visit-linked TIU)
 ; Returns TIUDA on success, 0^message on failure. Requires TIUSRVP on the system.
 n success,title,tiux,tli,i,n,duzsave
 i +$g(dfn)<1 q "0^missing dfn"
 i +$g(vsit)<1 q "0^missing visit ien"
 i $l($g(txt))<1 q "0^empty note text"
 s title=$$TITLEIEN^SYNFTIU
 i title<1 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: no 8925.1 title (PROGRESS NOTES)") q "0^no TIU title"
 i '$d(DT) n diquiet s diquiet=1 d DT^DICRW
 s duzsave=$g(DUZ)
 s DUZ=$$DUZ^SYNDHP69
 k tiux
 s tiux(1202)=DUZ
 k tli s tli(0)=txt
 d WRAP^DIKCU2(.tli,80)
 s n=0
 f i=0:1:$o(tli(" "),-1) s n=n+1,tiux("TEXT",n,0)=tli(i)
 i n<1 s tiux("TEXT",1,0)=txt
 s success=0
 i $t(MAKE^TIUSRVP)'="" d MAKE^TIUSRVP(.success,dfn,title,"","",vsit,.tiux,"",0,0)
 e  d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: MAKE^TIUSRVP not available") s DUZ=duzsave q "0^no TIUSRVP"
 s DUZ=duzsave
 i +success>0 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: TIU IEN="_success) q +success
 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: TIU MAKE failed: "_$g(success))
 q $g(success)
 ;
INGESTFHIR(ien,zi,encid,dfn,vsit,jlog,json,args) ; Encounter.note -> graph + TIU
 ; ien=graph store ien, zi=bundle entry index, encid=FHIR Encounter.id (unused; reserved)
 ; json: local array json("entry",zi,"resource","note",...)
 ; args("encounterGraphNotes") 0=skip graph (default 1)
 ; args("encounterTiu")        0=skip TIU   (default 1)
 n dograph,dotiu,ni,txt,sep
 s dograph=$s($g(args("encounterGraphNotes"))=0:0,1:1)
 s dotiu=$s($g(args("encounterTiu"))=0:0,1:1)
 q:'$d(json("entry",zi,"resource"))
 q:$o(json("entry",zi,"resource","note",""))=""
 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR Encounter.note ingest: graph="_dograph_" tiu="_dotiu)
 i dograph d KILLNOTEZI^SYNFTIU(ien,zi)
 s ni=""
 f  s ni=$o(json("entry",zi,"resource","note",ni)) q:ni=""  q:ni'=+ni  d
 . s txt=$g(json("entry",zi,"resource","note",ni,"text"))
 . q:'$l(txt)
 . i dograph d  ;
 . . s sep="-------- FHIR note #"_ni_" --------"
 . . d TONOTEZI^SYNFTIU(ien,zi,sep)
 . . d TONOTEZI^SYNFTIU(ien,zi,"")
 . . n pos,ch,buf s buf=""
 . . f pos=1:1:$l(txt) s ch=$e(txt,pos) d
 . . . i ch=$c(10) d TONOTEZI^SYNFTIU(ien,zi,buf) s buf="" q
 . . . s buf=buf_ch
 . . i $l(buf) d TONOTEZI^SYNFTIU(ien,zi,buf)
 . i dotiu,+vsit>0 d
 . . n tr s tr=$$FHIRNOTE2TIU^SYNFTIU(dfn,vsit,txt,jlog)
 . . i +tr>0 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note ni="_ni_" TIU="_tr)
 q
 ;
CLRNOTES(ien,rien) ; kill all notes for patient ien
 n root s root=$$INTROOT^SYNFTIU
 n groot s groot=$na(@root@(ien,"load","encounters"))
 n zi s zi=0
 f  s zi=$o(@groot@(zi)) q:+zi=0  d  ;
 . k @groot@(zi,"note")
 . w !,"kill ",groot," ",zi," note"
 q
 ;
T1 ;
 s ien=1640
 s enc="urn:uuid:02eb455c-787c-4abb-8f39-a9675a2db35c"
 w !,"note pointer: ",$$NOTEPTR^SYNFTIU(ien,enc)
 q
 ;
T2 ;
 s ien=1640
 s enc="urn:uuid:02eb455c-787c-4abb-8f39-a9675a2db35c"
 d KILLNOTE^SYNFTIU(ien,enc)
 d TONOTE^SYNFTIU(ien,enc,"Test Note Creation")
 d TONOTE^SYNFTIU(ien,enc,"Patient ien: "_ien)
 d TONOTE^SYNFTIU(ien,enc,"Encounter Id: "_enc)
 q
 ;
