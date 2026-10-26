import '../widgets/morph_icon.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_controller.dart';
import '../services/device_safety_bridge.dart';
import '../widgets/app_design.dart';
import '../widgets/emergency_services.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _phone;
  bool _dirty = false, _busy = false;
  String? _editingId;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.controller.contactName);
    _phone = TextEditingController(text: widget.controller.contactPhone);
    _editingId = widget.controller.contacts.firstOrNull?.id;
    widget.controller.addListener(_restoreSavedContact);
  }

  void _restoreSavedContact() {
    if (_dirty || !mounted) return;
    _editingId = widget.controller.contacts.firstOrNull?.id;
    if (_name.text != widget.controller.contactName) {
      _name.text = widget.controller.contactName;
    }
    if (_phone.text != widget.controller.contactPhone) {
      _phone.text = widget.controller.contactPhone;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_restoreSavedContact);
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final saved = await widget.controller.saveContact(
      _name.text,
      normalizePhone(_phone.text),
      id: _editingId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (saved) {
        _dirty = true;
        _editingId = null;
        _name.clear();
        _phone.clear();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Đã lưu liên hệ trên thiết bị.'
              : widget.controller.deviceError.isNotEmpty
              ? widget.controller.deviceError
              : 'Chưa lưu được liên hệ. Hãy kiểm tra bản Android và thử lại.',
        ),
      ),
    );
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickContact() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final contact = await widget.controller.device.pickContact();
      if (!mounted || contact == null) return;
      setState(() {
        _dirty = true;
        _name.text = contact['name'] as String? ?? '';
        _phone.text = normalizePhone(contact['phone'] as String? ?? '');
      });
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ??
                  'Không mở được danh bạ. Bạn có thể nhập số thủ công.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: ListView(
      key: const PageStorageKey('contact'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        const PageHeading(
          index: '03 / VÒNG TRÒN TIN CẬY',
          title: 'Những người thân.\nLuôn bên bạn.',
          description: 'SOS gửi đến tất cả liên hệ đã lưu, tối đa 10 người.',
        ),
        SurfacePanel(
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: context.colors.lime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MorphIcon(
                  AppGlyph.heart,
                  alternate: AppGlyph.shieldCheck,
                  active: widget.controller.contactPhone.isNotEmpty,
                  color: context.colors.background,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.controller.contactName.isEmpty
                          ? 'Người liên hệ khẩn cấp'
                          : widget.controller.contactName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.controller.contactPhone.isEmpty
                          ? 'Chưa thêm thông tin'
                          : widget.controller.contactPhone,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('DANH SÁCH NHẬN SOS'),
        for (final contact in widget.controller.contacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SurfacePanel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          contact.phone,
                          style: TextStyle(color: context.colors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: contact.id == widget.controller.contacts.first.id
                        ? 'Số ưu tiên gọi SOS'
                        : 'Ưu tiên gọi ${contact.name}',
                    icon: MorphIcon(
                      AppGlyph.phoneCall,
                      size: 19,
                      color: contact.id == widget.controller.contacts.first.id
                          ? context.colors.lime
                          : context.colors.muted,
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            final saved = await widget.controller
                                .setCallPriority(contact.id);
                            if (!mounted) return;
                            setState(() => _busy = false);
                            if (!saved) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(widget.controller.deviceError),
                                ),
                              );
                            }
                          },
                  ),
                  IconButton(
                    tooltip: 'Sửa ${contact.name}',
                    icon: const MorphIcon(AppGlyph.sliders, size: 19),
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _editingId = contact.id;
                            _dirty = true;
                            _name.text = contact.name;
                            _phone.text = contact.phone;
                          }),
                  ),
                  IconButton(
                    tooltip: 'Xóa ${contact.name}',
                    icon: const MorphIcon(AppGlyph.close, size: 19),
                    onPressed: _busy
                        ? null
                        : () async {
                            final accepted = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Xóa liên hệ?'),
                                content: Text(
                                  'Bỏ ${contact.name} khỏi danh sách nhận SOS?${widget.controller.autoCallEnabled && contact.id == widget.controller.contacts.first.id ? '\n\nĐây là số ưu tiên gọi. Người tiếp theo trong danh sách sẽ trở thành số gọi SOS.' : ''}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('GIỮ LẠI'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('XÓA'),
                                  ),
                                ],
                              ),
                            );
                            if (accepted != true || !mounted) return;
                            setState(() => _busy = true);
                            final removed = await widget.controller
                                .removeContact(contact.id);
                            if (!mounted) return;
                            setState(() {
                              _busy = false;
                              if (removed && _editingId == contact.id) {
                                _editingId = null;
                                _dirty = true;
                                _name.clear();
                                _phone.clear();
                              }
                            });
                            if (!removed) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(widget.controller.deviceError),
                                ),
                              );
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          key: const Key('addEmergencyContact'),
          onPressed: _busy
              ? null
              : () => setState(() {
                  _editingId = null;
                  _dirty = true;
                  _name.clear();
                  _phone.clear();
                }),
          child: const Text('THÊM LIÊN HỆ MỚI'),
        ),
        const SectionLabel('THÔNG TIN LIÊN HỆ'),
        ActionButton(
          key: const Key('pickContact'),
          label: _busy ? 'ĐANG XỬ LÝ…' : 'CHỌN TỪ DANH BẠ',
          icon: AppGlyph.bookUser,
          outlined: true,
          onPressed: _pickContact,
        ),
        const SizedBox(height: 12),
        const NoteLine(
          'Bạn chọn một số trong danh bạ Android. App chỉ đọc liên hệ bạn chọn; bấm LƯU để xác nhận.',
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const Key('contactName'),
          controller: _name,
          onChanged: (_) => _dirty = true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            labelText: 'Họ tên',
            prefixIcon: MorphIcon(AppGlyph.user),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Hãy nhập họ tên.' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const Key('contactPhone'),
          controller: _phone,
          onChanged: (_) => _dirty = true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          onFieldSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixIcon: MorphIcon(AppGlyph.phone),
          ),
          validator: (v) => validEmergencyPhone(v ?? '')
              ? null
              : 'Nhập 9–15 chữ số, có thể bắt đầu bằng +.',
        ),
        const SizedBox(height: 24),
        ActionButton(
          key: const Key('saveContact'),
          label: _busy ? 'ĐANG LƯU…' : 'LƯU LIÊN HỆ',
          onPressed: _save,
        ),
        const SizedBox(height: 22),
        const NoteLine(
          'Liên hệ được lưu trên thiết bị Android để dùng ở lần mở sau. Chọn hoặc lưu số không gửi SMS. SOS thật chỉ hoạt động sau khi bạn bật trong Cài đặt.',
        ),
        const SizedBox(height: 20),
        EmergencyServices(device: widget.controller.device),
      ],
    ),
  );
}
