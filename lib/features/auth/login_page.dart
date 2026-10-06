import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn});

  final VoidCallback onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool wide = MediaQuery.sizeOf(context).width >= 880;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (wide) const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 6,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildCard(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SessionController session = context.watch<SessionController>();
    final bool busy = session.busy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 18),
              Text('تسجيل الدخول', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'أدخل بيانات حسابك للوصول إلى مساحة العمل',
                style: theme.textTheme.bodySmall,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                autofillHints: const <String>[AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.mail_outline, size: 20),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'أدخل البريد الإلكتروني';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                enabled: !busy,
                obscureText: _obscurePassword,
                textDirection: TextDirection.ltr,
                autofillHints: const <String>[AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    tooltip: _obscurePassword
                        ? 'إظهار كلمة المرور'
                        : 'إخفاء كلمة المرور',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'أدخل كلمة المرور';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Checkbox(
                    value: _remember,
                    onChanged: busy
                        ? null
                        : (bool? value) =>
                              setState(() => _remember = value ?? true),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: busy
                          ? null
                          : () => setState(() => _remember = !_remember),
                      child: Text(
                        'تذكرني على هذا الجهاز',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text('تسجيل الدخول'),
              ),
              const SizedBox(height: 14),
              Text(
                'الحسابات محفوظة محلياً في قاعدة البيانات داخل المتصفح.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _error = null);

    final String? error = await context.read<SessionController>().login(
      email: _emailController.text,
      password: _passwordController.text,
      remember: _remember,
    );

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    widget.onLoggedIn();
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      color: AppColors.brand,
      padding: const EdgeInsets.all(46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            AppInfo.name,
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'نظام عمل محلي يعمل داخل المتصفح بقاعدة بيانات SQLite، '
            'بدون خادم خارجي.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 30),
          const _Feature(
            icon: Icons.shield_outlined,
            text: 'صلاحيات مختلفة لكل حساب',
          ),
          const SizedBox(height: 14),
          const _Feature(
            icon: Icons.storage_outlined,
            text: 'بيانات تبقى بعد تحديث الصفحة',
          ),
          const SizedBox(height: 14),
          const _Feature(
            icon: Icons.devices_outlined,
            text: 'مناسب لسطح المكتب والمتصفح',
          ),
          const Spacer(),
          Text(
            'المرحلة 1 · تسجيل الدخول · v${AppInfo.version}',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.92)),
          ),
        ),
      ],
    );
  }
}
