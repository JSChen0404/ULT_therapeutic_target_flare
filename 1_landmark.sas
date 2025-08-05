libname CGRD_K "Y:\CGRD\D_CG000_郭昶甫_Short Form\To_11112";
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


%Macro Retri_RCFNO(CODES=, DOSE=, OUT=);
	data &OUT (drop=RCFNO_C);
		set CGRD_K.OP_CGDA (keep=&ID QTY drug_days med_date RCFNO_C DYS DSG FRQ where=(RCFNO_C in ( &codes )));
		avg_dose = QTY*&DOSE / drug_days;		
	run;

	Proc sort data=&OUT; by &ID med_date; run;
	data &OUT._first28;
		set &OUT; by &ID med_date; 
		if first.&ID and drug_days>=28;
	run;
%Mend Retri_RCFNO;
%Retri_RCFNO(CODES = &Allopurinol   , DOSE = 100, OUT = Allopurinol);   * 1454030 -> 37470;
%Retri_RCFNO(CODES = &Benzbromarone , DOSE = 50 , OUT = Benzbromarone); * 1584619 -> 59870;
%Retri_RCFNO(CODES = &Probenecid    , DOSE = 500, OUT = Probenecid);    * 4020 -> 252;
%Retri_RCFNO(CODES = &Sulfinpyrazone, DOSE = 100, OUT = Sulfinpyrazone);* 569613 -> 20567;
%Retri_RCFNO(CODES = &Febuxostat    , DOSE = 80 , OUT = Febuxostat);    * 43042 -> 34635;
%Retri_RCFNO(CODES = &colchicine    , DOSE = 0.5, OUT = colchicine);    * 2138064 -> 44759;


Proc freq data = Febuxostat; table drug_days; run;
Proc freq data = Febuxostat; table avg_dose; run;
Proc freq data = Febuxostat_first28; table avg_dose; run;


/*
Proc freq  data=Febuxostat_first28_4; table avg_dose; run;
Proc means data=Febuxostat_first28_4 mean std ; var Value Value_umol; class avg_dose; run;
*/

/*  limit in the initial user  */
%Macro Retri_RCFNO(IN=, OUT=);
	PROC SQL;
	CREATE TABLE &OUT AS
	SELECT &ID, min(med_date) as &IN._date format=yymmdd10.
		FROM &IN 
		GROUP BY &ID
		ORDER BY &ID;
	QUIT;
%Mend Retri_RCFNO;
%Retri_RCFNO(IN = Allopurinol   , OUT = Allopurinol_first);
%Retri_RCFNO(IN = Benzbromarone , OUT = Benzbromarone_first);
%Retri_RCFNO(IN = Probenecid    , OUT = Probenecid_first);
%Retri_RCFNO(IN = Sulfinpyrazone, OUT = Sulfinpyrazone_first);
%Retri_RCFNO(IN = Febuxostat    , OUT = Febuxostat_first); 

 
data drug;
	length initial_drug $15;
    merge Allopurinol_first(in=_a) Benzbromarone_first(in=_b) Probenecid_first Sulfinpyrazone_first Febuxostat_first; by &ID;
    initial_date = min(Allopurinol_date, Benzbromarone_date, Probenecid_date, Sulfinpyrazone_date, Febuxostat_date);
	if initial_date = Allopurinol_date then initial_drug = "Allopurinol";
		else if initial_date = Benzbromarone_date then initial_drug = "Benzbromarone";
		else if initial_date = Probenecid_date then initial_drug = "Probenecid";
		else if initial_date = Sulfinpyrazone_date then initial_drug = "Sulfinpyrazone";
		else initial_drug = "Febuxostat";
	format initial_date yymmdd10.;
run;
Proc freq data=drug ; table initial_drug; run;
Proc sort data=drug nodupkey out=x ; by &ID; run;*delete 0;

data drug2;*143628;
	set drug;*146203;
	if initial_date < Allopurinol_date    <= initial_date+28 or 
	   initial_date < Benzbromarone_date  <= initial_date+28 or 
	   initial_date < Probenecid_date     <= initial_date+28 or 
	   initial_date < Sulfinpyrazone_date <= initial_date+28 or
	   initial_date < Febuxostat_date     <= initial_date+28
	then delete;
run;

Proc SQL;*142665;
create table drug3 as 
select a.*, yrdif(input(b.BIRTHDAY,yymmdd8.), initial_date) as age, b.SEX, b.LAST_VISIT_D
    from drug2 a
    inner join CGRD_K.UNIQUE_IDCODE b on a.IDCODE=b.IDCODE
	having age > 0;
quit;

%Macro Retri_Lab(CRITERIA=, OUT=);
	data &OUT;
		set CGRD_K.LAB_RESULT ; 
		where &CRITERIA ;
	run;
%Mend Retri_Lab;
%Retri_Lab(
CRITERIA = LABSH1IT in ("72-331" "72-563") and SPCM eq "B",
OUT      = UAC)

%Macro measure_before_and_after1(name, dose_specific);
	data &name._first28_2;*33312;
		set &name._first28 (keep=&ID avg_dose med_date where=(avg_dose in ( &dose_specific )));
		one_month_date = med_date + 28;
	run;

	PROC SQL;*33620;
	CREATE TABLE &name._first28_3 AS 
		SELECT b.*, a.Lab_date, a.Value, Value*59.48 as Value_umol 
		FROM UAC(where=(Value>0)) a
		INNER JOIN &name._first28_2 b 
		ON a.&ID=b.&ID and one_month_date <= Lab_date <= one_month_date+90
		ORDER BY b.&ID, a.Lab_date;
	QUIT;
	Proc sort data=&name._first28_3 nodupkey out=&name._first28_4 ; by &ID; run;*23162;


	PROC SQL;*43752;
	CREATE TABLE &name._baseline AS 
		SELECT b.*, a.Lab_date, a.Value, Value*59.48 as Value_umol 
		FROM UAC(where=(Value>0)) a
		INNER JOIN &name._first28_2 b 
		ON a.&ID=b.&ID and med_date - 90 <= Lab_date <= med_date
		ORDER BY b.&ID, a.Lab_date desc;
	QUIT;
	Proc sort data=&name._baseline nodupkey out=&name._baseline_2; by &ID; run;*29657;


	PROC SQL;*9459;
	CREATE TABLE &name._initial AS 
		SELECT b.*, c.Value as Value_base, c.Value_umol as Value_umol_base
		FROM drug3 (where=(initial_drug = "&name.")) a
		INNER JOIN &name._first28_4  b ON a.&ID=b.&ID
		INNER JOIN &name._baseline_2 c ON a.&ID=c.&ID;
	QUIT;
%mend measure_before_and_after1;
%measure_before_and_after1(Allopurinol   , 50 100 200);
%measure_before_and_after1(Benzbromarone , 25 50  100);
%measure_before_and_after1(Sulfinpyrazone, 50 100 200);
%measure_before_and_after1(Febuxostat    , 20 40  80) ;

Proc freq data=Allopurinol_initial   ; table avg_dose; run;*50/100/200;
Proc freq data=Benzbromarone_initial ; table avg_dose; run;*25/50/100;
Proc freq data=Sulfinpyrazone_initial; table avg_dose; run;*50/100/200;


data imf.all_initial (drop=dose_label);*43584;
	set Allopurinol_initial (in=_a)
		Benzbromarone_initial (in=_b)
		Febuxostat_initial (in=_c)
		Sulfinpyrazone_initial ;  
	length initial_drug $15 dose_label $5 group $25;
	if _a then do;
		initial_drug = "Allopurinol";
		if avg_dose = 50  then dose_label = '1.50';
		if avg_dose = 100 then dose_label = '2.100';
		if avg_dose = 200 then dose_label = '3.200';
	end;
		else if _b then do; 
			initial_drug = "Benzbromarone";
			if avg_dose = 25  then dose_label = '1.25';
			if avg_dose = 50  then dose_label = '2.50';
			if avg_dose = 100 then dose_label = '3.100';
		end;
		else if _c then do;  
			initial_drug = "Febuxostat";
			if avg_dose = 20 then dose_label = '1.20';
			if avg_dose = 40 then dose_label = '2.40';
			if avg_dose = 80 then dose_label = '3.80';
		end;
		else do; 
			initial_drug = "Sulfinpyrazone";
			if avg_dose = 50  then dose_label = '1.50';
			if avg_dose = 100 then dose_label = '2.100';
			if avg_dose = 200 then dose_label = '3.200';
		end;
	group = compress(initial_drug||"_"||dose_label);
run;
Proc freq data= all_initial; table initial_drug; run;

PROC SQL;*43584;
CREATE TABLE all_initial_2 AS 
	SELECT a.*, b.age, b.sex, b.LAST_VISIT_D
	FROM all_initial a
	INNER JOIN DRUG3 b 
	ON a.&ID=b.&ID and a.med_date=initial_date;
QUIT;
Proc sort data=all_initial_2 nodupkey out=x ; by &ID; run;*delete 0;

/* define confounder */
PROC SQL;
CREATE TABLE covar_colchicine AS 
	SELECT distinct a.&ID, 1 as colchicine
	FROM all_initial_2 a
	INNER JOIN CGRD_K.OP_CGDA (where=(RCFNO_C in ( &colchicine ))) b 
	ON a.&ID=b.&ID and a.med_date <= b.med_date <= a.one_month_date;
QUIT;

%Macro Retri_Lab(CRITERIA=, OUT=);
	data temp;
		set CGRD_K.LAB_RESULT ; 
		where &CRITERIA ;
	run;

	PROC SQL; 
	CREATE TABLE &OUT AS 
		SELECT b.&ID, b.med_date, a.Lab_date, a.Value 
		FROM temp (where=(Value>0)) a
		INNER JOIN all_initial_2 b 
		ON a.&ID=b.&ID and b.med_date - 90 <= a.Lab_date <= b.med_date
		ORDER BY b.&ID, a.Lab_date;
	QUIT;
	Proc sort data = &OUT nodupkey; by &ID; run;
%Mend Retri_Lab;
%Retri_Lab(
CRITERIA = LABSH1IT in ("72-307" "72-503") and SPCM eq "B", /* BUN */
OUT      = BUN)

%Retri_Lab(
CRITERIA = LABSH1IT in ("72-333" "72-505") and SPCM eq "B", /* Creatinine */
OUT      = Creatinine)

PROC SQL;*43444;
CREATE TABLE imf.all_initial_3 (rename=(med_date=start_date) where=(LAST_VISIT_D > one_month_date)) AS 
	SELECT a.*, coalesce(b.colchicine, 0) as colchicine, c.Value as BUN, d.Value as Creatinine
	FROM all_initial_2 a
	LEFT JOIN covar_colchicine b ON a.&ID=b.&ID
	LEFT JOIN BUN 			   c ON a.&ID=c.&ID
	LEFT JOIN Creatinine 	   d ON a.&ID=d.&ID;
QUIT;


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
Proc sort data=def_NSAID nodupkey; by &ID; run;*5203 -> 1988;

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
Proc sort data=def_colchicine nodupkey; by &ID; run;*8716 -> 2992;

PROC SQL; 
CREATE TABLE def_ER_return AS 
	SELECT distinct b.&ID, b.med_date as ER_return_date
	FROM imf.all_initial_3 a
	INNER JOIN CGRD_K.ER_DIAG (where=(DSSID in: ("274" "M10" "M1A" "E790")))  b 
	ON a.&ID=b.&ID and a.start_date < b.med_date
	order by a.&ID ;
QUIT;
Proc sort data=def_ER_return nodupkey; by &ID; run;*1837;

data def_flare; *11410 -> 4989;
    merge def_NSAID(in=_a) def_colchicine(in=_b) def_ER_return(in=_c); by &ID;
	flare_date = min(NSAID_date, colchicine_date, ER_return_date);
	if flare_date=NSAID_date then def_ver="1";
		else if flare_date=colchicine_date then def_ver="2";
		else def_ver="3";
	format flare_date yymmdd10.;
run;
Proc freq data= def_flare; table def_ver; run;
 

PROC SQL;*43444;
CREATE TABLE all_initial_4 AS 
	SELECT a.*, b.flare_date, ifn(flare_date ne ., 1, 0) as flare
	FROM imf.all_initial_3 a
	LEFT JOIN def_flare b ON a.&ID=b.&ID
	order by a.&ID;
QUIT;

/*(2) secondary outcomes such as number of people achieving the therapeutical target etc (6mg/dl).*/

PROC SQL;
CREATE TABLE target AS 
	SELECT a.&ID, a.Lab_date, a.value
	FROM UAC (where=(0 < value <= 6)) a
	INNER JOIN imf.all_initial_3 b 
	ON a.&ID=b.&ID and b.start_date <= a.Lab_date
	order by a.&ID, a.Lab_date;
QUIT;
Proc sort data=target nodupkey out=target_uni; by &ID; run;*35461;

PROC SQL;*43444;
CREATE TABLE all_initial_5 AS 
	SELECT a.*, b.Lab_date as target_UA_date, ifn(b.&ID is not null, 1 , 0) as target_UA
	FROM all_initial_4 a
	LEFT JOIN target_uni b ON a.&ID=b.&ID;
QUIT;
Proc freq data=all_initial_5; table target_UA; run;

data imf.all_initial_6;*40248;
	set all_initial_5; *43444;
	if Creatinine ne .;
	if flare_date = . or one_month_date < flare_date then do;
		if flare = 1 then fy_flare = yrdif(one_month_date, flare_date);
			else fy_flare = yrdif(one_month_date, LAST_VISIT_D);
	end;
	if target_UA_date = . or one_month_date < target_UA_date then do;
		if target_UA = 1 then fy_target_UA = yrdif(one_month_date, target_UA_date);
			else fy_target_UA = yrdif(one_month_date, LAST_VISIT_D);
	end;
run;

Proc freq  data=imf.all_initial_6; table flare 	  ; where fy_flare ne .; run;
Proc freq  data=imf.all_initial_6; table target_UA; where fy_target_UA ne .; run;
Proc means data=imf.all_initial_6 n mean std median q1 q3 min max; var fy_flare fy_target_UA; run;


data x1 x2 imf.all_initial_7;*37262;
	set imf.all_initial_6;*40248;
	start_y = year(start_date);
	if sex="F" then eGFR = 175 * (Creatinine**-1.154) * (age**-0.203) * 0.742;
	if sex="M" then eGFR = 175 * (Creatinine**-1.154) * (age**-0.203); 
	m_flare = fy_flare*12;
	m_target_UA = fy_target_UA*12;
	dif_Value = Value_base - Value;
	seq = scan(group, 2, '._')*1;
	if age<40 then age_c=1;
		else if 40 <= age < 50 then age_c=2;
		else if 50 <= age < 65 then age_c=3;
		else age_c=4;
	if 90 <= eGFR then eGFR_c=1;
		else if 60 <= eGFR < 90 then eGFR_c=2;
		else if 30 <= eGFR < 60 then eGFR_c=3;
		else if 15 <= eGFR < 30 then eGFR_c=4;
		else eGFR_c=5;
	if initial_drug = "Allopurinol"    then initial_drug = "1Allopurinol";
	if initial_drug = "Febuxostat"     then initial_drug = "2Febuxostat";
	if initial_drug = "Benzbromarone"  then initial_drug = "3Benzbromarone";
	if initial_drug = "Sulfinpyrazone" then initial_drug = "4Sulfinpyrazone";
	if group = "Allopurinol_1.50"     then group ="01.Allopurinol_1.50";
	if group = "Allopurinol_2.100"    then group ="02.Allopurinol_2.100";
	if group = "Allopurinol_3.200"    then group ="03.Allopurinol_3.200";
	if group = "Febuxostat_1.20"      then group ="04.Febuxostat_1.20";
	if group = "Febuxostat_2.40"      then group ="05.Febuxostat_2.40";
	if group = "Febuxostat_3.80"      then group ="06.Febuxostat_3.80";
	if group = "Benzbromarone_1.25"   then group ="07.Benzbromarone_1.25";
	if group = "Benzbromarone_2.50"   then group ="08.Benzbromarone_2.50";
	if group = "Benzbromarone_3.100"  then group ="09.Benzbromarone_3.100";
	if group = "Sulfinpyrazone_1.50"  then group ="10.Sulfinpyrazone_1.50";
	if group = "Sulfinpyrazone_2.100" then group ="11.Sulfinpyrazone_2.100";
	if group = "Sulfinpyrazone_3.200" then group ="12.Sulfinpyrazone_3.200";
	if age < 18 then output x1;*125;
		else if Value_base <= 7 then output x2;*2861;
		else output imf.all_initial_7;
run;

filename outpath "H:\Temporary\all_initial_7.csv" encoding="utf-8";
proc export data = imf.all_initial_7 outfile=outpath dbms=csv replace;
run;

Proc means data = imf.all_initial_7 mean std median q1 q3 min max; var fy_flare; run;


PROC SQL; 
CREATE TABLE imf.all_initial_8 AS 
	SELECT a.*, b.flare_date, ifn(flare_date ne ., 1, 0) as flare
	FROM imf.all_initial_7(drop=flare flare_date) a
	LEFT JOIN def_flare b ON a.&ID=b.&ID
	order by a.&ID;
QUIT;
Proc freq data = imf.all_initial_8; table flare; run;*flare = 1, 4049;

filename outpath "H:\Temporary\all_initial_8.csv" encoding="utf-8";
proc export data = imf.all_initial_8 outfile=outpath dbms=csv replace;
run;

/********************************************************************************************************************************/
/*  Result                                                                                                                      */
/********************************************************************************************************************************/

%Let final_data = imf.all_initial_8;

/*===   Table 1   ===*/
Proc means data= &final_data mean std maxdec=1; var age ; class group; run;
Proc means data= &final_data mean std maxdec=1; var eGFR; class group; run;
Proc means data= &final_data mean std maxdec=1; var BUN ; class group; run;

Proc means data= &final_data mean std maxdec=1; var eGFR; run;

Proc freq  data= &final_data; table group; run;
proc format;
	picture paren (round)
		low-high = '(009.99)'
		( prefix = '(' ); 
run;

proc tabulate data = &final_data Noseps;
	class group sex colchicine /MISSING;
	table sex colchicine, 
		  group="" *  ( N       ="" * [style=[just=R cellwidth=90  borderrightstyle = hidden] f=comma6.]
	                    ColPctN ="" * [style=[just=L cellwidth=110 borderleftstyle  = hidden] f=paren. ])/ box="factor" Misstext="0";
	*format id_gender gender. age_c age. class class. DM $DM;
run;
Proc freq data=&final_data ; table initial_drug; run;


%Macro p_for_trend(var);
	Proc freq data=&final_data ; table group*&var / trend; where initial_drug = '1Allopurinol'; ods select TrendTest; run;
	Proc freq data=&final_data ; table group*&var / trend; where initial_drug = '2Febuxostat'; ods select TrendTest;  run;
	Proc freq data=&final_data ; table group*&var / trend; where initial_drug = '3Benzbromarone'; ods select TrendTest;  run;
	Proc freq data=&final_data ; table group*&var / trend; where initial_drug = '4Sulfinpyrazone'; ods select TrendTest;  run; 
%Mend p_for_trend;
%p_for_trend(sex);
%p_for_trend(colchicine);
 


/* supp - medication and comorbidity*/

%Macro retri_drug(name);
	data &name (keep=&ID med_date);
		set CGRD_K.OP_OO (keep=&ID CHRGDAT NHINO QTY where=(NHINO in (&&&name)));
		if QTY > 0;
		med_date = input(CHRGDAT, yymmdd8.);
		format med_date yymmdd10.;
	run; 

	PROC SQL;
	CREATE TABLE &name._ID AS 
		SELECT distinct a.&ID
		FROM &name a
		INNER JOIN IMF.ALL_INITIAL_8 b 
		ON a.&ID=b.&ID and b.one_month_date - 118 <= a.med_date <= b.one_month_date;
	QUIT;
%Mend retri_drug;
%retri_drug(NSAID)
%retri_drug(Insulin)
%retri_drug(glucose_lowering)
%retri_drug(corticosteroids)
%retri_drug(ACEI)
%retri_drug(ARB)
%retri_drug(beta_blocker)
%retri_drug(CCB)
%retri_drug(Aspirin)
%retri_drug(Statin)
%retri_drug(diuretics_Kspar)
%retri_drug(diuretics_thiazide)
%retri_drug(diuretics_loop)
%retri_drug(P2Y12)
%retri_drug(PCSK9)
%retri_drug(SGLT2)
%retri_drug(GLP1)
%retri_drug(NOAC) 


PROC SQL;
CREATE TABLE test AS 
	SELECT a.*, 
ifn(b1.&ID is not null, 1, 0) as NSAID, ifn(b2.&ID is not null, 1, 0) as Insulin, ifn(b3.&ID is not null, 1, 0) as glucose_lowering, 
ifn(b4.&ID is not null, 1, 0) as corticosteroids, ifn(b5.&ID is not null, 1, 0) as ACEI, ifn(b6.&ID is not null, 1, 0) as ARB, 
ifn(b7.&ID is not null, 1, 0) as beta_blocker, ifn(b8.&ID is not null, 1, 0) as CCB, ifn(b9.&ID is not null, 1, 0) as Aspirin, 
ifn(b10.&ID is not null, 1, 0) as Statin, ifn(b11.&ID is not null, 1, 0) as diuretics_Kspar, ifn(b12.&ID is not null, 1, 0) as diuretics_thiazide, 
ifn(b13.&ID is not null, 1, 0) as diuretics_loop, ifn(b14.&ID is not null, 1, 0) as P2Y12, ifn(b15.&ID is not null, 1, 0) as PCSK9, 
ifn(b16.&ID is not null, 1, 0) as SGLT2, ifn(b17.&ID is not null, 1, 0) as GLP1, ifn(b18.&ID is not null, 1, 0) as NOAC
	FROM IMF.ALL_INITIAL_8 a
	LEFT JOIN NSAID_ID   b1 ON a.&ID=b1.&ID
	LEFT JOIN Insulin_ID b2 ON a.&ID=b2.&ID
	LEFT JOIN glucose_lowering_ID b3 ON a.&ID=b3.&ID
	LEFT JOIN corticosteroids_ID b4 ON a.&ID=b4.&ID
	LEFT JOIN ACEI_ID b5 ON a.&ID=b5.&ID
	LEFT JOIN ARB_ID b6 ON a.&ID=b6.&ID
	LEFT JOIN beta_blocker_ID b7 ON a.&ID=b7.&ID
	LEFT JOIN CCB_ID b8 ON a.&ID=b8.&ID
	LEFT JOIN Aspirin_ID b9 ON a.&ID=b9.&ID
	LEFT JOIN Statin_ID b10 ON a.&ID=b10.&ID
	LEFT JOIN diuretics_Kspar_ID b11 ON a.&ID=b11.&ID
	LEFT JOIN diuretics_thiazide_ID b12 ON a.&ID=b12.&ID
	LEFT JOIN diuretics_loop_ID b13 ON a.&ID=b13.&ID
	LEFT JOIN P2Y12_ID b14 ON a.&ID=b14.&ID
	LEFT JOIN PCSK9_ID b15 ON a.&ID=b15.&ID
	LEFT JOIN SGLT2_ID b16 ON a.&ID=b16.&ID
	LEFT JOIN GLP1_ID b17 ON a.&ID=b17.&ID
	LEFT JOIN NOAC_ID b18 ON a.&ID=b18.&ID;
QUIT;
Proc freq data=test ; table NSAID--NOAC; run;

%Macro print_percentage(name);
	Proc freq data = test ; table group*&name /nopercent nocol nofreq chisq ; 
		ods output CrossTabFreqs=IndTable;
	run; 
	proc print data = IndTable label;
		where group ne "" and rowpercent ne . and &name = 1;
		var group rowpercent;
		format rowpercent 8.1;
		label rowpercent=&name;
	run; 
%Mend print_percentage;
%print_percentage(NSAID)
%print_percentage(Insulin)
%print_percentage(glucose_lowering)
%print_percentage(corticosteroids)
%print_percentage(ACEI)
%print_percentage(ARB)
%print_percentage(beta_blocker)
%print_percentage(CCB)
%print_percentage(Aspirin)
%print_percentage(Statin)
%print_percentage(diuretics_Kspar)
%print_percentage(diuretics_thiazide)
%print_percentage(diuretics_loop)
%print_percentage(P2Y12) 
%print_percentage(SGLT2)
%print_percentage(GLP1)
%print_percentage(NOAC) 

%Macro Retri_All_Claims(IN= , OUT=All_claims);
	Proc sort data=&in (keep=&ID one_month_date) nodupkey out=tempid; by &id; run;

	Proc SQL;
	create table &out as 
	select a.&ID, input(PDBGNDAT,yymmdd8.) as MED_Date format=yymmdd10., a.DSSID1 as DXKD1 length=10, a.DSSID2 as DXKD2 length=10, 
           a.DSSID3 as DXKD3 length=10, a.MORCD as OPNO1 length=10, "CD" as source
	    from CGRD_K.OP_CD a
	        inner join tempid b on a.&id=b.&id and b.one_month_date - 1095 <= input(PDBGNDAT,yymmdd8.) <= b.one_month_date

	OUTER UNION CORR

	select a.&ID, admis_date as MED_Date format=yymmdd10., a.DXKD1, a.DXKD2, a.DXKD3, a.DXKD4, a.DXKD5, 
           a.OPNO1, a.OPNO2, a.OPNO3, a.OPNO4, a.OPNO5, "DD" as source
	    from CGRD_K.IP_ICD a
	        inner join tempid b on a.&id=b.&id and b.one_month_date - 1095 <= a.admis_date <= b.one_month_date;
	quit;
%Mend Retri_All_Claims;
%Retri_All_Claims(IN=IMF.ALL_INITIAL_8 , OUT= All_claims)


%Macro C_CCI(data=, id=idcode, med_d=med_date, number=17, output= CCI, ICDs=DXKD1-DXKD5, OPs=OPNO1-OPNO5, gap=30);
data claimdata (keep= &id &med_d D1-D&number source);
	set &data  (keep= &id &med_d source &ICDs &OPs);
	array ICD(*)    $ &ICDs;  	      
	array opcode(*) $ &OPs ;  
	do i=1 to dim(ICD);
	**MI ;     if ICD(i) in: ("410" "412" "I21" "I22" "I252") then D1="1";
	**CHF;	   if ICD(i) in: ("425" "428" "4293" "40201" "40211" "40291" "40401" "40403" "40411" "40413" "40491" "40493" "I099" "I110" "I130" "I132" "I255" "I420" "I425" "I426" "I427" "I428" "I429" "I43" "I50" "P290") then D2="1";
	**PVD;     if ("440" <=: ICD(i) <=: "4439") or ICD(i) in: ("4471" "7854" "I70" "I71" "I731" "I738" "I739" "I771" "I790" "I792" "K551" "K558" "K559" "Z958" "Z959") or opcode(i) in: ("3813" "3814" "3816" "3818" "3833" "3834" "3836" "3838" "3843" "3844" "3846" "3848" "3922" "3923" "3924" "3925" "3926" "3929") then D3="1";
	**CVA;     if ICD(i) in: ("437" "438" "4370" "4371" "4379" "7814" "7843" "9970" "36234" "G45" "G46" "H340" "I60" "I61" "I62" "I63" "I64" "I65" "I66" "I67" "I68" "I69") or ("430" <=: ICD(i) <=: "436") or opcode(i) in: ("3812" "3842") then D4="1";
	**DEM;     if ICD(i) in: ("290" "331" "3310" "3311" "3312" "F00" "F01" "F02" "F03" "F051" "G30" "G311") then D5="1";
	**CPD;     if ("491" <=: ICD(i) <=: "494") or ICD(i) in: ("496" "4150" "4168" "4169" "I278" "I279" "J40" "J41" "J42" "J43" "J44" "J45" "J46" "J47" "J60" "J61" "J62" "J63" "J64" "J65" "J66" "J67" "J684" "J701" "J703") then D6="1";
	**Rhe;     if ICD(i) in: ("710" "714" "M05" "M06" "M315" "M32" "M33" "M34" "M351" "M353" "M360") then D7="1";
	**Pud;     if ("531" <=: ICD(i) <=: "534") or ICD(i) in: ("K25" "K26" "K27" "K28") then D8="1";
	**Miliver; if ICD(i) in: ("5712" "5715" "5716" "5718" "5719" "B18" "K700" "K701" "K702" "K703" "K709" "K713" "K714" "K715" "K717" "K73" "K74" "K760" "K762" "K763" "K764" "K768" "K769" "Z944") then D9="1";
	**DM;      if ICD(i) in: ("2500" "2501" "2502" "2503" "E100" "E101" "E106" "E108" "E109" "E110" "E111" "E116" "E118" "E119" "E120" "E121" "E126" "E128" "E129" "E130" "E131" "E136" "E138" "E139" "E140" "E141" "E146" "E148" "E149") then D10="1";
	**DMcom;   if ICD(i) in: ("2504" "2505" "2506" "2507" "2508" "2509" "E102" "E103" "E104" "E105" "E107" "E112" "E113" "E114" "E115" "E117" "E122" "E123" "E124" "E125" "E127" "E132" "E133" "E134" "E135" "E137" "E142" "E143" "E144" "E145" "E147") then D11="1";
	**Hemi;    if ICD(i) in: ("342" "344" "G041" "G114" "G801" "G802" "G81" "G82" "G830" "G831" "G832" "G833" "G834" "G839") then D12="1";
	**Renal;   if ICD(i) in: ("585" "586" "V56" "V420" "V451" "I120" "I131" "N032" "N033" "N034" "N035" "N036" "N037" "N052" "N053" "N054" "N055" "N056" "N057" "N18" "N19" "N250" "Z490" "Z491" "Z492" "Z940" "Z992") or opcode(i) in: ("3927" "3942" "3993" "3994" "3995" "5498")  then D13="1";
	**Cancer;  if ("140" <=: ICD(i) <=: "171") or ("174" <=: ICD(i) <=: "195") or ("200" <=: ICD(i) <=: "208") or ICD(i) in: ("2730" "2733" "V1046") or opcode(i) in: ("605" "624" "6241") or (substr(ICD(i),1,1)="C" and substr(ICD(i),2,2) not in ("27" "28" "29" "35" "36" "42" "44" "59" "77" "78" "79" "80" "86" "87" "89" "98" "99")) then D14="1";
	**Seliver; if ICD(i) in: ("5722" "5723" "5724" "4560" "4561" "4562" "I850" "I859" "I864" "I982" "K704" "K711" "K721" "K729" "K765" "K766" "K767") or opcode(i) in: ("391" "4291") then D15="1";
	**Meta;    if ("196" <=: ICD(i) <=: "199") or ICD(i) in: ("C77" "C78" "C79" "C80") then D16="1";
	**AIDS;    if ("042" <=: ICD(i) <=: "044") or ICD(i) in: ("B20" "B21" "B22" "B24") then D17="1";
	END;
	if cmiss(of D1-D&number )=&number then delete;   
run;

proc sort data= claimdata; by &id source &med_d;
data &output (keep= &ID co1-co&number CCI );
	set claimdata; by &id source &med_d;
	if first.&id then do;
		%do k=1 %to &number; co&k="0"; first&k=.; last&k=.; %end;
	end;	
	if source="CD" then do;
		%do i=1 %to &number;
			if D&i = "1" and first&i =.  then first&i = &med_d;
			if D&i = "1"                 then last&i  = &med_d; 
			if (last&i - first&i) >=&gap then co&i    = "1";/*the time gap between two claims needs more than 30 days apart*/
		%end;
	end;
	else do;/*source="DD"*/
		%do j=1 %to &number;
			if D&j="1" then co&j="1"; 
		%end;
	end;
	retain first1-first&number last1-last&number co1-co&number;
	if last.&id;
	CCI = sum(co1,co2,co3,co4,co5,co6,co7,co8,co9,co10)+co11*2+co12*2+Co13*2+co14*2+Co15*3+co16*6+Co17*6;
	*format first1-first&number last1-last&number yymmdd10.;
run;
%Mend C_CCI;
%C_CCI(data = All_claims);

proc sort data=IMF.ALL_INITIAL_8 ; by &ID;
proc sort data=CCI ; by &ID;
data como;
    merge IMF.ALL_INITIAL_8(in=_a) CCI (in=_b); by &ID;
    if _a;
	array arrcomo co1-co17;
	do over arrcomo;
		if arrcomo = "" then arrcomo = "0";
	end;
		if CCI = . then CCI = 0;
run;

Proc means data = como mean maxdec=1; var CCI; class group; run;
proc anova data = como;  
  class group; 
  model age = group;  
  ods select ModelANOVA;
run;
proc anova data = como;  
  class group; 
  model eGFR = group;  
  ods select ModelANOVA;
run;
proc anova data = como;  
  class group; 
  model CCI = group;  
  ods select ModelANOVA;
run;

Proc freq data = como; table group*(co1-co17) /nopercent nocol nofreq; run; 
Proc freq data = como; table group*(sex colchicine co1-co17) /nopercent nocol nofreq nocol chisq; run; 

/*===   Table 2   ===*/
%Macro measure_before_and_after(name, dose_specific);
	PROC SQL;
	CREATE TABLE &name._first28_1 AS 
		SELECT a.*
		FROM &name._first28 a
		INNER JOIN &final_data b 
		ON a.&ID=b.&ID;
	QUIT;

	data &name._first28_2;*33312;
		set &name._first28_1 (keep=&ID avg_dose med_date where=(avg_dose in ( &dose_specific )));
		one_month_date = med_date + 28;
	run;

	PROC SQL;*33620;
	CREATE TABLE &name._first28_3 AS 
		SELECT b.*, a.Lab_date, a.Value, Value*59.48 as Value_umol 
		FROM UAC(where=(Value>0)) a
		INNER JOIN &name._first28_2 b 
		ON a.&ID=b.&ID and one_month_date <= Lab_date <= one_month_date+90
		ORDER BY b.&ID, a.Lab_date;
	QUIT;
	Proc sort data=&name._first28_3 nodupkey out=&name._first28_4 ; by &ID; run;*23162;


	PROC SQL;*43752;
	CREATE TABLE &name._baseline AS 
		SELECT b.*, a.Lab_date, a.Value, Value*59.48 as Value_umol 
		FROM UAC(where=(Value>0)) a
		INNER JOIN &name._first28_2 b 
		ON a.&ID=b.&ID and med_date - 90 <= Lab_date <= med_date
		ORDER BY b.&ID, a.Lab_date desc;
	QUIT;
	Proc sort data=&name._baseline nodupkey out=&name._baseline_2; by &ID; run;*29657;


	PROC SQL;*9459;
	CREATE TABLE &name._initial AS 
		SELECT b.*, c.Value as Value_base, c.Value_umol as Value_umol_base
		FROM drug3 (where=(initial_drug = "&name.")) a
		INNER JOIN &name._first28_4  b ON a.&ID=b.&ID
		INNER JOIN &name._baseline_2 c ON a.&ID=c.&ID;
	QUIT;

	title "&name._initial";
	%put &=name;
/*		%IF &name = Febuxostat %THEN %DO;*/
			Proc means data=&name._initial mean std maxdec=1; var Value_base Value_umol_base Value Value_umol; class avg_dose; run;
/*		%END;*/
/*		%ELSE %DO;*/
/*			Proc means data=&name._initial n mean std maxdec=1; var Value_base Value_umol_base Value Value_umol avg_dose; run;*/
/*		%END;*/
	title;
%mend measure_before_and_after;
%measure_before_and_after(Allopurinol   , 50 100 200);
%measure_before_and_after(Benzbromarone , 25 50  100);
%measure_before_and_after(Sulfinpyrazone, 50 100 200);
%measure_before_and_after(Febuxostat    , 20 40  80) ;

%Macro ttest(name, dose);
title "&name., dose = &dose";
	PROC TTEST DATA = &name._initial;
		WHERE avg_dose = &dose;
	    PAIRED Value_base*Value;  /*before is the value of first test and the after is the second test value*/ 
		ods select TTests;
	RUN;
title;
%Mend ttest;
%ttest(Allopurinol,50)
%ttest(Allopurinol,100)
%ttest(Allopurinol,200)

%ttest(Benzbromarone,25)
%ttest(Benzbromarone,50)
%ttest(Benzbromarone,100)

%ttest(Sulfinpyrazone,50)
%ttest(Sulfinpyrazone,100)
%ttest(Sulfinpyrazone,200)

%ttest(Febuxostat, 20)
%ttest(Febuxostat, 40)
%ttest(Febuxostat, 80)

**** P for trend;
%Macro p_trend(drugname);
	PROC NPAR1WAY data = &final_data WILCOXON;
		CLASS seq;
		VAR dif_Value; 
		where initial_drug = "&drugname";
	run; 
%Mend ;
%p_trend(1Allopurinol);
%p_trend(2Benzbromarone);
%p_trend(3Sulfinpyrazone);
%p_trend(4Febuxostat);

**** DID;
data testdata;
	*where initial_drug = "Allopurinol";
	set 
	&final_data (in=_a keep=&ID SEX age eGFR colchicine group Value_base initial_drug rename=(Value_base=Value))
	&final_data (in=_b keep=&ID SEX age eGFR colchicine group Value      initial_drug                          );
	if _a then Post = 0;
		else Post = 1;
run;


/*ADJUSTED REPEATED MEASURES LINEAR REGRESSION*/
%Macro DID(drugname);
	PROC MIXED DATA = testdata;
		WHERE initial_drug = "&drugname";
		CLASS &ID POST group SEX colchicine / REF=FIRST;
		MODEL Value = POST|group SEX AGE colchicine eGFR / SOLUTION;
		*LSMEANS POST|group / DIFF;
		*ESTIMATE 'D-I-D' group*POST 1 -1 -1 1;
		RANDOM int / SUBJECT = &ID TYPE=AR(1);
		ods select SolutionF;
	RUN;
%Mend DID;
%DID(1Allopurinol);
%DID(2Febuxostat);
%DID(3Benzbromarone);
%DID(4Sulfinpyrazone);*WARNING: Stopped because of infinite likelihood.;


PROC GLM DATA = &final_data;
	WHERE initial_drug = "Sulfinpyrazone" and group in ("Sulfinpyrazone_1.50" "Sulfinpyrazone_3.200");
	Class group SEX colchicine / REF=FIRST;
	MODEL Value_umol_base Value_umol = group SEX AGE colchicine eGFR;
	REPEATED TIME 2 / PRINTE MEAN;
	LSMEANS group;
	LSMEANS group / DIFF ; 
QUIT;

PROC GLM DATA = &final_data;
	WHERE initial_drug = "Sulfinpyrazone" and group in ("Sulfinpyrazone_1.50" "Sulfinpyrazone_3.200");
	Class group SEX colchicine / REF=FIRST;
	MODEL Value_umol_base Value_umol = group SEX AGE colchicine eGFR;
	REPEATED TIME 2 / PRINTE MEAN;
	LSMEANS group;
	LSMEANS group / DIFF ; 
QUIT;

/*===   Figure 3   ===*/ 
Proc freq  data = &final_data; table start_y*initial_drug/nopercent nocol norow; run;

/*===   Table 3 - target_UA  ===*/ 
%Macro cal_interval(subgroup, time, by_var);
	Proc means data = &final_data median q1 q3 maxdec=1;
		where &subgroup = 1;  
		var &time; 
		class &by_var;
	run;
%Mend cal_interval;
%cal_interval(target_UA, fy_target_UA, group);
%cal_interval(target_UA, fy_target_UA, initial_drug);

Proc freq data = &final_data; table group*target_UA    /nopercent nocol norow; where fy_target_UA ne .; run; 

 
%Macro Adjusted_incidence_rate(outcome, groupvar);
	PROC SQL;
	CREATE TABLE cal AS
	SELECT &groupvar, sex, age_c, sum(&outcome) as &outcome, log(sum(fy_&outcome)*12) as ln 
	   FROM &final_data
	   where fy_&outcome ne .
	   group by &groupvar, sex, age_c;
	QUIT;

	proc genmod data = cal;
		class &groupvar sex age_c;
		model &outcome = &groupvar sex age_c / dist=poisson link=log offset=ln;
		lsmeans &groupvar / ilink cl;
		ods select LSMeans;
	run; 
%Mend Adjusted_incidence_rate;
%Adjusted_incidence_rate(target_UA, group)


%Macro cox_target_UA(drug);
	proc phreg data = &final_data;
		where fy_target_UA ne . and initial_drug= "&drug";
		class sex group colchicine / ref = first param = ref ;
		model fy_target_UA*target_UA(0) = group sex age colchicine eGFR Value / risklimits ;/*censoring var. should be numeric*/
		ods select ParameterEstimates ; 
	run ; 
%Mend cox_target_UA;
%cox_target_UA(1Allopurinol);
%cox_target_UA(2Febuxostat);
%cox_target_UA(3Benzbromarone);
%cox_target_UA(4Sulfinpyrazone);


/*===   Table 4 - Flare  ===*/ 
%cal_interval(flare, fy_flare, group);
%cal_interval(flare, fy_flare, initial_drug);

Proc freq  data = &final_data; table initial_drug*flare /nopercent nocol norow; where fy_flare ne .; run; 
Proc freq  data = &final_data; table group*flare 	    /nopercent nocol norow; where fy_flare ne .; run; 

%Adjusted_incidence_rate(flare, group)
%Adjusted_incidence_rate(flare, initial_drug)

%Macro cox_flare(drug);
	proc phreg data = &final_data;
		where fy_flare ne . and initial_drug= "&drug";
		class sex group colchicine/ ref = first param = ref ;
		model fy_flare*flare(0) = group sex age colchicine eGFR Value / risklimits ;/*censoring var. should be numeric*/
		ods select ParameterEstimates ; 
	run ; 
%Mend cox_flare;
%cox_flare(1Allopurinol);
%cox_flare(2Febuxostat);
%cox_flare(3Benzbromarone);
%cox_flare(4Sulfinpyrazone);


/*===   Table 5   ===*/ 
proc phreg data = &final_data;
	where fy_target_UA ne .;
	class sex colchicine / ref = first param = ref ;
	model fy_target_UA*target_UA(0) = sex age colchicine eGFR Value / risklimits ;/*censoring var. should be numeric*/
	hazardratio age / units=10; 
	hazardratio eGFR / units=15;
	*ods select ParameterEstimates; 
run; 

proc phreg data = &final_data;
	where fy_flare ne .;
	class sex group colchicine/ ref = first param = ref ;
	model fy_flare*flare(0) = sex age colchicine eGFR Value / risklimits ;/*censoring var. should be numeric*/
	hazardratio age / units=10;
	hazardratio eGFR / units=15;
	*ods select ParameterEstimates ; 
run; 


%Macro cox_raw_target_UA(var);
	proc phreg data = &final_data;
		where fy_target_UA ne . ;
		class sex group colchicine/ ref = first param = ref ;
		model fy_target_UA*target_UA(0) = &var / risklimits ;/*censoring var. should be numeric*/
		ods select ParameterEstimates ; 
	run ; 
%Mend cox_raw_target_UA;
%cox_raw_target_UA(sex);
%cox_raw_target_UA(age);
%cox_raw_target_UA(colchicine);
%cox_raw_target_UA(eGFR);
%cox_raw_target_UA(Value);


%Macro cox_raw_flare(var);
	proc phreg data = &final_data;
		where fy_flare ne . ;
		class sex group colchicine/ ref = first param = ref ;
		model fy_flare*flare(0) = &var / risklimits ;/*censoring var. should be numeric*/
		ods select ParameterEstimates ; 
	run ; 
%Mend cox_raw_flare;
%cox_raw_flare(sex);
%cox_raw_flare(age);
%cox_raw_flare(colchicine);
%cox_raw_flare(eGFR);
%cox_raw_flare(Value);









/*畫不同藥物，發生target_UA的cumulative curves*/
filename outpath "H:\Temporary\all_initial_6.csv" encoding="utf-8";
proc export data=imf.all_initial_6 outfile=outpath dbms=csv replace;
run;


proc phreg data = imf.all_initial_6;
	where fy_flare ne . ;
	class sex group / ref = first param = ref ;
	model fy_flare*flare(0) = sex age colchicine Creatinine Value_base / risklimits ;/*censoring var. should be numeric*/
	ods select ParameterEstimates ; 
run ; 
proc phreg data = imf.all_initial_6;
	where fy_target_UA ne . ;
	class sex group / ref = first param = ref ;
	model fy_target_UA*target_UA(0) = sex age colchicine Creatinine Value_base / risklimits ;/*censoring var. should be numeric*/
	ods select ParameterEstimates ; 
run ;  

/*   2024-03-15  */
Proc SQL;
create table x as 
select a.&ID, yrdif(b.FIRST_VISIT_D, start_date) as yr
    from IMF.ALL_INITIAL_6 a
    left join CGRD_K.UNIQUE_IDCODE b on a.IDCODE=b.IDCODE;
quit;
Proc means data=x mean std median q1 q3 min max; var yr; run;*mean (SD): 8.9 (6.2);


/*測試是否能夠計算標準化的eGFR，有點奇怪...*/
proc genmod data = all_initial_7;
	class group SEX ;
	model eGFR = group SEX age;
	lsmeans group;
run;
 

/*   2024-04-08  蔡醫師要求新增分析  */
Proc means data=all_initial_7 mean std ; var age; run;
Proc means data=all_initial_7 mean std ; var age; class sex;run;
Proc freq  data=all_initial_7 ; table sex; run;

Proc means data=all_initial_7 mean std maxdec=1; var eGFR; class initial_drug;run;


/*   2024-05-09  郭醫師要求新增分析  
use months, KM curve for each possible?, for achieving target and flare
time to first flare (+)
all cox model, specific HR for each covariates
*/

data alldrug;
	set Allopurinol(in=_a) Benzbromarone(in=_b) Sulfinpyrazone(in=_c) Febuxostat(in=_d);
	length initial_drug $15;
	if _a then initial_drug = "1Allopurinol";
	if _b then initial_drug = "2Febuxostat";
	if _c then initial_drug = "3Benzbromarone";
	if _d then initial_drug = "4Sulfinpyrazone";
run;

PROC SQL;
CREATE TABLE alldrug_after AS 
	SELECT a.*, b.flare_date, b.target_UA_date
	FROM alldrug a
	INNER JOIN IMF.ALL_INITIAL_7 b ON a.&ID=b.&ID 
	where b.one_month_date <= a.med_date and a.initial_drug=b.initial_drug;
QUIT;

Proc SQL;
create table days_flare as
select &ID, initial_drug, sum(drug_days) as drug_days
	from alldrug_after
	where med_date <= flare_date
	group by &ID, initial_drug;
quit;

Proc SQL;
create table days_target_UA as
select &ID, initial_drug, sum(drug_days) as drug_days
	from alldrug_after
	where med_date <= target_UA_date
	group by &ID, initial_drug;
quit;

Proc means data = days_flare     mean std maxdec=1; var drug_days; class initial_drug; run;
Proc means data = days_target_UA mean std maxdec=1; var drug_days; class initial_drug; run;


