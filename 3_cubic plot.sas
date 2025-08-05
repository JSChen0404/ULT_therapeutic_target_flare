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


%Macro Retri_RCFNO(CODES=, DOSE=, OUT=);
	data &OUT (drop=RCFNO_C);
		set CGRD_K.OP_CGDA (keep=&ID QTY drug_days med_date RCFNO_C DYS DSG FRQ where=(RCFNO_C in ( &codes )));
		avg_dose = QTY*&DOSE / drug_days;		
	run;
%Mend Retri_RCFNO;
%Retri_RCFNO(CODES = &Allopurinol   , DOSE = 100, OUT = Allopurinol);   
%Retri_RCFNO(CODES = &Benzbromarone , DOSE = 50 , OUT = Benzbromarone); 
%Retri_RCFNO(CODES = &Probenecid    , DOSE = 500, OUT = Probenecid);    
%Retri_RCFNO(CODES = &Sulfinpyrazone, DOSE = 100, OUT = Sulfinpyrazone);
%Retri_RCFNO(CODES = &Febuxostat    , DOSE = 80 , OUT = Febuxostat);    

data data_all;
	set Allopurinol(in=_a) Benzbromarone(in=_b) Sulfinpyrazone(in=_c) Febuxostat(in=_d) Probenecid(in=_e);
	length drugname $20;
	if _a then drugname = "Allopurinol";
 	if _b then drugname = "Benzbromarone";
 	if _c then drugname = "Sulfinpyrazone";
	if _d then drugname = "Febuxostat";
	if _e then drugname = "Probenecid";
run;

data treat;*4408751;
	set data_all;
	if drug_days ne .; 
	if drugname = "Allopurinol"    then dose = 100;
 	if drugname = "Benzbromarone"  then dose = 50;
 	if drugname = "Sulfinpyrazone" then dose = 100;
	if drugname = "Febuxostat"     then dose = 80;
	if drugname = "Probenecid"     then dose = 500;

	if DSG in ("0.25" "1/4") and FRQ in ("QD" "QN"  ) then avg_dose = dose/4;
	if DSG in ("0.5" "1/2")  and FRQ in ("QD" "QN"  ) then avg_dose = dose/2;
	if DSG in ("1")  	     and FRQ in ("QD" "QN"  ) then avg_dose = dose;
	if DSG in ("1.5" "3/4")  and FRQ in ("QD" "QN"  ) then avg_dose = dose*1.5;
	if DSG in ("2")  		 and FRQ in ("QD" "QN"  ) then avg_dose = dose*2;
	if DSG in ("0.25" "1/4") and FRQ in ("QOD" "QON") then avg_dose = dose/8;
	if DSG in ("0.5" "1/2")  and FRQ in ("QOD" "QON") then avg_dose = dose/4;
	if DSG in ("1") 		 and FRQ in ("QOD" "QON") then avg_dose = dose/2;
	if DSG in ("1") 		 and FRQ in ("Q4D"      ) then avg_dose = dose/4;
	if DSG in ("0.5")  		 and FRQ in ("HS"       ) then avg_dose = dose/2; 
	if DSG in ("2")  		 and FRQ in ("TID"      ) then avg_dose = dose*6; 
	if DSG in ("1")  		 and FRQ in ("TID"      ) then avg_dose = dose*3; 
	if DSG in ("2")  		 and FRQ in ("BID"      ) then avg_dose = dose*4; 
	if DSG in ("1")  		 and FRQ in ("BID"      ) then avg_dose = dose*2; 
	*if avg_dose not in (10 12.5 20 25 40 50 60 75 80 100 120 150 160 200) and FRQ not in ("QW" "BIW" "TIW" "Q3D" "IRRE" "PRN");
	if FRQ in ("PRN" "IRRE") then delete;
	if drugname = "Allopurinol" and avg_dose > 5000 then delete;
	if drugname = "Febuxostat"  and avg_dose > 200  then delete; 
run;

Proc sort data=Allopurinol nodupkey out=x1(keep=&ID) ; by &ID; run;
Proc sort data=Benzbromarone nodupkey out=x2(keep=&ID) ; by &ID; run;
Proc sort data=Sulfinpyrazone nodupkey out=x3(keep=&ID) ; by &ID; run;
Proc sort data=Febuxostat nodupkey out=x4(keep=&ID) ; by &ID; run;
Proc sort data=Probenecid nodupkey out=x5(keep=&ID) ; by &ID; run; 
data count_id;
    merge x1(in=_a) x2(in=_b) x3(in=_c) x4(in=_d) x5(in=_e); by &ID;
    no = sum(of _a, _b, _c, _d, _e);
run;
Proc freq data=count_id ; table no; run;

PROC SQL; 
CREATE TABLE treat2 AS 
	SELECT a.*
	FROM treat a
	INNER JOIN count_id (where=(no=1)) b ON a.&ID=b.&ID
	order by a.&ID, med_date;
QUIT;
Proc sort data=treat2 nodupkey out=first_date(keep=&ID med_date rename=(med_date=start_date)) ; by &ID; run;*104963;

PROC SQL;*96052;
CREATE TABLE treat_more28 AS 
	SELECT a.&ID, sum(drug_days) as drug_days
	FROM treat2 a
	INNER JOIN first_date b ON a.&ID=b.&ID and b.start_date <= a.med_date <= b.start_date + 90
	GROUP BY a.&ID
	HAVING drug_days >= 28;
QUIT;

PROC SQL;*270428;
CREATE TABLE treat_90days AS 
	SELECT a.*, b.start_date
	FROM treat2 a
	INNER JOIN first_date   b ON a.&ID=b.&ID and b.start_date <= a.med_date <= b.start_date + 90
	INNER JOIN treat_more28 c ON a.&ID=c.&ID 
	order by a.&ID, med_date;
QUIT;

Proc SQL;*96052;
create table treat_average as
select &ID, start_date, drugname, avg(avg_dose) as avg_dose
	from treat_90days
	group by &ID, start_date, drugname;
quit;


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
select a.&ID, a.med_date, sum(drug_days) as drug_days
	from ULD a 
	inner join (select distinct &ID, start_date from first_date) b on a.&ID=b.&ID
	where a.drug_days > 0 and b.start_date < a.med_date
	group by a.&ID, a.med_date
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
	INNER JOIN NSAID b ON a.&ID=b.&ID and a.start_date < b.NSAID_date <= a.end_date
	INNER JOIN CGRD_K.OP_DIAG(where=(DSSID in: ("274" "M10" "M1A" "E790"))) c ON b.&ID=c.&ID and b.NSAID_date=c.med_date
	order by a.&ID, b.NSAID_date;
QUIT;
Proc sort data=def_NSAID nodupkey; by &ID; run;

data colchicine;
	set CGRD_K.OP_CGDA (keep=&ID med_date RCFNO_C rename=(med_date=colchicine_date) where=(RCFNO_C in (&colchicine))); 	
run;

PROC SQL;
CREATE TABLE def_colchicine AS 
	SELECT distinct b.&ID, b.colchicine_date
	FROM ULD3 a
	INNER JOIN colchicine b ON a.&ID=b.&ID and start_date < b.colchicine_date <= end_date
	INNER JOIN CGRD_K.OP_DIAG (where=(DSSID in: ("274" "M10" "M1A" "E790"))) c ON b.&ID=c.&ID and b.colchicine_date=c.med_date
	order by a.&ID, b.colchicine_date;
QUIT;
Proc sort data=def_colchicine nodupkey; by &ID; run;

PROC SQL; 
CREATE TABLE def_ER_return AS 
	SELECT distinct b.&ID, b.med_date as ER_return_date
	FROM first_date a
	INNER JOIN CGRD_K.ER_DIAG (where=(DSSID in: ("274" "M10" "M1A" "E790")))  b 
	ON a.&ID=b.&ID and a.start_date < b.med_date
	order by a.&ID ;
QUIT;
Proc sort data=def_ER_return nodupkey; by &ID; run;

data def_flare;
    merge def_NSAID(in=_a) def_colchicine(in=_b) def_ER_return(in=_c); by &ID;
	flare_date = min(NSAID_date, colchicine_date, ER_return_date);
	format flare_date yymmdd10.;
run;

 

PROC SQL; *95409;
CREATE TABLE imf.cubic_spline_flare AS 
	SELECT a.*, ifn(b.flare_date ne ., 1, 0) as flare, b.flare_date, 
	case when b.flare_date   ne . then (flare_date   - start_date + 1)/365
		 when c.LAST_VISIT_D ne . then (LAST_VISIT_D - start_date + 1)/365
		 						  else ("31DEC2022"d - start_date + 1)/365
		end as fy, 
	(start_date - input(c.BIRTHDAY, yymmdd8.))/365 as age, c.SEX 
	FROM treat_average a
	LEFT JOIN def_flare 			b ON a.&ID=b.&ID and not(start_date <= flare_date <= start_date + 90)
	inner JOIN CGRD_K.UNIQUE_IDCODE c ON a.&ID=c.&ID;
QUIT;
Proc means data=imf.cubic_spline_flare mean std median q1 q3 min max; var fy; run;
Proc means data=imf.cubic_spline_flare mean std median q1 q3 min max; var avg_dose; class drugname; run;

filename outpath "H:\Temporary\cubic_spline.csv" encoding="utf-8";
proc export data=imf.cubic_spline_flare outfile=outpath dbms=csv replace;
run;

/*2024-05-15 Request from Dr. Kuo
x軸是治療後尿酸濃度        y軸是HR 
x軸是治療前後尿酸濃度變化  y軸是HR */

data output;*37262;
	set imf.all_initial_7 ;
	*dif_Value = Value - Value_base;
	dose = scan(group, 4, '._')*1;
	keep &ID age SEX Value Value_base dif_Value initial_drug group dose flare target_UA fy_flare fy_target_UA colchicine eGFR Value;
run;
Proc means data=output mean std median q1 q3 min max; var dif_Value; run;

filename outpath "H:\Temporary\cubic_spline_v3.csv" encoding="utf-8";
proc export data=output outfile=outpath dbms=csv replace;
run;

data output;*37262;
	set imf.all_initial_8 ;
	*dif_Value = Value - Value_base;
	dose = scan(group, 4, '._')*1;
	keep &ID age SEX Value Value_base dif_Value initial_drug group dose flare target_UA fy_flare fy_target_UA colchicine eGFR Value;
run;
Proc means data=output mean std median q1 q3 min max; var dif_Value; run;

filename outpath "H:\Temporary\cubic_spline_v4.csv" encoding="utf-8";
proc export data=output outfile=outpath dbms=csv replace;
run;
 