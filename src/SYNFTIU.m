SYNFTIU  ;ven/gpl - fhir loader utilities ;2018-08-17  3:27 PM
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
 ; Encounter TIU note utilities (graph-store lines under load,encounters,rien,note)
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
=======TEMP=======
 n root,groot,encien,ci,cand,cands
 s root=$$INTROOT^SYNFTIU
 s groot=$na(@root@(ien))
 d CANDS^SYNFTIU($g(enc),.cands)
 s encien=""
 f ci=1:1 q:'$d(cands(ci))  q:encien'=""  d  ;
 . s cand=$g(cands(ci)) q:cand=""
 . s encien=$o(@groot@("PSO","rien",cand,""))
>>>>>>> e3232dd (SYNFTIU: use SYNWD graph root when present; normalize encounter keys for notes)
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
