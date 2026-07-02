#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"

NS_ASSUME_NONNULL_BEGIN

/// Table: paints the table box, hosts a cell grid in a horizontal scroller
/// so wide tables keep readable column widths.
@interface FMDTableView : UIView

- (void)bind:(FMDMeasuredBlock *)measured;

@end

NS_ASSUME_NONNULL_END
