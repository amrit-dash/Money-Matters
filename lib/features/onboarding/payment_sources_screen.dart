import 'package:flutter/material.dart';

import '../accounts/payment_source_widgets.dart';
import '../../core/widgets/app_ui.dart';
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.page,
                  AppSpacing.page,
                  0,
                ),
                child: const OnboardingStepIndicator(
                  currentStep: 1,
                  totalSteps: 3,
                  labels: ['Sign in', 'Accounts', 'Connect SMS'],
                ),
              ),
              Expanded(
                child: PaymentSourcesBody(
                  sources: state.paymentSources,
                  onSourcesChanged: state.setPaymentSources,
                  introText:
                      'Add at least one bank or card that sends debit/credit SMS.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: FilledButton(
                  onPressed: state.paymentSourcesComplete
                      ? () async {
                          try {
                            await state.persistPaymentSources(
                              paymentSourceService,
                            );
                            if (!context.mounted) return;
                            onContinue();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not save to cloud: $e'),
                              ),
                            );
                          }
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
