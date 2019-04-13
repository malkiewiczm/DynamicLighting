#pragma once

#include <Box2D/Box2D.h>

struct light_uniform_t {
	float *x;
	float *y;
	float *radius;
	float *red;
	float *green;
	float *blue;
};

struct body_data_t {
	float width;
	float height;
	int id;
	bool visible;
	b2Body *body;
	light_uniform_t *light;
};

int parse_level_file(
	const char *fname,
	b2World *world,
	light_uniform_t *lights,
	int *out_light_count
);
