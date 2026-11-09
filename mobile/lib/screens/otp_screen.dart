import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:local_auth/local_auth.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final String? debugCode;
  final bool isRegistration;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.isRegistration,
    this.debugCode,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _localAuth = LocalAuthentication();
  bool _loading = false;
  String? _error;
  String _code = "";

  Future<void> _verify(String code) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.instance.verifyCode(widget.phone, code);
      await _offerBiometrics();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _offerBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported || !mounted) return;

      final enable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("Включить вход по биометрии?"),
          content: const Text(
            "В следующий раз сможете входить по отпечатку пальца или Face ID, без ввода кода.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Не сейчас")),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Включить")),
          ],
        ),
      );
      if (enable == true) {
        await _localAuth.authenticate(
          localizedReason: "Подтвердите, чтобы включить вход по биометрии",
          options: const AuthenticationOptions(biometricOnly: true),
        );
        // В реальном проекте здесь нужно сохранить флаг
        // "биометрия включена" в secure storage и в дальнейшем
        // использовать local_auth на экране входа вместо кода.
      }
    } catch (_) {
      // Биометрия недоступна или отменена — это нормально, просто продолжаем.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(height: 8),
              const Text("Введите код", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                "Мы отправили 4-значный код на ${widget.phone}",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              if (widget.debugCode != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Демо-код (нет SMS-провайдера): ${widget.debugCode}",
                  style: const TextStyle(color: AppColors.accent, fontSize: 13),
                ),
              ],
              const SizedBox(height: 32),
              PinCodeTextField(
                appContext: context,
                length: 4,
                onChanged: (v) => _code = v,
                onCompleted: _verify,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(14),
                  fieldHeight: 56,
                  fieldWidth: 56,
                  activeColor: AppColors.primaryLight,
                  selectedColor: AppColors.primaryLight,
                  inactiveColor: AppColors.surfaceAlt,
                  activeFillColor: AppColors.surfaceAlt,
                  inactiveFillColor: AppColors.surfaceAlt,
                  selectedFillColor: AppColors.surfaceAlt,
                ),
                enableActiveFill: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 24),
              if (_loading) const Center(child: CircularProgressIndicator()),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => _verify(_code),
                  child: const Text("Подтвердить"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
