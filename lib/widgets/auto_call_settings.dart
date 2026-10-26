import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import 'app_design.dart';
import 'morph_icon.dart';

class AutoCallSettings extends StatefulWidget {
  const AutoCallSettings({super.key, required this.controller});
  final AppController controller;
  @override
  State<AutoCallSettings> createState() => _AutoCallSettingsState();
}

class _AutoCallSettingsState extends State<AutoCallSettings> {
  bool _busy = false;
  String? _error;
  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    final c = widget.controller;
    if (enabled) {
      if (c.contacts.isEmpty) {
        setState(() => _error = 'Lưu liên hệ trước khi bật tự gọi.');
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bật tự gọi khi SOS?'),
          content: Text(
            'Khi hết thời gian xác nhận hoặc bấm gửi SOS, app sẽ gọi ${c.contacts.first.name} · ${c.contacts.first.phone}, đồng thời gửi SMS đến danh sách đã lưu. App yêu cầu loa ngoài để bạn nói chuyện.\n\nCuộc gọi có thể tính phí. Hãy chọn SIM gọi mặc định trên điện thoại. Bật tùy chọn này chưa thực hiện cuộc gọi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ĐỂ SAU'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('BẬT TỰ GỌI'),
            ),
          ],
        ),
      );
      if (!mounted || accepted != true) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await c.setAutoCall(enabled);
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MorphIcon(
                  AppGlyph.phone,
                  alternate: AppGlyph.phoneCall,
                  active: c.autoCallEnabled,
                  color: context.colors.lime,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tự gọi cùng lúc gửi SOS',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  key: const Key('toggleAutoCall'),
                  value: c.autoCallEnabled && c.callPermission,
                  onChanged: _busy ? null : _toggle,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              c.contacts.isEmpty
                  ? 'Chưa có số ưu tiên để gọi.'
                  : 'Gọi đến: ${c.contacts.first.name} · ${c.contacts.first.phone}',
            ),
            const SizedBox(height: 10),
            Text(
              'Đổi số ưu tiên bằng nút điện thoại ở mục Liên hệ. Chỉ gọi một số, không tự gọi lại. SMS vẫn gửi độc lập nếu cuộc gọi lỗi. Không tự gọi 113/114/115.',
              style: TextStyle(
                color: context.colors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.colors.orange),
                ),
              ),
          ],
        ),
      );
    },
  );
}
