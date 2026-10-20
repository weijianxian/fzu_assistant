import 'dart:typed_data';

class CampusUser {
  const CampusUser({required this.name, required this.account});
  final String name;
  final String account;

  factory CampusUser.fromJson(Map<String, dynamic> json) {
    final account = json['account']?.toString() ?? '';
    if (account.isEmpty) throw const FormatException('一卡通未返回账号');
    return CampusUser(name: json['name']?.toString() ?? '', account: account);
  }
}

/// The legacy SO protocol contains raw bytes, not UTF-8 text.
class CampusPayCode {
  CampusPayCode({required Uint8List bytes, required this.createdAt})
    : bytes = bytes.asUnmodifiableView();
  final Uint8List bytes;
  final DateTime createdAt;
}
