#import "SwishContactTableViewCell.h"
#import "UIImageView+Letters.h"

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

@implementation SwishContactTableViewCell

- (void)configureWithContact:(SwishContact *)contact {
    // Texts
    self.textLabel.text = [contact fullName];
    if (contact.label != (NSString *)[NSNull null])
        self.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@", contact.label, contact.number];
    else
        self.detailTextLabel.text = contact.number;

    // Image
    [self.imageView setFrame:CGRectMake(0, 0, 35, 35)];
    if (contact.imageData) {
        UIImage *img = [UIImage imageWithData:contact.imageData];
        self.imageView.image = [UIImage imageWithImage:img scaledToSize:self.imageView.frame.size];
        self.imageView.layer.cornerRadius = self.imageView.frame.size.width / 2;
        self.imageView.layer.masksToBounds = YES;
    } else {
        if (!contact.color)
            contact.color = [self.imageView randomColor];

        [self.imageView setImageWithString:self.textLabel.text color:contact.color circular:YES];
    }
}

@end
