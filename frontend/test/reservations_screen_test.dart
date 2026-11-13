import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/screens/reservations_screen.dart';
import 'package:ginata_app/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reservation search matches guest and property details', (
    tester,
  ) async {
    final previousClient = ApiService.client;
    final client = MockClient((_) async {
      return http.Response(
        jsonEncode([
          _reservation(
            id: 'reservation-1',
            guest: 'Amina Kariuki',
            property: 'Villa Maji',
            reference: 'GIN-101',
          ),
          _reservation(
            id: 'reservation-2',
            guest: 'Brian Mwangi',
            property: 'Garden Loft',
            reference: 'GIN-102',
          ),
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    ApiService.client = client;
    addTearDown(() {
      ApiService.client = previousClient;
      client.close();
    });

    await tester.pumpWidget(
      MaterialApp(home: ReservationsScreen(onOpenNewBooking: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Kariuki'), findsOneWidget);
    expect(find.text('Brian Mwangi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'villa maji');
    await tester.pumpAndSettle();

    expect(find.text('Amina Kariuki'), findsOneWidget);
    expect(find.text('Brian Mwangi'), findsNothing);
  });
}

Map<String, dynamic> _reservation({
  required String id,
  required String guest,
  required String property,
  required String reference,
}) {
  final names = guest.split(' ');
  return {
    'id': id,
    'primary_guest': {'first_name': names.first, 'last_name': names.last},
    'property': {'name': property},
    'unit': {'name': 'Main Suite'},
    'booking_source': 'direct',
    'booking_reference': reference,
    'reservation_status': 'confirmed',
    'payment_status': 'unpaid',
    'guest_info_status': 'pending',
    'check_in_date': '2026-12-10',
    'check_out_date': '2026-12-12',
    'number_of_nights': 2,
    'number_of_guests': 2,
    'total_amount': 25000,
    'balance_due': 25000,
    'has_conflict': false,
    'has_agent': false,
  };
}
