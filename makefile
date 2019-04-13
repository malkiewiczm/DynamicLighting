MAKEFLAGS += Rr

CXX := g++
CXXFLAGS := -Wall -Wextra -Wpedantic -Wshadow -Wno-switch -std=c++11 -isystem .. -g
CXXFLAGS_LEX := -Wno-switch -std=c++11 -isystem .. -g
LDFLAGS := -L. -g
SFML_LIBS := -lsfml-graphics -lsfml-window -lsfml-system
BOX2D_LIBS := -lBox2D
LEXOUTPUT := lex.yy.c y.tab.c y.tab.h
LEXOBJECTS := lex.yy.o y.tab.o
OBJECTS := main.o common.o ssvm.o

.PHONY: all clean

all: main.app

clean:
	rm -f *.o *.app $(LEXOUTPUT)

main.app: $(OBJECTS) $(LEXOBJECTS)
	$(CXX) $(LDFLAGS) $(SFML_LIBS) $^ $(BOX2D_LIBS) -o $@

level_validator.app: level_validator.o common.o $(LEXOBJECTS)
	$(CXX) $(LDFLAGS) $^ $(BOX2D_LIBS) -o $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

lex.yy.o: $(LEXOUTPUT)
	$(CXX) $(CXXFLAGS_LEX) lex.yy.c -c -o $@

y.tab.o: $(LEXOUTPUT)
	$(CXX) $(CXXFLAGS_LEX) y.tab.c -c -o $@

lex.yy.c: level_parser.l
	flex $^

y.tab.c: level_parser.y
	yacc -d $^

y.tab.h: y.tab.c

common.o: common.cpp common.hpp
level_validator.o: level_validator.cpp common.hpp level_parser.hpp
main.o: main.cpp common.hpp level_parser.hpp
ssvm.o: ssvm.cpp ssvm.hpp level_parser.hpp common.hpp

