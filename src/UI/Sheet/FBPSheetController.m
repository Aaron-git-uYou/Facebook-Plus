// Content-sized bottom sheet: lays out the action rows and a separate Cancel
// card, and runs each action's handler after dismissal.

#import "FBPSheet.h"
#import "FBPResources.h"

static NSString *const kActionCell = @"fbp.action";
static NSString *const kCancelCell = @"fbp.cancel";

static const CGFloat kRowHeight    = 62.0;
static const CGFloat kCancelHeight = 56.0;
static const CGFloat kHeaderHeight = 44.0;

/// Row with the detail line above the title.
@interface FBPSheetCell : UITableViewCell
@property (nonatomic, strong) UIImageView *glyphView;
@property (nonatomic, strong) UILabel *detailLine;
@property (nonatomic, strong) UILabel *titleLine;
@end

@implementation FBPSheetCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = UIColor.clearColor;

        _glyphView = [[UIImageView alloc] init];
        _glyphView.contentMode = UIViewContentModeScaleAspectFit;
        _glyphView.tintColor = UIColor.labelColor;
        _glyphView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_glyphView];

        _detailLine = [[UILabel alloc] init];
        _detailLine.font = [UIFont systemFontOfSize:13];
        _detailLine.textColor = UIColor.secondaryLabelColor;
        _detailLine.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_detailLine];

        _titleLine = [[UILabel alloc] init];
        _titleLine.font = [UIFont systemFontOfSize:20 weight:UIFontWeightRegular];
        _titleLine.textColor = UIColor.labelColor;
        _titleLine.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleLine];

        UIView *selected = [[UIView alloc] init];
        selected.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.08];
        self.selectedBackgroundView = selected;

        [NSLayoutConstraint activateConstraints:@[
            [_glyphView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor
                                                     constant:16],
            [_glyphView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_glyphView.widthAnchor constraintEqualToConstant:26],
            [_glyphView.heightAnchor constraintEqualToConstant:26],

            [_detailLine.leadingAnchor constraintEqualToAnchor:_glyphView.trailingAnchor
                                                      constant:14],
            [_detailLine.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor
                                                       constant:-16],
            [_detailLine.topAnchor constraintEqualToAnchor:self.contentView.topAnchor
                                                  constant:10],

            [_titleLine.leadingAnchor constraintEqualToAnchor:_detailLine.leadingAnchor],
            [_titleLine.trailingAnchor constraintEqualToAnchor:_detailLine.trailingAnchor],
            [_titleLine.topAnchor constraintEqualToAnchor:_detailLine.bottomAnchor
                                                 constant:2],
        ]];
    }
    return self;
}

@end

@interface FBPSheetController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSArray<FBPSheetAction *> *actions;
@property (nonatomic, copy, nullable) NSString *sheetTitle;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation FBPSheetController

- (instancetype)initWithActions:(NSArray<FBPSheetAction *> *)actions
                          title:(NSString *)title {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _actions = [actions copy];
        _sheetTitle = [title copy];
    }
    return self;
}

- (CGFloat)preferredSheetHeight {
    CGFloat header = self.sheetTitle.length ? kHeaderHeight : 12.0;
    // actions card + spacing + cancel card + bottom safe area
    return header + (kRowHeight * self.actions.count) + 24.0 + kCancelHeight + 48.0;
}

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.clearColor;

    UIVisualEffectView *backdrop = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    backdrop.frame = self.view.bounds;
    backdrop.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:backdrop];
    [self.view sendSubviewToBack:backdrop];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                              style:UITableViewStyleInsetGrouped];
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.showsVerticalScrollIndicator = NO;
    _tableView.alwaysBounceVertical = NO;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [_tableView registerClass:FBPSheetCell.class forCellReuseIdentifier:kActionCell];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // actions, then Cancel in its own card
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)self.actions.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? self.sheetTitle : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? kRowHeight : kCancelHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:kCancelCell];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:kCancelCell];
            cell.backgroundColor = UIColor.clearColor;
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        }
        cell.textLabel.text = @"Cancel";
        cell.textLabel.textColor = UIColor.labelColor;
        return cell;
    }

    FBPSheetCell *cell = [tableView dequeueReusableCellWithIdentifier:kActionCell
                                                        forIndexPath:indexPath];
    FBPSheetAction *action = self.actions[indexPath.row];
    cell.titleLine.text = action.title;
    cell.detailLine.text = action.detail;
    cell.detailLine.hidden = (action.detail.length == 0);
    cell.glyphView.image = action.iconName
        ? [UIImage fbp_symbolNamed:action.iconName size:22]
        : nil;

    UIColor *tint = action.destructive ? UIColor.systemRedColor : UIColor.labelColor;
    cell.titleLine.textColor = tint;
    cell.glyphView.tintColor = tint;
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    dispatch_block_t handler = nil;
    if (indexPath.section == 0) handler = self.actions[indexPath.row].handler;

    // Run the handler after dismissal so anything it presents has a free stack.
    [self dismissViewControllerAnimated:YES completion:^{
        if (handler) handler();
    }];
}

@end
