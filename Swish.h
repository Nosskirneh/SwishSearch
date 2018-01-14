@interface CommerceAppDelegate : NSObject
@property (nonatomic, assign) NSMutableArray *contacts;
- (void)loadContactsIfNecessary;
- (void)loadContacts;
- (void)getAllContactsWithStore:(CNContactStore *)store;
- (void)parseContactWithContact:(CNContact *)contact;
@end

@interface NumberPaymentElement : UIView
@property (nonatomic, assign) UILabel *titleLabel;
@property (nonatomic, readwrite, assign) UITextField *textField;
@property (nonatomic, assign) UITextField *searchTextField;
@property (nonatomic, readwrite, assign) UILabel *placeHolderLabel;
@property (nonatomic, readwrite, assign) UIButton *addButton;
@property (nonatomic, readwrite, assign) UIScrollView *scrollView;
- (UIView *)findSeparatorView;
@end

@interface AmountPaymentElement : UIView
@property (nonatomic, readwrite, assign) UITextField *textEdit;
@end

@interface MessagePaymentElement : UIView
@property (nonatomic, readwrite, assign) UILabel *placeHolderLabel;
@end

@interface KeyboardPanel : UIView
@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) UIButton *switchButton;
@property (nonatomic, assign) UIButton *doneBtn;
- (void)addTextField:(UITextField *)textField;
- (void)updateNextPrevButtons;
@end

@interface PaymentsVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, readwrite, assign) UIScrollView *scrollView;
@property (nonatomic, readwrite, assign) NumberPaymentElement *payeeView;
@property (nonatomic, readwrite, assign) AmountPaymentElement *amountView;
@property (nonatomic, readwrite, assign) MessagePaymentElement *messageView;
@property (nonatomic, assign) NSArray *suggestions;
@property (nonatomic, assign) ContactsContainerView *contactsContainerView;
@property (nonatomic, assign) UITextField *previousSelectedTextField;
- (KeyboardPanel *)getKeybPanel;
- (void)updateSuggestionsFromText:(NSString *)text;
- (void)updatePaymentTextField:(UITextField *)textField;
- (void)ScrollTo:(id)arg;
@end

@interface JumpingLabels : NSObject

+ (void)performDidBeginEditingAnimationWithField:(UITextField *)textField
                                placeholderLabel:(UILabel *)placeholderLabel
                                      titleLabel:(UILabel *)titleLabel
                                      completion:(id)block;
+ (void)performShowPlaceholderAnimationWithField:(UITextField *)textField
                                placeholderLabel:(UILabel *)placeholderLabel
                                      titleLabel:(UILabel *)titleLabel
                                      completion:(id)block;

@end


/* Contacts framework */
@interface CNLabeledValue (Missing)
- (NSString *)localizedLabel;
@end
