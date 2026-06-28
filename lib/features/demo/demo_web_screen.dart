import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';

/// Full-screen WebView for MHG narrative demo — web parity via hosted routes.
class DemoWebScreen extends StatefulWidget {
  const DemoWebScreen({super.key, required this.webPath});

  final String webPath;

  @override
  State<DemoWebScreen> createState() => _DemoWebScreenState();
}

class _DemoWebScreenState extends State<DemoWebScreen> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final url = '${AppConfig.webOrigin}${widget.webPath}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MHG Demo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// Registers all `/demo/mhg/*` paths to the WebView shell.
List<RouteBase> demoStoryRoutes() => [
      GoRoute(
        path: '/demo/mhg',
        builder: (_, state) => DemoWebScreen(webPath: state.uri.path),
        routes: [
          GoRoute(
            path: 'outcome',
            builder: (_, state) => DemoWebScreen(webPath: state.uri.path),
          ),
          GoRoute(
            path: 'jam/1/live',
            builder: (_, state) => DemoWebScreen(webPath: state.uri.path),
          ),
          GoRoute(
            path: 'jam/2/live',
            builder: (_, state) => DemoWebScreen(webPath: state.uri.path),
          ),
          GoRoute(
            path: 'knowledge',
            builder: (_, state) => DemoWebScreen(webPath: state.uri.path),
          ),
          GoRoute(
            path: 'field',
            builder: (_, state) => DemoWebScreen(webPath: state.uri.path),
          ),
        ],
      ),
    ];
