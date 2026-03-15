SYNOS5PT ; ven/gpl - populate OS5 entries in file 81 ;2026-03-15
 ;;0.7;VISTA SYN DATA LOADER;;Mar 18, 2025
 ;
 ; Build any missing OS5 entries in file 81 and Lexicon code history
 ; from the ^SYN sct2os5 map.
 ;
 q
 ;
EN ; ensure file 81 and Lexicon contain all OS5 codes from ^SYN
 n CODE,SCT,DESC,IEN,LEXIEN,LASTIEN,LASTLEX,ADDED,HEADER,LEXHDR,OLDHIGH
 s LASTIEN=+$P($G(^ICPT(0)),U,3)
 i LASTIEN<199999999 s LASTIEN=199999999
 s LASTLEX=+$P($G(^LEX(757.02,0)),U,3)
 i LASTLEX<2999999999 s LASTLEX=3000000000
 s CODE="",ADDED=0
 f  s CODE=$O(^SYN("2002.030","sct2os5","inverse",CODE)) q:CODE=""  d
 . s SCT=$O(^SYN("2002.030","sct2os5","inverse",CODE,""))
 . q:SCT=""
 . s DESC=$G(^SYN("2002.030","sct2os5","inverse",CODE,SCT))
 . q:DESC=""
 . s IEN=$O(^ICPT("B",CODE,""))
 . i 'IEN s LASTIEN=LASTIEN+1,IEN=LASTIEN,ADDED=ADDED+1
 . i '$D(^ICPT(IEN,0)) d ADD(IEN,CODE,DESC)
 . s LEXIEN=$O(^LEX(757.02,"CODE",CODE_" ",""))
 . i 'LEXIEN s LASTLEX=LASTLEX+1,LEXIEN=LASTLEX
 . i LEXIEN>LASTLEX s LASTLEX=LEXIEN
 . i '$D(^LEX(757.02,LEXIEN,0)) d ADDLEX(LEXIEN,CODE)
 i ADDED d
 . s HEADER=$G(^ICPT(0))
 . i HEADER="" s HEADER="CPT^81I^^0"
 . s $P(HEADER,U,3)=LASTIEN
 . s $P(HEADER,U,4)=+$P(HEADER,U,4)+ADDED
 . s ^ICPT(0)=HEADER
 s LEXHDR=$G(^LEX(757.02,0)),OLDHIGH=+$P(LEXHDR,U,3)
 i LEXHDR="" s LEXHDR="CODES^757.02IP^^0",OLDHIGH=0
 i LASTLEX>OLDHIGH d
 . s $P(LEXHDR,U,3)=LASTLEX
 . s $P(LEXHDR,U,4)=+$P(LEXHDR,U,4)+(LASTLEX-OLDHIGH)
 . s ^LEX(757.02,0)=LEXHDR
 q
 ;
ADD(IEN,CODE,DESC) ; add one OS5 entry to file 81
 n EFF,SHORT
 s EFF=2110101
 s SHORT=$E(DESC,1,30)
 s ^ICPT(IEN,0)=CODE_U_DESC_U_30_U_U_U_"C"_U_U_EFF
 s ^ICPT(IEN,60,0)="^81.02DA^1^1"
 s ^ICPT(IEN,60,1,0)=EFF_U_1
 s ^ICPT(IEN,60,"B",EFF,1)=""
 s ^ICPT(IEN,61,0)="^81.061D^1^1"
 s ^ICPT(IEN,61,1,0)=EFF_U_DESC
 s ^ICPT(IEN,61,"B",EFF,1)=""
 s ^ICPT(IEN,62,0)="^81.062D^1^1"
 s ^ICPT(IEN,62,1,0)=EFF
 s ^ICPT(IEN,62,1,1,0)="^81.621^1^1"
 s ^ICPT(IEN,62,1,1,1,0)=DESC
 s ^ICPT(IEN,62,1,1,"B",SHORT,1)=""
 s ^ICPT(IEN,62,"B",EFF,1)=""
 s ^ICPT(IEN,"D",0)="^81.01A^1^1"
 s ^ICPT(IEN,"D",1,0)=DESC
 s ^ICPT(IEN,"D","B",SHORT,1)=""
 s ^ICPT("ACT",CODE_" ",1,EFF,IEN,1)=""
 s ^ICPT("ADS",CODE_" ",EFF,IEN,1)=""
 s ^ICPT("AST",CODE_" ",EFF,IEN,1)=""
 s ^ICPT("B",CODE,IEN)=""
 s ^ICPT("BA",CODE_" ",IEN)=""
 s ^ICPT("D",30,IEN)=""
 q
 ;
ADDLEX(IEN,CODE) ; add one OS5 entry to Lexicon code history
 n EFF
 s EFF=2110101
 s ^LEX(757.02,IEN,0)=IEN_U_CODE_U_3_U_0_U_1_U_U_1
 s ^LEX(757.02,IEN,4,0)="^757.28DA^1^1"
 s ^LEX(757.02,IEN,4,1,0)=EFF_U_1
 s ^LEX(757.02,IEN,4,"B",EFF,1)=""
 s ^LEX(757.02,"ACT",CODE_" ",1,EFF,IEN,1)=""
 s ^LEX(757.02,"ACT",CODE_" ",3,EFF,IEN,1)=""
 s ^LEX(757.02,"APCODE",CODE_" ",IEN)=""
 s ^LEX(757.02,"ASRC","CPT",IEN)=""
 s ^LEX(757.02,"AVA",CODE_" ",IEN,"CPT",IEN)=""
 s ^LEX(757.02,"B",IEN,IEN)=""
 s ^LEX(757.02,"CODE",CODE_" ",IEN)=""
 q
 ;
