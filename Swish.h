@interface NumberPaymentElement : UIView
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

@interface KeyboardPanel : UIView
@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) UIButton *switchButton;
- (void)addTextField:(UITextField *)textField;
@end

@interface PaymentsVC : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, readwrite, assign) UIScrollView *scrollView;
@property (nonatomic, readwrite, assign) NumberPaymentElement *payeeView;
@property (nonatomic, readwrite, assign) AmountPaymentElement *amountView;
@property (nonatomic, assign) NSMutableArray *contacts;
@property (nonatomic, assign) NSArray *suggestions;
@property (nonatomic, assign) ContactsContainerView *contactsContainerView;
- (KeyboardPanel *)getKeybPanel;

- (void)loadContacts;
- (void)getAllContactsWithStore:(CNContactStore *)store;
- (void)parseContactWithContact:(CNContact *)contact;
- (void)updateSuggestionsFromText:(NSString *)text;
@end


/* Contacts framework */
@interface CNLabeledValue (Missing)
- (NSString *)localizedLabel;
@end
