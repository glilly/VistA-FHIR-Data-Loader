SYNLABFX ;ven/gpl - lab setup audit/fix utilities ;2026-03-11
 ;;0.7;VISTA SYNTHETIC DATA LOADER;;Jul 01, 2019;Build 13
 ;
 ; API:
 ;   D audit^SYNLABFX(.RTN,IEN,.ARGS)
 ;   D fix^SYNLABFX(.RTN,IEN,.ARGS)
 ;
 ; ARGS (optional):
 ;   ARGS("inst")          institution IEN for #60.11 (.01) [default DUZ(2) or 1]
 ;   ARGS("accArea")       accession area IEN for #60.11 field 1 [default 11]
 ;   ARGS("defaultSample") collection sample IEN for #60.03 [.01] [default 1]
 ;   ARGS("urineSample")   urine sample IEN override [default "URINE" or default]
 ;
 q
 ;
audit(rtn,ien,args) ; audit only
 d run(.rtn,+$g(ien),.args,0)
 q
 ;
fix(rtn,ien,args) ; audit + apply safe fixes
 d run(.rtn,+$g(ien),.args,1)
 q
 ;
run(rtn,ien,args,dofix) ; core
 k rtn
 n root,troot,json
 n inst,acc,defsmp,urismp
 n zi,cat,loinc,txt,map,tien,tname,chg,samp
 ;
 i ien<1 s rtn("error")="missing graph IEN" q
 s root=$$setroot^SYNWD("fhir-intake")
 s troot=$na(@root@(ien,"type","Observation"))
 s json=$na(@root@(ien,"json"))
 i '$d(@troot) s rtn("error")="no observation graph for ien "_ien q
 ;
 s inst=+$g(args("inst"))
 i inst<1 s inst=+$g(DUZ(2))
 i inst<1 s inst=1
 s acc=+$g(args("accArea"))
 i acc<1 s acc=11
 s defsmp=+$g(args("defaultSample"))
 i defsmp<1 s defsmp=1
 s urismp=+$g(args("urineSample"))
 i urismp<1 s urismp=+$o(^LAB(62,"B","URINE",""))
 i urismp<1 s urismp=defsmp
 ;
 s rtn("mode")=$s($g(dofix)=1:"fix",1:"audit")
 s rtn("ien")=ien
 s rtn("config","inst")=inst
 s rtn("config","accArea")=acc
 s rtn("config","defaultSample")=defsmp
 s rtn("config","urineSample")=urismp
 ;
 s zi=0
 f  s zi=$o(@troot@(zi)) q:+zi=0  d
 . s rtn("summary","obsSeen")=$g(rtn("summary","obsSeen"))+1
 . s cat=$g(@json@("entry",zi,"resource","category",1,"coding",1,"code"))
 . q:cat'="laboratory"
 . s rtn("summary","labObs")=$g(rtn("summary","labObs"))+1
 . s loinc=$g(@json@("entry",zi,"resource","code","coding",1,"code"))
 . s txt=$$labText(json,zi)
 . s map=$$mapped(loinc,txt)
 . s map=$$override(loinc,map)
 . s tien=$$findTest(map,txt,.tname)
 . i tien<1 d  q
 . . s rtn("summary","missingTest")=$g(rtn("summary","missingTest"))+1
 . . d addLog(.rtn,"MISSING_TEST zi="_zi_" loinc="_loinc_" map="""_map_""" text="""_txt_"""")
 . s samp=$$pickSample(tname,defsmp,urismp)
 . s chg=$$ensureSample(.rtn,tien,samp,dofix,zi,loinc,tname)
 . i chg s rtn("summary","fixed")=$g(rtn("summary","fixed"))+1
 . s chg=$$ensureAcc(.rtn,tien,inst,acc,dofix,zi,loinc,tname)
 . i chg s rtn("summary","fixed")=$g(rtn("summary","fixed"))+1
 s rtn("result")="ok"
 q
 ;
labText(json,zi) ; preferred display text
 n t
 s t=$g(@json@("entry",zi,"resource","code","text"))
 i t="" s t=$g(@json@("entry",zi,"resource","code","coding",1,"display"))
 q t
 ;
mapped(loinc,txt) ; map loinc to lab name
 n x
 s x=$$graphmap^SYNGRAPH("loinc-lab-map",loinc)
 i +x=-1 s x=$$graphmap^SYNGRAPH("loinc-lab-map"," "_loinc)
 i +x=-1 s x=$$covid^SYNGRAPH(loinc)
 i +x=-1 s x=txt
 q $$TRIM^XLFSTR(x)
 ;
override(loinc,map) ; targeted map rules
 n x
 s x=$g(map)
 ; Estimated GFR is not always represented as a distinct #60 test in this build.
 ; Map to CREATININE so ingest can proceed (duplicate logic in SYNFLAB handles
 ; same-date repeats safely).
 i loinc="33914-3" s x="CREATININE"
 q x
 ;
findTest(map,txt,tname) ; return #60 ien
 n ien
 s ien=$o(^LAB(60,"B",map,""))
 i ien="" s ien=$o(^LAB(60,"B",$$UP^XLFSTR(map),""))
 i ien="" s ien=$o(^LAB(60,"B",txt,""))
 i ien="" s ien=$o(^LAB(60,"B",$$UP^XLFSTR(txt),""))
 s tname=$s(ien'="":$p($g(^LAB(60,ien,0)),"^"),1:"")
 q +ien
 ;
pickSample(tname,defsmp,urismp) ; choose sample for missing #60.03
 n u
 s u=$$UP^XLFSTR($g(tname))
 i u["ALBUMIN/CREATININE" q +urismp
 i u["MICROALBUMIN/CREATININE" q +urismp
 q +defsmp
 ;
ensureSample(rtn,tien,sample,dofix,zi,loinc,tname) ; ensure #60.03 exists
 n sub,chg
 n FDA,ERR,NEW
 s chg=0
 s sub=$o(^LAB(60,tien,3,0))
 i sub'="" q chg
 s rtn("summary","missingSample")=$g(rtn("summary","missingSample"))+1
 d addLog(.rtn,"MISSING_SAMPLE test="_tien_" """_tname_""" loinc="_loinc_" zi="_zi)
 i '$g(dofix) q chg
 k FDA,ERR,NEW
 s FDA(60.03,"+1,"_tien_",",.01)=+sample
 d UPDATE^DIE("","FDA","NEW","ERR")
 i $d(ERR) d  q chg
 . d addLog(.rtn,"FIX_FAIL_SAMPLE test="_tien_" loinc="_loinc)
 s chg=1
 d addLog(.rtn,"FIXED_SAMPLE test="_tien_" sample="_sample_" loinc="_loinc)
 q chg
 ;
ensureAcc(rtn,tien,inst,acc,dofix,zi,loinc,tname) ; ensure #60.11 exists/matches
 n sub,chg,old
 n FDA,ERR,NEW
 s chg=0
 s sub=$$accSub(tien,inst)
 i sub="" d  q chg
 . s rtn("summary","missingAccession")=$g(rtn("summary","missingAccession"))+1
 . d addLog(.rtn,"MISSING_ACCESSION test="_tien_" """_tname_""" inst="_inst_" loinc="_loinc_" zi="_zi)
 . i '$g(dofix) q
 . k FDA,ERR,NEW
 . s FDA(60.11,"+1,"_tien_",",.01)=+inst
 . s FDA(60.11,"+1,"_tien_",",1)=+acc
 . d UPDATE^DIE("","FDA","NEW","ERR")
 . i $d(ERR) d  q
 . . d addLog(.rtn,"FIX_FAIL_ACCESSION test="_tien_" inst="_inst_" acc="_acc)
 . s chg=1
 . d addLog(.rtn,"FIXED_ACCESSION test="_tien_" inst="_inst_" acc="_acc)
 ;
 s old=+$p($g(^LAB(60,tien,8,sub,0)),"^",2)
 i old=+acc q chg
 s rtn("summary","mismatchAccession")=$g(rtn("summary","mismatchAccession"))+1
 d addLog(.rtn,"MISMATCH_ACCESSION test="_tien_" inst="_inst_" old="_old_" new="_acc)
 i '$g(dofix) q chg
 s $p(^LAB(60,tien,8,sub,0),"^",2)=+acc
 s chg=1
 d addLog(.rtn,"FIXED_ACCESSION_MISMATCH test="_tien_" inst="_inst_" old="_old_" new="_acc)
 q chg
 ;
accSub(tien,inst) ; return #60.11 subentry with matching institution
 n sub,hit,val
 s (sub,hit)=0
 f  s sub=$o(^LAB(60,tien,8,sub)) q:'sub  d  q:hit
 . s val=+$p($g(^LAB(60,tien,8,sub,0)),"^")
 . i val=+inst s hit=sub
 q hit
 ;
addLog(rtn,txt) ; append message to rtn("log")
 n n
 s n=$o(rtn("log",""),-1)+1
 s rtn("log",n)=txt
 q
 ;
