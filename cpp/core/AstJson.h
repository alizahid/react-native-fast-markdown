#pragma once

#include <string>

#include "Ast.h"

namespace fastmarkdown {

// Compact JSON rendering of the AST for golden tests and debugging.
std::string astToJson(const Node* node);

} // namespace fastmarkdown
