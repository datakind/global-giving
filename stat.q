////////////////////////////////////////////////////////////////////////
// generally useful functions for loading data and taking a first look
////////////////////////////////////////////////////////////////////////

// rc: rows & cols per table (as a table)
/ x table
rc:{flip`table`rows`cols!{v:value each x;(x;count each v;count each cols each v)}tables`.}

// uc: count of unique values for sym columns
/ x table
uc:{
  n:exec c from meta x where"s"=t; / sym col names
  flip`column`uniqcount!(n;x{count?[x;();1b;((),y)!(),y]}/:n)}

// nc: null count (and pct) by column
/ x table
nc:{
  i:exec c from meta x where"C"<>t;                / non-string columns
  j:exec c from meta x where"C"=t;                 / string columns
  k:(i;sum each null x i),'(j;sum each""~/:/:x j); / combined
  p:100*k[1]%count x;                              / % of table row count
  `nulls xdesc delete from flip`column`nulls`pct!k,enlist p where 0=nulls}

// a2: add version number 2 to data file name
/ helper for rnq
/ x file handle eg `:data/organization.csv
/ return eg `:data/organization2.csv
a2:{
  ` sv{@[x;-1+count x;{` sv@[` vs x;0;{`$string[x],"2"}]}]}` vs x}

// rnqi: rnq implementation
/ x s file handle eg `:data/project.csv
/ broke apart to enable more effective garbage collection
rnqi:{
  p:read0[x]except\:"\r";
  oq:1=(sum each"\""=p)mod 2; / lines with an odd number of quotes
  / only put newlines when eoln coincides with even quote total
  / otherwise replace newline w/space
  / must drop last newline since 0: will put one
  a2[x]0:enlist -1_raze p,'" \n"0=sums[oq]mod 2}

// rnq: remove newlines inside quoted fields so q can read it
/ x file handle, e.g., `:project.csv
/ saves fixed-up data to, e.g., `:project2.csv
rnq:{{.Q.gc[];x}rnqi x} / rnqi leaves memory on the table

// fmt: format string for table
/ x table
fmt:{upper{@[x;where"C"=x;:;"*"]}exec t from meta x}

/ fixnullsym: replace `NULL with `
/ x table
fixnullsym:{
  sc:exec c from meta x where"s"=t; / sym cols
  / don't know why flip...flip is needed, but @ doesn't like tables
  flip@[flip x;sc;{@[x;where`NULL=x;:;`]}]}

// fixnullstr: replace "NULL" with ""
/ x table
fixnullstr:{
  sc:exec c from meta x where"C"=t; / string cols
  / don't know why flip...flip is needed, but @ doesn't like tables
  / have to create the rhs or else we get a 'length error
  flip@[flip x;sc;{@[x;i;:;(count i:where"NULL"~/:x)#enlist""]}]}

// fixts: Replace 2000.01.01 with null
/ TODO report bug to kx: "P"$(),"0" -> 2000.01.01 instead of 0Np
/ TODO let Jon know he turned NULL into 0 for approveddt in, e.g., record 6290
/ x table
fixts:{
  pc:exec c from meta x where"p"=t; / timestamp cols
  / don't know why flip...flip is needed, but @ doesn't like tables
  / have to create the rhs or else we get a 'length error
  flip@[flip x;pc;{@[x;i;:;(count i:where 0=x)#0Np]}]}

// trimstr: trim string columns
/ x table
trimstr:{@[x;exec c from meta x where"C"=t;trim]}

// missing: count null values in x
/ helper for st
/ x list of atoms
missing:{sum null x}

// st: summary stats
/ x table
st:{
  fn:`min`max`med`avg`dev`missing; / summary stat names
  ff:value each string fn;         / summary stat funcs
  nc:{x where not lower[x]like"*id"}exec c from meta x where t in"ijef"; / numeric cols
  flip(`column,fn)!enlist[nc],`float$ff@/:\:x nc}

// rtf: read table file; does not parse cells
/ x s table name
/ return table of strings
rtf:{
  f:`$":",string[x],".csv";
  cn:`$","vs first system"head -1 ",1_string f; / col names
  (count[cn]#"*";(),",")0: f}

// tpp: try perfect parse
/ x matrix of strings whose string rows we want to try to parse
/ y c format
/ return x where cols parseable as y have been parsed
tpp:{
  i:where 0=type each x;       / string cols
  p:y$x i;                     / parsed per y
  j:where not any each null p; / that parsed perfectly
  @[x;i j;:;p j]}              / replaced

// ipp: imperfect parse
/ ignore empty cells and tolerate one unique non-parsing value
/ and assume it represents null
/ x matrix of data whose string rows we want to try to parse
/ y c format
/ return x where cols parseable as y have been parsed
ipp:{
  i:where 0=type each x; / string cols
  / cols where throwing away "" leaves one null value, others parseable
  m:i where 1>=sum each null y$(distinct each x i)except\:enlist"";
  @[x;m;:;y$x m]}

// lt: load table
/ guesses schema based on data found in each column
/ q)rcpt:lt`rcpt / assumes `:rcpt.csv
lt:{
  nt:"IFDTP";                                    / numeric types we try to parse
  d:flip rtf x;                                  / data from file as a dict
  p:(value[d]tpp/nt)ipp/nt;                      / perfect and imperfect numeric parse
  i:where 0=type each p;                         / columns still not parsed
  sc:i where 5000>count each distinct each p i;  / sym cols
  trimstr flip key[d]!@[p;sc;:;`$p sc]}

// top & friends: top (n) count by categories
/ count rows in x by column specified by y and return desc by count
/ i.e., `n xdesc select n:count i,pct:100*count[i]%count x by y from x
top:{`n xdesc?[x;();((),y)!(),y;`n`pct!((count;`i);(*;100;(%;(count;`i);count x)))]}
top5:{5 sublist top[x;y]}
top10:{10 sublist top[x;y]}
top15:{15 sublist top[x;y]}
