SYNAUDIT ; VEN/DOC - Audit SYN KIDS install and repo artifacts ;2026-03-27
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
 ; Public entry: D EN^SYNAUDIT
 ;
 ; Read-only report: PACKAGE (#9.4), INSTALL (#9.7) names, spot-checked
 ; routines, ^SYN("2002.030",...) maps, graph roots via SYNWD, SYNINIT seeds.
 ;
 ; OS5: LOADOS5^SYNOS5LD (from EN^SYNGBLLD / POST^SYNKIDS) must populate
 ; ^SYN("2002.030","sct2os5","direct",...). Below-minimum counts are *** ERROR ***.
 ;
 QUIT
 ;
EN ; [Public] Full report to current device
 N U S U="^"
 K ^TMP("SYNAUDIT",$J)
 D HDR
 D PKG
 D KIDSIX
 D ROUT
 D GLOB
 D GRAPHS
 D INITMK
 D SUMMARY
 K ^TMP("SYNAUDIT",$J)
 QUIT
 ;
HDR ;
 W !,"=== SYNAUDIT: VISTA SYN DATA LOADER install / inventory ==="
 W !,"Run time: ",$$HTE^XLFDT($H)
 W !,$TR($J("",62)," ","-"),!
 QUIT
 ;
PKG ; PACKAGE (#9.4) — primary KIDS registration
 N NM,SYNP,ZERO
 S NM="VISTA SYN DATA LOADER"
 S SYNP=$$FIND1^DIC(9.4,,"QX",NM,"B")
 I 'SYNP D  QUIT
 . D WLIN("PACKAGE",NM_" — NOT in PACKAGE (#9.4). KIDS install likely absent or name differs.")
 S ZERO=$G(^DIC(9.4,SYNP,0))
 D WLIN("PACKAGE","IEN="_SYNP_"  "_ZERO)
 QUIT
 ;
KIDSIX ; INSTALL (#9.7) entries whose name mentions SYN DATA LOADER (newest first)
 N I,X,NM,SHOWN
 S SHOWN=0
 S I="" F  S I=$O(^XPD(9.7,I),-1) Q:'I  Q:SHOWN>12  D
 . S X=$G(^XPD(9.7,I,0)) Q:X=""
 . S NM=$P(X,U)
 . I NM'["SYN DATA LOADER" QUIT
 . W !,"INSTALL",?15,": ",NM,"  (9.7 ien=",I,")"
 . S SHOWN=SHOWN+1
 I 'SHOWN W !,"INSTALL",?15,": (no matching ^XPD(9.7) rows — empty file or different install names)"
 QUIT
 ;
ROUT ; Spot-check routines from this repo (loaded in this UCI)
 N LST,I,R,MISS,OK
 S MISS=0,OK=0
 S LST="SYNKIDS,SYNINIT,SYNGBLLD,SYNOS5LD,SYNOS5PT,SYNWD,SYNGRAPH,SYNFHIR,SYNFHIR2,SYNDHP61,SYNQLDM,SYNFLAB,SYNLABFX"
 F I=1:1 Q:$P(LST,",",I)=""  S R=$P(LST,",",I) D
 . I $L($T(+0^@R)) S OK=OK+1 QUIT
 . S MISS=MISS+1 W !,"ROUTINE",?15,": MISSING ",R
 D WLIN("ROUTINES","present="_OK_"  missing="_MISS_"  (spot list, not exhaustive)")
 QUIT
 ;
GLOB ; ^SYN("2002.030",...) mapping inventory
 I '$D(^SYN) D WLIN("^SYN","root global UNDEFINED — KIDS merge not done") QUIT
 D WLIN("^SYN","root defined")
 I '$D(^SYN("2002.030")) D WLIN("2002.030","UNDEFINED — POSTSYN merge likely incomplete") QUIT
 D WLIN("2002.030","defined")
 D MAPFLAG("sct2os5","SNOMED to OS5 (LOADOS5^SYNOS5LD / EN^SYNGBLLD)")
 D MAPFLAG("sct2cpt","SNOMED to CPT table")
 D MAPFLAG("sct2hf","SNOMED to health factors")
 D MAPFLAG("mh2loinc","MH to LOINC")
 D MAPFLAG("mh2sct","MH to SNOMED")
 D OS5CHK
 QUIT
 ;
OS5CHK ; OS5 loader: ^SYN("2002.030","sct2os5","direct",...) from LOADOS5^SYNOS5LD
 N MINOS5,C
 ; Floor below a full repo build (~1041 in recent validation); tune if generator changes.
 S MINOS5=800
 I '$D(^SYN("2002.030","sct2os5","direct")) D  QUIT
 . D ERR("OS5 installer not run: missing ^SYN(""2002.030"",""sct2os5"",""direct"") — run LOADOS5^SYNOS5LD (e.g. D EN^SYNGBLLD)")
 I '$L($T(COUNT^SYNOS5LD)) D  QUIT
 . D ERR("SYNOS5LD not in UCI — OS5 loader routine missing; install SYN repo routines then D EN^SYNGBLLD")
 S C=$$COUNT^SYNOS5LD
 D WLIN("sct2os5 COUNT","$$COUNT^SYNOS5LD="_C)
 I C<1 D ERR("OS5 installer produced zero direct mappings — LOADOS5^SYNOS5LD did not populate sct2os5") QUIT
 I C<MINOS5 D ERR("OS5 map incomplete: "_C_" direct mappings (minimum "_MINOS5_" expected) — re-run EN^SYNGBLLD or refresh SYNOS5D* / regenerate OS5 map") QUIT
 QUIT
 ;
MAPFLAG(SUB,LBL) ;
 I $D(^SYN("2002.030",SUB)) D WLIN(SUB,"present — "_LBL) QUIT
 D WLIN(SUB,"MISSING — "_LBL)
 QUIT
 ;
GRAPHS ; Graph roots (POSTMAP uses loinc-lab-map; SYNFHIR uses fhir-intake)
 I '$L($T(setroot^SYNWD)) D WLIN("SYNWD","not loaded — skip graph probe") QUIT
 D GROOT("loinc-lab-map","POSTMAP^SYNKIDS loinc-lab-map")
 D GROOT("fhir-intake","SYNFHIR / addPatient intake")
 QUIT
 ;
GROOT(GNAM,LBL) ; extrinsic would be cleaner; use as DO with side-effect lines
 N ROOT,SUB
 S ROOT=$$setroot^SYNWD(GNAM)
 I ROOT="" D WLIN("graph:"_GNAM,"setroot empty — "_LBL) QUIT
 S SUB=$O(@ROOT@(""))
 I SUB'="" D WLIN("graph:"_GNAM,"subscripts at "_ROOT_" — "_LBL) QUIT
 D WLIN("graph:"_GNAM,"no subscripts at "_ROOT_" — "_LBL)
 QUIT
 ;
INITMK ; FileMan artifacts from D ^SYNINIT (POST^SYNKIDS)
 N IEN
 S IEN=$O(^VA(200,"B","PROVIDER,UNKNOWN SYNTHEA",0))
 D WLIN("NEW PERSON","PROVIDER,UNKNOWN SYNTHEA "_$S(IEN:"IEN="_IEN,1:"MISSING"))
 S IEN=$O(^VA(200,"B","PHARMACIST,UNKNOWN SYNTHEA",0))
 D WLIN("NEW PERSON","PHARMACIST,UNKNOWN SYNTHEA "_$S(IEN:"IEN="_IEN,1:"MISSING"))
 S IEN=$O(^SC("B","GENERAL MEDICINE",0))
 D WLIN("HOSP LOC","GENERAL MEDICINE clinic "_$S(IEN:"IEN="_IEN,1:"MISSING"))
 S IEN=$$FIND1^DIC(19,,"QX","SYNMENU","B")
 D WLIN("OPTION","SYNMENU (file 19) "_$S(IEN:"IEN="_IEN,1:"MISSING"))
 QUIT
 ;
SUMMARY ;
 N EC
 S EC=+$G(^TMP("SYNAUDIT",$J,"ERR"))
 W !,$TR($J("",62)," ","-")
 I EC W !,"*** ",EC," ERROR(S) — fix OS5 / install before relying on Synthea encounter mapping. ***",!
 E  W !,"Status: no OS5 errors (direct map count meets minimum).",!
 W !,"Notes:"
 W !,"  - Missing PACKAGE (#9.4) usually means KIDS never installed this namespace."
 W !,"  - OS5 minimum direct count is 800 unless you change MINOS5 in tag OS5CHK."
 W !,"  - See SYNKIDS (POST,POSTSYN,POSTMAP), SYNINIT, SYNGBLLD, docs/FUTURE_KIDS_PACKAGING.md"
 W !
 QUIT
 ;
ERR(MSG) ; increment error tally and print
 W !,"*** ERROR ***",?15,MSG
 S ^TMP("SYNAUDIT",$J,"ERR")=$G(^TMP("SYNAUDIT",$J,"ERR"))+1
 QUIT
 ;
WLIN(LAB,TXT) ;
 W !,LAB,?15,": ",TXT
 QUIT
