import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'card_detail_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _cards = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await ApiService.instance.listCards();
      setState(() => _cards = cards);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _issueCard() async {
    try {
      await ApiService.instance.issueCard(label: "Цифровая карта");
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _logout() async {
    await ApiService.instance.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Сплит Банк", style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    ),
                  const Text("Мои карты", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  if (_cards.isEmpty)
                    _EmptyCardsState(onIssue: _issueCard)
                  else
                    ..._cards.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CardTile(
                          card: c,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CardDetailScreen(card: c)),
                          ).then((_) => _load()),
                        ),
                      ),
                    ),
                  if (_cards.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _issueCard,
                      icon: const Icon(Icons.add),
                      label: const Text("Выпустить ещё одну карту"),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EmptyCardsState extends StatelessWidget {
  final VoidCallback onIssue;
  const _EmptyCardsState({required this.onIssue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text("У вас пока нет карт", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            "Выпустите виртуальную демо-карту за пару секунд",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onIssue, child: const Text("Выпустить карту")),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final dynamic card;
  final VoidCallback onTap;
  const _CardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final frozen = card["frozen"] == true;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(card["label"] ?? "Карта", style: const TextStyle(color: Colors.white70)),
                if (frozen)
                  const Icon(Icons.ac_unit, color: Colors.white70, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              card["masked_number"] ?? "",
              style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 2, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${card["balance"] ?? 0} ₽",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(card["expiry"] ?? "", style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
