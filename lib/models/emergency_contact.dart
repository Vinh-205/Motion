class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
  });
  final String id, name, phone;
  factory EmergencyContact.fromMap(Map<String, dynamic> value) =>
      EmergencyContact(
        id: value['id'] as String,
        name: value['name'] as String,
        phone: value['phone'] as String,
      );
  Map<String, String> toMap() => {'id': id, 'name': name, 'phone': phone};
}
