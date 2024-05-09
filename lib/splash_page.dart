// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:si_bestie/core/config/assets_constants.dart';
import 'package:si_bestie/core/extension/context.dart';
import 'package:si_bestie/core/navigation/route.dart';
import 'package:si_bestie/core/util/secure_storage.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final SecureStorage secureStorage = SecureStorage();

  @override
  void initState() {
    super.initState();
    _navigateToNextPage();
  }

  Future<void> _navigateToNextPage() async {
    await Future.delayed(const Duration(seconds: 3), () async {
      final String? apiKey = await secureStorage.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        AppRoute.welcome.go(context);
      } else {}
      AppRoute.welcome.go(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          // image and text
          Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AssetConstants.sibestieLogo,
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [
                    context.colorScheme.primary,
                    context.colorScheme.secondary,
                  ],
                ).createShader(bounds);
              },
              child: const Text(
                'SiBestie',
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
