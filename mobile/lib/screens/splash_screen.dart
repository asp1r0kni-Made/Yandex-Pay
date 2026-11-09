import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import 'register_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = "Проверяем обновления…";
  double? _progress;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      final shouldUpdate = await _askToUpdate(update);
      if (shouldUpdate) {
        setState(() => _status = "Загружаем обновление ${update.version}…");
        await UpdateService.downloadAndInstall(
          update,
          onProgress: (p) => setState(() => _progress = p),
        );
        // После открытия системного установщика просто остаёмся на экране —
        // пользователь завершит установку сам.
        return;
      }
    }
    setState(() => _status = "Загрузка…");
    await _goNext();
  }

  Future<bool> _askToUpdate(UpdateInfo update) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text("Доступно обновление ${update.version}"),
            content: Text(
              update.releaseNotes.isEmpty
                  ? "Рекомендуем обновиться для стабильной работы."
                  : update.releaseNotes,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Позже"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Обновить"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _goNext() async {
    final token = await ApiService.instance.getToken();
    if (!mounted) return;
    if (token != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.call_split_rounded, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                "Сплит Банк",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 32),
              if (_progress != null)
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white24,
                    color: AppColors.accent,
                  ),
                )
              else
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                ),
              const SizedBox(height: 14),
              Text(_status, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
