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
#define CLIPBOARD [DOCUMENTS_FOLDER stringByAppendingPathComponent:@"clipboard.txt"]

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	// Recover the string
	if (!url) return NO;
    NSString *URLString = [url absoluteString];

	// Form of command will be: ipong:command?param1=p1&param2=p2&param3=p3&param4=p4&param5=p5
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
	
	// ipong:paste?scheme=iping&data=hello+world
	if ([[action uppercaseString] isEqualToString:@"PASTE"])
	{
		NSString *scheme = [paramDict objectForKey:@"scheme"];
		if (!scheme) return NO;
		
		NSString *data = [paramDict objectForKey:@"data"];
		if (!data) return NO;
		
		// write to disk
		[data writeToFile:CLIPBOARD atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		
		
		// pong back
		NSString *urlString = [NSString stringWithFormat:@"%@:pongpaste?success=YES&bytes=%d", scheme, [data length]];
		[self performSelector:@selector(doDebug:) withObject:[action stringByAppendingFormat:@"\n%@\n%@", [paramDict description], urlString] afterDelay:1.0f];
		[application openURL:[NSURL URLWithString:urlString]];

		// Never gets here
		return YES; 
	}
	
	// ipong:copy?scheme=iping
	if ([[action uppercaseString] isEqualToString:@"COPY"])
	{
		NSString *scheme = [paramDict objectForKey:@"scheme"];
		if (!scheme) return NO;

		NSString *data = [NSString stringWithContentsOfFile:CLIPBOARD];
		if (!data) data = @"";
		
		// pong back
		NSString *urlString = [NSString stringWithFormat:@"%@:pongcopy?success=YES&bytes=%d&data=%@", scheme, [data length], data];
		[application openURL:[NSURL URLWithString:urlString]];
		
		// Never gets here
		return YES;
	}
	
	// ipong:clear?scheme=iping
	if ([[action uppercaseString] isEqualToString:@"CLEAR"])
	{
		NSString *scheme = [paramDict objectForKey:@"scheme"];
		if (!scheme) return NO;
		
		// write to disk
		[@"" writeToFile:CLIPBOARD atomically:YES encoding:NSUTF8StringEncoding error:NULL];

		// pong back
		NSString *urlString = [NSString stringWithFormat:@"%@:pongclear?success=YES", scheme];
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
