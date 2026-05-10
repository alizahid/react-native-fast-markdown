#import "MarkdownSerializer.h"
#import "FormattingRange.h"
#import "FormattingStore.h"

// An "event" at a position in the text where a formatting span
// opens or closes.
@interface _MSEvent : NSObject
@property (nonatomic) NSUInteger position;
@property (nonatomic) BOOL isOpen;
@property (nonatomic) FormattingType type;
@property (nonatomic, copy, nullable) NSString *url;
@property (nonatomic) NSUInteger spanLength; // for sort tiebreaking
@end

@implementation _MSEvent
@end

@interface _MSAtom : NSObject
@property (nonatomic) NSUInteger start;
@property (nonatomic) NSUInteger end;
@property (nonatomic, copy) NSString *markdown;
@end

@implementation _MSAtom
@end

@implementation MarkdownSerializer

+ (NSString *)serializePlainText:(NSString *)text
                       withStore:(FormattingStore *)store {
  if (text.length == 0) return @"";

  NSMutableString *md = [NSMutableString new];

  // Collect code block ranges — stored as NSRange values, not per-
  // character indices, so memory is O(range count) not O(text length).
  NSMutableArray<FormattingRange *> *codeBlockRanges = [NSMutableArray new];
  for (FormattingRange *r in store.allRanges) {
    if (r.type == FormattingTypeCodeBlock) {
      [codeBlockRanges addObject:r];
    }
  }

  // Track whether we're inside a code block fence
  BOOL inCodeBlock = NO;

  // Process line by line
  NSArray<NSString *> *lines = [text componentsSeparatedByString:@"\n"];
  NSUInteger offset = 0;

  for (NSUInteger lineIdx = 0; lineIdx < lines.count; lineIdx++) {
    NSString *line = lines[lineIdx];
    NSRange lineRange = NSMakeRange(offset, line.length);

    if (lineIdx > 0) [md appendString:@"\n"];

    // Check if this line is in a code block
    FormattingRange *codeBlockRange = nil;
    for (FormattingRange *r in codeBlockRanges) {
      if ([self range:r.range containsLineRange:lineRange]) {
        codeBlockRange = r;
        break;
      }
    }
    BOOL lineInCodeBlock = codeBlockRange != nil;

    // Emit opening fence when entering code block
    if (lineInCodeBlock && !inCodeBlock) {
      [md appendString:@"```\n"];
      inCodeBlock = YES;
    }

    // Emit closing fence when leaving code block
    if (!lineInCodeBlock && inCodeBlock) {
      [md appendString:@"```\n"];
      inCodeBlock = NO;
    }

    if (lineInCodeBlock) {
      // Inside code block — emit raw content
      [md appendString:line];
    } else {
      // Check for block-level formatting
      NSString *prefix = [self blockPrefixForRange:lineRange store:store];
      NSString *contentToSerialize = line;

      // For list items, skip the bullet prefix in the plain text
      if (prefix) {
        FormattingRange *listRange =
            [self listRangeAt:lineRange store:store];
        if (listRange) {
          NSUInteger skipLen = [self bulletLengthInLine:line
                                              listType:listRange.type];
          if (skipLen > 0 && skipLen <= line.length) {
            contentToSerialize = [line substringFromIndex:skipLen];
            lineRange = NSMakeRange(lineRange.location + skipLen,
                                     lineRange.length - skipLen);
          }
        }
        [md appendString:prefix];
      }

      [self serializeInlineContent:contentToSerialize
                       sourceRange:lineRange
                             store:store
                              into:md];
    }

    offset += line.length + 1;
  }

  // Close any trailing code block
  if (inCodeBlock) {
    [md appendString:@"\n```"];
  }

  return [md copy];
}

#pragma mark - Block Prefix

+ (NSString *)blockPrefixForRange:(NSRange)lineRange
                            store:(FormattingStore *)store {
  for (FormattingRange *r in store.allRanges) {
    if (![self range:r.range containsLineRange:lineRange]) continue;

    if ([FormattingRange isHeadingType:r.type]) {
      NSInteger level = [FormattingRange headingLevelForType:r.type];
      NSMutableString *prefix = [NSMutableString new];
      for (NSInteger i = 0; i < level; i++) [prefix appendString:@"#"];
      [prefix appendString:@" "];
      return prefix;
    }

    if (r.type == FormattingTypeBlockquote) {
      return @"> ";
    }

    if (r.type == FormattingTypeUnorderedList) {
      return @"- ";
    }

    if (r.type == FormattingTypeOrderedList) {
      NSInteger number = r.listStart > 0 ? r.listStart : 1;
      return [NSString stringWithFormat:@"%ld. ", (long)number];
    }
  }
  return nil;
}

+ (BOOL)range:(NSRange)range containsLineRange:(NSRange)lineRange {
  if (lineRange.length > 0) {
    return NSIntersectionRange(range, lineRange).length > 0;
  }
  NSUInteger point = lineRange.location;
  return point >= range.location && point < NSMaxRange(range);
}

+ (FormattingRange *)listRangeAt:(NSRange)lineRange
                           store:(FormattingStore *)store {
  for (FormattingRange *r in store.allRanges) {
    if ((r.type == FormattingTypeOrderedList ||
         r.type == FormattingTypeUnorderedList) &&
        NSIntersectionRange(r.range, lineRange).length > 0) {
      return r;
    }
  }
  return nil;
}

+ (NSUInteger)bulletLengthInLine:(NSString *)line
                        listType:(FormattingType)type {
  if (type == FormattingTypeUnorderedList) {
    if ([line hasPrefix:@"\u2022  "]) return 3;
    if ([line hasPrefix:@"\u2022 "]) return 2;
    if ([line hasPrefix:@"\u2022"]) return 1;
  } else if (type == FormattingTypeOrderedList) {
    // "N. " pattern — static regex avoids recompilation per line
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      regex = [NSRegularExpression
          regularExpressionWithPattern:@"^\\d+\\.\\s"
                               options:0
                                 error:nil];
    });
    NSTextCheckingResult *match =
        [regex firstMatchInString:line
                          options:0
                            range:NSMakeRange(0, MIN(line.length, 10))];
    if (match) return match.range.length;
  }
  return 0;
}

#pragma mark - Inline Serialization

+ (void)serializeInlineContent:(NSString *)content
                   sourceRange:(NSRange)sourceRange
                         store:(FormattingStore *)store
                          into:(NSMutableString *)md {
  if (content.length == 0) return;

  NSMutableArray<_MSEvent *> *events = [NSMutableArray new];
  NSMutableArray<_MSAtom *> *atoms = [NSMutableArray new];
  NSMutableIndexSet *atomChars = [NSMutableIndexSet new];

  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isInlineType:r.type]) continue;

    NSRange intersection = NSIntersectionRange(r.range, sourceRange);
    if (intersection.length == 0) continue;

    NSUInteger localStart = intersection.location - sourceRange.location;
    NSUInteger localEnd = localStart + intersection.length;

    if (r.type == FormattingTypeMention) {
      _MSAtom *atom = [_MSAtom new];
      atom.start = localStart;
      atom.end = localEnd;
      atom.markdown = [self tagStringForMentionRange:r];
      [atoms addObject:atom];
      [atomChars addIndexesInRange:
          NSMakeRange(localStart, intersection.length)];
      continue;
    }

    if (r.type == FormattingTypeLink && [self linkRangeIsAutolink:r
                                                        localText:[content substringWithRange:
                                                            NSMakeRange(localStart, intersection.length)]]) {
      _MSAtom *atom = [_MSAtom new];
      atom.start = localStart;
      atom.end = localEnd;
      atom.markdown = [content substringWithRange:
          NSMakeRange(localStart, intersection.length)];
      [atoms addObject:atom];
      [atomChars addIndexesInRange:
          NSMakeRange(localStart, intersection.length)];
      continue;
    }

    _MSEvent *open = [_MSEvent new];
    open.position = localStart;
    open.isOpen = YES;
    open.type = r.type;
    open.url = r.url;
    open.spanLength = intersection.length;
    [events addObject:open];

    _MSEvent *close = [_MSEvent new];
    close.position = localEnd;
    close.isOpen = NO;
    close.type = r.type;
    close.url = r.url;
    close.spanLength = intersection.length;
    [events addObject:close];
  }

  [events sortUsingComparator:^NSComparisonResult(_MSEvent *a, _MSEvent *b) {
    if (a.position != b.position) {
      return a.position < b.position ? NSOrderedAscending
                                     : NSOrderedDescending;
    }
    // At the same position, close previous spans before opening new
    // adjacent spans so atoms/text at this boundary do not inherit
    // stale formatting.
    if (a.isOpen != b.isOpen) {
      return a.isOpen ? NSOrderedDescending : NSOrderedAscending;
    }
    // Both opens: wider first. Both closes: narrower first.
    if (a.isOpen) {
      return a.spanLength > b.spanLength ? NSOrderedAscending
                                         : NSOrderedDescending;
    } else {
      return a.spanLength < b.spanLength ? NSOrderedAscending
                                         : NSOrderedDescending;
    }
  }];

  [atoms sortUsingComparator:^NSComparisonResult(_MSAtom *a, _MSAtom *b) {
    if (a.start == b.start) return NSOrderedSame;
    return a.start < b.start ? NSOrderedAscending : NSOrderedDescending;
  }];

  NSUInteger eventIndex = 0;
  NSUInteger atomIndex = 0;
  NSUInteger cursor = 0;
  NSInteger codeDepth = 0;

  while (cursor <= content.length) {
    while (eventIndex < events.count &&
           events[eventIndex].position <= cursor) {
      _MSEvent *event = events[eventIndex];
      if (event.isOpen) {
        [md appendString:[self openMarkerForEvent:event]];
        if (event.type == FormattingTypeCode) codeDepth++;
      } else {
        if (event.type == FormattingTypeCode && codeDepth > 0) {
          codeDepth--;
        }
        [md appendString:[self closeMarkerForEvent:event]];
      }
      eventIndex++;
    }

    if (atomIndex < atoms.count && atoms[atomIndex].start == cursor) {
      [md appendString:atoms[atomIndex].markdown];
      cursor = atoms[atomIndex].end;
      atomIndex++;
      continue;
    }

    if (cursor == content.length) break;

    if (![atomChars containsIndex:cursor]) {
      NSString *ch = [content substringWithRange:NSMakeRange(cursor, 1)];
      [md appendString:codeDepth > 0 ? ch : [self escapedText:ch]];
    }
    cursor++;
  }
}

+ (BOOL)linkRangeIsAutolink:(FormattingRange *)range localText:(NSString *)text {
  if (range.autolink) return YES;
  if ([text isEqualToString:range.url ?: @""]) return YES;
  return [text hasPrefix:@"http://"] || [text hasPrefix:@"https://"];
}

+ (NSString *)openMarkerForEvent:(_MSEvent *)event {
  if (event.type == FormattingTypeLink) return @"[";
  return [self openMarkerForType:event.type];
}

+ (NSString *)closeMarkerForEvent:(_MSEvent *)event {
  if (event.type == FormattingTypeLink) {
    return [NSString stringWithFormat:@"](%@)", event.url ?: @""];
  }
  return [self closeMarkerForType:event.type];
}

+ (NSString *)openMarkerForType:(FormattingType)type {
  switch (type) {
  case FormattingTypeBold: return @"**";
  case FormattingTypeItalic: return @"*";
  case FormattingTypeStrikethrough: return @"~~";
  case FormattingTypeCode: return @"`";
  case FormattingTypeSpoiler: return @"||";
  case FormattingTypeSuperscript: return @"^(";
  default: return @"";
  }
}

+ (NSString *)closeMarkerForType:(FormattingType)type {
  if (type == FormattingTypeSuperscript) return @")";
  return [self openMarkerForType:type];
}

+ (NSString *)tagStringForMentionRange:(FormattingRange *)range {
  if (!range.tagName) return @"";
  NSMutableString *tag = [NSMutableString stringWithFormat:@"<%@", range.tagName];
  NSArray *keys = [[range.tagProps allKeys]
      sortedArrayUsingSelector:@selector(compare:)];
  for (NSString *key in keys) {
    NSString *value = range.tagProps[key] ?: @"";
    [tag appendFormat:@" %@=\"%@\"", key, [self escapedAttribute:value]];
  }
  [tag appendString:@" />"];
  return tag;
}

+ (NSString *)escapedAttribute:(NSString *)value {
  NSString *escaped = [value stringByReplacingOccurrencesOfString:@"&"
                                                       withString:@"&amp;"];
  escaped = [escaped stringByReplacingOccurrencesOfString:@"\""
                                               withString:@"&quot;"];
  escaped = [escaped stringByReplacingOccurrencesOfString:@"<"
                                               withString:@"&lt;"];
  escaped = [escaped stringByReplacingOccurrencesOfString:@">"
                                               withString:@"&gt;"];
  return escaped;
}

+ (NSString *)escapedText:(NSString *)text {
  static NSCharacterSet *chars;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    chars = [NSCharacterSet characterSetWithCharactersInString:@"\\`*_{}[]()#+-.!|>"];
  });
  if ([text rangeOfCharacterFromSet:chars].location == NSNotFound) {
    return text;
  }
  return [@"\\" stringByAppendingString:text];
}

@end
