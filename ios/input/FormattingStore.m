#import "FormattingStore.h"

@implementation FormattingStore {
  NSMutableArray<FormattingRange *> *_ranges;
  NSArray<FormattingRange *> *_cachedAllRanges;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _ranges = [NSMutableArray new];
    _pendingStyles = [NSMutableSet new];
    _pendingRemovals = [NSMutableSet new];
  }
  return self;
}

// ---------------------------------------------------------------
#pragma mark - Query
// ---------------------------------------------------------------

- (NSArray<FormattingRange *> *)allRanges {
  if (!_cachedAllRanges) {
    _cachedAllRanges = [_ranges copy];
  }
  return _cachedAllRanges;
}

- (BOOL)hasType:(FormattingType)type atIndex:(NSUInteger)index {
  for (FormattingRange *r in _ranges) {
    // Ranges are sorted by location — once we pass the index, no
    // subsequent range can contain it.
    if (r.range.location > index) break;
    if (r.type == type && index < NSMaxRange(r.range)) {
      return YES;
    }
  }
  return NO;
}

- (NSArray<FormattingRange *> *)rangesAtIndex:(NSUInteger)index {
  NSMutableArray *result = [NSMutableArray new];
  for (FormattingRange *r in _ranges) {
    if (r.range.location > index) break;
    if (index < NSMaxRange(r.range)) {
      [result addObject:r];
    }
  }
  return result;
}

- (NSArray<FormattingRange *> *)rangesOfType:(FormattingType)type
                                intersecting:(NSRange)range {
  NSMutableArray *result = [NSMutableArray new];
  for (FormattingRange *r in _ranges) {
    // Past the query range — no more intersections possible.
    if (r.range.location >= NSMaxRange(range)) break;
    if (r.type == type && NSIntersectionRange(r.range, range).length > 0) {
      [result addObject:r];
    }
  }
  return result;
}

// ---------------------------------------------------------------
#pragma mark - Mutate
// ---------------------------------------------------------------

- (void)addRange:(FormattingRange *)range {
  if (range.range.length == 0) return;

  // Merge with adjacent/overlapping ranges of the same type.
  // For links, only merge when the URLs match — merging links with
  // different URLs would silently discard one of them.
  NSMutableArray *toRemove = [NSMutableArray new];
  NSUInteger mergedStart = range.range.location;
  NSUInteger mergedEnd = NSMaxRange(range.range);

  for (FormattingRange *existing in _ranges) {
    if (existing.type != range.type) continue;

    // Don't merge link ranges with different URLs
    if (range.type == FormattingTypeLink &&
        range.url && existing.url &&
        ![range.url isEqualToString:existing.url]) {
      continue;
    }

    NSUInteger eStart = existing.range.location;
    NSUInteger eEnd = NSMaxRange(existing.range);

    // Adjacent or overlapping
    if (eStart <= mergedEnd && eEnd >= mergedStart) {
      mergedStart = MIN(mergedStart, eStart);
      mergedEnd = MAX(mergedEnd, eEnd);
      [toRemove addObject:existing];
    }
  }

  [_ranges removeObjectsInArray:toRemove];

  FormattingRange *merged = [FormattingRange
      rangeWithType:range.type
              range:NSMakeRange(mergedStart, mergedEnd - mergedStart)
                url:range.url];
  [_ranges addObject:merged];
  [self sortRanges];
}

- (void)removeRangesOfType:(FormattingType)type intersecting:(NSRange)range {
  NSMutableArray *toRemove = [NSMutableArray new];
  NSMutableArray *toAdd = [NSMutableArray new];

  for (FormattingRange *r in _ranges) {
    if (r.type != type) continue;

    NSRange intersection = NSIntersectionRange(r.range, range);
    if (intersection.length == 0) continue;

    [toRemove addObject:r];

    // Left remainder
    if (r.range.location < range.location) {
      FormattingRange *left = [FormattingRange
          rangeWithType:type
                  range:NSMakeRange(r.range.location,
                                     range.location - r.range.location)
                    url:r.url];
      [toAdd addObject:left];
    }

    // Right remainder
    if (NSMaxRange(r.range) > NSMaxRange(range)) {
      FormattingRange *right = [FormattingRange
          rangeWithType:type
                  range:NSMakeRange(NSMaxRange(range),
                                     NSMaxRange(r.range) - NSMaxRange(range))
                    url:r.url];
      [toAdd addObject:right];
    }
  }

  [_ranges removeObjectsInArray:toRemove];
  [_ranges addObjectsFromArray:toAdd];
  [self sortRanges];
}

- (void)replaceAllRanges:(NSArray<FormattingRange *> *)ranges {
  _ranges = [ranges mutableCopy];
  [self sortRanges];
}

- (void)removeAll {
  [_ranges removeAllObjects];
  [self invalidateCache];
}

// ---------------------------------------------------------------
#pragma mark - Edit Adjustment
// ---------------------------------------------------------------

- (void)adjustForEditAt:(NSUInteger)location
          deletedLength:(NSUInteger)deleted
         insertedLength:(NSUInteger)inserted {
  NSInteger delta = (NSInteger)inserted - (NSInteger)deleted;
  NSRange editRange = NSMakeRange(location, deleted);

  NSMutableArray *toRemove = [NSMutableArray new];

  for (FormattingRange *r in _ranges) {
    NSUInteger rStart = r.range.location;
    NSUInteger rEnd = NSMaxRange(r.range);

    // Case 1: range is entirely before the edit — no change
    if (rEnd <= location) {
      continue;
    }

    // Case 2: range is entirely after the edit — shift
    if (rStart >= location + deleted) {
      r.range = NSMakeRange((NSUInteger)((NSInteger)rStart + delta),
                             r.range.length);
      continue;
    }

    // Case 3: edit is entirely inside the range — expand/shrink
    if (rStart < location && rEnd > location + deleted) {
      r.range = NSMakeRange(rStart,
                             (NSUInteger)((NSInteger)r.range.length + delta));
      continue;
    }

    // Case 4: range starts at or after edit location, overlaps with
    // deleted region — the range partially or fully overlaps the
    // deletion.

    // If the entire range is within the deleted region, remove it.
    if (rStart >= location && rEnd <= location + deleted) {
      [toRemove addObject:r];
      continue;
    }

    // Range overlaps the edit on the left (range starts before edit,
    // range ends inside deleted region)
    if (rStart < location && rEnd <= location + deleted) {
      r.range = NSMakeRange(rStart, location - rStart);
      continue;
    }

    // Range overlaps the edit on the right (range starts inside
    // deleted region, range ends after)
    if (rStart >= location && rStart < location + deleted) {
      NSUInteger newStart = location + inserted;
      NSUInteger newLen = rEnd - (location + deleted);
      r.range = NSMakeRange(newStart, newLen);
      continue;
    }
  }

  [_ranges removeObjectsInArray:toRemove];

  // Remove zero-length ranges
  NSMutableArray *empty = [NSMutableArray new];
  for (FormattingRange *r in _ranges) {
    if (r.range.length == 0) [empty addObject:r];
  }
  [_ranges removeObjectsInArray:empty];
  [self invalidateCache];
}

// ---------------------------------------------------------------
#pragma mark - Pending Styles
// ---------------------------------------------------------------

- (void)clearPending {
  [_pendingStyles removeAllObjects];
  [_pendingRemovals removeAllObjects];
}

- (BOOL)isEffectivelyActive:(FormattingType)type atIndex:(NSUInteger)index {
  NSNumber *key = @(type);

  if ([_pendingRemovals containsObject:key]) return NO;
  if ([_pendingStyles containsObject:key]) return YES;

  return [self hasType:type atIndex:index];
}

- (NSString *)effectiveLinkAtIndex:(NSUInteger)index {
  NSNumber *key = @(FormattingTypeLink);

  if ([_pendingRemovals containsObject:key]) return nil;

  for (FormattingRange *r in _ranges) {
    if (r.type == FormattingTypeLink &&
        index >= r.range.location &&
        index < NSMaxRange(r.range)) {
      return r.url;
    }
  }

  return nil;
}

// ---------------------------------------------------------------
#pragma mark - Internal
// ---------------------------------------------------------------

- (void)invalidateCache {
  _cachedAllRanges = nil;
}

- (void)sortRanges {
  [_ranges sortUsingComparator:^NSComparisonResult(FormattingRange *a,
                                                    FormattingRange *b) {
    if (a.range.location != b.range.location) {
      return a.range.location < b.range.location
                 ? NSOrderedAscending
                 : NSOrderedDescending;
    }
    return a.range.length > b.range.length ? NSOrderedAscending
                                           : NSOrderedDescending;
  }];
  [self invalidateCache];
}

@end
