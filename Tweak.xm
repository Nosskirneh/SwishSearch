#import <Contacts/Contacts.h>

@interface NumberPaymentElement : UIView
@property (nonatomic, readwrite, assign) UITextField *textField;
@property (nonatomic, assign) UITextField *searchTextField;
@property (nonatomic, readwrite, assign) UILabel *placeHolderLabel;
@end

%hook NumberPaymentElement

%property (nonatomic, assign) UITextField *searchTextField;

- (void)layoutSubviews {
    %orig;

    if (self.searchTextField) {
        return;
    }

    self.textField.hidden = YES;
    self.searchTextField = [[UITextField alloc] initWithFrame:self.textField.frame];
    self.searchTextField.delegate = self.textField.delegate;
    [self.searchTextField setDefaultTextAttributes:self.textField.defaultTextAttributes];
    [self.searchTextField addTarget:self.searchTextField.delegate 
                             action:@selector(textFieldDidChange:) 
                   forControlEvents:UIControlEventEditingChanged];
    [self addSubview:self.searchTextField];
}

%end

@interface PaymentsVC : UIViewController
@property (nonatomic, readwrite, assign) NumberPaymentElement *payeeView;
@property (nonatomic, assign) NSMutableArray *contacts;

- (void)loadContacts;
- (void)getAllContactsWithStore:(CNContactStore *)store;
- (NSDictionary *)parseContactWithContact:(CNContact *)contact;
@end


%hook PaymentsVC

%property (nonatomic, assign) NSMutableArray *contacts;

- (void)viewDidLoad {
    %orig;

    [self loadContacts];
}

%new
- (void)loadContacts {
    self.contacts = [NSMutableArray new];

    CNEntityType entityType = CNEntityTypeContacts;
    CNContactStore *store = [[CNContactStore alloc] init];
    if ([CNContactStore authorizationStatusForEntityType:entityType] == CNAuthorizationStatusNotDetermined) {
        [store requestAccessForEntityType:entityType completionHandler:^void(BOOL granted, NSError *_Nullable error) {
            if (granted){
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
            NSDictionary *dict = [self parseContactWithContact:contact];
            if (dict)
                [self.contacts addObject:dict];
        }
    }];
}

%new
- (NSDictionary *)parseContactWithContact:(CNContact *)contact {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"firstName"] = contact.givenName;
    dict[@"lastName"] = contact.familyName;

    NSMutableArray *numbers = [NSMutableArray new];
    for (CNLabeledValue *label in contact.phoneNumbers) {
        NSString *digits = [label.value stringValue];
        if (digits.length > 0) {
            // Trim string
            digits = [[digits stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];

            if ((([digits hasPrefix:@"070"] && digits.length == 10) || // mobile
                 ([digits hasPrefix:@"+46"] && digits.length == 12) || // mobile with country code
                 ([digits hasPrefix:@"123"] && digits.length == 10) || // Swish registered number
                 ([digits hasPrefix:@"90"] && digits.length == 7))) {  // Swish registered number
                [numbers addObject:digits];
            }
        }
    }
    if (numbers.count == 0) {
        return nil;
    }
    dict[@"numbers"] = numbers;
    return dict;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    %log;
    if (textField == self.payeeView.searchTextField) {
        self.payeeView.placeHolderLabel.hidden = YES;
        return;
    }
    %orig;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    %log;
    if (textField == self.payeeView.searchTextField && textField.text.length == 0) {
        self.payeeView.placeHolderLabel.hidden = NO;
        return;
    }
    %orig;
}


- (void)textFieldDidChange:(UITextField *)textField {
    %log;
    if (textField == self.payeeView.searchTextField) {
        HBLogDebug(@"text: %@", textField.text);
        return;
    }
    %orig;
}

%end


// Allow app to ask permission for contacts
%hook NSBundle

- (id)infoDictionary {
    NSMutableDictionary *info = [%orig mutableCopy];
    info[@"NSContactsUsageDescription"] = @"Needed by BetterSwishSearch";
    return info;
}

%end
