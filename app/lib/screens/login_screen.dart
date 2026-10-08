import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../constants/theme.dart';
import '../constants/translations.dart';
import '../widgets/glass_card.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscureKey = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final cfg = await SupabaseService().getSavedConfig();
    if (mounted) {
      setState(() {
        if (cfg['url']?.isNotEmpty == true) _urlController.text = cfg['url']!;
        if (cfg['anon_key']?.isNotEmpty == true) _keyController.text = cfg['anon_key']!;
        if (cfg['email']?.isNotEmpty == true) _emailController.text = cfg['email']!;
      });
    }
  }

  String _cleanInput(String val, [String? prefix]) {
    var s = val.trim();
    if (prefix != null && s.toUpperCase().startsWith(prefix.toUpperCase())) {
      s = s.substring(prefix.length).trim();
      if (s.startsWith('=')) s = s.substring(1).trim();
    }
    // Remove surrounding quotes
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      if (s.length >= 2) s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  void _parseAndFillEnv(String raw) {
    final lines = raw.split(RegExp(r'[\r\n]+'));
    String? foundUrl;
    String? foundKey;
    String? foundEmail;
    String? foundPassword;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final eqIndex = line.indexOf('=');
      if (eqIndex != -1) {
        final k = line.substring(0, eqIndex).trim().toUpperCase();
        var v = line.substring(eqIndex + 1).trim();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
          if (v.length >= 2) v = v.substring(1, v.length - 1).trim();
        }
        if (k == 'SUPABASE_URL' || k == 'URL') {
          foundUrl = v;
        } else if (k == 'SUPABASE_ANON_KEY' || k == 'SUPABASE_KEY' || k == 'ANON_KEY' || k == 'KEY') {
          foundKey = v;
        } else if (k == 'AGENT_EMAIL' || k == 'EMAIL') {
          foundEmail = v;
        } else if (k == 'AGENT_PASSWORD' || k == 'PASSWORD') {
          foundPassword = v;
        }
      }
    }

    setState(() {
      if (foundUrl != null && foundUrl.isNotEmpty) _urlController.text = foundUrl;
      if (foundKey != null && foundKey.isNotEmpty) _keyController.text = foundKey;
      if (foundEmail != null && foundEmail.isNotEmpty) _emailController.text = foundEmail;
      if (foundPassword != null && foundPassword.isNotEmpty) _passwordController.text = foundPassword;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final lang = Provider.of<AppProvider>(context, listen: false).currentLanguage;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('login_clipboard_empty', lang))),
          );
        }
        return;
      }

      if (text.contains('=') && (text.contains('SUPABASE') || text.contains('AGENT') || text.contains('\n'))) {
        _parseAndFillEnv(text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('login_clipboard_success', lang))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('login_clipboard_not_found', lang))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pano okunamadı: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    _urlController.text = _cleanInput(_urlController.text, 'SUPABASE_URL');
    _keyController.text = _cleanInput(_keyController.text, 'SUPABASE_ANON_KEY');
    _emailController.text = _cleanInput(_emailController.text, 'AGENT_EMAIL');
    _passwordController.text = _cleanInput(_passwordController.text, 'AGENT_PASSWORD');

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final success = await provider.login(
        url: _urlController.text.trim(),
        anonKey: _keyController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage = provider.errorMessage ?? 'Giriş yapılamadı.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final accent = provider.accentColor;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon & Glow
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.15),
                        border: Border.all(color: accent.withValues(alpha: 0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AlertRox',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Güvenli Kimlik Doğrulama',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.statusOffline.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.statusOffline.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.statusOffline, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.statusOffline,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Credential Card
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Supabase Bağlantısı',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              TextButton.icon(
                                onPressed: _pasteFromClipboard,
                                icon: const Icon(Icons.paste_rounded, size: 16),
                                label: Text(
                                  AppTranslations.get('login_paste_clipboard', provider.currentLanguage),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            onChanged: (val) {
                              if (val.contains('SUPABASE_ANON_KEY') ||
                                  val.contains('AGENT_EMAIL') ||
                                  val.contains('\n')) {
                                _parseAndFillEnv(val);
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Supabase URL',
                              hintText: 'https://xxxx.supabase.co',
                              prefixIcon: Icon(Icons.link),
                            ),
                            validator: (val) {
                              final cleaned = _cleanInput(val ?? '', 'SUPABASE_URL');
                              if (cleaned.isEmpty) {
                                return 'Supabase URL gereklidir';
                              }
                              if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
                                return 'Geçerli bir URL girin (https://...)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _keyController,
                            obscureText: _obscureKey,
                            decoration: InputDecoration(
                              labelText: 'Anon Public Key',
                              hintText: 'eyJhbGciOi...',
                              prefixIcon: const Icon(Icons.key),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                              ),
                            ),
                            validator: (val) {
                              final cleaned = _cleanInput(val ?? '', 'SUPABASE_ANON_KEY');
                              if (cleaned.isEmpty) {
                                return 'Supabase Anon Key gereklidir';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            'Kullanıcı Hesabı',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              hintText: 'ornek@alanadi.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (val) {
                              final cleaned = _cleanInput(val ?? '', 'AGENT_EMAIL');
                              if (cleaned.isEmpty) {
                                return 'E-posta adresi gereklidir';
                              }
                              if (!cleaned.contains('@')) {
                                return 'Geçerli bir e-posta adresi girin';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (val) {
                              final cleaned = _cleanInput(val ?? '', 'AGENT_PASSWORD');
                              if (cleaned.isEmpty) {
                                return 'Şifre gereklidir';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Yetkisiz erişimler RLS koruması ile engellenir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
