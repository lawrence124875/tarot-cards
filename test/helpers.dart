import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tarot_cards/app/services.dart';
import 'package:tarot_cards/core/content/card_content.dart';
import 'package:tarot_cards/core/content/content_source.dart';
import 'package:tarot_cards/core/deck/deck.dart';
import 'package:tarot_cards/core/deck/deck_source.dart';
import 'package:tarot_cards/core/events/event_bus.dart';
import 'package:tarot_cards/core/feedback/feedback_sender.dart';
import 'package:tarot_cards/core/journal/journal_store.dart';
import 'package:tarot_cards/core/monetization/premium_service.dart';
import 'package:tarot_cards/core/onboarding/intro_store.dart';
import 'package:tarot_cards/core/reminders/reminder_service.dart';
import 'package:tarot_cards/l10n/l10n.dart';

/// 測試用：內容檔不在公開 repo（assets/content 只有 .gitkeep），一律回傳 null。
class EmptyContentSource implements ContentSource {
  const EmptyContentSource();

  @override
  Future<CardContent?> card(int id) async => null;

  @override
  Future<SpreadTexts?> spreads() async => null;

  @override
  Future<AtmosphereTexts?> atmosphere() async => null;

  @override
  Future<LessonBook?> lessons() async => null;
}

/// 測試用：沒有任何牌面組（畫面改用程式畫的牌面）。
class EmptyDeckSource implements DeckSource {
  const EmptyDeckSource();

  @override
  Future<List<Deck>> decks() async => const [];

  @override
  Future<Deck?> deck(String id) async => null;

  @override
  Future<ImageProvider?> cardArt(Deck? deck, int cardId) async => null;

  @override
  Future<Uint8List?> cardArtBytes(Deck? deck, int cardId) async => null;
}

Services testServices({
  IntroStore? intro,
  JournalStore? journal,
  FeedbackSender? feedback,
  BreathServices? breath,
  PremiumService? premium,
  int seed = 1,
}) =>
    Services(
      content: const EmptyContentSource(),
      decks: const EmptyDeckSource(),
      events: EventBus(),
      random: Random(seed),
      reminders: NoopReminderService(),
      intro: intro,
      journal: journal,
      feedback: feedback,
      breath: breath,
      premium: premium,
    );

const localizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// 包好 AppServices 與 MaterialApp（含翻譯）。
Widget testApp(Services services, Widget home, {Locale? locale}) => AppServices(
      services: services,
      child: MaterialApp(
        locale: locale ?? AppLanguages.zhHant.locale,
        supportedLocales: [for (final l in AppLanguages.all) l.locale],
        localizationsDelegates: localizationsDelegates,
        home: home,
      ),
    );
