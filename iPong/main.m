#import <UIKit/UIKit.h>

@interface TestBedController : UIViewController
@end

@implementation TestBedController
- (void) performAction
{
}

- (void)loadView
{
	UITextView *contentView = [[UITextView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	contentView.editable = NO;
	contentView.tag = 999;
	contentView.backgroundColor = [UIColor whiteColor];
	self.view = contentView;
    [contentView release];
}
@end


@interface TestBedAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation TestBedAppDelegate
- (void) doDebug: (NSString *) aString
{
	UITextView *tv = (UITextView *)[[[UIApplication sharedApplication] keyWindow] viewWithTag:999];
	[tv setText:aString];
}


#define DOCUMENTS_FOLDER [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
#define CLIPBOARD_PATH [DOCUMENTS_FOLDER stringByAppendingPathComponent:@"clipboard.txt"]

#define LEGAL	@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

- (BOOL) isValidParameterName: (NSString *) aName
{
	// Must be between 4 and 32 characters in length
	if ([aName length] < 4) return NO;
	if ([aName length] > 32) return NO;
	
    NSCharacterSet *cs = [[NSCharacterSet characterSetWithCharactersInString:LEGAL] invertedSet];
    NSString *filtered = [[aName componentsSeparatedByCharactersInSet:cs] componentsJoinedByString:@""];
    return [aName isEqualToString:filtered];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	// Recover the string
	if (!url) return NO;
    NSString *URLString = [url absoluteString];

	// Form of command will be: x-sadun-services:command?param1=p1&param2=p2&param3=p3&param4=p4&param5=p5
	NSRange colon = [URLString rangeOfString:@":"];
	if (colon.location == NSNotFound) return NO;
	
	// Extract command and parameter dictionary
	NSString *action = [URLString substringFromIndex:(colon.location + 1)];
	NSMutableDictionary *paramDict = [[[NSMutableDictionary alloc] init] autorelease];
	NSRange r = [action rangeOfString:@"?"];
	if (r.location != NSNotFound) 
	{
		NSString *paramString = [action substringFromIndex:(r.location + 1)];
		NSArray *parameters = [paramString componentsSeparatedByString:@"&"];
		action = [action substringToIndex:r.location];
		
		for (NSString *eachParam in parameters)
		{
			NSArray *pair = [eachParam componentsSeparatedByString:@"="];
			if ([pair count] != 2) continue;
			NSString *key = [[pair objectAtIndex:0] lowercaseString];
			NSString *value = [pair objectAtIndex:1];
			[paramDict setValue:value forKey:key];
		}
	}
		
	// wait for everything to catch up & print debug
	// [self performSelector:@selector(doDebug:) withObject:[action stringByAppendingFormat:@"\n%@", [paramDict description]] afterDelay:1.0f];
	
	NSString *scheme = [paramDict objectForKey:@"scheme"];
	if (!scheme) return NO;

	// Recover the key parameters
	NSString *clipboard = [paramDict objectForKey:@"clipboard"];
	NSString *password = [paramDict objectForKey:@"password"];
	NSString *expire = [paramDict objectForKey:@"expire"];
	
	// If parameters are provided, check for validity
	if (clipboard && (![self isValidParameterName:clipboard]))
	{
		// clipboard must conform to legal name
		NSString *urlString = [NSString stringWithFormat:@"%@:pasteservice?success=no&status=InvalidClipboardName", scheme];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}
	
	if (clipboard && password && (![self isValidParameterName:password]))
	{
		// password must conform to legal name
		NSString *urlString = [NSString stringWithFormat:@"%@:pasteservice?success=no&status=InvalidPassword", scheme];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}
	
	if (clipboard && expire && ([expire intValue] == 0))
	{
		// Expiration time in seconds must be a positive integer
		NSString *urlString = [NSString stringWithFormat:@"%@:pasteservice?success=no&status=InvalidExpiry", scheme];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}

	// Set up the key paths
	NSString *dataFilePath = CLIPBOARD_PATH;
	NSString *passwordPath = nil;
	NSString *expiryPath = nil;
	if (clipboard) dataFilePath =  [NSString stringWithFormat:@"%@/%@.txt", DOCUMENTS_FOLDER, clipboard];
	if (clipboard) passwordPath = [NSString stringWithFormat:@"%@/%@.password", DOCUMENTS_FOLDER, clipboard];
	if (clipboard) expiryPath =   [NSString stringWithFormat:@"%@/%@.expiration", DOCUMENTS_FOLDER, clipboard];

	// Recover any existing password for the clipboard
	NSString *pw = nil;
	if (clipboard) pw = [NSString stringWithContentsOfFile:passwordPath encoding:NSUTF8StringEncoding error:nil];
	
	// If a password is associated with the clipboard, compare it to anything that was sent along, whether or not one was supplied
	if (pw && ![pw isEqualToString:password])
	{
		// wrong password
		NSString *urlString = [NSString stringWithFormat:@"%@:copyservice?success=no&status=WrongPassword", scheme];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}
	
	// PASTE SERVICE
	// x-sadun-services:paste?scheme=iping&data=hello+world&clipboard=name&expire=3600
	if ([[action uppercaseString] isEqualToString:@"PASTE"])
	{
		
		NSString *data = [paramDict objectForKey:@"data"];
		if (!data) return NO;
		
				
		// write to disk
		[data writeToFile:dataFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
		
		// set expiry; only valid for custom clipboards
		if (clipboard && expire)
		{
			NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSDate dateWithTimeIntervalSinceNow:[expire intValue]] forKey:@"Expiration Date"];
			[dict writeToFile:expiryPath atomically:YES];
		}
		
		// set password; only valid for custom clipboards and will create the first time used. Use clear to remove passwords
		if (clipboard && password)
		{
			[password writeToFile:passwordPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
		}
		
		// pong back
		NSString *urlString = [NSString stringWithFormat:@"%@:pasteservice?success=yes&bytes=%d", scheme, [data length]];
		[self performSelector:@selector(doDebug:) withObject:[action stringByAppendingFormat:@"\n%@\n%@", [paramDict description], urlString] afterDelay:1.0f];
		[application openURL:[NSURL URLWithString:urlString]];

		// Never gets here
		return YES; 
	}
	
	// COPY SERVICE
	// x-sadun-services:copy?scheme=iping&clipboard=name
	if ([[action uppercaseString] isEqualToString:@"COPY"])
	{		
		if (clipboard)
		{
			NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:expiryPath];
			
			/* Removing this. Passwords are now ignored if there's none stored on the clipboard side.
			if (password && ![password isEqualToString:pw])
			{
				NSString *urlString = [NSString stringWithFormat:@"%@:copyservice?success=no&status=WrongPassword", scheme];
				[application openURL:[NSURL URLWithString:urlString]];
				return YES;
			}
			*/
						
			// Is there an expiration date?
			if (dict)
			{
				NSDate *expDate = [dict objectForKey:@"Expiration Date"];
				if ([[NSDate date] timeIntervalSinceDate:expDate] > 0)
				{
					// passed the expiry
					[[NSFileManager defaultManager] removeItemAtPath:dataFilePath error:nil];
					[[NSFileManager defaultManager] removeItemAtPath:expiryPath error:nil];
					[[NSFileManager defaultManager] removeItemAtPath:passwordPath error:nil];
					
					// To make the behavior consistent, expired copies return 0 bytes. Therefore the following expired behavior is removed.
					
					// NSString *urlString = [NSString stringWithFormat:@"%@:copyservice?success=no&status=Expired", scheme];
					// [application openURL:[NSURL URLWithString:urlString]];
					// Never gets here
					// return YES;
				}
			}
		}

		NSString *status = @"";
		NSString *data = [NSString stringWithContentsOfFile:dataFilePath];
		if (!data) 
		{
			data = @"";
			status = @"&status=ClipboardEmpty";
		}
		
		// pong back
		NSString *urlString = [NSString stringWithFormat:@"%@:copyservice?success=yes&bytes=%d&data=%@%@", scheme, [data length], data, status];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}
	
	// CLEAR SERVICE
	// x-sadun-services:clear?scheme=iping&clipboard=name
	if ([[action uppercaseString] isEqualToString:@"CLEAR"])
	{		
		/* Removing this. Passwords are now ignored if there's none stored on the clipboard side.
		 if (password && ![password isEqualToString:pw])
		 {
		 NSString *urlString = [NSString stringWithFormat:@"%@:copyservice?success=no&status=WrongPassword", scheme];
		 [application openURL:[NSURL URLWithString:urlString]];
		 return YES;
		 }
		 */
		
		[[NSFileManager defaultManager] removeItemAtPath:dataFilePath error:nil];

		if (clipboard)
		{
			[[NSFileManager defaultManager] removeItemAtPath:expiryPath error:nil];
			[[NSFileManager defaultManager] removeItemAtPath:passwordPath error:nil];
		}
		
		// pong back
		NSString *urlString = [NSString stringWithFormat:@"%@:clearservice?success=yes", scheme];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}
	
	// Shouldn't get here but may with ill-formed commands
	return YES;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {	
	UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UIViewController *vc = [[TestBedController alloc] init];
	[window addSubview:vc.view];
	[window makeKeyAndVisible];
}
@end

int main(int argc, char *argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	int retVal = UIApplicationMain(argc, argv, nil, @"TestBedAppDelegate");
	[pool release];
	return retVal;
}
