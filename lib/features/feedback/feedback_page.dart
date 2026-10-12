import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../core/feedback/feedback_sender.dart';
import '../../l10n/l10n.dart';

/// 意見回饋：首頁右上角選單開啟。送到 Firestore `tr_feedback`（只能新增，App 讀不到任何人的回饋）。
/// 版面與欄位同英文 App：類型、內容、選填的聯絡信箱。
Future<void> openFeedback(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FeedbackPage()));

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _message = TextEditingController();
  final _email = TextEditingController();
  var _category = FeedbackCategory.suggestion;
  var _sending = false;

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  String _label(FeedbackCategory c, AppLocalizations l) => switch (c) {
        FeedbackCategory.bug => l.feedbackCategoryBug,
        FeedbackCategory.suggestion => l.feedbackCategorySuggestion,
        FeedbackCategory.other => l.feedbackCategoryOther,
      };

  Future<void> _submit() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final message = _message.text.trim();
    if (message.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l.feedbackEmpty)));
      return;
    }
    final sender = AppServices.of(context).feedback;
    if (sender == null) return;
    final email = _email.text.trim();
    setState(() => _sending = true);
    try {
      await sender.send(FeedbackEntry(
        message: message,
        category: _category,
        contactEmail: email.isEmpty ? null : email,
        locale: Localizations.localeOf(context).toLanguageTag(),
      ));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.feedbackThanks)));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(l.feedbackFailed)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.menuFeedback)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560), // 平板不拉太寬
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l.feedbackCategoryLabel, style: t.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in FeedbackCategory.values)
                    ChoiceChip(
                      label: Text(_label(c, l)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ]),
                const SizedBox(height: 24),
                Text(l.feedbackMessageLabel, style: t.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _message,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: FeedbackEntry.maxMessageLength,
                  decoration: InputDecoration(hintText: l.feedbackMessageHint, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text(l.feedbackEmailLabel, style: t.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: FeedbackEntry.maxEmailLength,
                  decoration: InputDecoration(
                    hintText: l.feedbackEmailHint,
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l.feedbackSubmit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
