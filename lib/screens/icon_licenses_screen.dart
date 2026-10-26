import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';

class IconLicensesScreen extends StatelessWidget {
  const IconLicensesScreen({super.key});
  static final Future<String> _notice = rootBundle.loadString(
    'THIRD_PARTY_NOTICES.md',
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Giấy phép icon'),
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const MorphIcon(AppGlyph.arrowLeft),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<String>(
        future: _notice,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: NoteLine(
                'Không đọc được giấy phép. Xem THIRD_PARTY_NOTICES.md trong mã nguồn.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Đang tải giấy phép…'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          );
        },
      ),
    ),
  );
}
