#include "Preprocess.h"

namespace fastmarkdown {

namespace {

bool isFenceLine(const std::string& s, size_t lineStart, size_t lineEnd) {
  size_t i = lineStart;
  size_t spaces = 0;
  while (i < lineEnd && s[i] == ' ' && spaces < 3) {
    i++;
    spaces++;
  }
  if (i >= lineEnd) {
    return false;
  }
  char fence = s[i];
  if (fence != '`' && fence != '~') {
    return false;
  }
  size_t run = 0;
  while (i < lineEnd && s[i] == fence) {
    i++;
    run++;
  }
  return run >= 3;
}

} // namespace

std::string preprocessMarkdown(const std::string& input) {
  std::string out;
  out.reserve(input.size() + 8);

  bool inFence = false;
  size_t pos = 0;
  const size_t n = input.size();

  while (pos < n) {
    size_t lineEnd = input.find('\n', pos);
    if (lineEnd == std::string::npos) {
      lineEnd = n;
    }

    if (isFenceLine(input, pos, lineEnd)) {
      inFence = !inFence;
      out.append(input, pos, lineEnd - pos);
    } else if (inFence) {
      out.append(input, pos, lineEnd - pos);
    } else {
      // Skip up to 3 leading spaces; 4+ may be indented code -- leave alone.
      size_t i = pos;
      size_t spaces = 0;
      while (i < lineEnd && (input[i] == ' ' || input[i] == '\t') && spaces < 4) {
        if (input[i] == '\t') {
          spaces = 4;
        } else {
          spaces++;
        }
        i++;
      }
      bool escaped = false;
      if (spaces < 4) {
        // Walk any blockquote markers; escape the ">" that opens ">!".
        size_t j = i;
        while (j < lineEnd && input[j] == '>') {
          if (j + 1 < lineEnd && input[j + 1] == '!') {
            out.append(input, pos, j - pos);
            out.push_back('\\');
            out.append(input, j, lineEnd - j);
            escaped = true;
            break;
          }
          j++;
          if (j < lineEnd && input[j] == ' ') {
            j++;
          }
        }
      }
      if (!escaped) {
        out.append(input, pos, lineEnd - pos);
      }
    }

    if (lineEnd < n) {
      out.push_back('\n');
    }
    pos = lineEnd + 1;
  }

  return out;
}

} // namespace fastmarkdown
