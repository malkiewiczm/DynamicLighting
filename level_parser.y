%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "y.tab.h"

#include <vector>
#include <map>
#include <string>

extern int yylex(void);

static int error_level = 0;

void yyerror(const char *what)
{
	fprintf(stderr, "parse error: %s\n", what);
	error_level = 1;
}

static inline void die(const char *what)
{
	fprintf(stderr, "error: %s\n", what);
	exit(1);
}

extern FILE *yyin;

static std::map<std::string, body_data_t*> *body_symbols;
static std::map<std::string, light_uniform_t*> *light_symbols;
#define exists(table, what)((table)->find(what) != (table)->end())

static b2World *world;
static light_uniform_t *lights;
static int *light_count;
static unsigned int ground_count;
static body_data_t body_data_pool[60];

static bool insert_ground_data(const char *name, body_data_t *data)
{
	if (exists(body_symbols, name)) {
		yyerror("symbol already exists (ground)");
		printf("...when symbol = %s\n", name);
		return false;
	} else {
		body_symbols->emplace(name, data);
		return true;
	}
}

static bool insert_light_data(const char *name, light_uniform_t *data)
{
	if (exists(light_symbols, name)) {
		yyerror("symbol already exists (light)");
		printf("...when symbol = %s\n", name);
		return false;
	} else {
		light_symbols->emplace(name, data);
		return true;
	}
}

static bool get_light_data(const char *name, light_uniform_t **data)
{
	if (! exists(light_symbols, name)) {
		yyerror("light name not found");
		printf("...when symbol = %s\n", name);
		return false;
	}
	*data = light_symbols->find(name)->second;
	return true;
}

static bool get_body_data(const char *name, body_data_t **data)
{
	if (! exists(body_symbols, name)) {
		yyerror("ground name not found");
		printf("...when symbol = %s\n", name);
		return false;
	}
	*data = body_symbols->find(name)->second;
	return true;
}

static bool get_body_by_var(const char *a_name, const char *b_name, b2Body **a, b2Body **b)
{
	body_data_t *a_data, *b_data;
	if (! get_body_data(a_name, &a_data)) {
		return false;
	}
	if (! get_body_data(b_name, &b_data)) {
		return false;
	}
	if (a_data->body == nullptr) {
		yyerror("body def is null");
		printf("...when symbol = %s\n", a_name);
		return false;
	}
	if (b_data->body == nullptr) {
		yyerror("body def is null");
		printf("...when symbol = %s\n", b_name);
		return false;
	}
	*a = a_data->body;
	*b = b_data->body;
	return true;
}

static body_data_t *make_ground(const float *a, const float *b, dynamic_props_t *p, bool sensor)
{
	b2PolygonShape box;
	b2BodyDef body_def;
	b2FixtureDef fix_def;
	const float x = a[0], y = a[1], w = a[2], h = a[3];
	const float friction = b[0], restitution = b[1], rotation = b[2];
	box.SetAsBox(w / 2.0f, h / 2.0f);
	fix_def.shape = &box;
	fix_def.density = 1.0f;
	fix_def.friction = friction;
	fix_def.isSensor = sensor;
	fix_def.restitution = restitution;
	body_def.angle = rotation;
	body_def.position.Set(x, y);
	if (p) {
		// the ground is supposed to be dynamic
		body_def.type = b2_dynamicBody;
		body_def.linearDamping = p->linear_damping;
		body_def.angularDamping = p->linear_damping;
		body_def.fixedRotation = p->fixed_rotation;
	} else {
		body_def.type = b2_staticBody;
	}
	body_data_t *body_data = body_data_pool + ground_count;
	fix_def.userData = body_data;
	body_data->width = w;
	body_data->height = h;
	body_data->light = nullptr;
	body_data->id = ground_count;
	body_data->visible = ! sensor;
	body_def.userData = body_data;
	b2Body *body;
	body = world->CreateBody(&body_def);
	body->CreateFixture(&fix_def);
	body_data->body = body;
	++ground_count;
	return body_data;
}

int parse_level_file(
	const char *fname,
	b2World *lworld,
	light_uniform_t *llights,
	int *llight_count
)
{
	world = lworld;
	lights = llights;
	light_count = llight_count;
	if (! world)
		die("box2d world was nullptr");
	if (! lights)
		die("output lights was nullptr");
	if (! light_count)
		die("output lights count was nullptr");
	ground_count = 0;
	*light_count = 0;
	yyin = fopen(fname, "r");
	if (yyin == nullptr) {
		yyerror("file could not be opened");
		return 1;
	}
	body_symbols = new std::map<std::string, body_data_t*>();
	light_symbols = new std::map<std::string, light_uniform_t*>();
	yyparse();
	fclose(yyin);
	delete body_symbols;
	delete light_symbols;
	return error_level;
}
%}

%code requires {
	#include "level_parser.hpp"
	#include "ssvm.hpp"
	typedef struct {
		float mass, linear_damping, angular_damping;
		bool fixed_rotation, hits_player, hits_ground;
	} dynamic_props_t;
}

%union
{
	int i;
	float f;
	unsigned int u;
	char str[64];
	float vec[4];
	struct {
		float r, g, b;
	} color;
	dynamic_props_t dynamic_props;
	body_data_t *body_data_pointer;
	light_uniform_t *light_data_pointer;
}

%token <f> FLOAT
%token <i> INT BOOL
%token <str> VAR
%token GROUND_DEF LIGHT_DEF SENSOR_DEF JD_DEF JP_DEF JR_DEF JPL_DEF
%type <vec> vec4 vec3 vec2
%type <color> color
%type <dynamic_props> dynamic_props;
%type <body_data_pointer> ground_def sensor_def
%type <light_data_pointer> light_def

%%
program
: /* nothing */
| program expr ';'
;

expr
: def
| VAR '=' ground_def
{
	insert_ground_data($1, $3);
}
| VAR '=' sensor_def
{
	insert_ground_data($1, $3);
}
| VAR '=' light_def
{
	insert_light_data($1, $3);
}
;

def
: ground_def
| light_def
| jd_def
| jp_def
| jr_def
| jpl_def
;

ground_def
: GROUND_DEF '(' vec4 ',' vec3 ')'
{
	printf("static_ground(%u)\n", ground_count);
	$$ = make_ground($3, $5, nullptr, false);
}
| GROUND_DEF '(' vec4 ',' vec3 ',' dynamic_props ')'
{
	printf("dynamic_ground(%u)\n", ground_count);
	$$ = make_ground($3, $5, &($7), false);
}
;

sensor_def
: SENSOR_DEF '(' vec4 ',' FLOAT ')'
{
	printf("static_sensor(%u)\n", ground_count);
	const float props[3] = { 0.0f, 0.0f, $5 };
	$$ = make_ground($3, props, nullptr, true);
}
;

light_def
: LIGHT_DEF '(' vec3 ',' color ')'
{
	int id = *light_count;
	++*light_count;
	$$ = lights + id;
	*$$->x = $3[0] * 50.0f;
	*$$->y = $3[1] * 50.0f;
	*$$->radius = $3[2] * 50.0f;
	*$$->red = $5.r;
	*$$->green = $5.g;
	*$$->blue = $5.b;
	printf("light(%d)\n", id);
}
| LIGHT_DEF '(' vec3 ',' color ',' VAR ')'
{
	int id = *light_count;
	++*light_count;
	$$ = lights + id;
	*$$->x = $3[0] * 50.0f;
	*$$->y = $3[1] * 50.0f;
	*$$->radius = $3[2] * 50.0f;
	*$$->red = $5.r;
	*$$->green = $5.g;
	*$$->blue = $5.b;
	const char *ground_name = $7;
	body_data_t *body_data;
	if (get_body_data(ground_name, &body_data)) {
		body_data->light = $$;
	}
	printf("dynamic_light(%d) attached to %s\n", id, ground_name);
}
;

jd_def: JD_DEF '(' VAR ',' VAR ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2DistanceJointDef joint_def;
		joint_def.Initialize(a, b, a->GetWorldCenter(), b->GetWorldCenter());
		world->CreateJoint(&joint_def);
	}
	printf("distance(%s, %s)\n", $3, $5);
}

jp_def
: JP_DEF '(' VAR ',' VAR ',' vec2 ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2PrismaticJointDef joint_def;
		b2Vec2 anchor($7[0], $7[1]);
		b2Vec2 axis($9[0], $9[1]);
		joint_def.Initialize(a, b, anchor, axis);
		world->CreateJoint(&joint_def);
	}
	printf("prismatic(%s, %s)\n", $3, $5);
}
| JP_DEF '(' VAR ',' VAR ',' vec2 ',' vec2 ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2PrismaticJointDef joint_def;
		b2Vec2 anchor($7[0], $7[1]);
		b2Vec2 axis($9[0], $9[1]);
		joint_def.Initialize(a, b, anchor, axis);
		joint_def.enableMotor = true;
		joint_def.maxMotorForce = $11[0];
		joint_def.motorSpeed = $11[1];
		world->CreateJoint(&joint_def);
	}
	printf("prismatic_motor(%s, %s)\n", $3, $5);
}
| JP_DEF '(' VAR ',' VAR ',' vec2 ',' vec2 ',' vec2 ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2PrismaticJointDef joint_def;
		b2Vec2 anchor($7[0], $7[1]);
		b2Vec2 axis($9[0], $9[1]);
		joint_def.Initialize(a, b, anchor, axis);
		joint_def.enableMotor = true;
		joint_def.maxMotorForce = $11[0];
		joint_def.motorSpeed = $11[1];
		joint_def.enableLimit = true;
		joint_def.lowerTranslation = $13[0];
		joint_def.upperTranslation = $13[1];
		world->CreateJoint(&joint_def);
	}
	printf("prismatic_motor_limit(%s, %s)\n", $3, $5);
}
;

jr_def
: JR_DEF '(' VAR ',' VAR ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2RevoluteJointDef joint_def;
		b2Vec2 v($7[0], $7[1]);
		joint_def.Initialize(a, b, v);
		world->CreateJoint(&joint_def);
	}
	printf("revolute(%s, %s)\n", $3, $5);
}
| JR_DEF '(' VAR ',' VAR ',' vec2 ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2RevoluteJointDef joint_def;
		b2Vec2 v($7[0], $7[1]);
		joint_def.Initialize(a, b, v);
		joint_def.enableMotor = true;
		joint_def.maxMotorTorque = $9[0];
		joint_def.motorSpeed = $9[1];
		world->CreateJoint(&joint_def);
	}
	printf("revolute_motor(%s, %s)\n", $3, $5);
}
| JR_DEF '(' VAR ',' VAR ',' vec2 ',' vec2 ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2RevoluteJointDef joint_def;
		b2Vec2 v($7[0], $7[1]);
		joint_def.Initialize(a, b, v);
		joint_def.enableMotor = true;
		joint_def.maxMotorTorque = $9[0];
		joint_def.motorSpeed = $9[1];
		joint_def.enableLimit = true;
		joint_def.lowerAngle = $11[0];
		joint_def.upperAngle = $11[1];
		world->CreateJoint(&joint_def);
	}
	printf("revolute_motor_limit(%s, %s)\n", $3, $5);
}
;

jpl_def
: JPL_DEF '(' VAR ',' VAR ',' vec2 ',' vec2 ')'
{
	b2Body *a, *b;
	if (get_body_by_var($3, $5, &a, &b)) {
		b2PulleyJointDef joint_def;
		b2Vec2 av($7[0], $7[1]);
		b2Vec2 bv($9[0], $9[1]);
		constexpr float ratio = 1.0f;
		joint_def.Initialize(a, b, a->GetWorldCenter(), b->GetWorldCenter(), av, bv, ratio);
		world->CreateJoint(&joint_def);
	}
	printf("pully(%s, %s)\n", $3, $5);
}
;

vec4: '(' FLOAT ',' FLOAT ',' FLOAT ',' FLOAT ')'
{
	$$[0] = $2;
	$$[1] = $4;
	$$[2] = $6;
	$$[3] = $8;
}
vec3: '(' FLOAT ',' FLOAT ',' FLOAT ')'
{
	$$[0] = $2;
	$$[1] = $4;
	$$[2] = $6;
}
vec2: '(' FLOAT ',' FLOAT ')'
{
	$$[0] = $2;
	$$[1] = $4;
}
color: vec3
{
	$$.r = $1[0];
	$$.g = $1[1];
	$$.b = $1[2];
}

dynamic_props: '(' FLOAT ',' BOOL ',' FLOAT ',' FLOAT ',' BOOL ',' BOOL ')'
{
	$$.mass = $2;
	$$.fixed_rotation = $4 != 0;
	$$.linear_damping = $6;
	$$.angular_damping = $8;
	$$.hits_player = $10;
	$$.hits_ground = $12;
}
;
%%
