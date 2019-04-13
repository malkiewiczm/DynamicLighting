%{
#define YY_SKIP_YYWRAP

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"

extern void yyerror(const char*);
static int yywrap()
{
	return 1;
}
%}
%%
ground return GROUND_DEF;
sensor return SENSOR_DEF;
light return LIGHT_DEF;
jd return JD_DEF;
jp return JP_DEF;
jr return JR_DEF;
jpl return JPL_DEF;
yes yylval.i = 1; return BOOL;
no yylval.i = 0; return BOOL;
-?[0-9]+ yylval.i = atoi(yytext); return INT;
-?[0-9]*[.][0-9]+ yylval.f = atof(yytext); return FLOAT;
inf yylval.f = (1.0f/0.0f); return FLOAT;
[A-Za-z]+[_0-9]* {
	if (strlen(yytext) >= 60) {
		yyerror("identitfier name too big");
		strcpy(yylval.str, "__invalid__");
	} else {
		strcpy(yylval.str, yytext);
	}
	return VAR;
}
"/*"((\*+[^/*])|([^*]))*\**"*/" /* ignored */
[\r\n \t]+ /* ignored */
. return (int)yytext[0];
%%
