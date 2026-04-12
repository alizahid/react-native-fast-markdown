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

@implementation MarkdownSerializer

+ (NSString *)serializePlainText:(NSString *)text
                       withStore:(FormattingStore *)store {
  if (text.length == 0) return @"";

  NSMutableString *md = [NSMutableString new];

  // Collect code block ranges for fence wrapping
  NSMutableIndexSet *codeBlockChars = [NSMutableIndexSet new];
  for (FormattingRange *r in store.allRanges) {
    if (r.type == FormattingTypeCodeBlock) {
      [codeBlockChars addIndexesInRange:r.range];
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
    BOOL lineInCodeBlock = lineRange.length > 0 &&
        [codeBlockChars containsIndex:lineRange.location];

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
    if (NSIntersectionRange(r.range, lineRange).length == 0) continue;

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
      // TODO: proper numbering from store context
      return @"1. ";
    }
  }
  return nil;
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
    // "• " (bullet + two spaces)
    if ([line hasPrefix:@"\u2022  "]) return 3;
    if ([line hasPrefix:@"\u2022 "]) return 2;
  } else if (type == FormattingTypeOrderedList) {
    // "N. " pattern
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"^\\d+\\.\\s"
                             options:0
                               error:nil];
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

  // Build events for inline ranges that intersect this line
  NSMutableArray<_MSEvent *> *events = [NSMutableArray new];

  for (FormattingRange *r in store.allRanges) {
    if (![FormattingRange isInlineType:r.type]) continue;

    NSRange intersection = NSIntersectionRange(r.range, sourceRange);
    if (intersection.length == 0) continue;

    // Clamp to line bounds and convert to local offsets
    NSUInteger localStart = intersection.location - sourceRange.location;
    NSUInteger localEnd = localStart + intersection.length;

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

  if (events.count == 0) {
    [md appendString:content];
    return;
  }

  // Sort: by position, opens before closes at same position,
  // wider spans open first / close last.
  [events sortUsingComparator:^NSComparisonResult(_MSEvent *a, _MSEvent *b) {
    if (a.position != b.position) {
      return a.position < b.position ? NSOrderedAscending
                                     : NSOrderedDescending;
    }
    // At same position: opens before closes
    if (a.isOpen != b.isOpen) {
      return a.isOpen ? NSOrderedAscending : NSOrderedDescending;
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

  // Walk events and emit text + markers
  NSUInteger cursor = 0;
  for (_MSEvent *event in events) {
    // Emit text before this event
    if (event.position > cursor) {
      [md appendString:[content substringWithRange:
                            NSMakeRange(cursor, event.position - cursor)]];
      cursor = event.position;
    }

    if (event.isOpen) {
      if (event.type == FormattingTypeLink) {
        [md appendString:@"["];
      } else {
        [md appendString:[self openMarkerForType:event.type]];
      }
    } else {
      if (event.type == FormattingTypeLink) {
        [md appendFormat:@"](%@)", event.url ?: @""];
      } else {
        [md appendString:[self closeMarkerForType:event.type]];
      }
    }
  }

  // Emit remaining text
  if (cursor < content.length) {
    [md appendString:[content substringFromIndex:cursor]];
  }
}

+ (NSString *)openMarkerForType:(FormattingType)type {
  switch (type) {
  case FormattingTypeBold: return @"**";
  case FormattingTypeItalic: return @"*";
  case FormattingTypeStrikethrough: return @"~~";
  case FormattingTypeCode: return @"`";
  default: return @"";
  }
}

+ (NSString *)closeMarkerForType:(FormattingType)type {
  return [self openMarkerForType:type];
}

@end
