import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Showaika Europe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CrossPlatformWebViewScreen(),
    );
  }
}

class CrossPlatformWebViewScreen extends StatefulWidget {
  const CrossPlatformWebViewScreen({super.key});

  @override
  State<CrossPlatformWebViewScreen> createState() => _CrossPlatformWebViewScreenState();
}

class _CrossPlatformWebViewScreenState extends State<CrossPlatformWebViewScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  double progress = 0;

  // Platform-specific user agents
  String get userAgent {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1 '
          'ShowaikaApp/1.0';
    } else {
      return 'Mozilla/5.0 (Linux; Android 10; Pixel 3 Build/QQ3A.200805.001; wv) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/86.0.4240.198 Mobile Safari/537.36 '
          'ShowaikaApp/1.0';
    }
  }

  @override
  void initState() {
    super.initState();
    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Theme.of(context).platform == TargetPlatform.iOS) {
          await webViewController?.loadUrl(
            urlRequest: URLRequest(url: await webViewController?.getUrl()));
        } else {
          await webViewController?.reload();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Showaika Europe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (Theme.of(context).platform == TargetPlatform.iOS) {
                await webViewController?.loadUrl(
                  urlRequest: URLRequest(url: await webViewController?.getUrl()));
              } else {
                await webViewController?.reload();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(
              url: WebUri('https://products01.showaikaeurope.com/'),
              headers: {
                'User-Agent': userAgent,
                'X-Requested-With': 'com.showaika.app',
              },
            ),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                userAgent: userAgent,
                applicationNameForUserAgent: 'Safari',
                mediaPlaybackRequiresUserGesture: false,
                cacheEnabled: true,
                transparentBackground: true,
              ),
              android: AndroidInAppWebViewOptions(
                useHybridComposition: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                builtInZoomControls: true,
                displayZoomControls: false,
              ),
              ios: IOSInAppWebViewOptions(
                allowsInlineMediaPlayback: true,
                allowsBackForwardNavigationGestures: true,
                allowsLinkPreview: false,
                isFraudulentWebsiteWarningEnabled: false,
              ),
            ),
            pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (controller) async {
              webViewController = controller;
              // Additional initialization after creation
              await controller.setOptions(
                options: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    userAgent: userAgent,
                  ),
                ),
              );
            },
            onLoadStart: (controller, url) {
              setState(() {
                progress = 0;
              });
            },
            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                pullToRefreshController?.endRefreshing();
              }
              setState(() {
                this.progress = progress / 100;
              });
            },
            onLoadStop: (controller, url) async {
              pullToRefreshController?.endRefreshing();
              await injectAntiWarningScript(controller);
            },
            onConsoleMessage: (controller, consoleMessage) {
              if (!consoleMessage.message.toLowerCase().contains('pwa') &&
                  !consoleMessage.message.toLowerCase().contains('serviceworker')) {
                debugPrint("WebView Console: ${consoleMessage.message}");
              }
            },
          ),
          progress < 1.0
              ? LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                )
              : Container(),
        ],
      ),
    );
  }

  Future<void> injectAntiWarningScript(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: '''
      // iOS-safe warning removal function
      function hideWarnings() {
        try {
          // Remove all known warning elements (iOS-safe querySelector)
          var selectors = [
            '.pwa-warning',
            '.browser-warning',
            '.unsupported-browser',
            '.pwa-not-supported',
            '.install-prompt',
            '.modal',
            '.modal-backdrop',
            '.browser-alert'
          ];
          
          for (var i = 0; i < selectors.length; i++) {
            var elements = document.querySelectorAll(selectors[i]);
            for (var j = 0; j < elements.length; j++) {
              elements[j].style.display = 'none';
              elements[j].parentNode.removeChild(elements[j]);
            }
          }
          
          // Enable scrolling (iOS-safe)
          document.body.style.overflow = 'auto';
          document.body.style.position = 'static';
          
          // iOS-safe browser detection override
          if (typeof navigator !== 'undefined') {
            try {
              Object.defineProperty(navigator, 'standalone', {
                value: true,
                configurable: false,
                writable: false
              });
            } catch(e) {}
            
            try {
              Object.defineProperty(navigator, 'userAgent', {
                value: '$userAgent',
                configurable: false,
                writable: false
              });
            } catch(e) {}
          }
          
          // Safari environment simulation for iOS
          if (window.webkit && window.webkit.messageHandlers) {
            window.chrome = {
              runtime: {
                id: 'ios.webview.simulation',
                onInstalled: { addListener: function() {} },
                onMessage: { addListener: function() {} },
                sendMessage: function() {}
              }
            };
          }
        } catch(e) {
          console.log('Warning suppression error:', e);
        }
      }
      
      // Run immediately
      hideWarnings();
      
      // iOS-safe MutationObserver
      try {
        var observer = new MutationObserver(hideWarnings);
        observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: ['style', 'class']
        });
      } catch(e) {}
      
      // Periodically check for warnings (iOS-safe)
      setInterval(hideWarnings, 1000);
    ''');
  }
}