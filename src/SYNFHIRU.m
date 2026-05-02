SYNFHIRU ;ven/gpl - fhir loader utilities ;2018-08-17  3:27 PM
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
wsUpdatePatient(ARGS,BODY,RESULT)    ; recieve from updatepatient
 ;
 s U="^"
 ;S DUZ=1
 ;S DUZ("AG")="V"
 ;S DUZ(2)=500
 S USER=$$DUZ^SYNDHP69
 ;
 new json,ien,root,gr,id,return
 set root=$$setroot^SYNWD("fhir-intake")
 set id=$get(ARGS("id"))
 ;
 ; Locate graph row ien: query ien=, dfn= (VistA DFN on file), icn= / id= (full ICN string)
 ;
 n icn,had,dnx,newrow
 s (dnx,newrow)=0
 s had=0
 s ien=+$g(ARGS("ien")) i ien>0 s had=1
 i ien<1 s dnx=+$g(ARGS("dfn")) i dnx>0 s had=1,ien=$$dfn2ien^SYNFUTL(dnx)
 s icn=$g(ARGS("icn")) i icn="" s icn=$g(ARGS("id"))
 i ien<1,icn'="" s had=1,ien=$o(@root@("POS","ICN",icn,""))
 i ien<1,dnx<1,icn'="" s dnx=+$o(^DPT("AFICN",icn,""))
 i ien<1,dnx>0,$d(^DPT(dnx,0)) d
 . s ien=$order(@root@(" "),-1)+1
 . s newrow=1
 i ien<1 d  q 0
 . s HTTPERR=$s($g(had):404,1:400)
 i 'newrow,'$d(@root@(ien,"json","entry")) d  q 0
 . s HTTPERR=404
 ;
 merge json=BODY
 i '$d(json) d  q 0 ;
 . s HTTPERR=400
 ;
 n gr1,zi,cnt,rien,lastrien,haspat ; initial entries
 do DECODE^XLFJSON("json","gr1")
 ;
 i newrow d  ;
 . ; VistA-only patients get a new graph row containing just this update bundle.
 . m gr(ien,"json")=gr1
 . s lastrien=0
 . s zi=0,cnt=0
 . f  s zi=$o(gr1("entry",zi)) q:+zi=0  s cnt=cnt+1
 e  d  ;
 . ; start from existing graph row so indexes/json are not truncated to the delta only
 . m gr(ien)=@root@(ien)
 . ;
 . ; shift resource numbers to fit in graph
 . ;
 . s lastrien=$o(gr(ien,"json","entry"," "),-1)
 . s haspat=$$HASPAT($na(gr(ien)))
 . s zi=0,cnt=0
 . f  s zi=$o(gr1("entry",zi)) q:+zi=0  d  ;
 . . i haspat,$g(gr1("entry",zi,"resource","resourceType"))="Patient" q
 . . s cnt=cnt+1
 . . s rien=lastrien+cnt
 . . m gr(ien,"json","entry",rien)=gr1("entry",zi)
 ;
 ;
 do indexFhir(ien,"gr")
 ;
 ;
 set return("status")="ok"
 i icn="" d
 . n dfr s dfr=$o(@root@("SPO",ien,"DFN",""))
 . i dfr'="" s icn=$$dfn2icn^SYNFUTL(dfr)
 set return("icn")=icn
 set return("ien")=ien
 if newrow set return("createdGraph")=1
 n bundle s bundle=$$bundleId($na(gr(ien)))
 set return("bundle")=bundle
 set ARGS("bundle")=bundle ; ingest only resources in this bundle
 s SYNBUNDLE=bundle
 ;
 ; commit merged json subtree for this graph ien only
 m @root@(ien)=gr(ien)
 ;
 new rdfn set rdfn=$s(dnx>0:dnx,1:$o(@root@("SPO",ien,"DFN","")))
 if rdfn'="" do LNKPAT(ien,rdfn,.icn,root)
 if icn'="" set return("icn")=icn
 ;
 if rdfn'="" do  ; patient creation was successful
 . if $g(ARGS("load"))="" s ARGS("load")=1
 . if +$g(ARGS("load"))=0 s return("loadStatus")="skipped" q
 . ;do taskLabs(.return,ien,.ARGS)
 . n X
 . s X="importLabs^SYNFLAB(.return,ien,.ARGS)" d @X
 . s X="importVitals^SYNFVIT(.return,ien,.ARGS)" d @X
 . s X="importEncounters^SYNFENC(.return,ien,.ARGS)" d @X
 . i $t(importDocRefs^SYNFTIU)'="" s X="importDocRefs^SYNFTIU(.return,ien,.ARGS)" d @X
 . s X="importImmu^SYNFIMM(.return,ien,.ARGS)" d @X
 . s X="importConditions^SYNFPR2(.return,ien,.ARGS)" d @X
 . s X="importAllergy^SYNFALG(.return,ien,.ARGS)" d @X
 . s X="importAppointment^SYNFAPT(.return,ien,.ARGS)" d @X
 . s X="importMeds^SYNFMED2(.return,ien,.ARGS)" d @X
 . s X="importProcedures^SYNFPROC(.return,ien,.ARGS)" d @X
 . s X="importCarePlan^SYNFCP(.return,ien,.ARGS)" d @X
 ;
 if $get(ARGS("returngraph"))=1 do  ;
 . do transactionLoad(.return,ien,lastrien+1,lastrien+cnt)
 ;
 k SYNBUNDLE
 do ENCODE^XLFJSON("return","RESULT")
 set HTTPRSP("mime")="application/json"
 ;
 quit 1
 ;
LNKPAT(ien,dfn,icn,root) ; link an existing VistA patient to a graph row
 i $g(root)="" s root=$$setroot^SYNWD("fhir-intake")
 q:+$g(ien)<1
 q:+$g(dfn)<1
 q:'$d(^DPT(dfn,0))
 s @root@("DFN",dfn,ien)=""
 s @root@(ien,"DFN",dfn)=""
 d setIndex^SYNFUTL(ien,"DFN",dfn)
 i $g(@root@(ien,"load","Patient","status","DFN"))="" s @root@(ien,"load","Patient","status","DFN")=dfn
 i $g(@root@(ien,"load","Patient","status","loadStatus"))="" s @root@(ien,"load","Patient","status","loadStatus")="loaded"
 s icn=$$DPTICN(dfn,$g(icn))
 i icn'="",icn'=-1 d  ;
 . s @root@("ICN",icn,ien)=""
 . s @root@(ien,"ICN",icn)=""
 . d setIndex^SYNFUTL(ien,"ICN",icn)
 . i $g(@root@(ien,"load","Patient","status","ICN"))="" s @root@(ien,"load","Patient","status","ICN")=icn
 q
 ;
DPTICN(dfn,icn) ; existing patient ICN, without assigning a new one
 s icn=$g(icn)
 i icn'="" q icn
 i $t(icn^SYNFPAT)'="" d
 . s icn=$$icn^SYNFPAT(dfn)
 i icn'="",icn'=-1 q icn
 s icn=$o(^DPT("ARFICN",dfn,""))
 q icn
 ;
HASPAT(ary) ; true if graph row already has a Patient resource
 n zi
 s zi=0
 f  s zi=$o(@ary@("json","entry",zi)) q:+zi=0  i $g(@ary@("json","entry",zi,"resource","resourceType"))="Patient" q
 q $s(+zi>0:1,1:0)
 ;
indexFhir(ien,root)  ; generate indexes for parsed fhir json
 ;
 i $g(root)="" set root=$$setroot^SYNWD("fhir-intake")
 if $get(ien)="" quit  ;
 ;
 new jroot set jroot=$name(@root@(ien,"json","entry")) ; root of the json
 if '$data(@jroot) quit  ; can't find the json to index
 ;
 new jindex set jindex=$name(@root@(ien)) ; root of the index
 d clearIndexes(jindex)
 ;
 new %wi s %wi=0
 for  set %wi=$order(@jroot@(%wi)) quit:+%wi=0  do  ;
 . new type
 . set type=$get(@jroot@(%wi,"resource","resourceType"))
 . if type="" do  quit  ;
 . . w !,"error resource type not found ien= ",ien," entry= ",%wi
 . set @jindex@("type",type,%wi)=""
 . d triples(jindex,$na(@jroot@(%wi)),%wi)
 ;
 n bund
 s bund=$$bundleId(jindex)
 s %wi=0
 f  s %wi=$o(@jroot@(%wi)) q:+%wi=0  d  ;
 . s @jindex@(%wi,"bundle")=bund
 . d setIndex(jindex,%wi,"bundle",bund)
 ;
 quit
 ;
triples(index,ary,%wi)  ; index and array are passed by name
 ;
 i type="Patient" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 i type="Encounter" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 . n sdate s sdate=$g(@ary@("resource","period","start")) q:sdate=""
 . n hl7date s hl7date=$$fhirThl7^SYNFUTL(sdate)
 . d setIndex(index,purl,"dateTime",sdate)
 . d setIndex(index,purl,"hl7dateTime",hl7date)
 . n class s class=$g(@ary@("resource","class","code")) q:class=""
 . d setIndex(index,purl,"class",class)
 i type="Condition" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 . n enc s enc=$g(@ary@("resource","context","reference"))
 . i enc="" s enc=$g(@ary@("resource","encounter","reference")) q:enc=""
 . d setIndex(index,purl,"encounterReference",enc)
 . n pat s pat=$g(@ary@("resource","subject","reference")) q:pat=""
 . d setIndex(index,purl,"patientReference",pat)
 i type="Observation" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 . n enc s enc=$g(@ary@("resource","context","reference"))
 . i enc="" s enc=$g(@ary@("resource","encounter","reference")) q:enc=""
 . d setIndex(index,purl,"encounterReference",enc)
 . n pat s pat=$g(@ary@("resource","subject","reference")) q:pat=""
 . d setIndex(index,purl,"patientReference",pat)
 i type="Medication" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 i type="medicationReference" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 . n enc s enc=$g(@ary@("resource","context","reference"))
 . i enc="" s enc=$g(@ary@("resource","encounter","reference")) q:enc=""
 . d setIndex(index,purl,"encounterReference",enc)
 . n pat s pat=$g(@ary@("resource","subject","reference")) q:pat=""
 . d setIndex(index,purl,"patientReference",pat)
 i type="Immunization" d  q  ;
 . n purl s purl=$g(@ary@("fullUrl"))
 . i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 . i $e(purl,$l(purl))="/" s purl=purl_%wi
 . d setIndex(index,purl,"type",type)
 . d setIndex(index,purl,"rien",%wi)
 . n enc s enc=$g(@ary@("resource","encounter","reference")) q:enc=""
 . d setIndex(index,purl,"encounterReference",enc)
 . n pat s pat=$g(@ary@("resource","patient","reference")) q:pat=""
 . d setIndex(index,purl,"patientReference",pat)
 n purl s purl=$g(@ary@("fullUrl"))
 i purl="" s purl=type_"/"_$g(@ary@("resource","id"))
 i $e(purl,$l(purl))="/" s purl=purl_%wi
 d setIndex(index,purl,"type",type)
 d setIndex(index,purl,"rien",%wi)
 n enc s enc=$g(@ary@("resource","context","reference"))
 i enc="" s enc=$g(@ary@("resource","encounter","reference")) q:enc=""
 d setIndex(index,purl,"encounterReference",enc)
 n pat s pat=$g(@ary@("resource","subject","reference")) q:pat=""
 d setIndex(index,purl,"patientReference",pat)
 q
 ;
setIndex(gn,sub,pred,obj)       ; set the graph indexices
 ;n gn s gn=$$setroot^SYNWD("fhir-intake")
 q:sub=""
 q:pred=""
 q:obj=""
 s @gn@("SPO",sub,pred,obj)=""
 s @gn@("POS",pred,obj,sub)=""
 s @gn@("PSO",pred,sub,obj)=""
 s @gn@("OPS",obj,pred,sub)=""
 q
 ;
bundleId(ary) ; extrinsic returns the bundle date range
 n low,high
 s low=$o(@ary@("POS","dateTime",""))
 q:low="" ""
 s high=$o(@ary@("POS","dateTime",""),-1)
 s low=$p(low,"T",1)
 s high=$p(high,"T",1)
 q low_":"_high
 ;
clearIndexes(gn)        ; kill the indexes
 k @gn@("SPO")
 k @gn@("POS")
 k @gn@("PSO")
 k @gn@("OPS")
 q
 ;
getEntry(ary,ien,rien) ; returns one entry in ary, passed by name
 n root s root=$$setroot^SYNWD("fhir-intake")
 i '$d(@root@(ien,"json","entry",rien)) q  ;
 m @ary@("entry",rien)=@root@(ien,"json","entry",rien)
 q
 ;
loadStatus(ary,ien,rien) ; returns the "load" section of the patient graph
 ; if rien is not specified, all entries are included
 n root s root=$$setroot^SYNWD("fhir-intake")
 i '$d(@root@(ien)) q
 i $g(rien)="" d  q  ;
 . k @ary
 . m @ary@(ien)=@root@(ien,"load")
 n zi s zi=""
 f  s zi=$o(@root@(ien,"load",zi)) q:$d(@root@(ien,"load",zi,rien))
 k @ary
 m @ary@(ien,rien)=@root@(ien,"load",zi,rien)
 q
 ;
transactionLoad(return,ien,first,last) ; return load nodes for appended transaction entries
 n root s root=$$setroot^SYNWD("fhir-intake")
 n rien,domain
 s return("transaction","firstEntry")=first
 s return("transaction","lastEntry")=last
 s return("transaction","entryCount")=$s(last'<first:last-first+1,1:0)
 s rien=first-1
 f  s rien=$o(@root@(ien,"json","entry",rien)) q:+rien=0!(rien>last)  d  ;
 . n type s type=$g(@root@(ien,"json","entry",rien,"resource","resourceType"))
 . s return("transaction","entries",rien,"resourceType")=type
 . s domain=""
 . f  s domain=$o(@root@(ien,"load",domain)) q:domain=""  d  ;
 . . i '$d(@root@(ien,"load",domain,rien)) q
 . . m return("transactionLoad",rien,domain)=@root@(ien,"load",domain,rien)
 q
 ;
wsLoadStatus(rtn,filter) ; displays the load status
 ; filter must have ien or dfn to specify the patient
 ; optionally, entry number (rien) for a single entry
 ; if ien and dfn are both specified, dfn is used
 ; now supports latest=1 to show the load status of the lastest added patient
 n root s root=$$setroot^SYNWD("fhir-intake")
 n ien s ien=$g(filter("ien"))
 i $g(filter("latest"))=1 d  ;
 . set ien=$o(@root@(" "),-1)
 n dfn s dfn=$g(filter("dfn"))
 i dfn'="" s ien=$$dfn2ien^SYNFUTL(dfn)
 n rien s rien=$g(filter("rien"))
 q:ien=""
 n load
 d loadStatus("load",ien,rien)
 s filter("root")="load"
 s filter("local")=1
 d wsGLOBAL^SYNVPR(.rtn,.filter)
 q
 ;
