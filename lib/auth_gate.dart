import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'main.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF121212),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
            ),
          );
        }

        // No user → Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // User logged in → check Firestore permissions
        return _PermissionChecker(user: snapshot.data!);
      },
    );
  }
}

class _PermissionChecker extends StatefulWidget {
  final User user;
  const _PermissionChecker({required this.user});

  @override
  State<_PermissionChecker> createState() => _PermissionCheckerState();
}

class _PermissionCheckerState extends State<_PermissionChecker> {
  bool _isLoading = true;
  bool _hasProfile = false;
  bool _hasAccess = false;
  String _rolStatus = '';
  bool _trialActive = false;
  int _trialDaysLeft = 0;
  bool _trialExpired = false;
  bool _trialUsed = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.user.uid)
          .get();

      if (!docSnap.exists) {
        // No profile → needs onboarding
        setState(() {
          _isLoading = false;
          _hasProfile = false;
        });
        return;
      }

      final data = docSnap.data()!;
      final suscripciones = data['suscripciones_apps'] as Map<String, dynamic>?;
      final hasAfinador = suscripciones?['afinador'] == true;
      final rol = data['rol'] as String? ?? 'pendiente';

      // Check trial period
      bool trialActive = false;
      int trialDaysLeft = 0;
      bool trialExpired = false;
      bool trialUsed = false;

      final trialInicio = data['trial_afinador_inicio'];
      if (trialInicio != null) {
        trialUsed = true;
        final DateTime trialStart = (trialInicio as Timestamp).toDate();
        final DateTime trialEnd = trialStart.add(const Duration(days: 30));
        final DateTime now = DateTime.now();

        if (now.isBefore(trialEnd)) {
          trialActive = true;
          trialDaysLeft = trialEnd.difference(now).inDays;
        } else {
          trialExpired = true;
        }
      }

      setState(() {
        _isLoading = false;
        _hasProfile = true;
        _hasAccess = hasAfinador || rol == 'admin' || trialActive;
        _rolStatus = rol;
        _trialActive = trialActive;
        _trialDaysLeft = trialDaysLeft;
        _trialExpired = trialExpired;
        _trialUsed = trialUsed;
      });
    } catch (e) {
      debugPrint("Error checking permissions: $e");
      setState(() {
        _isLoading = false;
        _hasProfile = false;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF3B82F6)),
              SizedBox(height: 16),
              Text(
                "Verificando acceso...",
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // No profile → Onboarding
    if (!_hasProfile) {
      return const OnboardingScreen();
    }

    // Has profile but no access → pending screen
    if (!_hasAccess) {
      return _PendingAccessScreen(
        rol: _rolStatus,
        trialExpired: _trialExpired,
        trialUsed: _trialUsed,
        onSignOut: _signOut,
        onRetry: () {
          setState(() => _isLoading = true);
          _checkPermissions();
        },
        onTrialActivated: () {
          setState(() => _isLoading = true);
          _checkPermissions();
        },
      );
    }

    // Access granted → Tuner!
    // Show trial banner if on trial
    if (_trialActive) {
      return _TrialBannerWrapper(
        daysLeft: _trialDaysLeft,
        child: const TunerScreen(),
      );
    }
    return const TunerScreen();
  }
}

// ---------------------------------------------------------------------------
// Trial banner wrapper — shows remaining trial days at the top
// ---------------------------------------------------------------------------
class _TrialBannerWrapper extends StatelessWidget {
  final int daysLeft;
  final Widget child;

  const _TrialBannerWrapper({required this.daysLeft, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF1E3A5F),
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Período de prueba · $daysLeft ${daysLeft == 1 ? 'día' : 'días'} restantes",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openSubscription(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Suscribirse",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Future<void> _openSubscription() async {
    final uri = Uri.parse('https://federicorandazzo.com.ar/apps/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// Pending access screen — redesigned with trial, subscription & admin notice
// ---------------------------------------------------------------------------
class _PendingAccessScreen extends StatefulWidget {
  final String rol;
  final bool trialExpired;
  final bool trialUsed;
  final VoidCallback onSignOut;
  final VoidCallback onRetry;
  final VoidCallback onTrialActivated;

  const _PendingAccessScreen({
    required this.rol,
    required this.trialExpired,
    required this.trialUsed,
    required this.onSignOut,
    required this.onRetry,
    required this.onTrialActivated,
  });

  @override
  State<_PendingAccessScreen> createState() => _PendingAccessScreenState();
}

class _PendingAccessScreenState extends State<_PendingAccessScreen>
    with SingleTickerProviderStateMixin {
  bool _isActivatingTrial = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _activateTrial() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isActivatingTrial = true);

    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .update({
        'trial_afinador_inicio': FieldValue.serverTimestamp(),
      });

      // Also send admin notification about trial activation
      await FirebaseFirestore.instance.collection('consultas_web').add({
        'nombre': user.displayName ?? 'Usuario',
        'email': user.email,
        'motivo': 'Trial Activado - Afinador',
        'mensaje':
            '${user.displayName ?? "Un usuario"} (${user.email}) activó el período de prueba de 30 días para el Afinador.',
        'tipo': 'trial_activado',
        'fecha': FieldValue.serverTimestamp(),
        'leido': false,
        'eliminado': false,
      });

      if (mounted) {
        widget.onTrialActivated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al activar prueba: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isActivatingTrial = false);
      }
    }
  }

  Future<void> _openSubscription() async {
    final uri = Uri.parse('https://federicorandazzo.com.ar/apps/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Main card ──
                  _buildMainCard(),
                  const SizedBox(height: 16),

                  // ── Trial card ──
                  _buildTrialCard(),
                  const SizedBox(height: 16),

                  // ── Subscription card ──
                  _buildSubscriptionCard(),
                  const SizedBox(height: 24),

                  // ── Bottom actions ──
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Main info card ──
  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27272A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.15),
                    const Color(0xFF8B5CF6).withOpacity(0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: Color(0xFF3B82F6),
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            "Solicitud Enviada",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Info badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: const Color(0xFF10B981).withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  "El administrador fue notificado",
                  style: TextStyle(
                    color: const Color(0xFF10B981).withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            "Tu solicitud de acceso al Afinador está siendo revisada. "
            "Mientras tanto, podés iniciar un período de prueba gratuito "
            "o suscribirte directamente.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Trial card ──
  Widget _buildTrialCard() {
    final bool canTrial = !widget.trialUsed;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canTrial
              ? const Color(0xFF2563EB).withOpacity(0.3)
              : const Color(0xFF27272A),
        ),
        boxShadow: [
          if (canTrial)
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: canTrial
                      ? const Color(0xFF2563EB).withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  canTrial
                      ? Icons.rocket_launch_rounded
                      : Icons.timer_off_outlined,
                  color: canTrial
                      ? const Color(0xFF3B82F6)
                      : Colors.white38,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canTrial
                          ? "Prueba Gratuita"
                          : widget.trialExpired
                              ? "Prueba Finalizada"
                              : "Prueba no disponible",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      canTrial
                          ? "30 días de acceso completo, sin compromiso"
                          : "Tu período de prueba de 30 días ha expirado",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: canTrial && !_isActivatingTrial
                  ? _activateTrial
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withOpacity(0.06),
                disabledForegroundColor: Colors.white30,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isActivatingTrial
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          canTrial ? Icons.play_arrow_rounded : Icons.block,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canTrial
                              ? "Comenzar prueba gratuita"
                              : "Prueba utilizada",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subscription card ──
  Widget _buildSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Suscripción",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Acceso completo y permanente al Afinador",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _openSubscription,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: Color(0xFFF59E0B),
                  width: 1.5,
                ),
                foregroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.open_in_new_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "Ver opciones de suscripción",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom actions (retry + sign out) ──
  Widget _buildBottomActions() {
    return Column(
      children: [
        // Retry button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              "Verificar acceso de nuevo",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Sign out
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: widget.onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white30,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Cerrar sesión",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
