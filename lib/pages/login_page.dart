import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final auth = Provider.of<AuthService>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    // set loading = true (safe to call because the widget is mounted now)
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await auth.signInWithUsername(
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await auth.signUpWithUsername(
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
      // On success we typically let auth-state listener navigate away,
      // so we do not call setState here (and we definitely don't call it if not mounted).
    } catch (ex) {
      // Check mounted BEFORE calling setState
      if (!mounted) return;
      setState(() {
        _error = ex.toString();
      });
    } finally {
      // Only call setState if widget is still mounted
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Sign in' : 'Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Enter at least 3 chars' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
              ),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _loading ? null : _handleSubmit,
                child: _loading ? const CircularProgressIndicator() : Text(_isLogin ? 'Sign in' : 'Create account'),
              ),
              TextButton(
                onPressed: () {
                  // toggling local state is fine
                  if (!mounted) return;
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(_isLogin ? 'Create account' : 'Have an account? Sign in'),
              ),
            ]),
          )
        ]),
      ),
    );
  }
}
