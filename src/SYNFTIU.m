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
 ; Do not N zi - zi is a parameter; NEW zi would clear it and break callers (INGESTFHIR).
 n r,nroot,tline
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
TITLEIEN(name) ; TIU document definition (8925.1) for FHIR-imported notes
 n y
 s name=$$TRIM^SYNFTIU($g(name))
 i name'="" s y=$$FIND1^DIC(8925.1,,"QX",name,"B") i y>0 q +y
 s y=$$FIND1^DIC(8925.1,,"QX","PROGRESS NOTES","B")
 i y'>0 s y=$$FIND1^DIC(8925.1,,"QX","PRIMARY CARE NOTE","B")
 q +y
 ;
FHIRNOTE2TIU(dfn,vsit,txt,jlog,titleName) ; One Encounter.note -> MAKE^TIUSRVP
 ; Returns TIUDA on success, 0^message on failure. Requires TIUSRVP on the system.
 n success,title,tiux,pos,ch,line,n,duzsave
 i +$g(dfn)<1 q "0^missing dfn"
 i +$g(vsit)<1 q "0^missing visit ien"
 i $l($g(txt))<1 q "0^empty note text"
 s title=$$TITLEIEN^SYNFTIU($g(titleName))
 i title<1 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: no 8925.1 title") q "0^no TIU title"
 s txt=$$STRIPDOC^SYNFTIU(txt)
 i '$d(DT) n diquiet s diquiet=1 d DT^DICRW
 s duzsave=$g(DUZ)
 s DUZ=$$DUZ^SYNDHP69
 i +$g(DUZ)<1 s DUZ=duzsave q "0^missing DUZ"
 k tiux
 s tiux(1202)=DUZ
 s n=0
 s txt=$tr(txt,$c(13),"")
 s line=""
 f pos=1:1:$l(txt) s ch=$e(txt,pos) d
 . i ch=$c(10) d ADDLINE^SYNFTIU(.tiux,.n,line) s line="" q
 . s line=line_ch
 d ADDLINE^SYNFTIU(.tiux,.n,line)
 i n<1 s tiux("TEXT",1,0)=txt
 s success=0
 i $t(MAKE^TIUSRVP)'="" d MAKE^TIUSRVP(.success,dfn,title,"","",vsit,.tiux,"",0,0)
 e  d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: MAKE^TIUSRVP not available") s DUZ=duzsave q "0^no TIUSRVP"
 s DUZ=duzsave
 i +success>0 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: TIU IEN="_success) q +success
 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note: TIU MAKE failed: "_$g(success))
 q $g(success)
 ;
ADDLINE(tiux,n,line) ; Append one source line to TIU TEXT, wrapping long lines
 n tli,i
 i $g(line)="" s n=n+1,tiux("TEXT",n,0)="" q
 k tli s tli(0)=line
 d WRAP^DIKCU2(.tli,80)
 f i=0:1:$o(tli(" "),-1) s n=n+1,tiux("TEXT",n,0)=tli(i)
 q
 ;
STRIPDOC(txt) ; Remove Document: title header from TIU body; TIU stores title separately
 n first,rest
 s txt=$tr($g(txt),$c(13),"")
 s first=$$TRIM^SYNFTIU($p(txt,$c(10),1))
 i $$UP^XLFSTR($e(first,1,9))'="DOCUMENT:" q txt
 s rest=$p(txt,$c(10),2,999999)
 i $e(rest,1)=$c(10) s rest=$e(rest,2,$l(rest))
 q rest
 ;
TIUTITLE(json,zi,ni,txt) ; Note title from extension, Document header, or default
 n title
 s title=$$EXTITLE^SYNFTIU(json,zi,ni)
 i title="" s title=$$DOCTITLE^SYNFTIU($g(txt))
 i title="" s title="PROGRESS NOTES"
 q title
 ;
EXTITLE(json,zi,ni) ; Optional va-tiu-note-title extension on Encounter.note
 n ei,url,val
 s ei=""
 f  s ei=$o(@json@("entry",zi,"resource","note",ni,"extension",ei)) q:ei=""  d  q:$l($g(val))
 . s url=$g(@json@("entry",zi,"resource","note",ni,"extension",ei,"url"))
 . q:url'["va-tiu-note-title"
 . s val=$g(@json@("entry",zi,"resource","note",ni,"extension",ei,"valueString"))
 . i val="" s val=$g(@json@("entry",zi,"resource","note",ni,"extension",ei,"valueCode"))
 . i val="" s val=$g(@json@("entry",zi,"resource","note",ni,"extension",ei,"valueCodeableConcept","text"))
 . i val="" s val=$g(@json@("entry",zi,"resource","note",ni,"extension",ei,"valueCodeableConcept","coding",1,"display"))
 q $$TRIM^SYNFTIU($g(val))
 ;
DOCTITLE(txt) ; Parse "Document: TITLE" from first note line
 n line,up
 s line=$$TRIM^SYNFTIU($p($g(txt),$c(10),1))
 s up=$$UP^XLFSTR(line)
 i $e(up,1,9)="DOCUMENT:" q $$TRIM^SYNFTIU($e(line,10,$l(line)))
 q ""
 ;
TRIM(x) ; trim leading/trailing spaces
 f  q:$e($g(x),1)'=" "  s x=$e(x,2,$l(x))
 f  q:$e($g(x),$l(x))'=" "  s x=$e(x,1,$l(x)-1)
 q $g(x)
 ;
INGESTFHIR(ien,zi,encid,dfn,vsit,jlog,json,args) ; Encounter.note -> graph + TIU
 ; ien=graph store ien, zi=bundle entry index, encid=FHIR Encounter.id (unused; reserved)
 ; json: $NA of decoded bundle root (same as wsIntakeEncounters); use @json@(...) like SYNFENC
 ; args("encounterGraphNotes") 0=skip graph (default 1)
 ; args("encounterTiu")        0=skip TIU   (default 1)
 n dograph,dotiu,ni,txt,sep,titleName
 s dograph=$s($g(args("encounterGraphNotes"))=0:0,1:1)
 s dotiu=$s($g(args("encounterTiu"))=0:0,1:1)
 q:'$d(@json@("entry",zi,"resource"))
 q:$o(@json@("entry",zi,"resource","note",""))=""
 d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR Encounter.note ingest: graph="_dograph_" tiu="_dotiu)
 i dograph d KILLNOTEZI^SYNFTIU(ien,zi)
 s ni=""
 f  s ni=$o(@json@("entry",zi,"resource","note",ni)) q:ni=""  q:ni'=+ni  d
 . s txt=$g(@json@("entry",zi,"resource","note",ni,"text"))
 . q:'$l(txt)
 . s titleName=$$TIUTITLE^SYNFTIU(json,zi,ni,txt)
 . s @jlog@("tiu",ni,"title")=titleName
 . s @jlog@("tiu",ni,"visitIen")=$g(vsit)
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
 . . n tr s tr=$$FHIRNOTE2TIU^SYNFTIU(dfn,vsit,txt,jlog,titleName)
 . . s @jlog@("tiu",ni,"result")=tr
 . . i +tr>0 d  q
 . . . s @jlog@("tiu",ni,"status")="filed"
 . . . s @jlog@("tiu",ni,"ien")=+tr
 . . . d:$l($g(jlog)) log^SYNFENC(jlog,"FHIR note ni="_ni_" TIU="_tr)
 . . s @jlog@("tiu",ni,"status")="notFiled"
 . e  d
 . . s @jlog@("tiu",ni,"status")=$s('dotiu:"skipped",1:"notFiled")
 . . s @jlog@("tiu",ni,"result")=$s('dotiu:"0^encounterTiu disabled",1:"0^missing visit ien")
 q
 ;
importDocRefs(rtn,ien,args) ; File note-like DocumentReference attachments as visit TIU
 n grtn
 d DOCREFS(.grtn,ien,.args)
 s rtn("documentReferenceStatus","status")=$g(grtn("status","status"))
 s rtn("documentReferenceStatus","loaded")=$g(grtn("status","loaded"))
 s rtn("documentReferenceStatus","errors")=$g(grtn("status","errors"))
 q
 ;
DOCREFS(result,ien,args) ; Internal DocumentReference note importer
 n root,json,troot,eval,dfn,zi,bundle
 s root=$$INTROOT^SYNFTIU
 q:+$g(ien)<1
 s json=$na(@root@(ien,"json"))
 s troot=$na(@root@(ien,"type","DocumentReference"))
 s eval=$na(@root@(ien,"load"))
 s dfn=$$ien2dfn^SYNFUTL(ien)
 i +dfn<1 s result("status","status")="no patient" q
 s bundle=$g(args("bundle"))
 s zi=0
 f  s zi=$o(@troot@(zi)) q:+zi=0  d
 . i bundle'="",$g(@root@(ien,zi,"bundle"))'=bundle q
 . i $g(@eval@("documentReferences",zi,"status","loadstatus"))="loaded" q
 . d DOCREF1(ien,zi,dfn,json,eval,.args)
 s result("status","status")="ok"
 s result("status","loaded")=+$g(@eval@("documentReferences","status","loaded"))
 s result("status","errors")=+$g(@eval@("documentReferences","status","errors"))
 q
 ;
DOCREF1(ien,zi,dfn,json,eval,args) ; One DocumentReference -> TIU when encounter-linked
 n jlog,type,enc,visit,txt,title,tr
 s jlog=$na(@eval@("documentReferences",zi))
 s type=$g(@json@("entry",zi,"resource","resourceType"))
 i type'="DocumentReference" d DOCERR(jlog,eval,zi,"not DocumentReference") q
 s enc=$$DOCENC(json,zi)
 i enc="" d DOCERR(jlog,eval,zi,"missing encounter reference") q
 s visit=$$visitIen^SYNFENC(ien,enc)
 i +visit<1 d DOCERR(jlog,eval,zi,"encounter visit not found: "_enc) q
 s txt=$$DOCTEXT(json,zi)
 i txt="" d DOCERR(jlog,eval,zi,"missing text/plain attachment data") q
 s title=$$DOCREFTITLE(json,zi,txt)
 s @jlog@("encounterReference")=enc
 s @jlog@("visitIen")=visit
 s @jlog@("title")=title
 s tr=$$FHIRNOTE2TIU^SYNFTIU(dfn,visit,txt,jlog,title)
 s @jlog@("result")=tr
 i +tr>0 d  q
 . s @jlog@("status","loadstatus")="loaded"
 . s @jlog@("status","loadMessage")="1^"_visit_"^DocumentReference note filed"
 . s @jlog@("tiu",1,"status")="filed"
 . s @jlog@("tiu",1,"ien")=+tr
 . s @jlog@("tiu",1,"title")=title
 . s @jlog@("tiu",1,"visitIen")=visit
 . s @eval@("documentReferences","status","loaded")=+$g(@eval@("documentReferences","status","loaded"))+1
 s @jlog@("status","loadstatus")="notLoaded"
 s @jlog@("status","loadMessage")=tr
 s @jlog@("tiu",1,"status")="notFiled"
 s @eval@("documentReferences","status","errors")=+$g(@eval@("documentReferences","status","errors"))+1
 q
 ;
DOCERR(jlog,eval,zi,msg) ; record DocumentReference note import failure
 s @jlog@("status","loadstatus")="notLoaded"
 s @jlog@("status","loadMessage")="0^"_msg
 s @eval@("documentReferences","status","errors")=+$g(@eval@("documentReferences","status","errors"))+1
 q
 ;
DOCENC(json,zi) ; Encounter reference from DocumentReference.context.encounter
 n enc
 s enc=$g(@json@("entry",zi,"resource","context","encounter",1,"reference"))
 i enc="" s enc=$g(@json@("entry",zi,"resource","context","encounter","reference"))
 i enc="" s enc=$g(@json@("entry",zi,"resource","encounter","reference"))
 q enc
 ;
DOCTEXT(json,zi) ; Decode first text/plain DocumentReference attachment
 n ci,ctype,data
 s ci=""
 f  s ci=$o(@json@("entry",zi,"resource","content",ci)) q:ci=""  d  q:$l($g(data))
 . s ctype=$$LOW^XLFSTR($g(@json@("entry",zi,"resource","content",ci,"attachment","contentType")))
 . q:ctype'["text/plain"
 . s data=$g(@json@("entry",zi,"resource","content",ci,"attachment","data"))
 i $g(data)="" q ""
 q $$DECODE64^SYNWEBUT($tr(data,$c(10)_$c(13)_" ",""))
 ;
DOCREFTITLE(json,zi,txt) ; Title for DocumentReference-origin note
 n title
 s title=$$DOCTITLE^SYNFTIU($g(txt))
 i title'="" q title
 s title=$g(@json@("entry",zi,"resource","content",1,"attachment","title"))
 i title'="" q $$TRIM^SYNFTIU(title)
 s title=$g(@json@("entry",zi,"resource","type","text"))
 i title'="" q $$TRIM^SYNFTIU(title)
 q "PROGRESS NOTES"
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
