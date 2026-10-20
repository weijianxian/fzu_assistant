import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fzu_assistant/model/campus_code.dart';
import 'package:fzu_assistant/service/api/sso_service.dart';
import 'package:pointycastle/export.dart';

/// Campus card protocol: west2-online/fzuhelper-app lib/ykt-login.ts.
class CampusCodeService {
  CampusCodeService({Dio? dio, SsoService? sso})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              followRedirects: false,
            ),
          ),
      sso = sso ?? SsoService.instance;
  static final instance = CampusCodeService();
  final Dio dio;
  final SsoService sso;
  static const _base = 'https://xcx.fzu.edu.cn';

  Future<dynamic> _get(
    String path, {
    String? token,
    Map<String, dynamic>? query,
  }) async {
    final response = await dio.get<dynamic>(
      '$_base$path',
      queryParameters: {'synAccessSource': 'h5', ...?query},
      options: Options(
        headers: {
          'Referer': '$_base/plat/pay?appId=16&nodeId=15',
          'Synaccesssource': 'h5',
          if (token != null) 'Synjones-Auth': 'bearer $token',
        },
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final dynamic data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final code = data is Map ? data['code']?.toString() : null;
    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        code == '401' ||
        code == '403') {
      throw const SsoLoginRequired();
    }
    if (code != '200') {
      throw Exception(
        data is Map
            ? data['msg'] ?? data['message'] ?? '一卡通请求失败（$code）'
            : '一卡通返回了无效数据',
      );
    }
    return data['data'];
  }

  Future<({String token, CampusUser user})> loadSession() async {
    var token = await sso.loadCampusToken();
    if (token != null && token.isNotEmpty) {
      try {
        return (token: token, user: await getUser(token));
      } on SsoLoginRequired {
        await sso.clearCampusToken();
      }
    }
    token = await sso.getCampusToken();
    return (token: token, user: await getUser(token));
  }

  Future<CampusUser> getUser(String token) async => CampusUser.fromJson(
    Map<String, dynamic>.from(
      await _get('/berserker-base/user', token: token) as Map,
    ),
  );

  Future<CampusPayCode> getPayCode(String token) async {
    final rows = await _get(
      '/berserker-app/ykt/tsm/codebarPayinfo',
      token: token,
    );
    if (rows is! List || rows.isEmpty || rows.first is! Map) {
      throw Exception('获取支付信息失败');
    }
    final pay = Map<String, dynamic>.from(rows.first as Map);
    if ((pay['voucher']?.toString() ?? '').isEmpty &&
        pay['voucherStatus'].toString() == '0') {
      throw Exception('未开通离线支付权限，请前往“福大一卡通”微信小程序：我的 → 设置 → 支付设置 → 脱机二维码设置');
    }
    for (final key in ['account', 'payacc', 'paytype', 'voucher']) {
      if ((pay[key]?.toString() ?? '').isEmpty) throw Exception('获取支付信息失败');
    }
    final results = await Future.wait([
      _get(
        '/berserker-app/ykt/tsm/batchGetBarCodeGet',
        token: token,
        query: {
          for (final k in ['account', 'payacc', 'paytype']) k: pay[k],
        },
      ),
      _get(
        '/berserker-app/ykt/tsm/offlienPar',
        token: token,
        query: {
          for (final k in ['payacc', 'paytype', 'voucher']) k: pay[k],
        },
      ),
      _get('/berserker-app/frontInfo'),
    ]);
    final barcodes = (results[0] as Map)['barcode'];
    if (barcodes is! List ||
        barcodes.isEmpty ||
        barcodes.first.toString().length != 20) {
      throw Exception('获取支付条码失败');
    }
    final front = jsonDecode(
      (results[2] as Map)['getFrontConfig'] as String,
    ) as Map<String, dynamic>;
    final offline = Map<String, dynamic>.from(results[1] as Map);
    final hashKey = decryptHashKey(
      offline['userhashkey'] as String,
      front['privateKey'] as String,
    );
    final now = DateTime.now();
    return CampusPayCode(
      bytes: generatePayBytes(
        barcode: barcodes.first.toString(),
        payAccount: pay['payacc'].toString(),
        offlineData: offline['offline_userdata']?.toString() ?? '',
        hashKey: hashKey,
        version: int.tryParse(offline['version'].toString()) ?? 3,
        effectiveTime:
            num.tryParse(offline['offline_effective_time'].toString())
                ?.floor() ??
            0,
        newProtocol: front['offlineCode'].toString() != '0',
        now: now,
      ),
      createdAt: now,
    );
  }

  static Uint8List _unhex(String value) {
    if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(value)) {
      throw const FormatException('一卡通十六进制数据无效');
    }
    return Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
  }

  static String _hex(Iterable<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();

  static Uint8List decryptHashKey(String encryptedHex, String pem) {
    final der = base64Decode(pem.replaceAll(RegExp(r'-----[^-]+-----|\s'), ''));
    var sequence = ASN1Parser(der).nextObject() as ASN1Sequence;
    if (sequence.elements.length == 3 &&
        sequence.elements[2] is ASN1OctetString) {
      sequence =
          ASN1Parser((sequence.elements[2] as ASN1OctetString).valueBytes())
                  .nextObject()
              as ASN1Sequence;
    }
    BigInt integer(int index) =>
        (sequence.elements[index] as ASN1Integer).valueAsBigInteger;
    final key = RSAPrivateKey(integer(1), integer(3), integer(4), integer(5));
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(key));
    final decrypted = cipher.process(_unhex(encryptedHex));
    if (decrypted.length < 16) throw const FormatException('一卡通支付密钥长度不足');
    return Uint8List.fromList(decrypted.take(16).toList());
  }

  static Uint8List generatePayBytes({
    required String barcode,
    required String payAccount,
    required String offlineData,
    required Uint8List hashKey,
    required int version,
    required int effectiveTime,
    required bool newProtocol,
    required DateTime now,
  }) {
    if (!RegExp(r'^\d{20}$').hasMatch(barcode) || hashKey.length != 16) {
      throw const FormatException('一卡通支付参数无效');
    }
    final account = ascii.encode(payAccount);
    final tag = [
      0x6f,
      account.length + 5,
      0x84,
      account.length,
      ...account,
      0x85,
      1,
      1,
    ];
    if (tag.length > 255) throw const FormatException('一卡通账号长度无效');
    final payload = [
      ..._unhex(offlineData),
      if (newProtocol) ...[tag.length, ...tag],
    ];
    final length = 13 + payload.length;
    final ts = now.millisecondsSinceEpoch ~/ 1000;
    final header = [
      length >> 8 & 255,
      length & 255,
      version == 0 ? 3 : version,
      0,
      ts & 255,
      ts >> 8 & 255,
      ts >> 16 & 255,
      ts >> 24 & 255,
      1,
      effectiveTime & 255,
      1,
    ];
    // Digest the uppercase hex TEXT, rather than the bytes it represents.
    final digest = sha1
        .convert(
          utf8.encode(
            '${_hex(header.skip(2))}${_hex(payload)}${_hex(hashKey)}',
          ),
        )
        .bytes
        .take(4);
    final body = [...header, ...payload, ...digest];
    return Uint8List.fromList([
      ...ascii.encode('$barcode${newProtocol ? 'SP' : 'SO'}'),
      ...(newProtocol ? ascii.encode(base64Encode(body)) : body),
    ]);
  }
}
