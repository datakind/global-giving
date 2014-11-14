global-giving
=============

Repo for the GlobalGiving DataDive project

Instructions for using the q functions
----------------------------------------------------------
1) Get q from kx.com (Software -> Free Version).

2) Get the raw data files from google drive.

3) Start q and load gg.q:

nates-mbp:gg nate$ q gg.q
KDB+ 3.1 2014.05.21 Copyright (C) 1993-2014 Kx Systems
m32/ 8()core 8192MB nate nates-mbp.home 192.168.1.3 NONEXPIRE

Welcome to kdb+ 32bit edition
For support please see http://groups.google.com/d/forum/personal-kdbplus
Tutorials can be found at http://code.kx.com/wiki/Tutorials
To exit, type \\
To remove this startup msg, edit q.q
q)

4) Use the rnq function to remove newlines inside quotation marks from
the data files.  For example, if the data files are in the directory
data, the following command will a) create a list of the csv files in
directory data, and b) pass each one in turn to rnq to create a new,
repaired, csv file with the number 2 added to the each file's name
(and saved in the same directory):

q)rnq each{` sv/:x,/:{x where x like"*.csv"}key x}`:data
`:data/organization2.csv`:data/project2.csv`:data/rcpt2.csv`:data/rcptitem2.c..

5) Load the raw data into q using the load2 function.  loadfast
takes a single parameter: the directory where the <name>2.csv files
are.  load2 returns a list of the names of the tables it created.

q)load2`:data / a slash preceded by whitespace starts a line comment
`organization`project`rcpt`rcptitem`recurring`uauser`value_outcome

5.b) Save the tables in kdb format for faster loading next time:

q)savefast`:data
`:data/organization`:data/project`:data/rcpt`:data/rcptitem`:data/recurring`:..

Next you start q, you can use loadfast (which takes about 6 seconds on
my macbook to load everything):

q)\ts loadfast`:data / \ts gives time (ms) and size (bytes) for an operation
6097 1224506816

6) Examine the raw data:

q)tables`.
`organization`project`rcpt`rcptitem`recurring`uauser`value_outcome
q)5#project
projid status  type    deleted createdt                      modifdt         ..
-----------------------------------------------------------------------------..
2      funded  project 0       2003.05.16D12:57:20.000000000 2010.07.23D12:18..
3      retired project 0       2003.05.19D13:36:28.000000000 2010.07.23D12:18..
4      funded  project 0       2003.05.19D17:00:31.000000000 2010.07.23D12:18..
5      new     project 1       2003.05.19D17:46:47.000000000 2003.05.30D15:04..
6      retired project 0       2003.05.19D18:43:24.000000000 2010.07.23D12:18..

Here's one more example which may be helpful.  The rcptitem table has
48 projids that are not present in the project table:

q)count distinct (exec projid from rcptitem) except exec projid from project
48

If we get rid of them, we can create a foreign key relationship
between rcptitem and project, which will make queries that join the
two tables simpler to write:

q)delete from `rcptitem where not projid in exec distinct projid from project / delete the dangling projids from rcptitem
q)`projid xkey `project       / key project by projid
q)update projid:`project$projid from `rcptitem / make rcptitem.projid a foreign key to project.projid

Here's how to compute the total donated to funded and retired projects
each month:

q)5#()xkey select val:sum amount*quantity by projid,`month$creatdt from rcptitem where projid.status in`funded`retired
projid creatdt val
---------------------
2      2003.12 589.51
2      2004.01 1156
2      2004.05 120
2      2004.06 25
2      2004.07 80
