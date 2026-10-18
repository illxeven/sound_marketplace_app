import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

enum UserRoleOption { consumer, artistProducer }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login Controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;

  /// Red error text shown under each form (null = no error).
  String? _loginError;
  String? _registerError;

  static const int _minPasswordLength = 10;

  // Register Controllers
  final _regFormKey = GlobalKey<FormState>();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regDisplayNameController = TextEditingController();
  final _regStageNameController = TextEditingController();
  final _regBioController = TextEditingController();
  bool _regObscurePassword = true;
  PlatformFile? _pickedAvatarFile;

  // Role Selection
  UserRoleOption _selectedRole = UserRoleOption.consumer;

  // Terms and Service agreement state
  bool _agreedToTerms = false;

  static const String _defaultTermsOfServiceText = '''
SOUND MARKETPLACE - TERMS OF SERVICE
Effective Date: October 2026
Version: 1.0

1. ACCEPTANCE OF TERMS
By creating an account, accessing, or using the Sound Marketplace platform ("Platform", "we", "us", or "our"), you ("User", "you") agree to be bound by these Terms of Service ("Terms"). If you do not agree to all terms and conditions, you must not create an account or use our services.

2. ELIGIBILITY & REGISTRATION
2.1 You must be at least 18 years of age or the age of legal majority in your jurisdiction to create an account.
2.2 You agree to provide accurate, current, and complete information during registration and keep your account details updated.
2.3 You are responsible for safeguarding your password and credentials. You agree to notify us immediately of any unauthorized access to your account.

3. DIGITAL AUDIO CONTENT & LICENSING (BEATS, SOUND KITS, SAMPLES)
3.1 Non-Exclusive & Exclusive Licenses: Music tracks, beats, loops, and sound kits offered on Sound Marketplace may be purchased under specific licensing terms (Non-Exclusive Lease or Exclusive Rights) designated by the respective artist or producer.
3.2 Intellectual Property Rights: Unless explicitly conveyed through a written Exclusive Rights agreement, copyright ownership of all musical compositions, sound recordings, and samples remains with the original creator/producer.
3.3 Prohibited Resale: You may not resell, sub-license, distribute, or share raw audio files, loops, stems, or sound kit samples as standalone sample libraries or sound collections without authorization.

4. PHYSICAL & DIGITAL MERCHANDISE
4.1 Merchandise Sales: Physical goods (such as apparel, t-shirts, hoodies, vinyl records, stickers, posters, and accessories) are fulfilled according to the specifications provided in product listings.
4.2 Pricing & Availability: All merchandise prices and product availability are subject to change. Sound Marketplace reserves the right to cancel or limit quantities on any order.

5. PAYMENTS, BILLING & FEES
5.1 Payment Processing: All transactions on Sound Marketplace are processed securely via third-party payment gateways (including Stripe and PayPal). By providing payment information, you represent that you have legal authorization to use the payment method.
5.2 Platform Commission: Sound Marketplace may deduct applicable transaction fees and marketplace commissions from sales proceeds as disclosed in the seller dashboard.

6. USER CONDUCT & PROHIBITED ACTIVITIES
You agree NOT to:
- Upload, license, or sell audio, artwork, or merchandise that infringes upon any third party's copyright, trademark, privacy, or proprietary rights.
- Use bots, scrapers, automated scripts, or fraudulent methods to artificially inflate play counts, listen metrics, likes, or reviews.
- Upload malicious code, viruses, or disruptive scripts to the platform.
- Engage in abusive, harassing, defamatory, or deceptive conduct towards creators or community members.

7. TERMINATION & ACCOUNT SUSPENSION
We reserve the right to suspend or terminate your account and access to Sound Marketplace at our sole discretion, without notice, for conduct that violates these Terms or harms other users, artists, or the integrity of our platform.

8. DISCLAIMER OF WARRANTIES & LIMITATION OF LIABILITY
The platform and all content, digital assets, and merchandise are provided "AS IS" and "AS AVAILABLE" without warranties of any kind. Sound Marketplace is not liable for indirect, incidental, or consequential damages resulting from your use of the platform.

9. MODIFICATIONS TO TERMS
We reserve the right to update or modify these Terms at any time. Continued use of the platform following the posting of any changes constitutes acceptance of those changes.

10. CONTACT US
If you have questions regarding these Terms of Service, please contact us at support@soundmarketplace.com.
''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regDisplayNameController.dispose();
    _regStageNameController.dispose();
    _regBioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedAvatarFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting photo: $e')),
        );
      }
    }
  }

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g. name@example.com)';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    setState(() => _loginError = null);
    if (!_loginFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    final success = await auth.login(email: email, password: password);

    if (!mounted || success) return;
    if (auth.needsEmailVerification) {
      setState(() => _loginError = 'Your email isn\'t verified yet. Enter the code we emailed you.');
      _showVerificationDialog(email, password: password);
    } else {
      setState(() => _loginError = auth.errorMessage ?? 'Incorrect email or password.');
    }
  }

  Widget _errorText(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsOfServiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: context.read<AuthProvider>().fetchTermsOfService(),
          builder: (context, snapshot) {
            final termsDoc = snapshot.data;
            final content = termsDoc != null && termsDoc['content'] != null
                ? termsDoc['content'].toString()
                : _defaultTermsOfServiceText;
            final version = termsDoc != null && termsDoc['version'] != null
                ? termsDoc['version'].toString()
                : '1.0';

            return AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: AppTheme.secondaryCyan, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v$version',
                      style: const TextStyle(color: AppTheme.secondaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 480,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryCyan))
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(right: 12),
                          child: SelectableText(
                            content,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _agreedToTerms = true;
                    });
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('I Agree to Terms'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleRegister() async {
    setState(() => _registerError = null);
    if (!_regFormKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() => _registerError = 'Please read and agree to the Terms of Service.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final isArtist = _selectedRole == UserRoleOption.artistProducer;
    final effectiveDisplayName = isArtist && _regStageNameController.text.trim().isNotEmpty
        ? _regStageNameController.text.trim()
        : _regDisplayNameController.text.trim();

    // Country comes from the device locale; no third-party IP lookup without consent.
    final country = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;

    final success = await auth.register(
      email: email,
      password: password,
      displayName: effectiveDisplayName,
      country: country,
      role: isArtist ? 'music_artist' : 'consumer',
      bio: isArtist && _regBioController.text.trim().isNotEmpty ? _regBioController.text.trim() : null,
      termsAccepted: _agreedToTerms,
      avatarPath: _pickedAvatarFile?.path,
      avatarBytes: _pickedAvatarFile?.bytes,
      avatarFilename: _pickedAvatarFile?.name,
    );

    if (!mounted) return;
    if (!success) {
      setState(() => _registerError = auth.errorMessage ?? 'We couldn\'t create your account. Please try again.');
      return;
    }
    _loginEmailController.text = email;
    _showVerificationDialog(email, password: password);
  }

  /// Asks for the emailed code. When [password] is known (just registered or tried to sign in),
  /// the user is signed in automatically after a successful verification.
  void _showVerificationDialog(String email, {String? password}) {
    final tokenController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.mark_email_read_outlined, color: AppTheme.secondaryCyan),
              SizedBox(width: 10),
              Text('Verify Email Address'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We sent a verification code to:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    email,
                    style: const TextStyle(
                      color: AppTheme.secondaryCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please enter the 8-character verification code to activate your account and complete registration.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tokenController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Verification Code',
                    hintText: 'e.g. A1B2C3D4',
                    prefixIcon: const Icon(Icons.key, color: AppTheme.secondaryCyan),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Resend Verification Code', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final auth = context.read<AuthProvider>();
                        final ok = await auth.resendVerification(email);
                        if (!ctx.mounted) return;
                        if (ok) {
                          setModalState(() => dialogError = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('If your account still needs verifying, a new code is on its way. It can take a minute.'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        } else {
                          setModalState(() => dialogError = auth.errorMessage ?? 'We couldn\'t send a new code. Try again in a minute.');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(0);
              },
              child: const Text('Back to Sign In', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = tokenController.text.trim();
                      if (code.isEmpty) {
                        setModalState(() {
                          dialogError = 'Please enter the verification code';
                        });
                        return;
                      }
                      setModalState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      final auth = context.read<AuthProvider>();
                      final verified = await auth.verifyEmail(code);
                      if (!ctx.mounted) return;

                      if (!verified) {
                        setModalState(() {
                          isSubmitting = false;
                          dialogError = auth.errorMessage ?? 'That code is invalid or has expired. Tap "Resend" for a new one.';
                        });
                        return;
                      }

                      Navigator.pop(ctx);
                      setState(() => _loginError = null);
                      if (password != null) {
                        // Account is active: sign straight in.
                        final signedIn = await auth.login(email: email, password: password);
                        if (!mounted) return;
                        if (!signedIn) {
                          _tabController.animateTo(0);
                          setState(() => _loginError = auth.errorMessage);
                        }
                      } else {
                        _tabController.animateTo(0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email verified. Sign in to continue.'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify & Activate Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecoveryDialog() {
    final emailController = TextEditingController(text: _loginEmailController.text);
    final tokenController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isResetStage = false;
    String? emailErrorText;
    String? resetErrorText;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isResetStage ? 'Reset Password' : 'Account Recovery'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isResetStage) ...[
                  const Text(
                    'Enter your account email. We\'ll send a reset code (or a username reminder).',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (emailErrorText != null) {
                        setModalState(() => emailErrorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Account Email',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryPurple),
                      errorText: emailErrorText,
                      errorStyle: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.person_search_rounded, size: 16),
                        label: const Text('Remind Username', style: TextStyle(fontSize: 12)),
                        onPressed: isSubmitting ? null : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty) {
                            setModalState(() => emailErrorText = 'Please enter your email');
                            return;
                          }
                          setModalState(() {
                            isSubmitting = true;
                            emailErrorText = null;
                          });
                          final auth = context.read<AuthProvider>();
                          final ok = await auth.recoverUsername(email);
                          setModalState(() => isSubmitting = false);
                          if (!ctx.mounted) return;
                          if (ok) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('If an account exists for this email, we\'ve sent your username.')),
                            );
                          } else {
                            setModalState(() => emailErrorText = auth.errorMessage ?? 'We couldn\'t send the reminder. Try again.');
                          }
                        },
                      ),
                      TextButton(
                        onPressed: () => setModalState(() {
                          isResetStage = true;
                          emailErrorText = null;
                          resetErrorText = null;
                        }),
                        child: const Text('I have a code', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Enter the 8-character code from the email and choose a new password. The code expires in 30 minutes.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tokenController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 15),
                    onChanged: (_) {
                      if (resetErrorText != null) {
                        setModalState(() => resetErrorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Reset code (from email)',
                      hintText: 'e.g. A1B2C3D4',
                      prefixIcon: const Icon(Icons.vpn_key_outlined, color: AppTheme.secondaryCyan),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    onChanged: (_) {
                      if (resetErrorText != null) {
                        setModalState(() => resetErrorText = null);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'New password (min $_minPasswordLength characters)',
                      prefixIcon: Icon(Icons.lock_outline, color: AppTheme.secondaryCyan),
                    ),
                  ),
                  if (resetErrorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      resetErrorText!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text('Send a new code', style: TextStyle(fontSize: 12)),
                    onPressed: isSubmitting ? null : () => setModalState(() {
                      isResetStage = false;
                      resetErrorText = null;
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (!isResetStage)
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    setModalState(() => emailErrorText = 'Please enter your email');
                    return;
                  }
                  if (!email.contains('@') || !email.contains('.')) {
                    setModalState(() => emailErrorText = 'Invalid email address format');
                    return;
                  }

                  setModalState(() {
                    isSubmitting = true;
                    emailErrorText = null;
                  });

                  final auth = context.read<AuthProvider>();
                  final ok = await auth.forgotPassword(email);
                  setModalState(() => isSubmitting = false);
                  if (!ctx.mounted) return;

                  if (ok) {
                    // Same message whether or not the email has an account (no account discovery).
                    setModalState(() {
                      isResetStage = true;
                      emailErrorText = null;
                      resetErrorText = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('If an account exists for this email, we\'ve sent a reset code. Check your inbox and spam folder.'),
                        backgroundColor: AppTheme.successGreen,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  } else {
                    setModalState(() => emailErrorText = auth.errorMessage ?? 'We couldn\'t send the reset email. Try again.');
                  }
                },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send reset code'),
              )
            else
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  final token = tokenController.text.trim();
                  final newPass = newPasswordController.text;
                  if (token.isEmpty) {
                    setModalState(() => resetErrorText = 'Enter the code from the email.');
                    return;
                  }
                  if (newPass.length < _minPasswordLength) {
                    setModalState(() => resetErrorText = 'Password must be at least $_minPasswordLength characters.');
                    return;
                  }

                  setModalState(() {
                    isSubmitting = true;
                    resetErrorText = null;
                  });

                  final ok = await context.read<AuthProvider>().resetPassword(token, newPass);
                  setModalState(() => isSubmitting = false);

                  if (ctx.mounted) {
                    if (ok) {
                      Navigator.pop(ctx);
                      _loginEmailController.text = emailController.text.trim();
                      _loginPasswordController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated. Sign in with your new password.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    } else {
                      setModalState(() {
                        resetErrorText = context.read<AuthProvider>().errorMessage ?? 'That code is invalid or has expired. Send a new code.';
                      });
                    }
                  }
                },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save New Password'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Brand Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryPurple, AppTheme.secondaryCyan],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SOUND MARKETPLACE',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Exclusive audio marketplace, beats, and creator community',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // Tab Selector: Log In vs Register
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.secondaryCyan,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppTheme.primaryPurple,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tabs: const [
                        Tab(text: 'Log In'),
                        Tab(text: 'Create Account'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tab View Container
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: SizedBox(
                      height: _tabController.index == 0 ? 420 : (_selectedRole == UserRoleOption.artistProducer ? 860 : 780),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // ============================================
                          // 1. SIGN IN FORM
                          // ============================================
                          SingleChildScrollView(
                            child: Form(
                              key: _loginFormKey,
                              child: Column(
                              children: [
                                TextFormField(
                                  controller: _loginEmailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
                                  ),
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _loginPasswordController,
                                  obscureText: _loginObscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _loginObscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.white54,
                                      ),
                                      onPressed: () => setState(() => _loginObscurePassword = !_loginObscurePassword),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showRecoveryDialog,
                                    child: const Text(
                                      'Forgot Password / Username?',
                                      style: TextStyle(color: AppTheme.secondaryCyan, fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading ? null : _handleLogin,
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('Log In to Sound Marketplace'),
                                  ),
                                ),
                                _errorText(_loginError),
                                if (auth.needsEmailVerification)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                      onPressed: () => _showVerificationDialog(
                                        _loginEmailController.text.trim(),
                                        password: _loginPasswordController.text,
                                      ),
                                      child: const Text('Enter verification code', style: TextStyle(color: AppTheme.secondaryCyan)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                          // ============================================
                          // 2. ENHANCED REGISTRATION FORM
                          // ============================================
                          SingleChildScrollView(
                            child: Form(
                              key: _regFormKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                // Avatar Photo Picker
                                Center(
                                  child: Column(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 36,
                                            backgroundColor: AppTheme.surfaceColor,
                                            backgroundImage: _pickedAvatarFile != null && _pickedAvatarFile!.bytes != null
                                                ? MemoryImage(_pickedAvatarFile!.bytes!)
                                                : null,
                                            child: _pickedAvatarFile == null
                                                ? const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                    color: Colors.white54,
                                                  )
                                                : null,
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: InkWell(
                                              onTap: _pickAvatar,
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.secondaryCyan,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: AppTheme.cardColor, width: 2),
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  size: 14,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _pickedAvatarFile != null
                                            ? 'Profile Picture Selected (${_pickedAvatarFile!.name})'
                                            : 'Add Profile Photo (Optional)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _pickedAvatarFile != null
                                              ? AppTheme.secondaryCyan
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Role Selection Heading
                                const Text(
                                  'Choose Your Account Type:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Radio Button Row for Role Selection
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedRole = UserRoleOption.consumer),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _selectedRole == UserRoleOption.consumer
                                                ? AppTheme.primaryPurple.withValues(alpha: 0.25)
                                                : AppTheme.surfaceColor,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedRole == UserRoleOption.consumer
                                                  ? AppTheme.secondaryCyan
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Radio<UserRoleOption>(
                                                value: UserRoleOption.consumer,
                                                groupValue: _selectedRole,
                                                activeColor: AppTheme.secondaryCyan,
                                                onChanged: (val) => setState(() => _selectedRole = val!),
                                              ),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Consumer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                    Text('Listener & Buyer', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _selectedRole = UserRoleOption.artistProducer),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: _selectedRole == UserRoleOption.artistProducer
                                                ? AppTheme.primaryPurple.withValues(alpha: 0.25)
                                                : AppTheme.surfaceColor,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _selectedRole == UserRoleOption.artistProducer
                                                  ? AppTheme.secondaryCyan
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Radio<UserRoleOption>(
                                                value: UserRoleOption.artistProducer,
                                                groupValue: _selectedRole,
                                                activeColor: AppTheme.secondaryCyan,
                                                onChanged: (val) => setState(() => _selectedRole = val!),
                                              ),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Artist/Producer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                    Text('Creator & Seller', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // DYNAMIC CONDITIONAL FIELD: Only shown for Artist/Producer!
                                if (_selectedRole == UserRoleOption.artistProducer) ...[
                                  TextFormField(
                                    controller: _regStageNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Artist / Stage Name',
                                      prefixIcon: Icon(Icons.album_rounded, color: AppTheme.secondaryCyan),
                                      hintText: 'e.g. DJ Soundwave, BeatLord',
                                    ),
                                    validator: (v) {
                                      if (_selectedRole == UserRoleOption.artistProducer && (v == null || v.trim().isEmpty)) {
                                        return 'Please enter your artist / stage name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _regBioController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Artist Bio (Optional)',
                                      prefixIcon: Icon(Icons.description_outlined, color: AppTheme.secondaryCyan),
                                      hintText: 'Tell listeners about your sound and musical style...',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Common Display Name Field
                                TextFormField(
                                  controller: _regDisplayNameController,
                                  decoration: InputDecoration(
                                    labelText: _selectedRole == UserRoleOption.artistProducer
                                        ? 'Account Display Name'
                                        : 'Full Name / Display Name',
                                    prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter display name' : null,
                                ),
                                const SizedBox(height: 12),

                                // Email Field
                                TextFormField(
                                  controller: _regEmailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
                                  ),
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 12),

                                // Password Field with Visibility Toggle
                                TextFormField(
                                  controller: _regPasswordController,
                                  obscureText: _regObscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Create Password',
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _regObscurePassword ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.white54,
                                      ),
                                      onPressed: () => setState(() => _regObscurePassword = !_regObscurePassword),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length < _minPasswordLength)
                                      ? 'Password must be at least $_minPasswordLength characters'
                                      : null,
                                ),
                                const SizedBox(height: 14),

                                // Mandatory Terms of Service Agreement Checkbox
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: Checkbox(
                                        value: _agreedToTerms,
                                        activeColor: AppTheme.secondaryCyan,
                                        checkColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          setState(() {
                                            _agreedToTerms = val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          const Text(
                                            'I have read and agree to the ',
                                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                          ),
                                          InkWell(
                                            onTap: _showTermsOfServiceDialog,
                                            borderRadius: BorderRadius.circular(4),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 2),
                                              child: Text(
                                                'Terms of Service',
                                                style: TextStyle(
                                                  color: AppTheme.secondaryCyan,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                  decorationColor: AppTheme.secondaryCyan,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            ' *',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Register Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: auth.isLoading ? null : _handleRegister,
                                    child: auth.isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : Text(
                                            _selectedRole == UserRoleOption.artistProducer
                                                ? 'Register as Artist / Producer'
                                                : 'Register as Consumer',
                                          ),
                                  ),
                                ),
                                _errorText(_registerError),
                              ],
                            ),
                          ),
                        ),
                        ],
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
