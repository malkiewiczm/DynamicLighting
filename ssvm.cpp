#include "ssvm.hpp"
#include "common.hpp"
#include <algorithm>
#include <unordered_map>

namespace ssvm {
	class executer_t {
	private:
		const op_t *ip;
		body_data_t *ptr_sensor;
		body_data_t *ptr_other;
		data_type stack[32];
		int stack_ptr;
		int waiting;
		void push(data_type data);
		data_type pop();
		void kill();
	public:
		executer_t *next;
		executer_t *prev;
		void tick();
		void reset(const op_t *, body_data_t *, body_data_t *);
	};
}

class MyContactListener : public b2ContactListener
{
public:
	void BeginContact(b2Contact* contact);
	void EndContact(b2Contact* contact);
};

using namespace ssvm;

static op_t program[1000];
static int instruction_count;
static std::unordered_map<std::string, opcode_t> op_names;

op_t *ssvm::alloc()
{
	op_t *ret = program + instruction_count;
	++instruction_count;
	return ret;
}

op_t *ssvm::alloc(std::string op_name)
{
	op_t *ret = program + instruction_count;
	++instruction_count;
	auto item = op_names.find(op_name);
	if (item == op_names.end()) {
		printf("--> when name is %s\n", op_name.c_str());
		fatal("opcode name not recognized");
	}
	ret->code = item->second;
	return ret;
}

#define reg(name)(op_names[#name] = op_##name)

b2World *ssvm::init()
{
	static MyContactListener listener;
	reg(noop);
	reg(push);
	reg(exit);
	reg(wait);
	reg(get_sensor);
	reg(get_other);
	reg(get_light);
	reg(light_x);
	reg(light_y);
	reg(light_radius);
	reg(light_red);
	reg(light_green);
	reg(light_blue);

	b2Vec2 gravity(0.0f, 9.81f);
	b2World *world = new b2World(gravity);
	world->SetContactListener(&listener);
	return world;
}

void ssvm::reset()
{
	instruction_count = 0;
}

void ssvm::executer_t::push(data_type data)
{
	if (stack_ptr == 32)
		fatal("stack overflow");
	stack[stack_ptr] = data;
	++stack_ptr;
}

data_type ssvm::executer_t::pop()
{
	if (stack_ptr == 0)
		fatal("stack underflow");
	--stack_ptr;
	return stack[stack_ptr];
}

static executer_t *list = nullptr;

void ssvm::tick()
{
	executer_t *lnext = nullptr;
	for (executer_t *i = list; i; i = lnext) {
		lnext = i->next;
		i->tick();
	}
}

#ifdef sdfkj
static void add_executer(const op_t *lprogram, body_data_t *sensor, body_data_t *other)
{
	// TODO: pool this
	executer_t *obj = new executer_t();
	obj->reset(lprogram, sensor, other);
	if (list == nullptr) {
		obj->prev = nullptr;
		obj->next = nullptr;
		list = obj;
	} else {
		obj->prev = nullptr;
		obj->next = list;
		list->prev = obj;
	}
}
#endif

void ssvm::executer_t::kill()
{
	if (prev)
		prev->next = next;
	if (next)
		next->prev = prev;
	delete this;
}

void ssvm::executer_t::reset(const op_t *lprogram, body_data_t *sensor, body_data_t *other)
{
	ip = lprogram;
	stack_ptr = 0;
	waiting = 0;
	ptr_sensor = sensor;
	ptr_other = other;
}

void ssvm::executer_t::tick()
{
	if (waiting)
		--waiting;
	const op_t &op = *ip;
	++ip;
	switch (op.code) {
	case op_noop:
		break;
	case op_push:
		push(op.data);
		break;
	case op_exit:
		kill();
		break;
	case op_wait:
		waiting = pop().i;
		break;
	case op_get_sensor:
		push(ptr_sensor);
		break;
	case op_get_other:
		push(ptr_other);
		break;
	case op_get_light:
		push(pop().body_data->light);
		break;
	case op_light_x: {
		light_uniform_t *data = pop().light_data;
		*data->x = pop().f;
		break;
	}
	case op_light_y: {
		light_uniform_t *data = pop().light_data;
		*data->y = pop().f;
		break;
	}
	case op_light_radius: {
		light_uniform_t *data = pop().light_data;
		*data->radius = pop().f;
		break;
	}
	case op_light_red: {
		light_uniform_t *data = pop().light_data;
		*data->red = pop().f;
		break;
	}
	case op_light_green: {
		light_uniform_t *data = pop().light_data;
		*data->green = pop().f;
		break;
	}
	case op_light_blue: {
		light_uniform_t *data = pop().light_data;
		*data->blue = pop().f;
		break;
	}
	}
}

void MyContactListener::BeginContact(b2Contact* contact)
{
	const b2Fixture *sensor = contact->GetFixtureA();
	const b2Fixture *other = contact->GetFixtureB();
	if (other->IsSensor())
		std::swap(sensor, other);
	if (sensor->IsSensor() && ! other->IsSensor()) {
		trace("begin sensor !");
	}
}

void MyContactListener::EndContact(b2Contact* contact)
{
	const b2Fixture *sensor = contact->GetFixtureA();
	const b2Fixture *other = contact->GetFixtureB();
	if (other->IsSensor())
		std::swap(sensor, other);
	if (sensor->IsSensor() && ! other->IsSensor()) {
		trace("end sensor !");
	}
}
