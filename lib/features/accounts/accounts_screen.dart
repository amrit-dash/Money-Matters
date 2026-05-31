import 'package:flutter/material.dart';

import 'package:money_matters/models/payment_source.dart';

import '../../services/payment_source_service.dart';
import '../../services/ingest_parse_pipeline.dart';
import '../../core/theme/app_theme.dart';
import 'payment_source_widgets.dart';

/// Post-onboarding CRUD for banks and cards.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({
    super.key,
    required this.paymentSourceService,
    this.parsePipeline,
  });

  final PaymentSourceService paymentSourceService;
  final IngestParsePipeline? parsePipeline;

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
      final backlog = await widget.parsePipeline?.processBacklog();
      if (!mounted) return;
      setState(() {
        _sources = updated;
        _saving = false;
      });
      final rematched = backlog?.rematched ?? 0;
      final reclassified = backlog?.reclassified ?? 0;
      var message = 'Saved to cloud';
      if (rematched > 0 || reclassified > 0) {
        final bits = <String>[];
        if (rematched > 0) bits.add('$rematched matched');
        if (reclassified > 0) bits.add('$reclassified auto-classified');
        message = 'Saved — ${bits.join(', ')}';
      } else if (backlog?.classifyNeedsConfig == true) {
        message = 'Saved — LLM needs GEMINI_API_KEY (see USER-FIX.md)';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
                      'Banks and cards that send debit/credit SMS. Changes save automatically.',
                  showWalletNote: true,
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
      padding: const EdgeInsets.all(AppSpacing.page),
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
