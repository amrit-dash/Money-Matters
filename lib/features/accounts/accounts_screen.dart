import 'package:flutter/material.dart';

import 'package:money_matters/models/payment_source.dart';

import '../../services/payment_source_service.dart';
import 'payment_source_widgets.dart';

/// Post-onboarding CRUD for banks and cards.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.paymentSourceService,
  });

  final PaymentSourceService paymentSourceService;

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<PaymentSource> _sources = [];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.paymentSourceService.loadAll();
      if (!mounted) return;
      setState(() {
        _sources = loaded;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _persist(List<PaymentSource> updated) async {
    if (!hasBankOrCard(updated)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one bank or card before saving.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.paymentSourceService.saveAll(updated);
      if (!mounted) return;
      setState(() {
        _sources = updated;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to cloud')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save to cloud: $e')),
      );
    }
  }

  void _onSourcesChanged(List<PaymentSource> updated) {
    _persist(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorBody(message: _loadError!, onRetry: _load)
              : PaymentSourcesBody(
                  sources: _sources,
                  onSourcesChanged: _onSourcesChanged,
                  introText:
                      'Banks and cards that send you debit/credit SMS. '
                      'Changes save automatically.',
                ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
