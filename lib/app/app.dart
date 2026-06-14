import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/theme.dart';
import '../core/config/app_constants.dart';
import 'router.dart';

class KlasivoApp extends ConsumerWidget {
  const KlasivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Klasivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: klasivoRouter,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr, // Will be replaced with RTL-aware logic
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
