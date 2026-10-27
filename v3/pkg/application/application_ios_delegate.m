//go:build ios && !server
#import "application_ios_delegate.h"
#import "../events/events_ios.h"
#import "application_ios.h"
extern void processApplicationEvent(unsigned int, void* data);
extern void processWindowEvent(unsigned int, unsigned int);
extern bool hasListeners(unsigned int);
extern void iosApplicationDidLaunch(void);
// WailsIOSMain (app's generated main_ios.go) runs the user's main()/app.Run().
// The delegate starts it AFTER UIKit has launched (see below).
extern void WailsIOSMain(void);
// Registers the UNUserNotificationCenter delegate so local notifications are
// shown while the app is in the foreground (and taps are handled). Apple
// requires this be set before launch finishes, hence the call below.
extern void ios_notifications_init(void);

@implementation WailsAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    appDelegate = self;
    self.viewControllers = [NSMutableArray array];
    // Notification registration must happen before application launch completes.
    ios_notifications_init();
    // Existing apps without a scene manifest keep the legacy launch path.
    // Scene-enabled apps start Go only after their UIWindowScene is connected.
    if (![NSBundle mainBundle].infoDictionary[@"UIApplicationSceneManifest"]) {
        [self connectWindow:nil];
    }
    return YES;
}

- (void)connectWindow:(UIWindowScene *)scene {
    // Set global appDelegate reference and bring up a window if needed
    if (self.window == nil) {
        // Start the window with the launch-screen colour (a "LaunchBackground"
        // colour asset, also referenced by UILaunchScreen) so there's no white
        // flash between the launch screen and the first WebView paint. The Go
        // options set the colour too, but that happens after this delegate runs,
        // so it can't colour the initial window. Falls back to white if the
        // asset isn't present.
        UIColor *launchBG = [UIColor colorNamed:@"LaunchBackground"] ?: [UIColor whiteColor];
        self.window = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                            : [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
        self.window.backgroundColor = launchBG;
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = launchBG;
        self.window.rootViewController = rootVC;
        [self.window makeKeyAndVisible];
    }
    // Apply app-wide background colour if configured
    unsigned char r = 255, g = 255, b = 255, a = 255;
    if (ios_get_app_background_color(&r, &g, &b, &a)) {
        CGFloat fr = ((CGFloat)r) / 255.0;
        CGFloat fg = ((CGFloat)g) / 255.0;
        CGFloat fb = ((CGFloat)b) / 255.0;
        CGFloat fa = ((CGFloat)a) / 255.0;
        UIColor *color = [UIColor colorWithRed:fr green:fg blue:fb alpha:fa];
        self.window.backgroundColor = color;
        self.window.rootViewController.view.backgroundColor = color;
    }
    // Retain the existing root controller if UIKit reconnects the scene.
    if (scene && self.window.windowScene != scene) {
        self.window.windowScene = scene;
    }
    [self.window makeKeyAndVisible];
    // Scene reconnection must never start a second Go application.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            WailsIOSMain();
        });
    });
}
// GENERATED EVENTS START
- (void)applicationDidBecomeActive:(UIApplication *)application {
    if( hasListeners(EventApplicationDidBecomeActive) ) {
        processApplicationEvent(EventApplicationDidBecomeActive, NULL);
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if( hasListeners(EventApplicationDidEnterBackground) ) {
        processApplicationEvent(EventApplicationDidEnterBackground, NULL);
    }
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    if( hasListeners(EventApplicationDidFinishLaunching) ) {
        processApplicationEvent(EventApplicationDidFinishLaunching, NULL);
    }
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    if( hasListeners(EventApplicationDidReceiveMemoryWarning) ) {
        processApplicationEvent(EventApplicationDidReceiveMemoryWarning, NULL);
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    if( hasListeners(EventApplicationWillEnterForeground) ) {
        processApplicationEvent(EventApplicationWillEnterForeground, NULL);
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    if( hasListeners(EventApplicationWillResignActive) ) {
        processApplicationEvent(EventApplicationWillResignActive, NULL);
    }
}

- (void)applicationWillTerminate:(UIApplication *)application {
    if( hasListeners(EventApplicationWillTerminate) ) {
        processApplicationEvent(EventApplicationWillTerminate, NULL);
    }
}

// GENERATED EVENTS END
@end

// Wails currently owns one native window. Multiple scenes are disabled in the
// manifest; keep the app delegate's window reference for existing native APIs.
@implementation WailsSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;
    WailsAppDelegate *delegate = (WailsAppDelegate *)UIApplication.sharedApplication.delegate;
    [delegate connectWindow:(UIWindowScene *)scene];
    self.window = delegate.window;
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    [appDelegate applicationDidBecomeActive:UIApplication.sharedApplication];
}

- (void)sceneWillResignActive:(UIScene *)scene {
    [appDelegate applicationWillResignActive:UIApplication.sharedApplication];
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    [appDelegate applicationDidEnterBackground:UIApplication.sharedApplication];
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    [appDelegate applicationWillEnterForeground:UIApplication.sharedApplication];
}
@end
