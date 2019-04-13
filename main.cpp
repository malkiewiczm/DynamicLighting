#include "common.hpp"
#include <SFML/Graphics.hpp>
#include "level_parser.hpp"
#include "ssvm.hpp"

static sf::RectangleShape ground_shapes[60];
static sf::Shader shader;
static int light_count;
static float lightPosX[16];
static float lightPosY[16];
static float lightColorR[16];
static float lightColorG[16];
static float lightColorB[16];
static float lightRadius[16];
static light_uniform_t light_uniforms[16];

#define LIGHT_ON

static void update_lights()
{
	static float realY[16];
	for (int i = 0; i < light_count; ++i) {
		realY[i] = 600.0f - lightPosY[i];
	}
	shader.setUniform("light_count", light_count);
	shader.setUniformArray("lightPosX", lightPosX, 16);
	shader.setUniformArray("lightPosY", realY, 16);
	shader.setUniformArray("colorR", lightColorR, 16);
	shader.setUniformArray("colorG", lightColorG, 16);
	shader.setUniformArray("colorB", lightColorB, 16);
	shader.setUniformArray("radius", lightRadius, 16);
}

int main()
{
	if (!sf::Shader::isAvailable()) {
		fatal("shaders are not available");
	}
	if (! shader.loadFromFile("shader.frag", sf::Shader::Fragment)) {
		fatal("shader could not loaded");
	}
	sf::Texture stone_texture;
	if (! stone_texture.loadFromFile("stone.png")) {
		fatal("stone_texture could not be loaded");
	}
	b2World *world = ssvm::init();
	for (unsigned i = 0; i < 16; ++i) {
		light_uniforms[i] = {
			lightPosX + i,
			lightPosY + i,
			lightRadius + i,
			lightColorR + i,
			lightColorG + i,
			lightColorB + i
		};
	}
	if (parse_level_file("sample.world", world, light_uniforms, &light_count)) {
		fatal("world was not parsed correctly");
	}
	update_lights();
	sf::RenderWindow window(sf::VideoMode(800, 600), "swindow", sf::Style::Titlebar);
	window.setVerticalSyncEnabled(true);
	for (b2Body *b = world->GetBodyList(); b; b = b->GetNext()) {
		body_data_t *data = (body_data_t*)b->GetUserData();
		sf::RectangleShape &shape = ground_shapes[data->id];
		sf::Vector2f dim(data->width, data->height);
		shape = sf::RectangleShape(dim);
		shape.setTexture(&stone_texture);
		shape.setOrigin(dim.x / 2.0f, dim.y / 2.0f);
		shape.setScale(50.0f, 50.0f);
	}
	while (window.isOpen()) {
		sf::Event event;
		while (window.pollEvent(event)) {
			switch (event.type) {
			case sf::Event::Closed:
				window.close();
				break;
			case sf::Event::KeyPressed:
				if (event.key.code == 36)
					window.close();
				break;
			}
		}
		window.clear();
		constexpr int VelocityIterations = 8;
		constexpr int PositionIterations = 3;
#define TimeStep 0.0166667f
		world->Step(TimeStep, VelocityIterations, PositionIterations);
		for (b2Body *b = world->GetBodyList(); b; b = b->GetNext()) {
			body_data_t *data = (body_data_t*)b->GetUserData();
			b2Vec2 b2_pos = b->GetPosition();
			b2_pos *= 50.0f;
			if (data->light) {
				*data->light->x = b2_pos.x;
				*data->light->y = b2_pos.y;
			}
			if (! data->visible)
				continue;
			sf::RectangleShape &shape = ground_shapes[data->id];
			shape.setPosition(b2_pos.x, b2_pos.y);
			shape.setRotation(todeg(b->GetAngle()));
#ifdef LIGHT_ON
			window.draw(shape, &shader);
#else
			window.draw(shape);
#endif
		}
		update_lights();
		ssvm::tick();
		window.display();
	}
	return 0;
}
