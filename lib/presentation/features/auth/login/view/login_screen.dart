import 'package:flutter/material.dart';
import 'package:horaextra_app/presentation/app/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        final role = authProvider.userRole;
        String route;
        
        if (role == 'provider') {
          route = AppRoutes.providerDashboard;
        } else if (role == 'admin') {
          route = AppRoutes.adminDashboard;
        } else {
          route = AppRoutes.clientDashboard;
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, route);
        }
      } else {
        _showSnackBar(authProvider.error ?? 'Email ou password incorrectos');
      }
    } catch (e) {
      _showSnackBar('Erro ao fazer login: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E3A5F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isTablet = size.width > 600 && size.width <= 900;

    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 48 : 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              children: [
                                Container(
                                  width: isDesktop ? 120 : (isTablet ? 100 : 80),
                                  height: isDesktop ? 120 : (isTablet ? 100 : 80),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF5E6D3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.access_time_filled,
                                      color: const Color(0xFF1E3A5F),
                                      size: isDesktop ? 60 : (isTablet ? 50 : 40),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 24 : 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Hora',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 48 : (isTablet ? 40 : 32),
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFF5E6D3),
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    Text(
                                      'Extra',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 48 : (isTablet ? 40 : 32),
                                        fontWeight: FontWeight.w300,
                                        color: const Color(0xFFF5E6D3).withOpacity(0.8),
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isDesktop ? 8 : 4),
                                Text(
                                  'Serviços profissionais ao seu alcance',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : (isTablet ? 14 : 12),
                                    color: const Color(0xFFF5E6D3).withOpacity(0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isDesktop ? 48 : 32),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              width: isDesktop ? 500 : double.infinity,
                              padding: EdgeInsets.all(isDesktop ? 32 : 24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bem-vindo de volta',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 24 : 20,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1E3A5F),
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 8 : 4),
                                    Text(
                                      'Faça login para continuar',
                                      style: TextStyle(
                                        fontSize: isDesktop ? 14 : 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 32 : 24),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        labelStyle: TextStyle(
                                          fontSize: isDesktop ? 16 : 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.email_outlined,
                                          color: const Color(0xFF1E3A5F).withOpacity(0.5),
                                          size: isDesktop ? 24 : 20,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E3A5F),
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: isDesktop ? 16 : 14,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Email obrigatório';
                                        }
                                        if (!value.contains('@') || !value.contains('.')) {
                                          return 'Email inválido';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: isDesktop ? 16 : 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      style: const TextStyle(color: Color(0xFF1E3A5F)),
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        labelStyle: TextStyle(
                                          fontSize: isDesktop ? 16 : 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline,
                                          color: const Color(0xFF1E3A5F).withOpacity(0.5),
                                          size: isDesktop ? 24 : 20,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: const Color(0xFF1E3A5F).withOpacity(0.5),
                                            size: isDesktop ? 24 : 20,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible = !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF1E3A5F),
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: isDesktop ? 16 : 14,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Password obrigatória';
                                        }
                                        if (value.length < 6) {
                                          return 'Mínimo 6 caracteres';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(height: isDesktop ? 24 : 20),
                                    SizedBox(
                                      width: double.infinity,
                                      height: isDesktop ? 56 : 48,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E3A5F),
                                          foregroundColor: const Color(0xFFF5E6D3),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? SizedBox(
                                                width: isDesktop ? 24 : 20,
                                                height: isDesktop ? 24 : 20,
                                                child: const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFF5E6D3),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                'Entrar',
                                                style: TextStyle(
                                                  fontSize: isDesktop ? 18 : 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: isDesktop ? 24 : 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Não tem conta? ',
                                          style: TextStyle(
                                            fontSize: isDesktop ? 16 : 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              AppRoutes.roleSelection,
                                            );
                                          },
                                          child: Text(
                                            'Registe-se',
                                            style: TextStyle(
                                              fontSize: isDesktop ? 16 : 14,
                                              color: const Color(0xFF1E3A5F),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Text(
                            '© 2026 HoraExtra. Todos os direitos reservados.',
                            style: TextStyle(
                              fontSize: isDesktop ? 12 : 10,
                              color: const Color(0xFFF5E6D3).withOpacity(0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: isDesktop ? 24 : 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}