import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_config.dart';
import 'offline_screen.dart';

const String _lastUrlKey = 'last_url';
const String _fcmRouteKey = 'fcm_route';

Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  runApp(const WrapperApp());
}

class WrapperApp extends StatelessWidget {
  const WrapperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Wrapper',
      theme: ThemeData(useMaterial3: true),
      home: const WebWrapperScreen(),
    );
  }
}

class WebWrapperScreen extends StatefulWidget {
  const WebWrapperScreen({super.key});

  @override
  State<WebWrapperScreen> createState() => _WebWrapperScreenState();
}

class _WebWrapperScreenState extends State<WebWrapperScreen> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late final WebViewController _controller;
  bool _isOffline = false;
  String _pendingRoute = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _handleNavigationRequest,
          onPageFinished: _onPageFinished,
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _handleJsMessage,
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _restoreSession();
    _listenConnectivity();
    _listenDeepLinks();
    _listenFcmMessages();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUrl = prefs.getString(_lastUrlKey);
    final fallbackUrl = baseUrl;
    final initialUrl = lastUrl ?? fallbackUrl;
    await _loadUrl(initialUrl, allowSameDomainOnly: true);
  }

  void _listenConnectivity() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final offline = !results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
      if (offline != _isOffline) {
        setState(() {
          _isOffline = offline;
        });
      }
    });
  }

  void _listenDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri == null) {
        return;
      }
      _pendingRoute = uri.toString();
      _loadUrl(_pendingRoute, allowSameDomainOnly: true);
    });
  }

  void _listenFcmMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      final route = message.data['route']?.toString();
      if (route != null && route.isNotEmpty) {
        _pendingRoute = route;
        _loadUrl(_pendingRoute, allowSameDomainOnly: true);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = message.data['route']?.toString();
      if (route != null && route.isNotEmpty) {
        _pendingRoute = route;
        _loadUrl(_pendingRoute, allowSameDomainOnly: true);
      }
    });
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null || uri.scheme != 'https') {
      return NavigationDecision.prevent;
    }
    if (_isSameDomain(uri)) {
      return NavigationDecision.navigate;
    }
    _launchExternal(uri);
    return NavigationDecision.prevent;
  }

  bool _isSameDomain(Uri uri) {
    final baseUri = Uri.parse(baseUrl);
    return uri.host == baseUri.host;
  }

  Future<void> _launchExternal(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }

  void _onPageFinished(String url) {
    _persistLastUrl(url);
    _injectWebTweaks();
  }

  Future<void> _persistLastUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUrlKey, url);
  }

  Future<void> _loadUrl(
    String url, {
    required bool allowSameDomainOnly,
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      return;
    }
    if (allowSameDomainOnly && !_isSameDomain(uri)) {
      return;
    }
    await _controller.loadRequest(uri);
  }

  Future<void> _injectWebTweaks() async {
    const disableZoomJs = """
      var meta = document.querySelector('meta[name=viewport]');
      if (!meta) {
        meta = document.createElement('meta');
        meta.name = 'viewport';
        document.head.appendChild(meta);
      }
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      document.documentElement.style.overscrollBehavior = 'none';
      document.body.style.overscrollBehavior = 'none';
      document.body.style.touchAction = 'pan-y';
      document.body.style.overflowX = 'hidden';
    """;
    await _controller.runJavaScript(disableZoomJs);
  }

  void _handleJsMessage(JavaScriptMessage message) {
    final payload = message.message;
    if (payload.startsWith('navigate:')) {
      final target = payload.replaceFirst('navigate:', '').trim();
      _loadUrl(target, allowSameDomainOnly: true);
    } else if (payload.startsWith('external:')) {
      final target = payload.replaceFirst('external:', '').trim();
      final uri = Uri.tryParse(target);
      if (uri != null) {
        _launchExternal(uri);
      }
    } else if (payload == 'refresh') {
      _controller.reload();
    }
  }

  Future<bool> _handleBackNavigation() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return OfflineScreen(
        onRetry: () {
          setState(() {
            _isOffline = false;
          });
          _controller.reload();
        },
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }
        final shouldPop = await _handleBackNavigation();
        if (shouldPop && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}
