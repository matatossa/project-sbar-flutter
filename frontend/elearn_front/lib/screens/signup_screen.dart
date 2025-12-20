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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter your name',
                            prefixIcon: Icon(Icons.person_outlined),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF7F9FA),
                          ),
                          validator: (val) => val != null && val.isNotEmpty ? null : 'Required',
                          onSaved: (val) => _fullName = val ?? '',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF7F9FA),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                          onSaved: (val) => _email = val ?? '',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock_outlined),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF7F9FA),
                          ),
                          obscureText: true,
                          validator: (val) => val != null && val.length >= 4 ? null : 'Password too short',
                          onSaved: (val) => _password = val ?? '',
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<List<String>>(
                          future: SpecializationService.fetchSpecializations(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 60,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              final specializations = snapshot.data!;
                              return DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Specialization',
                                  hintText: 'Select specialization',
                                  prefixIcon: Icon(Icons.school_outlined),
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Color(0xFFF7F9FA),
                                ),
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
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No specializations found',
                                      style: TextStyle(color: Colors.orange[700], fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(color: Colors.red[700], fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0056D2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Sign Up',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                          child: const Text(
                            'Already have an account? Log in',
                            style: TextStyle(color: Color(0xFF0056D2)),
                          ),
                        ),
                      ],
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
