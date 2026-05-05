SYNFENC ;ven/gpl - fhir loader utilities ;Aug 15, 2019@13:57:48
 ;;0.7;VISTA SYN DATA LOADER;;Mar 18, 2025
 ;
 ; Copyright (c) 2017-2018 George P. Lilly
 ;
 ;Licensed under the Apache License, Version 2.0 (the "License");
 ;you may not use this file except in compliance with the License.
 ;You may obtain a copy of the License at
 ;
 ;    http://www.apache.org/licenses/LICENSE-2.0
 ;
 ;Unless required by applicable law or agreed to in writing, software
 ;distributed under the License is distributed on an "AS IS" BASIS,
 ;WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 ;See the License for the specific language governing permissions and
 ;limitations under the License.
 ;
 ;
 q
 ;
importEncounters(rtn,ien,args)  ; entry point for loading encounters for a patient
 ; calls the intake Encounters web service directly
 ;
 n grtn
 n root s root=$$setroot^SYNWD("fhir-intake")
 d wsIntakeEncounters(.args,,.grtn,ien)
 ;
 s rtn("encountersStatus","status")=$g(grtn("status","status"))
 s rtn("encountersStatus","loaded")=$g(grtn("status","loaded"))
 s rtn("encountersStatus","errors")=$g(grtn("status","errors"))
 ;
 ;
 q
 ;
wsIntakeEncounters(args,body,result,ien)        ; web service entry (post)
 ; for intake of one or more Encounters. input are fhir resources
 ; result is json and summarizes what was done
 ; args include patientId
 ; ien is specified for internal calls, where the json is already in a graph
 ;
 n root,troot
 s root=$$setroot^SYNWD("fhir-intake")
 ;
 n jtmp,json,jrslt,eval
 i $g(ien)'="" d  ; internal call
 . s troot=$na(@root@(ien,"type","Encounter"))
 . s eval=$na(@root@(ien,"load")) ; move eval to the graph
 e  q 0  ; sending not decoded json in BODY to this routine not supported
 ; todo: locate the patient and add the encounters in BODY to the graph
 s json=$na(@root@(ien,"json"))
 ;
 ; determine the patient
 ;
 n dfn
 if $g(ien)'="" d  ;
 . s dfn=$$ien2dfn^SYNFUTL(ien) ; look up dfn in the graph
 else  d  ;
 . s dfn=$g(args("dfn"))
 . i dfn="" d  ;
 . . n icn s icn=$g(args("icn"))
 . . i icn'="" s dfn=$$icn2dfn^SYNFUTL(icn)
 i $g(dfn)="" do  quit  ; need the patient
 . s result("encounters",1,"log",1)="Error, patient not found.. terminating"
 ;
 ;
 new zi s zi=0
 for  set zi=$order(@troot@(zi)) quit:+zi=0  do  ;
 . ;
 . ; define a place to log the processing of this entry
 . ;
 . new jlog set jlog=$name(@eval@("encounters",zi))
 . ;
 . ; insure that the resourceType is Encounter
 . ;
 . new type set type=$get(@json@("entry",zi,"resource","resourceType"))
 . if type'="Encounter" do  quit  ;
 . . set @eval@("encounters",zi,"vars","resourceType")=type
 . . do log(jlog,"Resource type not Encounter, skipping entry")
 . set @eval@("encounters",zi,"vars","resourceType")=type
 . ;
 . ; see if this resource has already been loaded. if so, skip it
 . ;
 . if $g(ien)'="" if $$loadStatus("encounters",zi,ien)=1 do  quit  ;
 . . d log(jlog,"Encounter already loaded, skipping")
 . ;
 . ; determine Encounters code, coding system, and display text
 . ;
 . ;
 . ; determine the id of the resource
 . ;
 . new id set id=$get(@json@("entry",zi,"resource","id"))
 . set @eval@("encounters",zi,"vars","id")=id
 . d log(jlog,"ID is: "_id)
 . new knownVisit s knownVisit=$$visitIen^SYNFENC(ien,id)
 . if +knownVisit>0,$o(@json@("entry",zi,"resource","note",""))'="" do  quit  ;
 . . d log(jlog,"Encounter already has visitIen "_knownVisit_"; filing Encounter.note only")
 . . s @eval@("encounters",zi,"visitIen")=knownVisit
 . . s @eval@("encounters",zi,"status","loadstatus")="loaded"
 . . s @eval@("encounters",zi,"status","loadMessage")="1^"_knownVisit_"^known encounter note filed"
 . . if $g(args("skipEncounterNotes"))'=1,$t(INGESTFHIR^SYNFTIU)'="" do
 . . . d INGESTFHIR^SYNFTIU(ien,zi,id,dfn,knownVisit,jlog,.json,.args)
 . . . if $d(@root@(ien,"load","encounters",zi,"note")) m @eval@("encounters",zi,"note")=@root@(ien,"load","encounters",zi,"note")
 . . s @eval@("encounters","status","loaded")=$g(@eval@("encounters","status","loaded"))+1
 . ;
 . new enccode set enccode=$get(@json@("entry",zi,"resource","type",1,"coding",1,"code"))
 . ;n visitcpt s visitcpt=$$MAP^SYNQLDM(enccode)
 . ;i visitcpt="" d  ;
 . ;. d MAPERR^SYNQLDM(enccode,"sct2cpt")
 . ;. d log(jlog,"-1^Encounter code does not map: "_enccode)
 . i enccode="" s enccode=185349003 ; generic visit
 . do log(jlog,"code is: "_enccode)
 . set @eval@("encounters",zi,"vars","code")=enccode
 . ;
 . ;
 . new codesystem set codesystem=$get(@json@("entry",zi,"resource","type",1,"coding",1,"system"))
 . do log(jlog,"code system is: "_codesystem)
 . set @eval@("encounters",zi,"vars","codeSystem")=codesystem
 . ;
 . ; determine the reason code and system (Encounter Diagnosis)
 . ;
 . n reasoncode s reasoncode=$get(@json@("entry",zi,"resource","reason","coding",1,"code"))
 . i reasoncode="" s reasoncode=$get(@json@("entry",zi,"resource","reasonCode",1,"coding",1,"code"))
 . d log(jlog,"reasonCode is: "_reasoncode)
 . set @eval@("encounters",zi,"vars","reasonCode")=reasoncode
 . ;
 . ; determine reason code system
 . ;
 . new reasoncdsys set reasoncdsys=$get(@json@("entry",zi,"resource","reason","coding",1,"system"))
 . i reasoncdsys="" set reasoncdsys=$get(@json@("entry",zi,"resource","reasonCode",1,"coding",1,"system"))
 . d log(jlog,"reasonCode system is: "_reasoncdsys)
 . set @eval@("encounters",zi,"vars","reasonCodeSys")=reasoncdsys
 . ;
 . ; determine the effective date
 . ;
 . new effdate set effdate=$get(@json@("entry",zi,"resource","period","start"))
 . i effdate="" s effdate=$get(@json@("entry",zi,"resource","period","end"))
 . i effdate="" s effdate=$get(@json@("entry",zi,"resource","meta","lastUpdated"))
 . do log(jlog,"effectiveDateTime is: "_effdate)
 . set @eval@("encounters",zi,"vars","effectiveDateTime")=effdate
 . new fmtime s fmtime=$$fhirTfm^SYNFUTL(effdate)
 . d log(jlog,"fileman dateTime is: "_fmtime)
 . set @eval@("encounters",zi,"vars","fmDateTime")=fmtime ;
 . ; 1=ICD-9, 30=ICD-10, 0=SNOMED (ENCTUPD uses ^SYN map); heuristic uses encounter date
 . new dxIcdCs s dxIcdCs=$$DXICDCS^SYNDHP61(reasoncdsys)
 . i dxIcdCs=0,reasoncode'="",reasoncdsys="",reasoncode["." s dxIcdCs=$select(fmtime<3151001:1,1:30)
 . d log(jlog,"reason DX ICDEX cs (0=SNOMED): "_dxIcdCs)
 . set @eval@("encounters",zi,"vars","dxIcdCs")=dxIcdCs
 . new hl7time s hl7time=$$fhirThl7^SYNFUTL(effdate)
 . d log(jlog,"hl7 dateTime is: "_hl7time)
 . set @eval@("encounters",zi,"vars","hl7DateTime")=hl7time ;
 . ;
 . new effdateEnd set effdateEnd=$get(@json@("entry",zi,"resource","period","end"))
 . do log(jlog,"endDateTime is: "_effdateEnd)
 . set @eval@("encounters",zi,"vars","endDateTime")=effdateEnd
 . new fmtimeEnd s fmtimeEnd=$$fhirTfm^SYNFUTL(effdateEnd)
 . d log(jlog,"fileman endDateTime is: "_fmtimeEnd)
 . set @eval@("encounters",zi,"vars","fmEndDateTime")=fmtimeEnd ;
 . new hl7endTime s hl7endTime=$$fhirThl7^SYNFUTL(effdateEnd)
 . d log(jlog,"hl7 endDateTime is: "_hl7endTime)
 . set @eval@("encounters",zi,"vars","hl7endDateTime")=hl7endTime ;
 . ;
 . ; set up to call the data loader
 . ;
 . ;ENCTUPD(RETSTA,DHPPAT,STARTDT,ENDDT,ENCPROV,CLINIC,SCTDX,SCTCPT)     ;Encounter update
 . ;
 . n RETSTA,DHPPAT,STARTDT,ENDDT,ENCPROV,CLINIC,SCTDX,SCTCPT
 . ;
 . s DHPPAT=$$dfn2icn^SYNFUTL(dfn)
 . s @eval@("encounters",zi,"parms","DHPPAT")=DHPPAT
 . ;
 . s SCTCPT=enccode
 . s @eval@("encounters",zi,"parms","SCTCPT")=SCTCPT
 . ;
 . ; reason code
 . s SCTDX=reasoncode
 . s @eval@("encounters",zi,"parms","SCTDX")=SCTDX
 . ;
 . s STARTDT=hl7time
 . s @eval@("encounters",zi,"parms","STARTDT")=hl7time
 . d log(jlog,"HL7 StartDateTime is: "_hl7time)
 . ;
 . s ENDDT=hl7endTime
 . s @eval@("encounters",zi,"parms","ENDDT")=ENDDT
 . d log(jlog,"HL7 End DateTime is: "_ENDDT)
 . ;
 . ; reason code
 . s SCTDX=reasoncode
 . n icdcode,icdcodetype,notmapped,sctcode
 . s icdcode=""
 . s sctcode=reasoncode
 . s notmapped=0
 . ;i sctcode'="" q:'$d(^BSTS)  d
 . i sctcode'=""  d  ;
 . . i dxIcdCs=1!(dxIcdCs=30) d  ;
 . . . n icdtx s icdtx=$$ICDDX^ICDEX(sctcode,dxIcdCs)
 . . . s icdcode=+icdtx
 . . . i icdcode=-1 s notmapped=1
 . . . d log(jlog,"direct ICD lookup ("_dxIcdCs_") is: "_icdcode)
 . . e  d  ;
 . . . i fmtime<3151001 s icdcodetype="icd9"
 . . . e  s icdcodetype="icd10"
 . . . d log(jlog,"icd code type is: "_icdcodetype)
 . . . i icdcodetype="icd9" s icdcode=$$MAP^SYNDHPMP("sct2icdnine",sctcode)
 . . . e  s icdcode=$$MAP^SYNDHPMP("sct2icd",sctcode)
 . . . i +icdcode=-1 s notmapped=1
 . . . d:notmapped MAPERR^SYNQLDM(sctcode,icdcodetype)
 . . . do log(jlog,"icd mapping is: "_icdcode)
 . . . do:notmapped log(jlog,"snomed code "_sctcode_" is not mapped")
 . . set @eval@("conditions",zi,"vars","mappedIcdCode")=icdcode
 . s @eval@("encounters",zi,"parms","SCTDX")=SCTDX
 . s @eval@("encounters",zi,"parms","DXICDCS")=dxIcdCs
 . ;
 . s ENCPROV=$$MAP^SYNQLDM("OP","provider") ; map should return the NPI number
 . ;n DHPPROVIEN s DHPPROVIEN=$o(^VA(200,"B",ENCPROV,"")) ; this has to be the NPI number
 . ;if DHPPROVIEN="" S DHPPROVIEN=3
 . s @eval@("encounters",zi,"parms","ENCPROV")=ENCPROV
 . d log(jlog,"Provider for outpatient is: "_ENCPROV)
 . ;
 . s CLINIC=$$MAP^SYNQLDM("OP","location") ; map containes the name of the clinic file #44
 . ;n DHPLOCIEN s DHPLOCIEN=$o(^SC("B",CLINIC,""))
 . ;if DHPLOCIEN="" S DHPLOCIEN=4
 . s @eval@("encounters",zi,"parms","CLINIC")=CLINIC
 . d log(jlog,"Location for outpatient is: "_CLINIC)
 . ;
 . s @eval@("encounters",zi,"status","loadstatus")="readyToLoad"
 . ;
 . if $g(args("load"))=1 d  ; only load if told to
 . . if $g(ien)="" n ien s ien=$$dfn2ien^SYNFUTL(dfn)
 . . i ien="" q  ;
 . . if $$loadStatus("encounters",zi,ien)=1 do  quit  ;
 . . . d log(jlog,"Encounter already loaded, skipping")
 . . i hl7time="" d
 . . . s RETSTA="-1^Missing encounter visit date (period.start/end)"
 . . . d log(jlog,"Skipping ENCTUPD: no HL7 start date")
 . . e  d
 . . . d log(jlog,"Calling ENCTUPD^SYNDHP61 data loader to add encounter")
 . . . d ENCTUPD^SYNDHP61(.RETSTA,DHPPAT,STARTDT,ENDDT,ENCPROV,CLINIC,SCTDX,SCTCPT,dxIcdCs)        ;Encounter update
 . . d log(jlog,"Return from data loader was: "_$g(RETSTA))
 . . ;
 . . ; MERGE keeps destination subscripts not present in RETSTA - stale ENCDATA/DIERR from prior runs otherwise.
 . . k @eval@("encounters",zi,"status","return")
 . . m @eval@("encounters",zi,"status","return")=RETSTA
 . . n visitIen s visitIen=$p(RETSTA,"^",2) ; returned visit ien
 . . i +visitIen>0 d
 . . . ;
 . . . n groot s groot=$na(@root@(ien))
 . . . d setIndex^SYNFHIR(groot,id,"visitIen",visitIen) ; save the visit ien in the indexes
 . . . s @eval@("encounters",zi,"visitIen")=visitIen
 . . e  s visitIen=""
 . . if +$g(RETSTA)=1 do  ;
 . . . s @eval@("encounters","status","loaded")=$g(@eval@("encounters","status","loaded"))+1
 . . . s @eval@("encounters",zi,"status","loadstatus")="loaded"
 . . . s @eval@("encounters",zi,"status","loadMessage")=$g(RETSTA)
 . . else  d  ;
 . . . s @eval@("encounters","status","errors")=$g(@eval@("encounters","status","errors"))+1
 . . . s @eval@("encounters",zi,"status","loadstatus")="notLoaded"
 . . . s @eval@("encounters",zi,"status","loadMessage")=$g(RETSTA)
 . . ; Do not KILL encounters,zi here - only return was cleared above before merge. Data already lives at @root@(ien,"load","encounters",zi).
 . . ; FHIR Encounter.note -> fhir-intake graph (TONOTEZI) + visit-linked TIU (MAKE^TIUSRVP)
 . . i +$g(RETSTA)=1,+visitIen>0,$g(args("skipEncounterNotes"))'=1,$t(INGESTFHIR^SYNFTIU)'="" d  ;
 . . . d INGESTFHIR^SYNFTIU(ien,zi,id,dfn,visitIen,jlog,.json,.args)
 . . . i $d(@root@(ien,"load","encounters",zi,"note")) m @eval@("encounters",zi,"note")=@root@(ien,"load","encounters",zi,"note")
 ;
 if $get(args("debug"))=1 do  ;
 . m jrslt("source")=json
 . m jrslt("args")=args
 . m jrslt("eval")=@eval
 m jrslt("encountersStatus")=@eval@("encountersStatus")
 set jrslt("result","status")="ok"
 set jrslt("result","loaded")=$g(@eval@("encounters","status","loaded"))
 set jrslt("result","errors")=$g(@eval@("encounters","status","errors"))
 m result("status")=jrslt("result")
 q
 ;
log(ary,txt)    ; adds a text line to @ary@("log")
 s @ary@("log",$o(@ary@("log",""),-1)+1)=$g(txt)
 w:$G(DEBUG) !,"      ",$G(txt)
 q
 ;
loadStatus(typ,zx,zien) ; extrinsic return 1 if resource was loaded
 n root s root=$$setroot^SYNWD("fhir-intake")
 n rt s rt=0
 i $g(zx)="" i $d(@root@(zien,"load",typ)) s rt=1 q rt
 i $get(@root@(zien,"load",typ,zx,"status","loadstatus"))="loaded" s rt=1
 q rt
 ;
retryEncounterTiuNotes(rtn,ien,args) ; File missing TIU from Encounter.note (plain text); bypasses encounter loadStatus skip
 ; For patients where ENCTUPD ran and load.encounters status is "loaded" but INGESTFHIR never filed (e.g. first replay skipped).
 ; Idempotent: INGESTFHIR^SYNFTIU skips note indices that already have @jlog@("tiu",ni,"ien").
 ; Call via replayIntakeDomains with args("retryEncounterTiuNotes")=1 or GET replayIntake?dfn=&retryEncounterTiuNotes=1
 n root,troot,eval,json,dfn,zi,id,jlog,knownVisit,ni,skipped,filed,all
 k rtn("retryEncounterTiuNotes")
 s root=$$setroot^SYNWD("fhir-intake")
 s dfn=$$ien2dfn^SYNFUTL(ien)
 i +dfn<1 s rtn("retryEncounterTiuNotes","status")="error",rtn("retryEncounterTiuNotes","reason")="no DFN for graph ien" q
 s troot=$na(@root@(ien,"type","Encounter"))
 s json=$na(@root@(ien,"json"))
 s eval=$na(@root@(ien,"load"))
 s (skipped,filed)=0
 s zi=0
 f  s zi=$o(@troot@(zi)) q:+zi=0  d
 . s jlog=$na(@eval@("encounters",zi))
 . i $g(@json@("entry",zi,"resource","resourceType"))'="Encounter" q
 . i $o(@json@("entry",zi,"resource","note",""))="" s skipped=skipped+1 q
 . s ni="",all=1
 . f  s ni=$o(@json@("entry",zi,"resource","note",ni)) q:ni=""  q:ni'=+ni  d
 . . i +$g(@eval@("encounters",zi,"tiu",ni,"ien"))<1 s all=0
 . i all s skipped=skipped+1 q
 . s id=$g(@json@("entry",zi,"resource","id"))
 . s knownVisit=$$visitIen^SYNFENC(ien,id)
 . i +knownVisit<1 d log(jlog,"retryTiuNotes: no visitIen for encounter id="_id) s skipped=skipped+1 q
 . d INGESTFHIR^SYNFTIU(ien,zi,id,dfn,knownVisit,jlog,.json,.args)
 . i $d(@root@(ien,"load","encounters",zi,"note")) m @eval@("encounters",zi,"note")=@root@(ien,"load","encounters",zi,"note")
 . s filed=filed+1
 s rtn("retryEncounterTiuNotes","status")="ok"
 s rtn("retryEncounterTiuNotes","encountersNotesFiled")=filed
 s rtn("retryEncounterTiuNotes","encountersSkipped")=skipped
 q
 ;
visitIen(ien,encId)     ; extrinsic returns the visit ien for the Encounter ID
 ; returns -1 if none found
 i $g(encId)="" q -1
 n root s root=$$setroot^SYNWD("fhir-intake")
 n useenc s useenc=encId
 i useenc["urn:uuid:" s useenc=$p(useenc,"urn:uuid:",2)
 i useenc["Encounter/" s useenc=$p(useenc,"Encounter/",2)
 n vrtn
 s vrtn=$o(@root@(ien,"SPO",useenc,"visitIen",""))
 i vrtn'="" q vrtn
 n zi
 s zi=0
 f  s zi=$o(@root@(ien,"load","encounters",zi)) q:+zi=0  d  q:vrtn'=""
 . q:$g(@root@(ien,"json","entry",zi,"resource","id"))'=useenc
 . s vrtn=$g(@root@(ien,"load","encounters",zi,"visitIen"))
 i vrtn="" s vrtn=-1
 q vrtn
 ;
testall ; run the encounters import on all imported patients
 new root s root=$$setroot^SYNWD("fhir-intake")
 new indx s indx=$na(@root@("POS","DFN"))
 n dfn,ien,filter,reslt
 s dfn=0
 f  s dfn=$o(@indx@(dfn)) q:+dfn=0  d  ;
 . s ien=$o(@indx@(dfn,""))
 . q:ien=""
 . s filter("dfn")=dfn
 . k reslt
 . d wsIntakeEncounters(.filter,,.reslt,ien)
 q
 ;
IMPORT(rtn,ien) ; encounters, immunizations, problems for patient ien
 n filter
 k rtn
 s filter("load")=1
 s filter("debug")=1
 d importEncounters^SYNFENC(.rtn,ien,.filter)
 d importImmu^SYNFIMM(.rtn,ien,.filter)
 d importConditions^SYNFPR2(.rtn,ien,.filter)
 q
 ;
 ;
LOADALL(count) ; count is how many to do. default is 1000
 D INITMAPS^SYNQLDM ; make sure map table is loaded
 i '$d(count) s count=1000
 n root s groot=$$setroot^SYNWD("fhir-intake")
 n cnt s cnt=0
 n %1 s %1=0
 f  s %1=$o(@groot@(%1)) q:+%1=0  q:cnt=count  d  ;
 . n eroot s eroot=$na(@groot@(%1,"load","encounters"))
 . q:$d(@eroot)
 . q:%1=33
 . q:%1=82
 . q:$g(@eroot@("loadstatus"))="started"
 . s cnt=cnt+1
 . s @eroot@("loadstatus")="started"
 . n filter
 . s filter("load")=1
 . n g s $p(g,"+",80)="" w !,g
 . w !,"loading "_%1_" "_$$FMTE^XLFDT($$NOW^XLFDT)
 . w !,g
 . n rtn
 . ;d taskLabs^SYNFHIR(.rtn,%1,.filter)
 . d importEncounters^SYNFENC(.rtn,%1,.filter)
 . d importImmu^SYNFIMM(.rtn,%1,.filter)
 . d importConditions^SYNFPRB(.rtn,%1,.filter)
 . do importAppointment^SYNFAPT(.return,%1,.filter)
 . ;do importMeds^SYNFMED2(.return,%1,.filter)
 . do importProcedures^SYNFPROC(.return,%1,.filter)
 q
 ;
NEXT(start) ; extrinsic which returns the next patient for encounter loading
 ; start is the dfn to start looking, default is zerro
 i '$d(start) s start=0
 n root s groot=$$setroot^SYNWD("fhir-intake")
 n %1 s %1=start
 n returnien s returnien=0
 f  s %1=$o(@groot@(%1)) q:+%1=0  q:+returnien>0  d  ;
 . n eroot s eroot=$na(@groot@(%1,"load","encounters"))
 . q:$d(@eroot)
 . q:%1=33
 . q:%1=82
 . q:$g(@eroot@("loadstatus"))="started"
 . s returnien=%1
 q returnien
 ;
