#import "FMDBlock.h"

@implementation FMDListRow
@end

@implementation FMDBlock
@end

@implementation FMDMeasuredBlock

- (instancetype)init {
  if (self = [super init]) {
    _children = @[];
    _markerHeights = @[];
    _rowContents = @[];
  }
  return self;
}

@end
