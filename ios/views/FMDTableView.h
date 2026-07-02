#import <UIKit/UIKit.h>

#import "../render/FMDBlock.h"
#import "FMDMarkdownHost.h"

NS_ASSUME_NONNULL_BEGIN

/// Table: paints the table box, hosts a cell grid in a horizontal scroller
/// so wide tables keep readable column widths.
@interface FMDTableView : UIView

- (void)bind:(FMDMeasuredBlock *)measured host:(nullable id<FMDMarkdownHost>)host;

@end

NS_ASSUME_NONNULL_END
