import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/specialization_service.dart';
import '../widgets/app_navbar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _fullName = '';
  String _specialization = '';
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      appBar: const AppNavbar(title: 'Sign Up'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (val) => val != null && val.isNotEmpty ? null : 'Required',
                  onSaved: (val) => _fullName = val ?? '',
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                  onSaved: (val) => _email = val ?? '',
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (val) => val != null && val.length >= 4 ? null : 'Password too short',
                  onSaved: (val) => _password = val ?? '',
                ),
                FutureBuilder<List<String>>(
                  future: SpecializationService.fetchSpecializations(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final specializations = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Specialization'),
                        items: specializations.map((s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        )).toList(),
                        validator: (val) => val != null && val.isNotEmpty ? null : 'Required',
                        onChanged: (val) => setState(() { _specialization = val ?? ''; }),
                        onSaved: (val) => _specialization = val ?? '',
                        value: _specialization.isNotEmpty ? _specialization : null,
                      );
                    }
                    return const Text('No specializations found');
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 24),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          _formKey.currentState!.save();
                          setState(() { _loading = true; _error = null; });
                          final result = await authService.signup(_fullName, _email, _password, _specialization);
                          setState(() { _loading = false; _error = result; });
                          if (result == null && context.mounted) {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        },
                        child: const Text('Sign up'),
                      ),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Already have an account? Log in'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
