import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:ui_web' as ui;

class MetabaseScreen extends StatefulWidget {
  const MetabaseScreen({super.key});

  @override
  State<MetabaseScreen> createState() => _MetabaseScreenState();
}

class _MetabaseScreenState extends State<MetabaseScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _iframeCreated = false;
  bool _iframeLoadAttempted = false;

  final String _iframeId = 'metabase-iframe';
  
  // Metabase URL - make sure this is correct
  final String _metabaseUrl = 'http://localhost:3000/question/38-chiffre-daffaires-par-mois';
  // Alternative: If you need to use HTTPS in production
  // final String _metabaseUrl = 'https://your-domain.com/question/38-chiffre-daffaires-par-mois';

  final Color _primaryColor = const Color(0xFFDF8EFF);
  final Color _surfaceColor = const Color(0xFF0E0E11);
  final Color _surfaceContainer = const Color(0xFF19191D);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _registerIframeView();
      _checkMetabaseConnection();
    }
  }
  
  // Check if Metabase is reachable
  Future<void> _checkMetabaseConnection() async {
    try {
      final response = await html.HttpRequest.getString('$_metabaseUrl/api/health');
      print('✅ Metabase health check: $response');
    } catch (e) {
      print('⚠️ Metabase connection check failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Metabase server not reachable. Please ensure Metabase is running on localhost:3000';
        });
      }
    }
  }

  void _registerIframeView() {
    if (_iframeCreated) return;
    
    print('📝 Registering iframe view...');
    
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _iframeId,
      (int viewId) {
        print('🔧 Creating iframe element...');
        
        final iframe = html.IFrameElement()
          ..src = _metabaseUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.backgroundColor = '#0E0E11'
          ..style.borderRadius = '0px'
          ..allow = 'autoplay; encrypted-media; fullscreen'
          ..allowFullscreen = true;
        
        // Handle load event
        iframe.onLoad.listen((event) {
          print('✅ Iframe loaded successfully from: $_metabaseUrl');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = null;
            });
          }
        });
        
        // Handle error event
        iframe.onError.listen((event) {
          print('❌ Iframe error: $event');
          if (mounted && !_iframeLoadAttempted) {
            _iframeLoadAttempted = true;
            setState(() {
              _errorMessage = '❌ Impossible de charger Metabase.\n\n'
                             'Vérifiez que:\n'
                             '• Metabase est démarré sur localhost:3000\n'
                             '• Le dashboard existe (ID: 38)\n'
                             '• Pas de problèmes CORS\n\n'
                             'Essayez d\'ouvrir directement: $_metabaseUrl';
              _isLoading = false;
            });
          }
        });
        
        // Add a timeout
        Future.delayed(const Duration(seconds: 10), () {
          if (_isLoading && mounted && !_iframeLoadAttempted) {
            _iframeLoadAttempted = true;
            setState(() {
              _errorMessage = '⏱️ Timeout: Metabase met trop de temps à répondre.\n\n'
                             'Vérifiez que Metabase fonctionne correctement sur localhost:3000';
              _isLoading = false;
            });
          }
        });
        
        return iframe;
      },
    );
    
    _iframeCreated = true;
  }

  void _reload() {
    print('🔄 Reloading iframe...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _iframeLoadAttempted = false;
    });
    
    // Recreate the iframe
    _iframeCreated = false;
    _registerIframeView();
    
    // Force rebuild
    setState(() {});
  }
  
  void _openInBrowser() async {
    final url = Uri.parse(_metabaseUrl);
    await html.window.open(url.toString(), '_blank');
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        backgroundColor: _surfaceColor,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.analytics_rounded,
                  size: 48,
                  color: Color(0xFFDF8EFF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Metabase',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Disponible uniquement sur le web',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_surfaceColor, _surfaceContainer],
              ),
            ),
          ),

          Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Color(0xFFDF8EFF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Chiffre d\'affaires par mois',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '💰 73 700 DT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFFDF8EFF)),
                      onPressed: _reload,
                      tooltip: 'Rafraîchir',
                    ),
                  ],
                ),
              ),

              // Iframe
              Expanded(
                child: _errorMessage != null
                    ? _buildErrorWidget()
                    : HtmlElementView(
                        viewType: _iframeId,
                        key: ValueKey(_iframeId),
                      ),
              ),
            ],
          ),

          // Loading
          if (_isLoading && _errorMessage == null)
            Container(
              color: _surfaceColor.withOpacity(0.9),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: Color(0xFFDF8EFF),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Connexion à Metabase...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'localhost:3000',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceContainer.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Erreur de connexion à Metabase',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Impossible de charger Metabase',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _reload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDF8EFF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Réessayer'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _openInBrowser,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Ouvrir dans navigateur'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}