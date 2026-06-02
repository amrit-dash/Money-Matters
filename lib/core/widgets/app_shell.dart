import 'package:flutter/material.dart';

import '../../features/dashboard/dashboard_repository.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/recovery/recovery_repository.dart';
import '../../features/recovery/recovery_screen.dart';
import '../../features/review/review_repository.dart';
import '../../features/review/review_screen.dart';
import '../../ingest/ingest_queue_drain.dart';
import '../../services/category_service.dart';
import '../../services/payment_source_service.dart';
import '../../services/user_data_deletion_service.dart';
import '../auth/auth_service.dart';

/// Main signed-in shell: bottom nav across home, inbox, recovery, and profile.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.dashboardRepository,
    required this.reviewRepository,
    required this.categoryService,
    required this.paymentSourceService,
    required this.recoveryRepository,
    required this.queueDrain,
    required this.authService,
    required this.userDataDeletionService,
  });

  final DashboardRepository dashboardRepository;
  final ReviewRepository reviewRepository;
  final CategoryService categoryService;
  final PaymentSourceService paymentSourceService;
  final RecoveryRepository recoveryRepository;
  final IngestQueueDrain queueDrain;
  final AuthService authService;
  final UserDataDeletionService userDataDeletionService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _inboxCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshInboxBadge();
  }

  Future<void> _refreshInboxBadge() async {
    final count = await widget.reviewRepository.needsInputCount();
    if (!mounted) return;
    setState(() => _inboxCount = count);
  }

  void _onTabSelected(int index) {
    setState(() => _index = index);
    if (index == 0 || index == 1) _refreshInboxBadge();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              repository: widget.dashboardRepository,
              reviewRepository: widget.reviewRepository,
              categoryService: widget.categoryService,
              paymentSourceService: widget.paymentSourceService,
              recoveryRepository: widget.recoveryRepository,
              queueDrain: widget.queueDrain,
              embeddedInShell: true,
              onInboxCountChanged: _refreshInboxBadge,
            ),
            ReviewScreen(
              repository: widget.reviewRepository,
              embeddedInShell: true,
              onListChanged: _refreshInboxBadge,
            ),
            RecoveryScreen(
              repository: widget.recoveryRepository,
              embeddedInShell: true,
            ),
            ProfileScreen(
              authService: widget.authService,
              userDataDeletionService: widget.userDataDeletionService,
              embeddedInShell: true,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onTabSelected,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _inboxCount > 0,
                label: Text('$_inboxCount'),
                child: const Icon(Icons.inbox_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _inboxCount > 0,
                label: Text('$_inboxCount'),
                child: const Icon(Icons.inbox),
              ),
              label: 'Inbox',
            ),
            const NavigationDestination(
              icon: Icon(Icons.cloud_sync_outlined),
              selectedIcon: Icon(Icons.cloud_sync),
              label: 'Recovery',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
