import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/motion_api.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';

String roleLabel(String role) => switch (role) {
  'admin' => 'Quản trị viên',
  'staff' => 'Nhân viên hỗ trợ',
  _ => 'Người dùng',
};
String statusLabel(String status) => switch (status) {
  'safe' => 'Đã an toàn',
  'needs_help' => 'Cần hỗ trợ',
  'resolved' => 'Đã hỗ trợ',
  _ => 'Chờ xác nhận',
};
String cloudTime(dynamic value) {
  final d = DateTime.fromMillisecondsSinceEpoch(value as int).toLocal();
  String pad(int n) => '$n'.padLeft(2, '0');
  return '${pad(d.day)}/${pad(d.month)}/${d.year} ${pad(d.hour)}:${pad(d.minute)}';
}

class CloudDashboardScreen extends StatefulWidget {
  const CloudDashboardScreen({super.key, required this.api, this.controller});
  final MotionApi api;
  final AppController? controller;
  @override
  State<CloudDashboardScreen> createState() => _CloudDashboardScreenState();
}

class _CloudDashboardScreenState extends State<CloudDashboardScreen> {
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> users = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.list('/users');
      if (mounted) setState(() => users = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted && widget.api.signedIn) await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _profile() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CloudEditor(
        title: 'Hồ sơ của bạn',
        fields: const [CloudField('name', 'Tên hiển thị', max: 80)],
        initial: widget.api.user!,
      ),
    );
    if (result != null) {
      await _run(() => widget.api.updateName(result['name'] as String));
    }
  }

  Future<void> _editUser([Map<String, dynamic>? user]) async {
    final staff = users
        .where((u) => u['role'] == 'staff' && u['active'] == true)
        .toList();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CloudEditor(
        title: user == null ? 'Tạo tài khoản' : 'Quản lý tài khoản',
        initial: user ?? {'role': 'member', 'active': true},
        fields: [
          const CloudField('name', 'Tên hiển thị', max: 80),
          if (user == null) ...[
            const CloudField('email', 'Email', email: true, max: 254),
            const CloudField(
              'password',
              'Mật khẩu ban đầu',
              secret: true,
              min: 10,
              max: 128,
            ),
          ],
        ],
        choices: {
          'role': {
            'admin': roleLabel('admin'),
            'staff': roleLabel('staff'),
            'member': roleLabel('member'),
          },
          if (user != null)
            'assignedStaffId': {
              '': 'Chưa phân công',
              for (final s in staff) s['id'] as String: s['name'] as String,
            },
        },
        choiceLabels: const {
          'role': 'Vai trò',
          'assignedStaffId': 'Nhân viên hỗ trợ (chỉ người dùng)',
        },
        activeSwitch: user != null,
      ),
    );
    if (result == null) return;
    if (result['role'] != 'member') result['assignedStaffId'] = null;
    if (user == null) result.remove('assignedStaffId');
    await _run(() async {
      await widget.api.request(
        user == null ? 'POST' : 'PATCH',
        user == null ? '/users' : '/users/${user['id']}',
        result,
      );
    });
  }

  Future<void> _deleteAccount() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CloudEditor(
        title: 'Xóa tài khoản đám mây',
        description: 'Xóa vĩnh viễn tài khoản, liên hệ đám mây và lịch hẹn. Thao tác này không xóa liên hệ SOS trên điện thoại.',
        fields: [
          CloudField('password', 'Xác nhận mật khẩu', secret: true, max: 128),
        ],
        submit: 'XÓA TÀI KHOẢN',
      ),
    );
    if (result != null) {
      await _run(() async {
        await widget.api.request('DELETE', '/me', result);
        await widget.api.clearSession();
      });
    }
  }

  void _records(String resource, String title, [Map<String, dynamic>? owner]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CloudRecordsScreen(
          api: widget.api,
          resource: resource,
          title: title,
          ownerId: owner?['id'] as String?,
          ownerName: owner?['name'] as String?,
          controller: widget.controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      appBar: AppBar(
        title: Text(roleLabel(api.role)),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: busy ? null : _load,
            icon: const MorphIcon(AppGlyph.rotateCw),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Xin chào, ${api.user?['name'] ?? ''}.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(api.user?['email'] as String? ?? ''),
                const SizedBox(height: 20),
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VÒNG AN TOÀN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Hẹn giờ xác nhận, ghi nhận an toàn hoặc yêu cầu hỗ trợ. Nhân viên chỉ xem người được phân công. Lịch quá hạn hiển thị khi mở hoặc làm mới trang; chưa có thông báo đẩy hay tự gửi SOS.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            _records('checkins', 'Lịch hẹn của tôi'),
                        child: const Text('MỞ VÒNG AN TOÀN'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            _records('contacts', 'Liên hệ đám mây'),
                        child: const Text('LIÊN HỆ ĐÁM MÂY'),
                      ),
                    ],
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (api.role != 'member') ...[
                  const SizedBox(height: 28),
                  Text(
                    api.role == 'admin'
                        ? 'Quản trị tài khoản'
                        : 'Người được phân công',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (api.role == 'admin')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: busy ? null : _editUser,
                        child: const Text('TẠO TÀI KHOẢN'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (final user in users.where(
                    (u) => api.role == 'admin' || u['id'] != api.user?['id'],
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SurfacePanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${user['email']} · ${roleLabel(user['role'] as String)}${user['active'] == true ? '' : ' · Đã khóa'}',
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _records(
                                    'checkins',
                                    'Vòng an toàn',
                                    user,
                                  ),
                                  child: const Text('Lịch hẹn'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _records(
                                    'contacts',
                                    'Liên hệ đám mây',
                                    user,
                                  ),
                                  child: const Text('Liên hệ'),
                                ),
                                if (api.role == 'admin') ...[
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => _editUser(user),
                                    child: const Text('Sửa / phân quyền'),
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            if (await confirmCloudDelete(
                                              context,
                                              'Xóa ${user['name']} và toàn bộ dữ liệu đám mây?',
                                            )) {
                                              await _run(() async {
                                                await api.request(
                                                  'DELETE',
                                                  '/users/${user['id']}',
                                                );
                                              });
                                            }
                                          },
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!busy &&
                      users.where((u) => u['id'] != api.user?['id']).isEmpty)
                    const Text('Chưa có người được phân công.'),
                ],
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: busy ? null : _profile,
                  child: const Text('SỬA TÊN HIỂN THỊ'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _run(api.logout),
                  child: const Text('ĐĂNG XUẤT'),
                ),
                TextButton(
                  onPressed: busy ? null : _deleteAccount,
                  child: const Text('Xóa tài khoản đám mây'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Đăng xuất không tắt giám sát hay SOS trên thiết bị. Liên hệ đám mây chỉ trở thành người nhận SOS khi bạn chủ động thêm vào máy.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmCloudDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    ) ??
    false;

class CloudRecordsScreen extends StatefulWidget {
  const CloudRecordsScreen({
    super.key,
    required this.api,
    required this.resource,
    required this.title,
    this.ownerId,
    this.ownerName,
    this.controller,
  });
  final MotionApi api;
  final String resource, title;
  final String? ownerId, ownerName;
  final AppController? controller;
  @override
  State<CloudRecordsScreen> createState() => _CloudRecordsScreenState();
}

class _CloudRecordsScreenState extends State<CloudRecordsScreen> {
  List<Map<String, dynamic>> items = [];
  bool busy = false;
  String? error;
  bool get contacts => widget.resource == 'contacts';
  bool get own =>
      widget.ownerId == null || widget.ownerId == widget.api.user?['id'];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rows = await widget.api.list(
        '/${widget.resource}${widget.ownerId == null ? '' : '?ownerId=${widget.ownerId}'}',
      );
      if (mounted) setState(() => items = rows);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _mutate(Future<void> Function() operation) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final initial =
        item ??
        (contacts
            ? <String, dynamic>{}
            : {
                'dueAt': DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch,
                'status': 'pending',
              });
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CloudEditor(
        title:
            '${item == null ? 'Thêm' : 'Sửa'} ${contacts ? 'liên hệ' : 'lịch hẹn'}',
        initial: initial,
        fields: contacts
            ? const [
                CloudField('name', 'Tên liên hệ', max: 80),
                CloudField('phone', 'Số điện thoại', phone: true, max: 30),
                CloudField(
                  'relationship',
                  'Mối quan hệ',
                  optional: true,
                  max: 80,
                ),
              ]
            : const [
                CloudField('title', 'Nội dung hẹn', max: 120),
                CloudField('note', 'Ghi chú', optional: true, max: 1000),
              ],
        choices: contacts
            ? const {}
            : {
                'status': {
                  for (final s in ['pending', 'safe', 'needs_help', 'resolved'])
                    s: statusLabel(s),
                },
              },
        choiceLabels: const {'status': 'Trạng thái'},
        dateField: contacts ? null : 'dueAt',
      ),
    );
    if (data == null) return;
    if (!contacts && item != null && data['dueAt'] == item['dueAt']) {
      data.remove('dueAt');
    }
    if (item == null && widget.ownerId != null) {
      data['ownerId'] = widget.ownerId;
    }
    await _mutate(() async {
      await widget.api.request(
        item == null ? 'POST' : 'PATCH',
        '/${widget.resource}${item == null ? '' : '/${item['id']}'}',
        data,
      );
    });
  }

  Future<void> _detail(Map<String, dynamic> item) async {
    try {
      final detail = await widget.api.request(
        'GET',
        '/${widget.resource}/${item['id']}',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(detail[contacts ? 'name' : 'title'] as String),
          content: SingleChildScrollView(
            child: Text(
              contacts
                  ? '${detail['phone']}\n${detail['relationship']}\nCập nhật: ${cloudTime(detail['updatedAt'])}'
                  : '${statusLabel(detail['status'] as String)}\nHẹn: ${cloudTime(detail['dueAt'])}\n${detail['note']}\nCập nhật: ${cloudTime(detail['updatedAt'])}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> _useForSos(Map<String, dynamic> item) async {
    final controller = widget.controller;
    if (controller == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm vào người nhận SOS trên máy?'),
        content: Text(
          '${item['name']} · ${item['phone']}\nNgười này có thể nhận SMS thật khi SOS được bật trên thiết bị. Liên hệ hiện tại được giữ lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thêm vào máy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _mutate(() async {
      final saved = await controller.saveContact(
        item['name'] as String,
        item['phone'] as String,
      );
      if (!saved) {
        throw const ApiFailure(
          'Chưa thêm được: kiểm tra liên hệ trùng, giới hạn 10 người và trạng thái thiết bị.',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm người nhận SOS vào điện thoại.'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: busy ? null : _load,
          icon: const MorphIcon(AppGlyph.rotateCw),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: busy ? null : _edit,
      icon: const MorphIcon(AppGlyph.arrowUpRight),
      label: Text(contacts ? 'Thêm liên hệ' : 'Tạo lịch hẹn'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
            children: [
              if (widget.ownerName != null)
                Text(
                  'Người dùng: ${widget.ownerName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              Text(
                contacts
                    ? 'Liên hệ đám mây được lưu theo tài khoản. Sửa hoặc xóa ở đây không tự thay đổi người nhận SOS trên điện thoại.'
                    : 'Lịch hẹn và xác nhận được chia sẻ với nhân viên phụ trách. Quá hạn chưa tự gọi điện, gửi SMS hay thông báo đẩy.',
              ),
              const SizedBox(height: 16),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!busy && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('Chưa có dữ liệu. Bấm nút bên dưới để thêm.'),
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item[contacts ? 'name' : 'title'] as String,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          contacts
                              ? '${item['phone']} · ${item['relationship']}'
                              : '${cloudTime(item['dueAt'])}\n${item['overdue'] == true ? 'QUÁ HẠN · ' : ''}${statusLabel(item['status'] as String)}',
                        ),
                        if (!contacts && (item['note'] as String).isNotEmpty)
                          Text(item['note'] as String),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: busy ? null : () => _detail(item),
                              child: const Text('Chi tiết'),
                            ),
                            OutlinedButton(
                              onPressed: busy ? null : () => _edit(item),
                              child: const Text('Sửa'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await confirmCloudDelete(
                                        context,
                                        'Xóa bản ghi này khỏi tài khoản?',
                                      )) {
                                        await _mutate(() async {
                                          await widget.api.request(
                                            'DELETE',
                                            '/${widget.resource}/${item['id']}',
                                          );
                                        });
                                      }
                                    },
                              child: const Text('Xóa'),
                            ),
                            if (!contacts && item['status'] == 'pending') ...[
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => _mutate(() async {
                                        await widget.api.request(
                                          'PATCH',
                                          '/checkins/${item['id']}',
                                          {'status': 'safe'},
                                        );
                                      }),
                                child: Text(
                                  own ? 'TÔI ỔN' : 'XÁC NHẬN AN TOÀN',
                                ),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => _mutate(() async {
                                        await widget.api.request(
                                          'PATCH',
                                          '/checkins/${item['id']}',
                                          {'status': 'needs_help'},
                                        );
                                      }),
                                child: const Text('CẦN HỖ TRỢ'),
                              ),
                            ],
                            if (contacts && own && widget.controller != null)
                              FilledButton(
                                onPressed: busy ? null : () => _useForSos(item),
                                child: const Text('Thêm vào SOS trên máy'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CloudField {
  const CloudField(
    this.keyName,
    this.label, {
    this.secret = false,
    this.optional = false,
    this.phone = false,
    this.email = false,
    this.min = 1,
    this.max = 120,
  });
  final String keyName, label;
  final bool secret, optional, phone, email;
  final int min, max;
}

class _CloudEditor extends StatefulWidget {
  const _CloudEditor({
    required this.title,
    required this.fields,
    this.initial = const {},
    this.choices = const {},
    this.choiceLabels = const {},
    this.dateField,
    this.activeSwitch = false,
    this.description,
    this.submit = 'LƯU',
  });
  final String title, submit;
  final String? description, dateField;
  final List<CloudField> fields;
  final Map<String, dynamic> initial;
  final Map<String, Map<String, String>> choices;
  final Map<String, String> choiceLabels;
  final bool activeSwitch;
  @override
  State<_CloudEditor> createState() => _CloudEditorState();
}

class _CloudEditorState extends State<_CloudEditor> {
  final _form = GlobalKey<FormState>();
  late final controllers = {
    for (final field in widget.fields)
      field.keyName: TextEditingController(
        text: widget.initial[field.keyName]?.toString() ?? '',
      ),
  };
  late final selected = {
    for (final entry in widget.choices.entries)
      entry.key:
          widget.initial[entry.key]?.toString() ?? entry.value.keys.first,
  };
  late bool active = widget.initial['active'] as bool? ?? true;
  late DateTime due = DateTime.fromMillisecondsSinceEpoch(
    (widget.initial[widget.dateField] as int?) ??
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
  );
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: due.isBefore(now) ? now : due,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(due),
    );
    if (time != null && mounted) {
      setState(
        () => due = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.description != null) Text(widget.description!),
              for (final field in widget.fields)
                TextFormField(
                  controller: controllers[field.keyName],
                  obscureText: field.secret,
                  keyboardType: field.email
                      ? TextInputType.emailAddress
                      : field.phone
                      ? TextInputType.phone
                      : TextInputType.text,
                  maxLength: field.max,
                  maxLines: field.secret
                      ? 1
                      : field.max > 200
                      ? 3
                      : 1,
                  autocorrect: !field.secret && !field.email,
                  decoration: InputDecoration(labelText: field.label),
                  validator: (value) {
                    final v = field.secret ? value ?? '' : (value ?? '').trim();
                    if (v.isEmpty && field.optional) return null;
                    if (v.length < field.min) {
                      return 'Nhập ít nhất ${field.min} ký tự';
                    }
                    if (field.email &&
                        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                      return 'Email không hợp lệ';
                    }
                    if (field.phone &&
                        !RegExp(r'^(0\d{8,10}|\+[1-9]\d{7,14})$')
                            .hasMatch(v.replaceAll(RegExp(r'[\s().-]'), ''))) {
                      return 'Số điện thoại không hợp lệ';
                    }
                    return null;
                  },
                ),
              for (final entry in widget.choices.entries)
                DropdownButtonFormField<String>(
                  initialValue: entry.value.containsKey(selected[entry.key])
                      ? selected[entry.key]
                      : entry.value.keys.first,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: widget.choiceLabels[entry.key] ?? entry.key,
                  ),
                  items: [
                    for (final option in entry.value.entries)
                      DropdownMenuItem(
                        value: option.key,
                        child: Text(
                          option.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => selected[entry.key] = value!),
                ),
              if (widget.dateField != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      'Thời gian: ${cloudTime(due.millisecondsSinceEpoch)}',
                    ),
                  ),
                ),
              if (widget.activeSwitch)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tài khoản hoạt động'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, dynamic>{
            for (final f in widget.fields)
              f.keyName: f.secret
                  ? controllers[f.keyName]!.text
                  : controllers[f.keyName]!.text.trim(),
            for (final entry in selected.entries)
              entry.key: entry.key == 'assignedStaffId' && entry.value.isEmpty
                  ? null
                  : entry.value,
            if (widget.dateField != null)
              widget.dateField!: due.millisecondsSinceEpoch,
            if (widget.activeSwitch) 'active': active,
          });
        },
        child: Text(widget.submit),
      ),
    ],
  );
}
