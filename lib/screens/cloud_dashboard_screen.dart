import 'emergency_card_screen.dart';

import 'package:flutter/material.dart';

import '../services/app_controller.dart';
import '../services/motion_api.dart';
import '../widgets/app_design.dart';
import '../widgets/morph_icon.dart';
import '../widgets/role_overview.dart';
import '../services/app_appearance.dart';

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
  const CloudDashboardScreen({
    super.key,
    required this.api,
    this.controller,
    this.onOpenMonitor,
  });
  final MotionApi api;
  final AppController? controller;
  final VoidCallback? onOpenMonitor;
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

  String query = '', roleFilter = 'all';
  List<Map<String, dynamic>> get visibleUsers => users.where((user) {
    if (widget.api.role != 'admin' && user['id'] == widget.api.user?['id']) {
      return false;
    }
    if (roleFilter != 'all' && user['role'] != roleFilter) return false;
    final text = '${user['name']} ${user['email']}'.toLowerCase();
    return text.contains(query.trim().toLowerCase());
  }).toList();

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  Widget _userCard(Map<String, dynamic> user) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.line.withValues(alpha: 0.65)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.lime.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: Text(
            _initials(user['name'] as String),
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: context.colors.lime,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user['name'] as String,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user['email'] as String,
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RolePill(
                    label: roleLabel(user['role'] as String),
                    color: context.colors.lime,
                  ),
                  _RolePill(
                    label: user['active'] == true ? 'Đang hoạt động' : 'Đã khóa',
                    color: user['active'] == true
                        ? context.colors.muted
                        : context.colors.red,
                  ),
                  if (user['verified'] != true)
                    _RolePill(
                      label: 'Chưa xác thực email',
                      color: context.colors.orange,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (widget.api.role == 'admin')
          PopupMenuButton<String>(
            tooltip: 'Quản lý tài khoản',
            icon: const MorphIcon(AppGlyph.sliders, size: 20),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Sửa / phân quyền')),
              PopupMenuItem(value: 'delete', child: Text('Xóa tài khoản')),
            ],
            onSelected: (action) async {
              if (action == 'edit') {
                await _editUser(user);
                return;
              }
              if (await confirmCloudDelete(
                context,
                'Xóa ${user['name']} và toàn bộ dữ liệu đám mây?',
              )) {
                await _run(() async {
                  await widget.api.request('DELETE', '/users/${user['id']}');
                });
              }
            },
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          api.role == 'admin'
              ? 'Quản trị Motion'
              : api.role == 'staff'
              ? 'Không gian hỗ trợ'
              : 'Tài khoản của bạn',
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: busy ? null : _load,
            icon: const MorphIcon(AppGlyph.rotateCw),
          ),
          if (AppearanceScope.of(context) case final appearance?)
            IconButton(
              tooltip: appearance.isDark
                  ? 'Chuyển sang giao diện sáng'
                  : 'Chuyển sang giao diện tối',
              onPressed: appearance.toggle,
              icon: MorphIcon(
                AppGlyph.sun,
                alternate: AppGlyph.moon,
                active: appearance.isDark,
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                RoleOverview(
                  role: api.role,
                  label: roleLabel(api.role),
                  name: api.user?['name'] as String? ?? '',
                  email: api.user?['email'] as String? ?? '',
                ),
                const SizedBox(height: 16),
                if (widget.onOpenMonitor != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: FilledButton(
                      onPressed: widget.onOpenMonitor,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('MỞ GIÁM SÁT TRÊN THIẾT BỊ'),
                      ),
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
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        api.role == 'admin'
                            ? 'Tài khoản & phân quyền'
                            : 'Người được phân công',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (api.role == 'admin')
                        FilledButton.icon(
                          onPressed: busy ? null : _editUser,
                          icon: const MorphIcon(AppGlyph.user, size: 16),
                          label: const Text('TẠO TÀI KHOẢN'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    api.role == 'admin'
                        ? 'Cấp đúng quyền. Phân công đúng người.'
                        : 'Chỉ những người được giao cho bạn xuất hiện tại đây.',
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('accountSearch'),
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Tìm theo tên hoặc email',
                      isDense: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(12),
                        child: MorphIcon(AppGlyph.users, size: 18),
                      ),
                    ),
                  ),
                  if (api.role == 'admin') ...[
                    const SizedBox(height: 10),
                    Wrap(
                      key: const Key('roleFilter'),
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (value, label) in const [
                          ('all', 'Tất cả'),
                          ('member', 'Người dùng'),
                          ('staff', 'Nhân viên'),
                          ('admin', 'Quản trị'),
                        ])
                          ChoiceChip(
                            label: Text(
                              '$label · ${value == 'all' ? users.length : users.where((u) => u['role'] == value).length}',
                            ),
                            selected: roleFilter == value,
                            showCheckmark: false,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) =>
                                setState(() => roleFilter = value),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  for (final user in visibleUsers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _userCard(user),
                    ),
                  if (!busy && visibleUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Chưa có tài khoản phù hợp.'),
                    ),
                  const SizedBox(height: 20),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const EmergencyCardScreen(),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('THẺ THÔNG TIN KHẨN CẤP'),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Hồ sơ & bảo mật',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : _profile,
                  child: const Text('SỬA TÊN HIỂN THỊ'),
                ),
                OutlinedButton(
                  key: const Key('linkGoogleAccount'),
                  onPressed: busy
                      ? null
                      : () => _run(() async {
                          await api.signInWithGoogle(linkAccount: true);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã liên kết Google. Lần sau bạn có thể đăng nhập bằng Google.',
                                ),
                              ),
                            );
                          }
                        }),
                  child: const Text('LIÊN KẾT GOOGLE'),
                ),
                TextButton(
                  onPressed: busy ? null : () => _run(api.logout),
                  child: const Text('ĐĂNG XUẤT'),
                ),
                TextButton(
                  onPressed: busy ? null : _deleteAccount,
                  child: Text(
                    'Xóa tài khoản đám mây',
                    style: TextStyle(color: context.colors.red),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Đăng xuất không tắt giám sát hay SOS trên thiết bị. Liên hệ đám mây chỉ trở thành người nhận SOS khi bạn chủ động thêm vào máy.',
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .20)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
    ),
  );
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
                if (entry.key == 'role')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vai trò truy cập',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in entry.value.entries)
                              ChoiceChip(
                                label: Text(option.value),
                                selected: selected[entry.key] == option.key,
                                onSelected: (_) => setState(
                                  () => selected[entry.key] = option.key,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          switch (selected['role']) {
                            'admin' => 'Quản lý tài khoản, phân quyền và toàn bộ dữ liệu đám mây.',
                            'staff' => 'Chỉ hỗ trợ người dùng được phân công; không cấp quyền tài khoản.',
                            _ => 'Chỉ truy cập hồ sơ, liên hệ và lịch hẹn của chính mình.',
                          },
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (entry.key != 'assignedStaffId' ||
                    selected['role'] == 'member')
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
