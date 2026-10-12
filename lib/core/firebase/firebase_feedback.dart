import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../feedback/feedback_sender.dart';

/// 意見回饋寫進 Firestore `tr_feedback` 集合（HANDOFF §18.1 第 7 點）。
/// Firestore 規則整個專案共用一份：英文 App 用 `feedback`，本 App 一律 `tr_` 開頭；兩個集合都只能新增、不能讀改刪。
/// 欄位與英文 App 的 `feedback` 相同，後台看起來一致。
class FirestoreFeedbackSender implements FeedbackSender {
  const FirestoreFeedbackSender();

  static const collection = 'tr_feedback';

  @override
  Future<void> send(FeedbackEntry entry) async {
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    final write = FirebaseFirestore.instance.collection(collection).add({
      'message': entry.message,
      'category': entry.category.name,
      'contactEmail': entry.contactEmail,
      'appVersion': version,
      'platform': defaultTargetPlatform.name,
      'locale': entry.locale,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      // 沒有網路時 Firestore 先存在手機上、連上網路後自動送出，這個 Future 要等到伺服器確認才完成；
      // 等太久就當作已排入佇列，不讓使用者卡在轉圈，也不讓他以為失敗而重送。
      await write.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('意見回饋已排入佇列，連上網路後送出');
    }
  }
}
