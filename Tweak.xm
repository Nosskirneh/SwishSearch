#import <Contacts/Contacts.h>
#import "ContactsContainerView.h"
#import "Swish.h"
#import "SwishContact.h"
#import "SwishContactTableViewCell.h"


UIView *findLastSeparatorViewInView(UIView *view) {
    for (UIView *v in [view.subviews reverseObjectEnumerator]) {
        if (v.frame.size.height == 1.0f) {
            return v;
        }
    }
    return nil;
}

UITextField *createSearchTextField(UITextField *textField) {
    UITextField *searchTextField = [[UITextField alloc] initWithFrame:textField.frame];
    searchTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    searchTextField.delegate = textField.delegate;
    [searchTextField setDefaultTextAttributes:textField.defaultTextAttributes];
    [searchTextField addTarget:textField.delegate 
                        action:@selector(textFieldDidChange:) 
              forControlEvents:UIControlEventEditingChanged];
    return searchTextField;
}

NSArray *updateSuggestionsFromText(NSString *text) {
    NSMutableArray *contacts = ((CommerceAppDelegate *)[[UIApplication sharedApplication] delegate]).contacts;

    NSPredicate *predContains = [NSPredicate predicateWithFormat:@"fullName contains[c] %@", text];
    NSMutableArray *filteredContains = [[contacts filteredArrayUsingPredicate:predContains] mutableCopy];

    NSPredicate *predBegins = [NSPredicate predicateWithFormat:@"fullName BEGINSWITH %@", text];
    NSArray *filteredBegins = [contacts filteredArrayUsingPredicate:predBegins];

    [filteredContains removeObjectsInArray:filteredBegins];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [filteredBegins count])];
    [filteredContains insertObjects:filteredBegins atIndexes:indexes];

    return filteredContains;
}

/* Add keyboard switch to the keyboard panel */
%hook KeyboardPanel

%property (nonatomic, assign) UIButton *switchButton;
%property (nonatomic, assign) CGFloat keyboardHeight;

- (void)layoutSubviews {
    %orig;

    if ([self.delegate respondsToSelector:@selector(searchTextField)] &&
        !self.switchButton) {
        // Create button
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button addTarget:self.delegate
                   action:@selector(switchInput:)
         forControlEvents:UIControlEventTouchUpInside];
        button.titleLabel.font = [UIFont systemFontOfSize:12];
        button.backgroundColor = UIColor.grayColor;
        button.layer.cornerRadius = 8;
        button.clipsToBounds = YES;
        button.frame = CGRectMake(self.frame.size.width / 2 - 30 / 2,
                                  self.frame.size.height / 2 - 30 / 2,
                                  30.0,
                                  30.0);
        self.switchButton = button;
        [self addSubview:button];

        // Modify text / hidden state
        if ([[self.delegate searchTextField] isFirstResponder]) {
            [self.switchButton setTitle:@"123" forState:UIControlStateNormal];
            self.switchButton.hidden = NO;
        } else if ([[self.delegate standardTextField] isFirstResponder]) {
            [self.switchButton setTitle:@"ABC" forState:UIControlStateNormal];
            self.switchButton.hidden = NO;
        } else {
            self.switchButton.hidden = YES;   
        }
    }
}

- (void)keyboardShown:(id)notification {
    %orig;

    NSDictionary *keyboardInfo = [notification userInfo];
    NSValue *keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameBeginUserInfoKey];
    self.keyboardHeight = [keyboardFrameBegin CGRectValue].size.height;
}

%end

/* Add the search text fields */
// Add new favorite
%hook AddFavoriteViewController

%property (nonatomic, assign) NSArray *suggestions;
%property (nonatomic, assign) UITextField *searchTextField;
%property (nonatomic, assign) UITextField *previousSelectedTextField;
%property (nonatomic, assign) ContactsContainerView *contactsContainerView;

- (void)viewDidLayoutSubviews {
    %orig;

    [(CommerceAppDelegate *)[[UIApplication sharedApplication] delegate] loadContactsIfNecessary];

    if (self.searchTextField)
        return;

    self.searchTextField = createSearchTextField(self.phoneNumberTextField);
    [self.scrollView addSubview:self.searchTextField];
    [[self getKeybPanel] addTextField:self.searchTextField];

    self.phoneNumberTextField.hidden = YES;
}

// Manually fetching a contact (the old way)
- (void)ContactPickerEnded:(BOOL)ended withNumber:(NSString *)number withName:(NSString *)name {
    %orig;

    self.searchTextField.text = name;
    self.searchTextField.hidden = YES;
    self.phoneNumberTextField.hidden = NO;
}

%new
- (void)switchInput:(UIButton *)sender {
    if ([self.searchTextField isFirstResponder]) {
        [self.phoneNumberTextField becomeFirstResponder];
        self.searchTextField.hidden = YES;
        self.phoneNumberTextField.hidden = NO;
    } else {
        [self.searchTextField becomeFirstResponder];
        self.searchTextField.hidden = NO;
        self.phoneNumberTextField.hidden = YES;
    }
}

%new
- (UITextField *)standardTextField {
    return self.phoneNumberTextField;
}

// Keyboard delegation methods
- (BOOL)canGoPrev {
    if ([self.searchTextField isFirstResponder] ||
        [self.phoneNumberTextField isFirstResponder]) {
        return YES;
    }

    return %orig;
}

- (BOOL)canGoNext {
    if ([self.searchTextField isFirstResponder] ||
        [self.phoneNumberTextField isFirstResponder]) {
        return NO;
    }

    return %orig;
}

- (void)KbdPrev:(id)button {
    [self.nameTextField becomeFirstResponder];
}

- (void)KbdNext:(id)button {
    if (self.searchTextField.hidden) {
        [self.phoneNumberTextField becomeFirstResponder];
    } else {
        [self.searchTextField becomeFirstResponder];
    }
}

/* Text detection */
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    %log;
    if (textField == self.searchTextField) {
        [[self getKeybPanel].switchButton setTitle:@"123" forState:UIControlStateNormal];
        [self updateNumberTextField:textField];
        return;
    } else if (textField == self.phoneNumberTextField) {
        [[self getKeybPanel].switchButton setTitle:@"ABC" forState:UIControlStateNormal];
        [self updateNumberTextField:textField];
        return;
    } else {
        if ((self.previousSelectedTextField == self.searchTextField ||
             self.previousSelectedTextField == self.phoneNumberTextField) &&
            ![self.previousSelectedTextField hasText]) {
            [%c(JumpingLabels) performShowPlaceholderAnimationWithField:self.previousSelectedTextField
                                                       placeholderLabel:self.phoneNumberPlaceholder
                                                             titleLabel:self.phoneNumberTitle
                                                             completion:nil];
        }
        [self getKeybPanel].switchButton.hidden = YES;
    }

    %orig;
}

%new
- (void)updateNumberTextField:(UITextField *)textField {
    [self getKeybPanel].switchButton.hidden = NO;
    [[self getKeybPanel] updateNextPrevButtons];
    self.phoneNumberPlaceholder.hidden = YES;
    if (self.previousSelectedTextField != self.phoneNumberTextField &&
        self.previousSelectedTextField != self.searchTextField &&
        (self.phoneNumberTitle.alpha == 0 || self.phoneNumberTitle.hidden))
        [%c(JumpingLabels) performDidBeginEditingAnimationWithField:textField
                                                   placeholderLabel:self.phoneNumberPlaceholder
                                                         titleLabel:self.phoneNumberTitle
                                                         completion:nil];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.previousSelectedTextField = textField;

    // We're doing stuff manually in the next textFieldDidBegin instead
    if (textField == self.searchTextField || textField == self.phoneNumberTextField) {
        [self.contactsContainerView removeFromSuperview];
        return;
    }

    %orig;
}

// Search for matching contacts
- (void)textFieldDidChange:(UITextField *)textField {
    %log;
    if (textField == self.searchTextField) {
        if ([textField hasText]) {
            // Search in contacts
            self.suggestions = updateSuggestionsFromText(textField.text);
            if (self.suggestions.count == 0) {
                [self.contactsContainerView removeFromSuperview];
                return;
            }

            // Present table view
            if (!self.contactsContainerView) {
                UIView *separator = findLastSeparatorViewInView(self.contentView);

                CGRect frame = CGRectMake(separator.frame.origin.x,
                                          separator.frame.origin.y,
                                          separator.frame.size.width,
                                          0);
                self.contactsContainerView = [[ContactsContainerView alloc] initWithFrame:frame delegate:self];
            }

            float maxHeight = self.scrollView.frame.size.height - [self getKeybPanel].keyboardHeight - self.contactsContainerView.frame.origin.y;
            [self.contactsContainerView setNumberOfSuggestions:self.suggestions.count maxHeight:maxHeight];
            [self.scrollView addSubview:self.contactsContainerView];
        } else {
            [self.contactsContainerView removeFromSuperview];
        }
        return;
    } else {
        [[self getKeybPanel].doneBtn setEnabled:([self.nameTextField hasText] &&
                                                 !self.phoneNumberTextField.hidden &&
                                                 [self.phoneNumberTextField hasText])];
    }
}

/* Table View delegation methods */
%new
- (SwishContactTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";

    SwishContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[SwishContactTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    SwishContact *contact = self.suggestions[indexPath.row];
    [cell configureWithContact:contact];

    return cell;
}

%new
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SwishContact *contact = self.suggestions[indexPath.row];
    self.searchTextField.text = [NSString stringWithFormat:@"%@ %@", contact.firstName, contact.lastName];
    self.phoneNumberTextField.text = contact.number;
    self.phoneNumberTextField.hidden = NO;
    [self.contactsContainerView removeFromSuperview];
    self.searchTextField.hidden = YES;

    [self.phoneNumberTextField becomeFirstResponder];

    [[self getKeybPanel].doneBtn setEnabled:([self.nameTextField hasText] &&
                                             !self.phoneNumberTextField.hidden &&
                                             [self.phoneNumberTextField hasText])];
}

%new
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.suggestions.count;
}

%new
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return tableView.estimatedRowHeight;
}

%end


// Normal payment
%hook NumberPaymentElement

%property (nonatomic, assign) UITextField *searchTextField;

- (void)layoutSubviews {
    %orig;

    if (self.searchTextField) {
        return;
    }

    self.searchTextField = createSearchTextField(self.textField);
    [[((PaymentsVC *)self.searchTextField.delegate) getKeybPanel] addTextField:self.searchTextField];
    [self addSubview:self.searchTextField];

    if (![self.textField hasText]) {
        self.textField.hidden = YES;
    } else {
        self.searchTextField.hidden = YES;
    }
}

%end


%hook PaymentsVC

%property (nonatomic, assign) NSArray *suggestions;
%property (nonatomic, assign) ContactsContainerView *contactsContainerView;
%property (nonatomic, assign) UITextField *previousSelectedTextField;

// Only load contacts if we're going to make a payment
- (void)viewDidLoad {
    %orig;

    [(CommerceAppDelegate *)[[UIApplication sharedApplication] delegate] loadContactsIfNecessary];
}

%new
- (UITextField *)searchTextField {
    return self.payeeView.searchTextField;
}

%new
- (UITextField *)standardTextField {
    return self.payeeView.textField;
}

// Keyboard delegation methods
- (BOOL)canGoPrev {
    if ([self.payeeView.searchTextField isFirstResponder] ||
        [self.payeeView.textField isFirstResponder]) {
        return NO;
    }

    return %orig;
}

- (BOOL)canGoNext {
    if ([self.payeeView.searchTextField isFirstResponder] ||
        [self.payeeView.textField isFirstResponder]) {
        return YES;
    }

    return %orig;
}

- (void)KbdNext:(id)button {
    if ([self.payeeView.searchTextField isFirstResponder] ||
        [self.payeeView.textField isFirstResponder]) {
        [self.amountView.textEdit becomeFirstResponder];
        return;
    }

    %orig;
}

- (void)KbdPrev:(id)button {
    if ([self.amountView.textEdit isFirstResponder] && !self.payeeView.searchTextField.hidden) {
        [self.payeeView.searchTextField becomeFirstResponder];
        [self ScrollTo:self.payeeView.searchTextField];
        return;
    }

    %orig;
}

// Manually fetching a contact (the old way)
- (void)ContactPickerEnded:(BOOL)ended withNumber:(NSString *)number withName:(NSString *)name {
    %orig;

    // Hidden states will be changed in layoutSubviews of the payeeView
    self.payeeView.searchTextField.text = name;
}

// Choosing a contact from the favorite list
- (void)favoriteButtonAction:(id)favorite {
    %orig;

    self.payeeView.searchTextField.hidden = YES;
    self.payeeView.textField.hidden = NO;
    [self.payeeView.textField becomeFirstResponder];
}

%new
- (void)switchInput:(UIButton *)sender {
    if ([self.payeeView.searchTextField isFirstResponder]) {
        [self.payeeView.textField becomeFirstResponder];
        self.payeeView.searchTextField.hidden = YES;
        self.payeeView.textField.hidden = NO;
    } else {
        [self.payeeView.searchTextField becomeFirstResponder];
        self.payeeView.searchTextField.hidden = NO;
        self.payeeView.textField.hidden = YES;
    }
}

/* Text detection */
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == self.payeeView.searchTextField) {
        [[self getKeybPanel].switchButton setTitle:@"123" forState:UIControlStateNormal];
        [self updatePaymentTextField:textField];
        return;
    } else if (textField == self.payeeView.textField) {
        [[self getKeybPanel].switchButton setTitle:@"ABC" forState:UIControlStateNormal];
        [self updatePaymentTextField:textField];
        return;
    } else {
        if ((self.previousSelectedTextField == self.payeeView.searchTextField ||
            self.previousSelectedTextField == self.payeeView.textField) &&
            ![self.previousSelectedTextField hasText]) {
            [%c(JumpingLabels) performShowPlaceholderAnimationWithField:self.previousSelectedTextField
                                                       placeholderLabel:self.payeeView.placeHolderLabel
                                                             titleLabel:self.payeeView.titleLabel
                                                             completion:nil];
        }
        [self getKeybPanel].switchButton.hidden = YES;
    }

    %orig;
}

%new
- (void)updatePaymentTextField:(UITextField *)textField {
    [self getKeybPanel].switchButton.hidden = NO;
    [[self getKeybPanel] updateNextPrevButtons];
    self.payeeView.placeHolderLabel.hidden = YES;
    if (self.previousSelectedTextField != self.payeeView.textField &&
        self.previousSelectedTextField != self.payeeView.searchTextField &&
        (self.payeeView.titleLabel.alpha == 0 || self.payeeView.titleLabel.hidden))
        [%c(JumpingLabels) performDidBeginEditingAnimationWithField:textField
                                                   placeholderLabel:self.payeeView.placeHolderLabel
                                                         titleLabel:self.payeeView.titleLabel
                                                         completion:nil];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.previousSelectedTextField = textField;

    // We're doing stuff manually in the next textFieldDidBegin instead
    if (textField == self.payeeView.searchTextField || textField == self.payeeView.textField) {
        [self.contactsContainerView removeFromSuperview];
        return;
    }

    %orig;
}

// Search for matching contacts. Also overriding this method completely,
// otherwise it will unhide the number placeholder label
- (void)textFieldDidChange:(UITextField *)textField {
    if (textField == self.payeeView.searchTextField) {
        if ([textField hasText]) {
            // Search in contacts
            self.suggestions = updateSuggestionsFromText(textField.text);
            if (self.suggestions.count == 0) {
                [self.contactsContainerView removeFromSuperview];
                return;
            }

            // Present table view
            if (!self.contactsContainerView) {
                UIView *separator = findLastSeparatorViewInView(self.payeeView);

                CGRect frame = CGRectMake(separator.frame.origin.x,
                                          separator.frame.origin.y,
                                          separator.frame.size.width,
                                          0);
                self.contactsContainerView = [[ContactsContainerView alloc] initWithFrame:frame delegate:self];
            }

            float maxHeight = self.scrollView.frame.size.height - [self getKeybPanel].keyboardHeight - self.contactsContainerView.frame.origin.y;
            [self.contactsContainerView setNumberOfSuggestions:self.suggestions.count maxHeight:maxHeight];
            [self.scrollView addSubview:self.contactsContainerView];
        } else {
            [self.contactsContainerView removeFromSuperview];
        }
        return;
    } else {
        [[self getKeybPanel].doneBtn setEnabled:([self.amountView.textEdit hasText] &&
                                                 !self.payeeView.textField.hidden &&
                                                 [self.payeeView.textField hasText])];
    }
}

// Hide the switch button when selecting the message text view
- (void)textViewDidBeginEditing:(UITextField *)textView {
    [self getKeybPanel].switchButton.hidden = YES;

    if (![self.previousSelectedTextField hasText]) {
        self.payeeView.placeHolderLabel.hidden = NO;
    }

    %orig;
}

// Do not unhide the placeholder label when going back from the message view
- (void)textViewDidEndEditing:(UITextField *)textView {
    if (textView.text.length == 0) {
        self.messageView.placeHolderLabel.hidden = NO;
    }
}

// Prevent number placeholder label from being unhidden
- (void)textViewDidChange:(UITextField *)textView {
    return;
}

/* Table View delegation methods */
%new
- (SwishContactTableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";

    SwishContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[SwishContactTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    SwishContact *contact = self.suggestions[indexPath.row];
    [cell configureWithContact:contact];

    return cell;
}

%new
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    SwishContact *contact = self.suggestions[indexPath.row];
    self.payeeView.searchTextField.text = [NSString stringWithFormat:@"%@ %@", contact.firstName, contact.lastName];
    self.payeeView.textField.text = contact.number;
    self.payeeView.textField.hidden = NO;
    [self.contactsContainerView removeFromSuperview];
    self.payeeView.searchTextField.hidden = YES;

    [self.amountView.textEdit becomeFirstResponder];

    [[self getKeybPanel].doneBtn setEnabled:([self.amountView.textEdit hasText] &&
                                             !self.payeeView.textField.hidden &&
                                             [self.payeeView.textField hasText])];
}

%new
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.suggestions.count;
}

%new
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return tableView.estimatedRowHeight;
}

%end

/* Contacts */
// Only load contacts once
%hook CommerceAppDelegate

%property (nonatomic, assign) NSMutableArray *contacts;

%new
- (void)loadContactsIfNecessary {
    if (self.contacts)
        return;

    [self loadContacts];
}

%new
- (void)loadContacts {
    self.contacts = [NSMutableArray new];

    CNEntityType entityType = CNEntityTypeContacts;
    CNContactStore *store = [[CNContactStore alloc] init];
    if ([CNContactStore authorizationStatusForEntityType:entityType] == CNAuthorizationStatusNotDetermined) {
        [store requestAccessForEntityType:entityType completionHandler:^void(BOOL granted, NSError *_Nullable error) {
            if (granted) {
                [self getAllContactsWithStore:store];
            }
        }];
    } else if ([CNContactStore authorizationStatusForEntityType:entityType] == CNAuthorizationStatusAuthorized) {
        [self getAllContactsWithStore:store];
    }
}

%new
- (void)getAllContactsWithStore:(CNContactStore *)store {
    NSArray *keys = @[CNContactFamilyNameKey, CNContactGivenNameKey, CNContactPhoneNumbersKey, CNContactImageDataKey];
    CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keys];
    NSError *error;
    [store enumerateContactsWithFetchRequest:request error:&error usingBlock:^(CNContact *__nonnull contact, BOOL *__nonnull stop) {
        if (error) {
            HBLogError(@"error fetching contacts %@", error);
        } else {
            [self parseContactWithContact:contact];
        }
    }];
}

%new
- (void)parseContactWithContact:(CNContact *)_contact {
    NSMutableDictionary *numbers = [NSMutableDictionary new];
    for (CNLabeledValue *label in _contact.phoneNumbers) {
        NSString *digits = [label.value stringValue];
        if (digits.length > 0) {
            // Trim string
            digits = [[[digits stringByReplacingOccurrencesOfString:@"-" withString:@""]
                               stringByReplacingOccurrencesOfString:@" " withString:@""]
                               stringByReplacingOccurrencesOfString:@" " withString:@""]; // Another type of space

            // Only add valid numbers
            if ((([digits hasPrefix:@"07"] && digits.length == 10) || // mobile
                 ([digits hasPrefix:@"+467"] && digits.length == 12) || // mobile with country code
                 ([digits hasPrefix:@"123"] && digits.length == 10) || // Swish registered number
                 ([digits hasPrefix:@"90"] && digits.length == 7))) {  // Swish registered number
                NSString *tag = [label localizedLabel];
                numbers[digits] = tag ? tag : [NSNull null];
            }
        }
    }
    if (numbers.count == 0)
        return;

    for (NSString *number in numbers) {
        SwishContact *contact = [[SwishContact alloc] init];
        contact.firstName = _contact.givenName;
        contact.lastName = _contact.familyName;
        contact.number = number;
        contact.label = numbers[number];
        contact.imageData = _contact.imageData;
        [self.contacts addObject:contact];
    }
}

%end


// Allow app to ask permission for contacts
%hook NSBundle

- (id)infoDictionary {
    NSMutableDictionary *info = [%orig mutableCopy];
    info[@"NSContactsUsageDescription"] = @"Needed by SwishSearch";
    return info;
}

%end
