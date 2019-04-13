#pragma once

#include <string>
#include "level_parser.hpp"
#include <Box2D/Box2D.h>

namespace ssvm {
	enum opcode_t {
		op_noop,
		op_push,
		op_exit,
		op_wait,
		op_get_sensor,
		op_get_other,
		op_get_light,
		op_light_x,
		op_light_y,
		op_light_radius,
		op_light_red,
		op_light_green,
		op_light_blue,
	};
	union data_type {
		int i;
		float f;
		unsigned char b[4];
		light_uniform_t *light_data;
		body_data_t *body_data;
		data_type() {}
#define foop(type, name) data_type(type l##name) : name(l##name) {}
		foop(int, i)
		foop(float, f)
		foop(light_uniform_t*, light_data)
		foop(body_data_t*, body_data)
	};
	struct op_t {
		opcode_t code;
		data_type data;
	};
	op_t *alloc();
	op_t *alloc(std::string);
	void reset();
	b2World *init();
	void tick();
}
