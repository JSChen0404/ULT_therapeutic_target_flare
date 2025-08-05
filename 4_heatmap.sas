libname imf    "C:\SAS\Analysis data\ULD";

%Let ID = IDCODE;

data output;*37262;
	set imf.all_initial_8 ;
	*dif_Value = Value - Value_base;
	dose = scan(group, 4, '._')*1;
	if dif_Value <= -1 then dif_Value_c = '-1';
		else if -1 <  dif_Value < 1 then dif_Value_c = '0';
		else if 1  <= dif_Value < 2 then dif_Value_c = '1';
		else if 2  <= dif_Value < 3 then dif_Value_c = '2';
		else if 3  <= dif_Value < 4 then dif_Value_c = '3';
		else dif_Value_c = '4';
	if round(Value,1) <= 5 			then Value_c = '05'; 
		else if round(Value,1) = 6  then Value_c = '06';	
 		else if round(Value,1) = 7  then Value_c = '07';
		else if round(Value,1) = 8  then Value_c = '08'; 
 		else Value_c = '09';
	if age <= 55 then age_c = 1;
		else if age <= 65 then age_c = 2;
		else age_c = 3;
	if 90 <= eGFR then eGFR_c = 1;
		else if 60 <= eGFR < 90 then eGFR_c = 2;
		else if 30 <= eGFR < 60 then eGFR_c = 3;
		else if 15 <= eGFR < 30 then eGFR_c = 4;
		else eGFR_c = 5;	
	combine_c = compress(Value_c||"_"||dif_Value_c);
	combine_c2 = compress(colchicine||"_"||Value_c||"_"||dif_Value_c);
	keep combine_c combine_c2 dif_Value_c &ID age age_c SEX Value Value_c Value_base dif_Value initial_drug group dose 
		 flare target_UA fy_flare fy_target_UA colchicine eGFR eGFR_c;
run;

Proc freq data = output; 
	table combine_c combine_c2; 
	where fy_flare ne . and dif_Value >= 0;
run;

Proc freq data = output; 
	table combine_c2*flare/ nopercent nocol norow; 
	where fy_flare ne . and dif_Value >= 0;
run;

Proc means data = output mean std median q1 q3 min max; var Value ; run;
Proc freq  data = output; 
	where fy_flare ne .; 
	table colchicine*dif_Value_c*Value_c / nopercent nocol norow; 
run;

proc phreg data = output;
	where fy_flare ne . and dif_Value >= 0 /*and combine_c2 not in ("1_05_1" "1_06_0" "0_05_1" "0_06_0")*/;
	class sex combine_c(ref="05_1") / ref = first param = ref ;
	model fy_flare*flare(0) = combine_c sex age eGFR colchicine / risklimits ;  
	ods select ParameterEstimates ; 
run;

proc phreg data = output; 
	where fy_flare ne . and colchicine = 1 and dif_Value >= 0 and combine_c2 not in ("1_05_1" "1_06_0" "0_05_1" "0_06_0");
	class sex combine_c(ref="07_0") / ref = first param = ref ;
	model fy_flare*flare(0) = combine_c sex age eGFR / risklimits ;  
	ods select ParameterEstimates ; 
run;
 
proc phreg data = output; 
	where fy_flare ne . and colchicine = 0 and dif_Value >= 0 and combine_c2 not in ("1_05_1" "1_06_0" "0_05_1" "0_06_0");
	class sex combine_c(ref="07_0") / ref = first param = ref ;
	model fy_flare*flare(0) = combine_c sex age eGFR / risklimits ;  
	ods select ParameterEstimates ; 
run;

proc phreg data = output;*33669;
	where fy_flare ne . and dif_Value >= 0 and combine_c2 not in ("1_05_1" "1_06_0" "0_05_1" "0_06_0");
	class sex age_c eGFR_c combine_c2(ref="0_07_0") / ref = first param = ref ;
	model fy_flare*flare(0) = combine_c2 sex age_c eGFR_c / risklimits ;/*censoring var. should be numeric*/
	*hazardratio dif_Value_c / at(Value_c=ALL) diff=REF;
	ods select ParameterEstimates ; 
run;


proc phreg data = output;*33669;
	where fy_flare ne . and dif_Value >= 0 and combine_c2 not in ("1_05_1" "1_06_0" "0_05_1" "0_06_0") ;
	class sex age_c eGFR_c combine_c2(ref="0_05_3") / ref = first param = ref ;
	model fy_flare*flare(0) = combine_c2 sex age_c eGFR_c / risklimits ;/*censoring var. should be numeric*/
	*hazardratio dif_Value_c / at(Value_c=ALL) diff=REF;
	ods select ParameterEstimates ; 
run;
 