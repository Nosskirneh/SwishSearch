@interface ContactsContainerView : UIView
@property (nonatomic, readwrite, assign) UITableView *tableView;
@property (nonatomic, assign) CAShapeLayer *border;
- (id)initWithFrame:(CGRect)frame delegate:(id)delegate;
- (void)setNumberOfSuggestions:(NSUInteger)count maxHeight:(CGFloat)maxHeight;
@end
