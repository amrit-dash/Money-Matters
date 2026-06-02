import 'package:flutter_test/flutter_test.dart';
import 'package:money_matters/services/user_data_deletion_service.dart';

void main() {
  group('UserDataDeletionService.userSubcollectionNames', () {
    test('covers all documented Firestore user subcollections', () {
      expect(
        UserDataDeletionService.userSubcollectionNames,
        containsAll([
          'transactions',
          'raw_ingests',
          'parse_jobs',
          'payment_sources',
          'categories',
          'device_tokens',
          'fcm_tokens',
        ]),
      );
      expect(UserDataDeletionService.userSubcollectionNames.length, 7);
    });
  });
}
