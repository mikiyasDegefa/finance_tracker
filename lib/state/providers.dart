import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../core/security/key_store.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../features/parsing/parsing_engine.dart';

enum AuthStage { loading, setupPin, locked, unlocked }

final authStageProvider = StateProvider<AuthStage>((_) => AuthStage.loading);
final keyStoreProvider = Provider<KeyStore>((_) => KeyStore());
final dbProvider = StateProvider<AppDatabase?>((_) => null);
final revisionProvider = StateProvider<int>((_) => 0);
final workspaceIdProvider = StateProvider<int?>((_) => null);

final repoProvider = Provider<Repo?>((ref) {
  final db = ref.watch(dbProvider);
  if (db == null) return null;
  return Repo(db, () => ref.read(revisionProvider.notifier).state++);
});

final workspacesProvider = Provider<List<Workspace>>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(repoProvider)?.workspaces() ?? const [];
});

final accountsProvider = Provider<List<Account>>((ref) {
  ref.watch(revisionProvider);
  final r = ref.watch(repoProvider);
  final w = ref.watch(workspaceIdProvider);
  if (r == null || w == null) return const [];
  return r.accounts(w);
});

final sourcesProvider = Provider<List<Source>>((ref) {
  ref.watch(revisionProvider);
  final r = ref.watch(repoProvider);
  final w = ref.watch(workspaceIdProvider);
  if (r == null || w == null) return const [];
  return r.sources(w);
});

final templatesProvider = Provider<List<SmsTemplate>>((ref) {
  ref.watch(revisionProvider);
  final r = ref.watch(repoProvider);
  final w = ref.watch(workspaceIdProvider);
  if (r == null || w == null) return const [];
  return r.templates(w);
});

final transactionsProvider = Provider<List<Tx>>((ref) {
  ref.watch(revisionProvider);
  final r = ref.watch(repoProvider);
  final w = ref.watch(workspaceIdProvider);
  if (r == null || w == null) return const [];
  return r.transactions(w);
});

final smsListProvider = Provider<List<SmsMsg>>((ref) {
  ref.watch(revisionProvider);
  final r = ref.watch(repoProvider);
  final w = ref.watch(workspaceIdProvider);
  if (r == null || w == null) return const [];
  return r.smsMessages(w);
});

final modeProvider = Provider<String>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(repoProvider)?.setting('mode') ?? 'hybrid';
});

final monthTotalsProvider = Provider<({int credit, int debit})>((ref) {
  ref.watch(revisionProvider);
  final r = ref.watch(repoProvider);
  final w = ref.watch(workspaceIdProvider);
  if (r == null || w == null) return (credit: 0, debit: 0);
  final now = DateTime.now();
  return r.totals(w, DateTime(now.year, now.month, 1));
});

void switchWorkspace(WidgetRef ref, int id) {
  ref.read(repoProvider)?.setSetting('current_workspace', '$id');
  ref.read(workspaceIdProvider.notifier).state = id;
}
