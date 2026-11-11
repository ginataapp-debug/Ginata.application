import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginata_app/screens/guest_forms_screen.dart';
import 'package:ginata_app/services/api_service.dart';
import 'package:ginata_app/services/notification_center.dart';
import 'package:ginata_app/theme/ginata_theme.dart';
import 'package:ginata_app/theme/ginata_ui.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _phone(WidgetTester tester, {double width = 360}) async {
  tester.view.physicalSize = Size(width, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'test-token';
  });

  testWidgets('status chip and header truncate instead of overflowing on narrow screens', (tester) async {
    await _phone(tester, width: 280);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: buildGinataTheme(),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(GSpace.md),
          child: Column(
            children: [
              GSectionHeader(
                title: 'An exceptionally long section title that would normally overflow a small phone',
                subtitle: 'Subtitle text that also keeps going and going to make sure it wraps nicely',
                trailing: GStatusChip(label: 'Pending review', tone: GStatusTone.warning, icon: Icons.schedule),
              ),
              GInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: 'a.very.long.email.address.for.a.guest@an-extremely-long-domain-name.example.com',
              ),
            ],
          ),
        ),
      ),
    ));
    expect(find.text('PENDING REVIEW'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Status: Pending review')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('empty and error states render their content and retry action', (tester) async {
    await _phone(tester);
    var retried = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const GEmptyState(icon: Icons.inbox, title: 'Nothing here', message: 'Items will appear soon.'),
            GErrorState(message: 'Could not reach the Ginata server.', onRetry: () => retried++),
          ],
        ),
      ),
    ));
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
    expect(tester.takeException(), isNull);
  });

  test('host notifications parse safely from the API', () {
    final n = HostNotification.fromJson({
      'id': 'n1',
      'kind': 'guest_check_in',
      'title': 'New guest check-in received!',
      'body': 'Amina Otieno · Garden Villa · Check-in 14 Nov 2026',
      'entity_type': 'google_form_response',
      'entity_id': 'r1',
      'read_at': null,
      'created_at': '2026-11-12T08:30:00',
    });
    expect(n.isRead, isFalse);
    expect(n.isGuestUpdate, isTrue);
    expect(n.entityId, 'r1');
    expect(HostNotification.fromJson({'id': 2}).title, 'Notification');
  });

  testWidgets('guest check-ins screen shows synced and unmatched Google responses on a phone', (tester) async {
    await _phone(tester);
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/integrations/google/status')) {
        return _json({'connected': true, 'email': 'host.with.a.long.address@gmail.com', 'scopes': []});
      }
      if (path.endsWith('/guest-forms/google/status')) {
        return _json({
          'google_connected': true,
          'form_linked': true,
          'form_title': 'Garden Villa pre-arrival check-in',
          'responder_url': 'https://docs.google.com/forms/d/e/abc/viewform',
          'edit_url': 'https://docs.google.com/forms/d/abc/edit',
          'sync_status': 'connected',
          'last_sync_at': '2026-11-12T08:30:00',
          'realtime': 'polling',
          'poll_seconds': 60,
          'counts': {'synced': 1, 'pending_review': 1, 'failed': 0, 'processing': 0},
        });
      }
      if (path.endsWith('/guest-forms/google/responses')) {
        return _json([
          {
            'id': 'r1',
            'google_response_id': 'g1',
            'match_status': 'unmatched',
            'sync_status': 'pending_review',
            'match_reason': 'No booking matched this guest yet.',
            'guest_name': 'Wanjiru Kamau-Ochieng',
            'guest_email': 'wanjiru.kamau.ochieng@example.com',
            'guest_phone': '+254 700 000 000',
            'booking_reference': 'GIN-2026-000123',
            'check_in_date': '2026-11-20',
            'answers': [
              {'question': 'ID / Passport number', 'answer': '*****5678'},
            ],
            'submitted_at': '2026-11-12T08:29:00',
            'created_at': '2026-11-12T08:30:00',
          },
          {
            'id': 'r2',
            'google_response_id': 'g2',
            'reservation_id': 'res-1',
            'match_status': 'matched',
            'sync_status': 'synced',
            'guest_name': 'Daniel Mwangi',
            'check_in_date': '2026-11-14',
            'created_at': '2026-11-12T08:00:00',
          },
        ]);
      }
      return _json([]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: buildGinataTheme(), home: const GuestFormsScreen()));
      await tester.pumpAndSettle();
    }, () => client);

    expect(find.text('Garden Villa pre-arrival check-in'), findsOneWidget);
    expect(find.text('1 SYNCED'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Match to booking'), 200);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('NEEDS MATCH'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Daniel Mwangi'), 200);
    expect(find.text('Daniel Mwangi'), findsOneWidget);
    expect(find.textContaining('5678'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest check-ins screen explains when the server lacks Google sync', (tester) async {
    await _phone(tester);
    final client = MockClient((request) async {
      if (request.url.path.contains('google')) return _json({'detail': 'Not Found'}, 404);
      return _json([]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: buildGinataTheme(), home: const GuestFormsScreen()));
      await tester.pumpAndSettle();
    }, () => client);

    expect(find.textContaining('not available on the server yet'), findsOneWidget);
    expect(find.text('UNAVAILABLE'), findsOneWidget);
    expect(find.text('No guest responses yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
