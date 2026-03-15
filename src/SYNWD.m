SYNWD     ;ven/gpl - mash graph utilities ; 9/24/17 4:33pm
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
 ; All the public entry points for handling in mash data are in this routine
 ;
 ;
 ; graph handling routines
 ;
setroot(graph) ; root of working storage
 new RTN set RTN=$$GRTN($get(graph))
 if RTN="%wd" quit $$setroot^%wd(graph)
 quit $$setroot^SYNGRAF(graph)
 ;
rootOf(graph) ; return the root of graph named graph
 new RTN set RTN=$$GRTN($get(graph))
 if RTN="%wd" quit $$rootOf^%wd(graph)
 quit $$rootOf^SYNGRAF(graph)
 ;
addgraph(graph) ; makes a place in the graph file for a new graph
 new RTN set RTN=$$GRTN($get(graph))
 if RTN="%wd" quit $$addgraph^%wd(graph)
 quit $$addgraph^SYNGRAF(graph)
 ;
purgegraph(graph) ; delete a graph
 new RTN set RTN=$$GRTN($get(graph))
 if RTN="%wd" quit $$purgegraph^%wd(graph)
 quit $$purgegraph^SYNGRAF(graph)
 ;
insert2graph(ary,graph,replace) ; insert a new entry to a graph
 new RTN set RTN=$$GRTN($get(graph))
 if RTN="%wd" do insert2graph^%wd(.ary,graph,replace) quit
 do insert2graph^SYNGRAF(.ary,graph,replace)
 quit
 ;
GRTN(GRAPH) ; detect the active graph backend for a named graph
 set GRAPH=$get(GRAPH)
 if $$SYNHAS(GRAPH) quit "SYNGRAF"
 if $$WDHAS(GRAPH) quit "%wd"
 ;
 ; If the requested graph does not exist yet, follow the store that already
 ; owns the standard SYN working graphs on this system.
 if $$SYNHAS("fhir-intake") quit "SYNGRAF"
 if $$WDHAS("fhir-intake") quit "%wd"
 if $$SYNHAS("loinc-lab-map") quit "SYNGRAF"
 if $$WDHAS("loinc-lab-map") quit "%wd"
 if $$SYNHAS("html-cache") quit "SYNGRAF"
 if $$WDHAS("html-cache") quit "%wd"
 if $$SYNHAS("seeGraph") quit "SYNGRAF"
 if $$WDHAS("seeGraph") quit "%wd"
 ;
 if $$SYNOK,'$$WDOK quit "SYNGRAF"
 if $$WDOK,'$$SYNOK quit "%wd"
 ;
 ; This branch is vaready-derived, so new graphs default to SYNGRAPH when
 ; both backends are present but no existing graph anchors the choice.
 if $$SYNOK quit "SYNGRAF"
 if $$WDOK quit "%wd"
 quit "SYNGRAF"
 ;
WDOK() ; legacy %wd graph store is available
 quit $select($text(setroot^%wd)="":0,$piece($get(^DIC(17.040801,0)),"^")="":0,1:1)
 ;
SYNOK() ; SYNGRAPH graph store is available
 quit $select($text(setroot^SYNGRAF)="":0,$piece($get(^DIC(2002.801,0)),"^")="":0,1:1)
 ;
WDHAS(GRAPH) ; named graph already exists in the %wd store
 new GIEN,ROOT
 if $get(GRAPH)="" quit 0
 if '$$WDOK quit 0
 set ROOT="^"_$char(37)_"wd(17.040801,""B"")"
 set GIEN=$order(@ROOT@(GRAPH,0))
 quit $select(+GIEN>0:1,1:0)
 ;
SYNHAS(GRAPH) ; named graph already exists in the SYNGRAPH store
 new GIEN
 if $get(GRAPH)="" quit 0
 if '$$SYNOK quit 0
 set GIEN=$order(^SYNGRAPH(2002.801,"B",GRAPH,0))
 quit $select(+GIEN>0:1,1:0)
 ;
nameThis(altname) ; returns the id to be used for altname
 ; this will eventually use the context graph and the
 ; local variable context to query the altname and obtain an id
 quit $$nameThis^SYNGRAF(altname)
 ;
getThis(rary,fn,nocache) ; find a file and read it into rary array
 do getThis^SYNGRAF(rary,fn,$get(nocache))
 quit
 ;
queryContext(context,locator,property) ; look up project specific
 ; names and values from the context graph
 ; tbd
 quit $$queryContext^SYNGRAF(context,locator,property)
 ;
queryTag(rtn,tag) ; returns a json/mumps array of tagged items
 do queryTag^SYNGRAF(rtn,tag)
 quit
 ;
fromCache(rary,name,graph) ; return a file from the cache
 do fromCache(rary,name,graph)
 quit
 ;
toCache(arry,name,graph) ; put a file in the cache
 do toCache^SYNGRAF(arry,name,graph)
 quit
 ;
beautify(inary,outary) ; pretty print a line of json
 do beautify^SYNGRAF(inary,outary)
 quit
 ;
ary2file(ary,dir,file) ;
 do ary2file^SYNGRAF(.ary,dir,file)
 quit
 ;
file2ary(ary,dir,file)
 do file2ary^SYNGRAF(.ary,dir,file)
 quit
 ;
 ;
 ;
 ; csv handling routines
 ;
csv2graph(source,graph) ; import a csv file to a graph
 ; graph is optional, will default to csvGraph
 ; source is either a filename which will be found in seeGraph
 ; or a global passed by name usually loaded with FTG^%ZISH
 ;
 d csv2graph^SYNCSV(source,$get(graph))
 quit
 ;
prune(txt) ; extrinsic removes extra quotes
 quit $$prune^SYNCSV(txt)
 ;
delim(ary) ; figures out the cvs delimiter
 ; return -1 if there not found
 ; ary is passed by reference
 ; returns the delimiter
 quit $$delim^SYNCSV(.ary)
 ;
wellformed(ary,delim) ; extrinsic returns 1 if ary is well formed
 ; checks to see that the count of the delimiter is the same
 ; on every line
 ; ary is passed by reference
 ;
 quit $$wellformed^SYNCSV(.ary,delim)
 ;
