\l stat.q

////////////////////////////////////////////////////////////////////////
// Global Giving project-specific functions
////////////////////////////////////////////////////////////////////////

// loadall: obsolete
/ uses lt to load all *2.csv files found in the current directory
/ not needed anymore since we have format strings; use load2 instead.
loadall:{
  f:{x where x like"*2.csv"}key`:.; / data files in pwd
  t:`$.[;(::;0)]"."vs/:string f;    / derive table names
  {.[x;();:;lt x]}each t}           / create global tables

/ format strings for the 7 original raw files (with quoted newlines removed)
/ Started with output of 'fmt lt tab' and then tweaked by hand.
/ MAYBE: F -> E and P -> D to save memory
googfmt:"ISIPPSDDS*IIIEEIIIIIIEIIIIII";
organfmt:"ISPP*****SS*S***IIIIPIPSS";
projefmt:"ISSIPP******S*****SSS*S*SSEPE*********PPPSIEIEIIIIPI";
rcptfmt:"IEEPIISISIISIIIII**SIEE**II";
rcptifmt:"IIEIIISIII**I*****IIIISPIE";
recurfmt:"IISEPPPPIIEIISSEESS";
recurfmt:"IISEIISSBPPS";
uausefmt:"IIPPS*S*SSS*SIIPIPII";
valuefmt:"IIIP*";

/ projectNumbericalSummary.csv format
pnsfmt:"I*SSESPPPEEEEEEEEE"; / upper{@[x;where"C"=x;:;"*"]}exec t from meta s;
/ obsolete
/ NB: don't name a column type! q doesn't like it
/ pns:@[;`num_donations;`int$]@[;`projtitle;trim]`projid`projtitle`ptype xcol lt`projectNumericalSummary;

// bn: basename
/ chop off dirs, extension, and version number from the back
/ of a data file path
/ x file handle eg `:data/organization2.csv
/ return C eg "organization"
bn:{
  f:first` vs last` vs x; / base file name (still has version #)
  / drop consecutive digits from the back of f
  reverse{_[;x]sum(and\)10>.Q.n?x}reverse string f}

// lf: load fast helper
/ uses pre-calculated format strings stored in globals
/ whose names are based on the table name
/ x file handle e.g., `:data/organization.csv
/ creates the table in the global namespace
lf:{
  t:`$bn x;                          / table name
  f:value(5 sublist string t),"fmt"; / get format string from global
  t set trimstr fixnullstr fixnullsym(f;(),",")0:x}

// load2: load the 7 original tables using their format strings
/ assumes the files have been processed by rnq and have 2 in the name
/ x optional directory containing the csv files
load2:{
/ t:`organization`project`rcpt`rcptitem`recurring`uauser`value_outcome;
  t:`goog`organization2`project2`rcpt2`rcptitem2`recurring2`uauser2`value_outcome2;
  lf each` sv/:hsym[$[null x;`.;x]],/:` sv/:t,\:`csv}

// loadfast: load the tables in kdb format
/ they must have been previously saved in kdb format using savefast.
/ x optional dir to find table files in kdb format
loadfast:{
 load each` sv/:hsym[x],/:{x where not x like"*.*"}key hsym x}

// savefast: save all the tables current in memory in kdb format
/ x optional dir to save the files in
savefast:{
  x{(` sv hsym[x],y)set value y}/:tables`}

// val: add val column (and line_item_id and volume_bucket_id) to rcptitem
/ focus on only funded and retired projects
val:{
  update val:amount*quantity from
    select from rcptitem lj
                  `rcptid xkey(select rcptid, line_item_id, volume_bucket_id
                                 from rcpt)
      where projid in
        exec distinct projid from project
          where status in`funded`retired}

// helper for summary Jon's aggregation
agg:{
  update direct_frac        :direct_frac % num_donations,
         disaster_frac      :disaster_frac % num_donations,
         open_challenge_frac:open_challenge_frac % num_donations
    from
      select total_raised       :sum val,
             mean_donation      :avg val,
             median_donation    :med val,
             max_donation       :max val,
             min_donation       :{?[0w=x;0f;x]}min{x where x>0}val,
             num_donations      :sum signum val,
             direct_frac        :sum signum val where line_item_id=135,
             disaster_frac      :sum signum val where line_item_id=103,
             open_challenge_frac:sum signum val where volume_bucket_id=6
        by projid
        from val[]}

// summary: attempt to imitate Jon's summary table
summary:{
  t:(select projid,
            projtitle,
            ptype,
            projthemeid,
            projamt,
            status,
            createdt,
            approveddt,
            deactivateDate
       from project where status in`funded`retired)
    lj agg[];
  / replace nulls (generated by join) with 0
  @[@[t;`num_donations;0i^];
    `total_raised`mean_donation`median_donation`max_donation`min_donation,
      `direct_frac`disaster_frac`open_challenge_frac;
    0f^]}

// don: donations and total by projid,date
/ x s optional currency
don:{
  ()xkey
    $[null x;
      select n:sum signum amount, sum amount*quantity
        by projid, date:creatdt
        from rcptitem;
      select n:sum signum amount, sum amount*quantity
        by projid, date:creatdt
        from rcptitem
        where currency_code=x]}

/ count how many projects received funds in particular currencies
/ select n:count i by currency_code from currcounts[]
currcounts:{
  1_()xkey / drop null projid
    select `#asc distinct currency_code
      by projid from
        (select rcptid, currency_code from rcpt)
          lj
        `rcptid xkey select rcptid, projid, amount, quantity from rcptitem}

// addkeys: define foreign key relationships so we can use dot notation
/ for simple joins, eg
/ ()xkey select val:sum amount*quantity by projid,`month$creatdt
/    from rcptitem where projid.status in`funded`retired
addkeys:{
  / key target tables
  `id`projid`rcptid`recurringid`uauserid xkey'
    `organization`project`rcpt`recurring`uauser;

  / delete the dangling fkeys and then make the links
  delete from `goog where not reference_id in
    exec distinct projid from project;
  update projid:`project$reference_id from `goog;

  update organization_id:`organization$organization_id from `project;
  update uauserid:`uauser$uauserid from `rcpt;

  delete from `rcptitem where
    (not projid in exec distinct projid from project)|
    not rcptid in exec distinct rcptid from rcpt;
  update organization_id:`organization$organization_id,
         projid:`project$projid,
         rcptid:`rcpt$rcptid
    from `rcptitem;

  update uauserid:`uauser$uauserid from `recurring;

  delete from `recurringitem where
    (not projid in exec projid from project)|
    not recurringid in exec recurringid from recurring;
  update organization_id:`organization$organization_id,
         projid:`project$projid,
         recurringid:`recurring$recurringid
    from `recurringitem;

  update projid:`project$projid from `value_outcome;
  }

// roll: roll-up recurring items in rcptitem
roll:{
  select
    from (update sum quantity by recurringitemid
            from rcptitem where recurringitemid>0)
    where (recurringitemid<=0) or i=(first;i)fby recurringitemid}

// dbd: donations by projid,date
/ x s optional currency eg `USD
dbd:{
  ()xkey
    $[null x;
      select donations:sum signum amount,sum amount*quantity
        by projid, date:`date$creatdt
        from rcptitem;
      select donations:sum signum amount,sum amount*quantity
        by projid, date:`date$creatdt
        from rcptitem
        where currency_code=x]}
                    
// dbp: donations by projid
/ x s optional currency eg `USD
dbp:{
  ()xkey
  $[null x;
    select donations:sum signum amount,sum amount*quantity
      by projid from rcptitem;
    select donations:sum signum amount,sum amount*quantity
      by projid from rcptitem where currency_code=x]}

// crd: conversion rates by projid,date
crd:{
  t:select
      from (dbd[`USD] lj
            select from select sum visits
              by projid:reference_id, date:start_date
              from goog)
      where not null visits;
  update cr:donations%visits,dpv:amount%visits from t where 0<visits}

// cr: conversion rates by projid
cr:{
  t:select
     from (dbp[`USD] lj
           select sum visits by projid:reference_id from goog)
      where not null visits;
  `cr xdesc
    update cr:donations%visits,dpv:amount%visits
      from t where 0<visits}

/ q)loadfast`:data / dir containing the rnq'd data files
/ q)tables`.
/ `organization`project`rcpt`rcptitem`recurring`uauser`value_outcome
/ q)d:dbd[] / donations by date
/ q)s:summary[]
/ who is donating?
/ q)select n:count i,sum val:quantity*amount by uauserid from update rcptid.uauserid from rcptitem
/ q)select sum amount by projid,date from d
/ q)select sum visits by projid,start_date from goog
/ q)crated:crd[] / by projid and date
/ q)crate:cr[]  / ignoring dates

prep:{
  loadfast`data;
  rawsummary::summary[];
  rcptitem:roll_rcptitem;
  delete roll_rcptitem from `.;
  addkeys[];
  rollsummary::summary[];
  / uastatus => real user
  donor::select from uauser
           where uastatus=1,
                 uauserid in exec distinct uauserid from rcpt;
  .Q.gc[];
  }

////////////////////////////////////////////////////////////////////////
/ Success histogram
success:{
  `n xdesc
    update h:(`int$100*n)#\:"*" from
      select n:sum[total_raised>projamt]%count i
        by projthemeid
        from summary[]
        where status=`funded}

////////////////////////////////////////////////////////////////////////
/ Words in project titles, summaries, ...

// wtp: words to project row numbers
/ works like group but one level deeper
/ x list of list of C
/ takes a few seconds
/ TODO: handle punctuation better
/       reduce words to stems
/       count punctuation marks as distinct words?
wtp:{
  if[`i in key`.;
     '"wtp overwrites global var i, but i is already defined"];

  w:({x where x in .Q.a,"-"}'')lower" "vs/:x; / words in each element of x

  i::0; / gross but I haven't found a better way to append row #s
  f:(enlist[""]!enlist(),-1){x@[;;,;-1+i+::1]/y}/w; / words!projrows
  delete i from `.;

  (!).(key f;value f)@\:where not key[f]in / remove uninteresting words
    ("";(),"&";(),"-";(),"a";"an";"and";"are";"as";"at";
     "be";"but";"by";"for";"from";
     "in";"is";"it";"of";"on";"or";
     "that";"the";"their";"this";"to";
     "was";"which";"will";"with")}

// word ratios table
/ x output of wtp
wrt:{
  p:(exec status from project)x;
  t:([]word   :key p;
       funded :sum each`funded=value p;
       retired:sum each`retired=value p;
       total  :count each value p);
  `pct2 xdesc update pct:funded%funded+retired,pct2:funded%total from t
    where 0<retired}

/ q)wpt:wtp exec projtitle from project
/ q)rat:wrt wpt
/ q)select from rat where 0<retired
/ q)`funded xdesc rat
/ q)wps:wtp exec projsummary from project
/ q)srat:wrt sp
/ q)select from srat where 0<retired
/ q)`funded xdesc srat
/ q)wpn:wtp exec projneed from project / etc

////////////////////////////////////////////////////////////////////////
// value outcome impact

// select distinct amount by projid from value_outcome
// `projid xasc `n xdesc select n:sum quantity by projid, amount from rcptitem
