#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <math.h>

#define trace(what)(std::cout << "[" __FILE__ ":"<< __LINE__ << "] " #what " = " << what << std::endl)
#define fatal(msg)(_fatal(msg, __FILE__, __LINE__))
void _fatal(const char *msg, const char *file, const int line);
#define torad(what)(0.017453292519943f * (what))
#define todeg(what)(57.295779513082 * (what))
/*
static inline std::ostream &operator<< (std::ostream &lhs, const sf::Vector2f &rhs)
{
	lhs << '(' << rhs.x << ", " << rhs.y << ')';
	return lhs;
}
*/
