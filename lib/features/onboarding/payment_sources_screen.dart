import 'package:flutter/material.dart';

import '../accounts/payment_source_widgets.dart';
import 'onboarding_state.dart';
import '../../services/payment_source_service.dart';

class PaymentSourcesScreen extends StatelessWidget {
  const PaymentSourcesScreen({
    super.key,
    required this.state,
    required this.paymentSourceService,
    required this.onContinue,
  });

  final OnboardingState state;
  final PaymentSourceService paymentSourceService;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment sources')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                child: PaymentSourcesBody(
                  sources: state.paymentSources,
                  onSourcesChanged: state.setPaymentSources,
                  introText:
                      'Add at least one bank or card that sends you debit/credit SMS. '
                      'You can manage them later in Profile → Accounts.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: state.paymentSourcesComplete
                      ? () async {
                          await state.persistPaymentSources(
                            paymentSourceService,
                          );
                          onContinue();
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
