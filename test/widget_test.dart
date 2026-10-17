import 'package:flutter_test/flutter_test.dart';
import 'package:sound_marketplace_app/main.dart';

void main() {
  testWidgets('SoundMarketplaceApp loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SoundMarketplaceApp());
    await tester.pump();

    // Verify main app renders auth guard or app title
    expect(find.text('SOUND MARKETPLACE'), findsWidgets);
  });
}
