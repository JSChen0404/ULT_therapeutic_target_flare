libname CGRD_K "D:\CGRD\ShortForm";
libname imf    "C:\SAS\Analysis data\ULD";

%Let ID = IDCODE;
%Let Allopurinol    = "PIH005M";           * 100 mg;
%Let Benzbromarone  = "PIH006M" "P6A001M"; * 50 mg;
%Let Probenecid     = "PIH008M";           * 500 mg;
%Let Sulfinpyrazone = "PIH002M";           * 100 mg;
%Let Febuxostat     = "PIH012M" "PIH014M"; * 80 mg;
%Let colchicine     = "PGC020M" "PGC107M"; * 0.5 mg;
%Let NSAID          = "P6A098M" "PGC002M" "PGC010M" "PGC012M" "PGC014M" "PGC018M" "PGC028M" "PGC032E" "PGC037M" "PGC040M" "PGC048M" "PGC050M" 
"PGC051M" "PGC053M" "PGC054M" "PGC058M" "PGC060M" "PGC064E" "PGC068M" "PGC072M" "PGC078M" "PGC080M" "PGC092P" "PGC100P" "PGC105M" "PGC106P" 
"PGC108M" "PGC109M" "PKA020M" "PTA016S";

/* (1) define gout flares (ED, unexpected return to OPD) per dose level and ULD：
    - 定義：若看診後，在開藥的時間內，又有回診且開1)NSAID、2)或是秋水仙素、3)或是急診痛風回診就算
    - number of hospital visits after the treatment may be an alternative?!
*/

data ULD;
	set CGRD_K.OP_CGDA (keep=&ID QTY drug_days med_date RCFNO_C DYS DSG FRQ CHRGDPTID
						where=(RCFNO_C in (&Allopurinol &Benzbromarone &Sulfinpyrazone &Febuxostat &Probenecid))); 	
run;

Proc SQL;
create table ULD2 as
select a.&ID, a.med_date, CHRGDPTID, sum(drug_days) as drug_days
	from ULD a 
	inner join (select distinct &ID, start_date from imf.all_initial_3) b on a.&ID=b.&ID
	where a.drug_days > 0 and b.start_date < a.med_date
	group by a.&ID, a.med_date, CHRGDPTID
	order by a.&ID, a.med_date;
quit;

data ULD3;
	set ULD2;
	end_date = med_date + drug_days;
	format end_date yymmdd10.;
	rename med_date = start_date;
run;

data NSAID;
	set CGRD_K.OP_CGDA (keep=&ID med_date RCFNO_C CHRGDPTID rename=(med_date=NSAID_date) where=(RCFNO_C in (&NSAID))); 	
run;

PROC SQL;
CREATE TABLE def_NSAID AS 
	SELECT distinct b.&ID, b.NSAID_date
	FROM ULD3 a
	INNER JOIN NSAID b ON a.&ID=b.&ID and a.start_date < b.NSAID_date <= a.end_date - 3 and a.CHRGDPTID=b.CHRGDPTID 
	INNER JOIN CGRD_K.OP_DIAG(where=(DSSID in: ("274" "M10" "M1A" "E790"))) c ON b.&ID=c.&ID and b.NSAID_date=c.med_date
	order by a.&ID, b.NSAID_date;
QUIT;

data d_colchicine;
	set CGRD_K.OP_CGDA (keep=&ID med_date RCFNO_C CHRGDPTID rename=(med_date=colchicine_date) where=(RCFNO_C in (&colchicine))); 	
run;

PROC SQL;
CREATE TABLE def_colchicine AS 
	SELECT distinct b.&ID, b.colchicine_date
	FROM ULD3 a
	INNER JOIN d_colchicine b ON a.&ID=b.&ID and start_date < b.colchicine_date <= end_date - 3 and a.CHRGDPTID=b.CHRGDPTID
	INNER JOIN CGRD_K.OP_DIAG (where=(DSSID in: ("274" "M10" "M1A" "E790"))) c ON b.&ID=c.&ID and b.colchicine_date=c.med_date
	order by a.&ID, b.colchicine_date;
QUIT;

PROC SQL; 
CREATE TABLE def_ER_return AS 
	SELECT distinct b.&ID, b.med_date as ER_return_date
	FROM imf.all_initial_3 a
	INNER JOIN CGRD_K.ER_DIAG (where=(DSSID in: ("274" "M10" "M1A" "E790")))  b 
	ON a.&ID=b.&ID and a.start_date < b.med_date
	order by a.&ID ;
QUIT;

data def_flare_all;
	set def_NSAID      (keep=&ID NSAID_date      rename=(NSAID_date=flare_date)) 
		def_colchicine (keep=&ID colchicine_date rename=(colchicine_date=flare_date))  
		def_ER_return  (keep=&ID ER_return_date  rename=(ER_return_date=flare_date)) ;
run;
Proc sort data=def_flare_all nodupkey ; by _all_; run;*14326;

PROC SQL;*11508;
CREATE TABLE def_flare_all2 AS 
	SELECT a.&ID, one_month_date, flare_date, flare_date - one_month_date as dif
	FROM def_flare_all a
	INNER JOIN imf.all_initial_7 (drop= flare_date) b 
	ON a.&ID=b.&ID
	order by a.&ID, flare_date;
QUIT;

data def_flare_all3;
	set def_flare_all2;
	if dif <= 90  then period = 1;
		else if dif <= 180 then period = 2;
		else period = 3;
run;

PROC SQL;
CREATE TABLE temp AS 
	SELECT coalesce(a.&ID, b.&ID) as &ID, 
		   flare_date_period1 format=yymmdd10., 
		   flare_date_period2 format=yymmdd10.
	FROM (select &ID, min(flare_date) as flare_date_period1 from def_flare_all3 where period = 1 group by &ID) a
	FULL JOIN (select &ID, min(flare_date) as flare_date_period2 from def_flare_all3 where period = 2 group by &ID) b ON a.&ID=b.&ID;

CREATE TABLE def_flare_all4 AS 
	SELECT coalesce(a.&ID, b.&ID) as &ID, 
		   a.flare_date_period1, a.flare_date_period2, 
		   b.flare_date_period3 format=yymmdd10. 
	FROM temp a
	FULL JOIN (select &ID, min(flare_date) as flare_date_period3 from def_flare_all3 where period = 3 group by &ID) b ON a.&ID=b.&ID;
QUIT;
Proc sort data=def_flare_all4 ; by &ID; run;

PROC SQL;* 37262;
CREATE TABLE def_flare_all5 AS 
	SELECT a.*, b.flare_date_period1, b.flare_date_period2, b.flare_date_period3
	FROM imf.all_initial_7 (drop=flare flare_date) a
	LEFT JOIN def_flare_all4 b ON a.&ID=b.&ID ;
QUIT; 

data def_flare_all6;
	set def_flare_all5; 
	if flare_date_period1 ne . then flare_period1 = 1; else flare_period1 = 0;
	if flare_date_period2 ne . then flare_period2 = 1; else flare_period2 = 0;
	if flare_date_period3 ne . then flare_period3 = 1; else flare_period3 = 0;
	days_period1 = min(flare_date_period1 - one_month_date	    									, 90);
	days_period2 = min(flare_date_period2 - one_month_date + 90 , LAST_VISIT_D - one_month_date + 90, 90);
	days_period3 = min(flare_date_period3 - one_month_date + 180, LAST_VISIT_D - one_month_date + 180); 
	if age<40 then age_c=1;
		else if 40 <= age < 50 then age_c=2;
		else if 50 <= age < 65 then age_c=3;
		else age_c=4;
run;

Proc SQL;
CREATE TABLE def_flare_all7 AS 
select group, sex, age_c, 
	   sum(flare_period1) as flare_period1, log(sum(days_period1)) as days_period1,
	   sum(flare_period2) as flare_period2, log(sum(days_period2)) as days_period2,
	   sum(flare_period3) as flare_period3, log(sum(days_period3)) as days_period3
	from def_flare_all6
	group by group, sex, age_c;
quit;

/********************************************************************************************************************************/
/*  Result                                                                                                                      */
/********************************************************************************************************************************/

Proc freq data = def_flare_all6; table group*(flare_period1 flare_period2 flare_period3) /nocol norow nopercent; run;

/*
proc genmod data = def_flare_all7;
	class group sex age_c;
	model flare_period1 = group sex age_c / dist=poisson link=log offset=days_period1;
	lsmeans group / ilink cl;
run; 
*/


%Macro Adjusted_incidence_rate();
	%do no = 1 %to 3;
		proc genmod data = def_flare_all7;
			class group sex age_c;
			model flare_period&no = group sex age_c / dist=poisson link=log offset=days_period&no;
			lsmeans group / ilink cl;
			ods select LSMeans;
		run; 
	%end;
%Mend Adjusted_incidence_rate;
%Adjusted_incidence_rate(); 