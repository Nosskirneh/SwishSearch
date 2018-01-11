#import "ContactsContainerView.h"

@implementation ContactsContainerView

- (id)initWithFrame:(CGRect)frame delegate:(id)delegate {
    if (self == [super initWithFrame:frame]) {
        self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        self.tableView.delegate = delegate;
        self.tableView.dataSource = delegate;
        self.tableView.estimatedRowHeight = 50;
        self.tableView.backgroundColor = UIColor.whiteColor;
        [self addSubview:self.tableView];
    }
    return self;
}

- (void)layoutSubviews {
    [self setupOrUpdateBorderLayer:UIRectCornerBottomLeft | UIRectCornerBottomRight];
}

- (void)setupOrUpdateBorderLayer:(NSUInteger)corners {
    UIBezierPath *maskPath = [UIBezierPath
        bezierPathWithRoundedRect:self.bounds
        byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight)
        cornerRadii:CGSizeMake(15, 15)
    ];

    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.path = maskPath.CGPath;

    if (self.border) {
        // Shape already exist, update its frame
        self.border.frame = self.bounds;
        self.border.path = maskPath.CGPath;
        self.layer.mask = maskLayer;
        return;
    }

    self.border = [[CAShapeLayer alloc] init];
    self.border.frame = self.bounds;
    self.border.path = maskPath.CGPath;
    self.border.lineWidth   = 1.0f;
    self.border.strokeColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:0.7].CGColor;
    self.border.fillColor   = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.border];

    // Set the mask of the view.
    self.layer.mask = maskLayer;

}

- (void)setNumberOfSuggestions:(NSUInteger)count {
    int height = MIN(count * self.tableView.estimatedRowHeight, self.tableView.estimatedRowHeight * 4);
    [self setHeight:height];
    [self.tableView reloadData];
}

- (void)setHeight:(CGFloat)height {
    CGRect frame = self.frame;
    self.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, height);
    self.tableView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
}

@end
