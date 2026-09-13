SYNFPAN ;ven/gpl - fhir loader utilities ;2018-05-08  4:23 PM
 ;;0.7;VISTA SYN DATA LOADER;;Mar 18, 2025
 ;
 ; Copyright (c) 2025 DocMe360 LLC
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
 q
 ;
importPanels(rtn,ien,args) ; entry point for loading lab panels for a patient
 ; calls the intake Labs web service directly
 ;
 n grtn
 n root s root=$$setroot^SYNWD("fhir-intake")
 n % s %=$$wsIntakePanels(.args,,.grtn,ien)
 ;i $d(grtn) d  ; something was returned
 ;. k @root@(ien,"load","panels")
 ;. m @root@(ien,"load","panels")=grtn("panels")
 ;. if $g(args("debug"))=1 m rtn=grtn
 if $g(args("debug"))=1 m rtn=grtn
 s rtn("panelStatus","status")=$g(grtn("status","status"),"unknown")
 s rtn("panelStatus","loaded")=+$g(grtn("status","loaded"))
 s rtn("panelStatus","errors")=+$g(grtn("status","errors"))
 ;b
 ;
 ;
 q
 ;
PNOUT(rtn,jrslt,eval,st,ldov,erov) ; set rtn("status",*) for wsIntakePanels (all exit paths)
 ; st=ok|skipped|error; ldov/erov optional numeric overrides ("" = from eval panels counters)
 n ld,er
 s ld=$s($g(ldov)'="":+ldov,$g(eval)'="":+$g(@eval@("panels","status","loaded")),1:0)
 s er=$s($g(erov)'="":+erov,$g(eval)'="":+$g(@eval@("panels","status","errors")),1:0)
 k jrslt("result")
 i $g(eval)'="",$d(@eval@("labsStatus")) m jrslt("labsStatus")=@eval@("labsStatus")
 e  k jrslt("labsStatus")
 s jrslt("result","status")=$g(st,"ok")
 s jrslt("result","loaded")=ld
 s jrslt("result","errors")=er
 m rtn("status")=jrslt("result")
 q
 ;
wsIntakePanels(SYNARGS,SYNBODY,SYNRSLT,SYNIEN) ; web service entry (post)
 ; for intake of one or more Lab panel results. input are fhir resources
 ; SYNRSLT is json and summarizes what was done
 ; SYNARGS include patientId
 ; SYNIEN is specified for internal calls, where the json is already in a graph
 ;
 ; NOTE on naming: every local this routine needs across a LAB^ISIIMP12 call
 ; is SYN-namespaced. The ISI filer's LR* lab chain KILLs common local names
 ; out from under the caller (same class as the PSO chain killing
 ; args("load") in SYNFMED2 and the Day-4 LAST kill): with the old names
 ; (troot/eval/json/args...) the panel loop died after the first filed
 ; panel — 2 of 316 entries processed on the iris lane, silent stop.
 ; Formal parameters are positional, so callers are unaffected.
 ;
 n SYNROOT,SYNTROOT
 s SYNROOT=$$setroot^SYNWD("fhir-intake")
 ;
 n SYNJSON,SYNJRSLT,SYNEVAL
 s (SYNTROOT,SYNEVAL)=""
 i $g(SYNIEN)'="" d  ; internal call
 . s SYNTROOT=$na(@SYNROOT@(SYNIEN,"type","DiagnosticReport"))
 . s SYNEVAL=$na(@SYNROOT@(SYNIEN,"load")) ; move eval to the graph
 ; todo: locate the patient and add the labs in BODY to the graph
 ;   this is for the use case when we are processing an update to
 ;   the patient rather than the initial load
 ;
 i $g(SYNIEN)="" d PNOUT^SYNFPAN(.SYNRSLT,.SYNJRSLT,"","skipped",0,0) q 0
 i '$d(@SYNTROOT) d PNOUT^SYNFPAN(.SYNRSLT,.SYNJRSLT,.SYNEVAL,"skipped",0,0) q 0
 s SYNJSON=$na(@SYNROOT@(SYNIEN,"json"))
 ;
 ; Initialize panel counters on graph load node
 s @SYNEVAL@("panels","status","errors")=0
 s @SYNEVAL@("panels","status","loaded")=0
 ;
 ; snapshot request flags (survive any downstream kill)
 n SYNLOAD,SYNDBG
 s SYNLOAD=+$g(SYNARGS("load")),SYNDBG=+$g(SYNARGS("debug"))
 ;
 ; determine the patient
 ;
 n SYNDFN
 if $g(SYNIEN)'="" d  ;
 . s SYNDFN=$$ien2dfn^SYNFUTL(SYNIEN) ; look up dfn in the graph
 else  d  ;
 . s SYNDFN=$g(SYNARGS("dfn"))
 . i SYNDFN="" d  ;
 . . n icn s icn=$g(SYNARGS("icn"))
 . . i icn'="" s SYNDFN=$$icn2dfn^SYNFUTL(icn)
 i $g(SYNDFN)="" d  q 0  ; need the patient
 . s SYNRSLT("panels",1,"log",1)="Error, patient not found.. terminating"
 . d PNOUT^SYNFPAN(.SYNRSLT,.SYNJRSLT,.SYNEVAL,"error",0,0)
 ;
 ;
 new SYNZI s SYNZI=0
 for  set SYNZI=$order(@SYNTROOT@(SYNZI)) quit:+SYNZI=0  do  ;
 . ;
 . ; define a place to log the processing of this entry
 . ;
 . new SYNJLOG set SYNJLOG=$name(@SYNEVAL@("panels",SYNZI))
 . ; clear only log+vars: killing the whole entry node destroyed the
 . ; "status","loadstatus"="loaded" marker BEFORE the loadStatus skip check,
 . ; so every rerun refiled every panel (proven: run2 on a CI container
 . ; re-accessioned all 11 panels). The marker must survive reruns.
 . k @SYNJLOG@("log"),@SYNJLOG@("vars")
 . ;
 . ; ensure that the resourceType is DiagnosticReports
 . ;
 . new type set type=$get(@SYNJSON@("entry",SYNZI,"resource","resourceType"))
 . q:type'="DiagnosticReport"
 . ;
 . ; determine the DiagnosticReport category and quit if not a lab panel
 . ;
 . new catcode set catcode=$get(@SYNJSON@("entry",SYNZI,"resource","category",1,"coding",1,"code"))
 . q:$$UP^XLFSTR(catcode)'["LAB"
 . new loinc s loinc=""
 . set loinc=$g(@SYNJSON@("entry",SYNZI,"resource","code","coding",1,"code"))
 . d log(SYNJLOG,"Panel loinc code is  "_loinc)
 . ;
 . ; see if this resource has already been loaded. if so, skip it
 . ;
 . if $g(SYNIEN)'="" if $$loadStatus("panels",SYNZI,SYNIEN)=1 do  quit  ;
 . . d log(SYNJLOG,"Panel already loaded, skipping")
 . ;
 . ; determine Panel type, code, coding system, and display text
 . ;
 . new paneltype set paneltype=$get(@SYNJSON@("entry",SYNZI,"resource","code","text"))
 . if paneltype="" set paneltype=$get(@SYNJSON@("entry",SYNZI,"resource","code","coding",1,"display"))
 . do log(SYNJLOG,"Panel type is: "_paneltype)
 . set @SYNEVAL@("panels",SYNZI,"vars","type")=paneltype
 . ;
 . ; determine the id of the resource
 . ;
 . new id set id=$get(@SYNJSON@("entry",SYNZI,"resource","id"))
 . set @SYNEVAL@("panels",SYNZI,"vars","id")=id
 . d log(SYNJLOG,"ID is: "_id)
 . ;
 . ;Here's the spec for uploading a panel:
 . ;KBANTEST ;
 . ;N %,SAM,RC
 . ;S SAM("LAB_PANEL")="CHEM 7"
 . ;S SAM("LAB_TEST","BUN")=10
 . ;S SAM("LAB_TEST","CO2")=34
 . ;S SAM("LAB_TEST","GLUCOSE")=180
 . ;S SAM("PAT_SSN")="999504449"
 . ;S SAM("RESULT_DT")="NOW"
 . ;S SAM("LOCATION")="3E NORTH"
 . ;S SAM("COLLECTION_SAMPLE")="BLOOD" ; optional
 . ;S %=$$LAB^ISIIMP12(.RC,.SAM)
 . ;ZWRITE RC
 . ;QUIT
 . ;
 . ; starting the parameter array with the panel level elements
 . ;
 . n SYNMISC ; parameter array
 . ;
 . ; lab panel
 . ;
 . N PANEL
 . S PANEL=$$MAP^SYNQLDM(loinc,"vistapanel")
 . i PANEL="" do  quit
 . . d fail(SYNJLOG,SYNEVAL,SYNZI,"Return: -1^Panel with loinc "_loinc_" has no mapping to a VistA Lab Panel")
 . d log(SYNJLOG,"VistA panel is: "_PANEL)
 . S SYNMISC("LAB_PANEL")=PANEL
 . ;
 . ; patient
 . ;
 . s SYNMISC("PAT_SSN")=$$GET1^DIQ(2,SYNDFN_",","SSN")
 . ;
 . ; result date/time
 . ;
 . new effdate set effdate=$get(@SYNJSON@("entry",SYNZI,"resource","effectiveDateTime"))
 . do log(SYNJLOG,"effectiveDateTime is: "_effdate)
 . set @SYNEVAL@("panels",SYNZI,"vars","effectiveDateTime")=effdate
 . new fmtime s fmtime=$$fhirTfm^SYNFUTL(effdate)
 . d log(SYNJLOG,"fileman dateTime is: "_fmtime)
 . set @SYNEVAL@("panels",SYNZI,"vars","fmDateTime")=fmtime ;
 . new hl7time s hl7time=$$fhirThl7^SYNFUTL(effdate)
 . d log(SYNJLOG,"hl7 dateTime is: "_hl7time)
 . set @SYNEVAL@("panels",SYNZI,"vars","hl7DateTime")=hl7time ;
 . s SYNMISC("RESULT_DT")=fmtime
 . ;
 . ; location
 . ;
 . n SYNDHPLC s SYNDHPLC=$$MAP^SYNQLDM("OP","location")
 . n DHPLOCIEN s DHPLOCIEN=$o(^SC("B",SYNDHPLC,""))
 . if DHPLOCIEN="" S DHPLOCIEN=4
 . d log(SYNJLOG,"Location for outpatient is: #"_DHPLOCIEN_" "_SYNDHPLC)
 . s SYNMISC("LOCATION")=SYNDHPLC
 . ;
 . ; collection sample
 . ;
 . n CSAMP
 . S CSAMP=$$GET1^DIQ(95.3,$p(loinc,"-"),4)
 . I CSAMP["SER/PLAS" S CSAMP="SERUM"
 . I CSAMP["Whole blood" S CSAMP="BLOOD"
 . I CSAMP["Blood venous" S CSAMP="BLOOD"
 . I CSAMP["Urine Sediment" S CSAMP="URINE"
 . I CSAMP["Platelet poor plasma" S CSAMP="PLASMA"
 . I CSAMP["Blood arterial" S CSAMP="ARTERIAL BLOOD"
 . d log(SYNJLOG,"Collection sample is: "_CSAMP)
 . s SYNMISC("COLLECTION_SAMPLE")=CSAMP
 . ;
 . ;  ; add code to process DiagnosticReport results here
 . ;
 . n triples s triples=$na(@SYNROOT@(SYNIEN))
 . n atomptr s atomptr=$na(@SYNJSON@("entry",SYNZI,"resource","result"))
 . n atomdisp s atomdisp=""
 . n SYNSUCC s SYNSUCC="" ; array of labs to be marked as loaded on success
 . n rien s rien=""
 . n zj s zj=0
 . f  s zj=$o(@atomptr@(zj)) q:+zj=0  d  ;
 . . s atomdisp=$get(@atomptr@(zj,"display"))
 . . n atomref s atomref=$get(@atomptr@(zj,"reference"))
 . . s rien=$o(@triples@("SPO",atomref,"rien",""))
 . . d log(SYNJLOG,zj_" result "_atomdisp_" rien="_rien)
 . . ;
 . . ; call one result lab
 . . ;
 . . n lablog s lablog=$na(@SYNROOT@(SYNIEN,"load","labs",rien))
 . . D ONELAB(.SYNMISC,SYNJSON,rien,zj,SYNJLOG,SYNEVAL,lablog,.SYNSUCC,atomdisp)
 . . ;
 . m @SYNEVAL@("panels",SYNZI,"vars","MISC")=SYNMISC ;
 . ;
 . if SYNLOAD=1 d  ; only load if told to
 . . if $g(SYNIEN)'="" if $$loadStatus("panels",SYNZI,SYNIEN)=1 do  quit  ;
 . . . d log(SYNJLOG,"Panel already loaded, skipping")
 . . d log(SYNJLOG,"Calling LAB^ISIIMP12 to add panel")
 . . n SYNRESTA,SYNRC
 . . s (SYNRESTA,SYNRC)=""
 . . S SYNRESTA=$$LAB^ISIIMP12(.SYNRC,.SYNMISC)
 . . ;
 . . if +SYNRESTA=1 do  ;
 . . . d log(SYNJLOG,"Return from LAB^ISIIMP12 was: "_$g(SYNRESTA))
 . . . s @SYNEVAL@("panels","status","loaded")=@SYNEVAL@("panels","status","loaded")+1
 . . . s @SYNEVAL@("panels",SYNZI,"status","loadstatus")="loaded"
 . . . d SUCCESS(SYNZI,.SYNSUCC,SYNEVAL,SYNIEN) ; mark labs as loaded
 . . else  d fail(SYNJLOG,SYNEVAL,SYNZI,"Return from LAB^ISIIMP12 was: "_$g(SYNRESTA))
 ;
 if SYNDBG=1 do  ;
 . m SYNJRSLT("source")=@SYNJSON
 . m SYNJRSLT("args")=SYNARGS
 . m SYNJRSLT("eval")=@SYNEVAL
 d PNOUT^SYNFPAN(.SYNRSLT,.SYNJRSLT,.SYNEVAL,"ok",,)
 q:$Q 0 Q
 ;
SUCCESS(SYNZI,success,eval,ien) ; after a panel has loaded, mark the successful lab tests as loaded
 ;
 n root s root=$$setroot^SYNWD("fhir-intake")
 ;
 n sucien s sucien=""
 f  s sucien=$o(success(sucien)) q:sucien=""  d  ;
 . n lablog s lablog=$na(@root@(ien,"load","labs",sucien))
 . d log(lablog,"Return from LAB^ISIIMP12 was: 1^Part of a Lab Panel "_SYNZI)
 . s @eval@("labs",sucien,"status","loadstatus")="loaded"
 . i '$d(@eval@("labs","status","loaded")) s @eval@("labs","status","loaded")=0
 . s @eval@("labs","status","loaded")=@eval@("labs","status","loaded")+1
 ;
 Q
 ;
ONELAB(MISCARY,json,ien,zj,jlog,eval,lablog,callbak,atomdisp)
 ;
 new obscode set obscode=$get(@json@("entry",ien,"resource","code","coding",1,"code"))
 do log(lablog,"result "_zj_" code is: "_obscode)
 do log(jlog,"result "_zj_" code is: "_obscode)
 set @eval@("labs",SYNZI,"vars",zj_" code")=obscode
 ;
 I $G(DEBUG2) W !,obscode," ",atomdisp
 ;
 new codesystem set codesystem=$get(@json@("entry",ien,"resource","code","coding",1,"system"))
 do log(jlog,"result "_zj_" code system is: "_codesystem)
 do log(lablog,"result "_zj_" code system is: "_codesystem)
 set @eval@("labs",SYNZI,"vars",zj_" codeSystem")=codesystem
 ;
 ; determine the value and units
 ;
 new value set value=$get(@json@("entry",ien,"resource","valueQuantity","value"))
 if value="" d  ;
 . new sctcode,scttxt
 . s sctcode=$get(@json@("entry",ien,"resource","valueCodeableConcept","coding",1,"code"))
 . s scttxt=$get(@json@("entry",ien,"resource","valueCodeableConcept","coding",1,"display"))
 . s value=sctcode_"^"_scttxt
 . do log(jlog,"result "_zj_" value before adjust is: "_value)
 . d ADJUST(.value)
 . do log(jlog,"result "_zj_" value after adjust is: "_value)
 else  d  ;
 . ;
 . ; source: https://doi.org/10.30574/gscbps.2023.22.2.0091
 . ;
 . if obscode="5792-7" d  ; Glucose
 . . n x s x=value
 . . s value=$s(x<100:"NEG",x<250:"TRACE",x<500:"1+",x<1000:"2+",x<2000:"3+",1:"4+")
 . if obscode="5804-0" d  ; Protein
 . . n x s x=value
 . . s value=$s(x<15:"NEG",x<30:"TRACE",x<100:"1+",x<300:"2+",x<1000:"3+",1:"4+")
 . if atomdisp["[Presence]" d  ; Various presence values
 . . s value=$s(value=0:"NEG",1:value)
 ;
 i value="" d  quit
 . do log(jlog,"result "_zj_" value is null, quitting")
 . do log(lablog,"result "_zj_" value is null, quitting")
 do log(jlog,"result "_zj_" value is: "_value)
 do log(lablog,"result "_zj_" value is: "_value)
 set @eval@("labs",SYNZI,"vars",zj_" value")=value
 ;
 ;new unit set unit=$get(@json@("entry",SYNZI,"resource","valueQuantity","unit"))
 ;do log(jlog,"units are: "_unit)
 ;set @eval@("labs",SYNZI,"vars","units")=unit
 ;
 ; add to MISCARY
 ;
 n VLAB ; VistA lab name
 s VLAB=$$MAP^SYNQLDM(obscode,"labs")
 i VLAB="" d  quit
 . do log(jlog,"result "_zj_" VistA Lab not found for loinc="_obscode)
 . do log(lablog,"result "_zj_" VistA Lab not found for loinc="_obscode)
 . i $g(DEBUG2) W !,"result "_zj_" VistA Lab not found for loinc="_obscode
 ;
 ; Check if lab is member of a panel; if not, don't add, lab filer will file it later
 I '$$PMEM^ISIIMPU7(MISCARY("LAB_PANEL"),VLAB) d  quit
 . do log(jlog,"result "_zj_" Lab "_VLAB_" not in Panel "_MISCARY("LAB_PANEL"))
 . do log(lablog,"result "_zj_" Lab "_VLAB_" not in Panel "_MISCARY("LAB_PANEL"))
 ;
 d log(jlog,"result "_zj_" VistA Lab for "_obscode_" is: "_VLAB)
 d log(lablog,"result "_zj_" VistA Lab for "_obscode_" is: "_VLAB)
 i $g(DEBUG2) W !,"result "_zj_" VistA Lab for "_obscode_" is: "_VLAB
 s MISCARY("LAB_TEST",VLAB)=value
 ;
 s callbak(ien,VLAB)="" ; call back pointer to be used if panel is successful to mark the lab as loaded
 ;
 ;
 Q
 ;
ADJUST(ZV) ; adjust the value for specific text based values
 ;
 i ZV["^",$L(ZV)=1 S ZV="" Q
 i ZV["394717006^Urine leukocytes not detected (finding)" S ZV="NEG" Q
 i ZV["314137006^Nitrite detected in urine (finding)" S ZV="NEG" Q
 i ZV["394712000^Urine leukocyte test one plus (finding)" S ZV="1+" Q
 i ZV["276409005^Mucus in urine (finding)" S ZV="1+" Q
 i ZV["167287002^Urine ketones not detected (finding)" S ZV="NEG" Q
 i ZV["167336003^Urine microscopy: no casts (finding)" S ZV="NoneObs" Q
 i ZV["365691004^Finding of presence of bacteria (finding)" S ZV="1+" Q
 i ZV["+" D  Q
 . i ZV["++++" S ZV="4+" Q
 . i ZV["+++"  S ZV="3+" Q
 . i ZV["++"   S ZV="2+" Q
 . i ZV["+"    S ZV="1+" Q
 s:ZV["Brown" ZV="BROWN"
 s:ZV["Redish" ZV="REDISH"
 s:ZV["Cloudy" ZV="CLOUDY"
 s:ZV["Translucent" ZV="BROWN"
 s:ZV["Foul" ZV="FOUL"
 s:ZV["not detected in urine" ZV="NEG"
 s:ZV["Finding of bilirubin in urine" ZV="1+"
 i ZV["trace" S ZV="TRACE"
 Q
 ;
INITMAPS(LOC) ; initialize mapping table for panels
 ;
 ; This routine is called by INITMAPS^SYNQLDM - don't run it directly
 ;
 N MAP
 ; vistapanel
 S MAP="vistapanel"
 ; Panel type is: 24321-2 Basic metabolic 2000 panel - Serum or Plasma
 S @LOC@(MAP,"CODE","24321-2","BASIC METABOLIC PANEL")=""
 ; Panel type is: 51990-0 Basic metabolic panel - Blood
 S @LOC@(MAP,"CODE","51990-0","BASIC METABOLIC PANEL")=""
 ; Panel type is: 24357-6 Urinalysis macro (dipstick) panel - Urine
 S @LOC@(MAP,"CODE","24357-6","URINALYSIS")=""
 ; Panel type is: 24356-8 Urinalysis complete panel - Urine
 S @LOC@(MAP,"CODE","24356-8","URINALYSIS")=""
 ; Panel type is: 57698-3 Lipid panel with direct LDL - Serum or Plasma
 S @LOC@(MAP,"CODE","57698-3","LIPID PROFILE")=""
 ; Panel type is: 58410-2 CBC panel - Blood by Automated count
 S @LOC@(MAP,"CODE","58410-2","CBC")=""
 ; Panel type is: 24323-8 Comprehensive metabolic 2000 panel - Serum or Plasma
 S @LOC@(MAP,"CODE","24323-8","CMP")=""
 ; Panel type is: 50190-8 Iron and Iron binding capacity panel - Serum or Plasma
 S @LOC@(MAP,"CODE","50190-8","IRON GROUP")=""
 ; Panel type is: 75689-0 Iron panel - Serum or Plasma
 ;S @LOC@(MAP,"CODE","75689-0","IRON GROUP")=""
 ; Panel type is:  89577-1 Troponin I.cardiac panel - Serum or Plasma by High sensitivity method
 ;S @LOC@(MAP,"CODE","89577-1","TROPONIN")=""
 ; Panel type is:  34528-0 PT panel - Platelet poor plasma by Coagulation assay
 S @LOC@(MAP,"CODE","34528-0","COAG PROFILE")=""
 ; CBC W Differential panel, method unspecified - Blood (69742-5) -> CBC
 S @LOC@(MAP,"CODE","69742-5","CBC")=""
 ; Auto Differential panel - Blood (57023-4) -> DIFFERENTIAL COUNT
 S @LOC@(MAP,"CODE","57023-4","DIFFERENTIAL COUNT")=""
 ; Gas panel - Venous blood (24339-4) -> BLOOD GASES
 S @LOC@(MAP,"CODE","24339-4","BLOOD GASES")=""
 ;
 Q
 ;
fail(jlog,eval,zrien,zmsg) ; standard way to mark a lab as failed and increment error count
 ;
 s @eval@("panels",zrien,"status","loadstatus")="readyToLoad"
 d log(jlog,zmsg)
 i '$d(@eval@("panels","status","errors")) s @eval@("panels","status","errors")=0
 s @eval@("panels","status","errors")=@eval@("panels","status","errors")+1
 ;
 q
 ;
log(ary,txt) ; adds a text line to @ary@("log")
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
testall ; run the panels import on all imported patients
 new root s root=$$setroot^SYNWD("fhir-intake")
 new indx s indx=$na(@root@("POS","DFN"))
 n dfn,ien,filter,reslt
 s dfn=0
 n cnt s cnt=0
 f  s dfn=$o(@indx@(dfn)) q:+dfn=0  q:cnt>0  d  ;
 . s ien=$o(@indx@(dfn,""))
 . s ien=196
 . w !,"ien= "_ien
 . q:ien=""
 . s cnt=cnt+1
 . s filter("dfn")=dfn
 . s filter("load")=1
 . s filter("debug")=1
 . k reslt
 . d wsIntakePanels(.filter,,.reslt,ien)
 q
 ;
panelsum ; summary of panel tests for patient ien pien
 n root s root=$$setroot^SYNWD("fhir-intake")
 n table
 n zzi s zzi=0
 f  s zzi=$o(@root@(zzi)) q:+zzi=0  d  ;
 . n panels
 . d getIntakeFhir^SYNFHIR("panels",,"DiagnosticReport",zzi,1)
 . n zi s zi=0
 . f  s zi=$o(panels("entry",zi)) q:+zi=0  d  ;
 . . n groot s groot=$na(panels("entry",zi,"resource"))
 . . i $g(@groot@("category",1,"coding",1,"code"))'="LAB" q  ;
 . . n loinc
 . . s loinc=$g(@groot@("code","coding",1,"code"))
 . . q:loinc=""
 . . ;i loinc="6082-2" b  ;
 . . n text s text=$g(@groot@("code","coding",1,"display"))
 . . i $d(table(loinc_" "_text)) d  ;
 . . . s table(loinc_" "_text)=table(loinc_" "_text)+1
 . . e  d  ;
 . . . s table(loinc_" "_text)=1
 . . . w !,"patient= "_zzi_" entry= "_zi,!
 . . . n rptary m rptary=@root@(zzi,"json","entry",zi,"resource")
 . . . ;zwrite rptary
 ;zwrite table
 q
 ;
