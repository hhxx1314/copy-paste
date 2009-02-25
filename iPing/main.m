#import <UIKit/UIKit.h>

// If you're interested in peeking:
// cd ~/Library/Application\ Support/iPhone\ Simulator/User/Applications
// cat */iPong.app/../Documents/clipboard.txt

@interface TestBedController : UIViewController
@end

#define START_KEY	@"Start Time"

@implementation TestBedController
- (void) paste
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:START_KEY];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	NSString *s = [(UITextView *)self.view text];
	NSString *escapedString = [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,  (CFStringRef)s, NULL,  CFSTR("?=&amp;+"), kCFStringEncodingUTF8) autorelease];
	NSString *urlString = [NSString stringWithFormat:@"ipong:paste?scheme=iping&data=%@", escapedString];
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
}

- (void) copy
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:START_KEY];
	[[NSUserDefaults standardUserDefaults] synchronize];

	NSString *urlString = @"ipong:copy?scheme=iping";
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
}

- (void)loadView
{
	UITextView *contentView = [[UITextView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	contentView.tag = 999;
	self.view = contentView;
	contentView.backgroundColor = [UIColor whiteColor];
    [contentView release];
	
	
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
											   initWithTitle:@"Copy" 
											   style:UIBarButtonItemStylePlain 
											   target:self 
											   action:@selector(copy)] autorelease];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
											   initWithTitle:@"Paste" 
											   style:UIBarButtonItemStylePlain 
											   target:self 
											   action:@selector(paste)] autorelease];
}
@end


@interface TestBedAppDelegate : NSObject <UIApplicationDelegate>
@end

@implementation TestBedAppDelegate
- (void) doDebug: (NSString *) aString
{
	UITextView *tv = (UITextView *)[[[UIApplication sharedApplication] keyWindow] viewWithTag:999];
	
	NSDate *date = [[NSUserDefaults standardUserDefaults] objectForKey:START_KEY];
	NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:date];
	
	NSRange colon = [aString rangeOfString:@":"];
	NSString *action = [aString substringFromIndex:(colon.location + 1)];
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
			NSString *key = [pair objectAtIndex:0];
			NSString *value = [pair objectAtIndex:1];
			if ([key isEqualToString:@"data"]) [paramDict setValue:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:key];
			else [paramDict setValue:value forKey:key];
		}
	}
	
	[tv setText:[NSString stringWithFormat:@"Time: %0.3f seconds\n %@\n %@", ti, aString, [paramDict description]]];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	if (!url) {  return NO; }
	
	// Recover the string
    NSString *URLString = [url absoluteString];
	
	[self performSelector:@selector(doDebug:) withObject:URLString afterDelay:0.5f];
		
	return YES;
}	

- (void)applicationDidFinishLaunching:(UIApplication *)application {	
	UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[TestBedController alloc] init]];
	[window addSubview:nav.view];
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
