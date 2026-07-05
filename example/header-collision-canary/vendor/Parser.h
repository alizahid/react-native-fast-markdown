// Stand-in for another pod's Parser.h (react-native-unistyles has
// cxx/parser/Parser.h with its own namespace).
#pragma once

namespace canary::parser {
struct Parser {
  int value = 0;
};
} // namespace canary::parser
