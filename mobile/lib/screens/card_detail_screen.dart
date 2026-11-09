import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../theme.dart';
import '../services/api_service.dart';

class CardDetailScreen extends StatefulWidget {
  final dynamic card;
  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  bool _revealed = false;
  bool _frozen = false;
  final _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _frozen = widget.card["frozen"] == true;
  }

  Future<void> _reveal() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck) {
        final ok = await _localAuth.authenticate(
          localizedReason: "Подтвердите личность, чтобы увидеть номер карты",
          options: const AuthenticationOptions(biometricOnly: true),
        );
        if (!ok) return;
      }
    } catch (_) {
      // Если биометрия недоступна — просто показываем (демо-режим).
    }
    setState(() => _revealed = true);
  }

  Future<void> _toggleFreeze() async {
    try {
      final res = await ApiService.instance.toggleFreeze(widget.card["id"] as int);
      setState(() => _frozen = res["frozen"] == true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _copy(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label скопирован")));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final number = card["card_number"] as String? ?? "";
    final masked = "•••• •••• •••• ${number.length >= 4 ? number.substring(number.length - 4) : ''}";

    return Scaffold(
      appBar: AppBar(title: Text(card["label"] ?? "Карта")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 200,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.call_split_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text("Сплит Банк", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                Text(
                  _revealed ? number : masked,
                  style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 2),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _revealed ? "До ${card["expiry"]}" : "До ••/••",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      _revealed ? "CVV ${card["cvv"]}" : "CVV •••",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_revealed)
            ElevatedButton.icon(
              onPressed: _reveal,
              icon: const Icon(Icons.fingerprint),
              label: const Text("Показать реквизиты"),
            )
          else
            Column(
              children: [
                _ReqRow(label: "Номер карты", value: number, onCopy: () => _copy(number, "Номер")),
                _ReqRow(label: "Срок действия", value: card["expiry"] ?? "", onCopy: () => _copy(card["expiry"] ?? "", "Срок")),
                _ReqRow(label: "CVV", value: card["cvv"] ?? "", onCopy: () => _copy(card["cvv"] ?? "", "CVV")),
              ],
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _toggleFreeze,
            icon: Icon(_frozen ? Icons.ac_unit : Icons.ac_unit_outlined),
            label: Text(_frozen ? "Разморозить карту" : "Заморозить карту"),
          ),
        ],
      ),
    );
  }
}

class _ReqRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _ReqRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          IconButton(onPressed: onCopy, icon: const Icon(Icons.copy, size: 20)),
        ],
      ),
    );
  }
}
