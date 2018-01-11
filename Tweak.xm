#import <Contacts/Contacts.h>
#import "ContactsContainerView.h"
#import "UIImageView+Letters.h"
#import "Swish.h"


@interface UIImage (Resize)
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
@end

@implementation UIImage (Resize)

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
    return newImage;
}

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
    self.searchTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchTextField.delegate = self.textField.delegate;
    [self.searchTextField setDefaultTextAttributes:self.textField.defaultTextAttributes];
    [self.searchTextField addTarget:self.searchTextField.delegate 
                             action:@selector(textFieldDidChange:) 
                   forControlEvents:UIControlEventEditingChanged];
    [self addSubview:self.searchTextField];
    [[((PaymentsVC *)self.searchTextField.delegate) getKeybPanel] addTextField:self.searchTextField];
}

%new
- (UIView *)findSeparatorView {
    for (UIView *view in self.subviews) {
        if (view.frame.size.height == 1.0f) {
            return view;
        }
    }
    return nil;
}

%end



%hook PaymentsVC

%property (nonatomic, assign) NSMutableArray *contacts;
%property (nonatomic, assign) NSArray *suggestions;
%property (nonatomic, assign) ContactsContainerView *contactsContainerView;

- (void)viewDidLoad {
    %orig;

    [self loadContacts];
}

- (BOOL)canGoPrev {
    if ([self.payeeView.searchTextField isFirstResponder]) {
        return NO;
    }

    return %orig;
}

- (void)KbdNext:(id)button {
    if ([self.payeeView.searchTextField isFirstResponder]) {
        [self.amountView.textEdit becomeFirstResponder];
        return;
    }
    %orig;
}

- (void)KbdPrev:(id)button {
    if ([self.amountView.textEdit isFirstResponder] && !self.payeeView.searchTextField.hidden) {
        [self.payeeView.searchTextField becomeFirstResponder];
        return;
    }

    %orig;
}

/* Contacts */
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
- (void)parseContactWithContact:(CNContact *)contact {
    NSMutableDictionary *numbers = [NSMutableDictionary new];
    for (CNLabeledValue *label in contact.phoneNumbers) {
        NSString *digits = [label.value stringValue];
        if (digits.length > 0) {
            // Trim string
            digits = [[digits stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];

            // Only add valid numbers
            if ((([digits hasPrefix:@"070"] && digits.length == 10) || // mobile
                 ([digits hasPrefix:@"+46"] && digits.length == 12) || // mobile with country code
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
        NSMutableDictionary *dict = [NSMutableDictionary new];
        dict[@"firstName"] = contact.givenName;
        dict[@"lastName"] = contact.familyName;
        dict[@"number"] = number;
        dict[@"label"] = numbers[number];
        dict[@"imageData"] = contact.imageData;
        [self.contacts addObject:dict];
    }
}

/* Text detection */
- (void)textFieldDidBeginEditing:(UITextField *)textField {
    if (textField == self.payeeView.searchTextField) {
        self.payeeView.placeHolderLabel.hidden = YES;
        return;
    }
    %orig;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.payeeView.searchTextField && textField.text.length == 0) {
        self.payeeView.placeHolderLabel.hidden = NO;
        return;
    }
    %orig;
}

- (void)textFieldDidChange:(UITextField *)textField {
    if (textField == self.payeeView.searchTextField) {
        HBLogDebug(@"text: %@", textField.text);
        if (textField.text.length != 0) {
            // Search in contacts
            [self updateSuggestionsFromText:textField.text];
            if (self.suggestions.count == 0) {
                [self.contactsContainerView removeFromSuperview];
                return;
            }

            // Present table view
            if (!self.contactsContainerView) {
                UIView *separator = [self.payeeView findSeparatorView];

                CGRect frame = CGRectMake(separator.frame.origin.x,
                                          separator.frame.origin.y,
                                          separator.frame.size.width,
                                          0);
                self.contactsContainerView = [[ContactsContainerView alloc] initWithFrame:frame delegate:self];
            }

            [self.contactsContainerView setNumberOfSuggestions:self.suggestions.count];
            [self.scrollView addSubview:self.contactsContainerView];
        } else {
            [self.contactsContainerView removeFromSuperview];
        }
        return;
    }
    %orig;
}

%new
- (void)updateSuggestionsFromText:(NSString *)text {
    // Last name
    NSPredicate *predContains = [NSPredicate predicateWithFormat:@"lastName contains[c] %@", text];
    NSMutableArray *lastNameFilteredContains = [[self.contacts filteredArrayUsingPredicate:predContains] mutableCopy];

    NSPredicate *predBegins = [NSPredicate predicateWithFormat:@"lastName BEGINSWITH %@", text];
    NSArray *lastNamefilteredBegins = [self.contacts filteredArrayUsingPredicate:predBegins];

    [lastNameFilteredContains removeObjectsInArray:lastNamefilteredBegins];
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [lastNamefilteredBegins count])];
    [lastNameFilteredContains insertObjects:lastNamefilteredBegins atIndexes:indexes];

    // First name
    predContains = [NSPredicate predicateWithFormat:@"firstName contains[c] %@", text];
    NSMutableArray *firstNameFilteredContains = [[self.contacts filteredArrayUsingPredicate:predContains] mutableCopy];

    predBegins = [NSPredicate predicateWithFormat:@"firstName BEGINSWITH %@", text];
    NSArray *firstNameFilteredBegins = [self.contacts filteredArrayUsingPredicate:predBegins];

    [firstNameFilteredContains removeObjectsInArray:firstNameFilteredBegins];
    indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [firstNameFilteredBegins count])];
    [firstNameFilteredContains insertObjects:firstNameFilteredBegins atIndexes:indexes];

    // Concat first name and last name arrays
    [lastNameFilteredContains removeObjectsInArray:firstNameFilteredContains];
    indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [firstNameFilteredContains count])];
    [lastNameFilteredContains insertObjects:firstNameFilteredContains atIndexes:indexes];

    self.suggestions = lastNameFilteredContains;
}

/* Table View delegation methods */
%new
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Standard"];
    }

    NSDictionary *contact = self.suggestions[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", contact[@"firstName"], contact[@"lastName"]];
    if (contact[@"label"] != [NSNull null])
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@", contact[@"label"], contact[@"number"]];
    else
        cell.detailTextLabel.text = contact[@"number"];


    [cell.imageView setFrame:CGRectMake(0, 0, 35, 35)];
    if (contact[@"imageData"]) {
        UIImage *img = [UIImage imageWithData:contact[@"imageData"]];
        cell.imageView.image = [UIImage imageWithImage:img scaledToSize:cell.imageView.frame.size];
        cell.imageView.layer.cornerRadius = cell.imageView.frame.size.width / 2;
        cell.imageView.layer.masksToBounds = YES;
    } else {
        [cell.imageView setImageWithString:cell.textLabel.text color:nil circular:YES];
    }
    return cell;
}

%new
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *contact = self.suggestions[indexPath.row];
    self.payeeView.searchTextField.text = [NSString stringWithFormat:@"%@ %@", contact[@"firstName"], contact[@"lastName"]];
    self.payeeView.textField.text = contact[@"number"];
    self.payeeView.textField.hidden = NO;
    [self.contactsContainerView removeFromSuperview];
    self.payeeView.searchTextField.hidden = YES;

    [self.amountView.textEdit becomeFirstResponder];
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


// Allow app to ask permission for contacts
%hook NSBundle

- (id)infoDictionary {
    NSMutableDictionary *info = [%orig mutableCopy];
    info[@"NSContactsUsageDescription"] = @"Needed by BetterSwishSearch";
    return info;
}

%end
