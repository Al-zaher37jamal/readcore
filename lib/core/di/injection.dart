import 'dart:io';
import 'package:get_it/get_it.dart';
import 'package:readmesh/data/database/app_database.dart';
import 'package:readmesh/data/database/single_writer_lock.dart';
import 'package:readmesh/data/repositories/book_repository.dart';
import 'package:readmesh/data/repositories/device_profile_repository.dart';
import 'package:readmesh/data/repositories/kvs_repository.dart';
import 'package:readmesh/data/repositories/message_repository.dart';
import 'package:readmesh/data/repositories/note_repository.dart';
import 'package:readmesh/data/repositories/outbox_repository.dart';
import 'package:readmesh/data/repositories/page_activity_repository.dart';
import 'package:readmesh/data/repositories/participant_reading_time_repository.dart';
import 'package:readmesh/data/repositories/reading_progress_repository.dart';
import 'package:readmesh/data/repositories/session_event_repository.dart';
import 'package:readmesh/data/repositories/session_member_repository.dart';
import 'package:readmesh/data/repositories/session_repository.dart';
import 'package:readmesh/data/storage/book_file_manager.dart';
import 'package:readmesh/data/storage/disk_space_checker.dart';
import 'package:readmesh/data/storage/orphan_reconciler.dart';
import 'package:readmesh/data/storage/pdf_import_pipeline.dart';
import 'package:readmesh/data/storage/pdf_inspector.dart';
import 'package:readmesh/data/storage/storage_manager.dart';
import 'package:readmesh/features/profile/device_service.dart';
import 'package:readmesh/features/room/local_room_service.dart';
import 'package:readmesh/features/lan/lan_discovery_service.dart';
import 'package:readmesh/core/l10n/language_service.dart';

final getIt = GetIt.instance;

/// Configures and registers dependencies into the service locator.
Future<void> setupLocator({
  AppDatabase? customDatabase,
  File? customDatabaseFile,
  Directory? customStorageDir,
  DiskSpaceChecker? customDiskSpaceChecker,
  bool runIntegrityCheck = true,
}) async {
  if (getIt.isRegistered<AppDatabase>()) {
    await resetLocator();
  }

  // Database & Locks
  final singleWriterLock = SingleWriterLock();
  final database = customDatabase ??
      AppDatabase(
        null,
        singleWriterLock,
        runIntegrityCheck,
      );

  getIt.registerSingleton<SingleWriterLock>(singleWriterLock);
  getIt.registerSingleton<AppDatabase>(database);

  // Storage Services
  final fileManager = BookFileManager(customStorageDir);
  await fileManager.initialize();
  getIt.registerSingleton<BookFileManager>(fileManager);

  final diskSpaceChecker = customDiskSpaceChecker ?? const SystemDiskSpaceChecker();
  getIt.registerSingleton<DiskSpaceChecker>(diskSpaceChecker);

  const pdfInspector = PdfInspector();
  getIt.registerSingleton<PdfInspector>(pdfInspector);

  // Repositories
  final bookRepo = BookRepositoryImpl(database);
  final deviceProfileRepo = DeviceProfileRepositoryImpl(database);
  final sessionRepo = SessionRepositoryImpl(database);
  final sessionMemberRepo = SessionMemberRepositoryImpl(database);
  final sessionEventRepo = SessionEventRepositoryImpl(database);
  final outboxRepo = OutboxRepositoryImpl(database);
  final readingProgressRepo = ReadingProgressRepositoryImpl(database);
  final participantReadingTimeRepo = ParticipantReadingTimeRepositoryImpl(database);
  final pageActivityRepo = PageActivityRepositoryImpl(database);
  final messageRepo = MessageRepositoryImpl(database);
  final noteRepo = NoteRepositoryImpl(database);
  final kvsRepo = KvsRepositoryImpl(database);

  getIt.registerSingleton<BookRepository>(bookRepo);
  getIt.registerSingleton<DeviceProfileRepository>(deviceProfileRepo);
  getIt.registerSingleton<SessionRepository>(sessionRepo);
  getIt.registerSingleton<SessionMemberRepository>(sessionMemberRepo);
  getIt.registerSingleton<SessionEventRepository>(sessionEventRepo);
  getIt.registerSingleton<OutboxRepository>(outboxRepo);
  getIt.registerSingleton<ReadingProgressRepository>(readingProgressRepo);
  getIt.registerSingleton<ParticipantReadingTimeRepository>(participantReadingTimeRepo);
  getIt.registerSingleton<PageActivityRepository>(pageActivityRepo);
  getIt.registerSingleton<MessageRepository>(messageRepo);
  getIt.registerSingleton<NoteRepository>(noteRepo);
  getIt.registerSingleton<KvsRepository>(kvsRepo);

  // High-level pipeline & managers
  final pdfImportPipeline = PdfImportPipeline(
    fileManager: fileManager,
    bookRepository: bookRepo,
    diskSpaceChecker: diskSpaceChecker,
    pdfInspector: pdfInspector,
  );
  getIt.registerSingleton<PdfImportPipeline>(pdfImportPipeline);

  final storageManager = StorageManager(
    fileManager: fileManager,
    diskSpaceChecker: diskSpaceChecker,
    customDatabaseFile: customDatabaseFile,
  );
  getIt.registerSingleton<StorageManager>(storageManager);

  final orphanReconciler = OrphanReconciler(
    fileManager: fileManager,
    bookRepository: bookRepo,
  );
  getIt.registerSingleton<OrphanReconciler>(orphanReconciler);

  // Phase 3: Profile & Room Services
  final deviceService = DeviceService(repository: deviceProfileRepo);
  await deviceService.getOrCreateCurrentProfile();
  getIt.registerSingleton<DeviceService>(deviceService);

  final roomService = LocalRoomService(
    sessionRepository: sessionRepo,
    sessionMemberRepository: sessionMemberRepo,
    deviceService: deviceService,
  );
  getIt.registerSingleton<LocalRoomService>(roomService);

  // Phase 4: LAN Discovery Service
  final discoveryService = LanDiscoveryService();
  getIt.registerSingleton<LanDiscoveryService>(discoveryService);

  // Phase 5: Language Service (Arabic default RTL)
  final languageService = LanguageService(kvsRepo);
  await languageService.init();
  getIt.registerSingleton<LanguageService>(languageService);
}

/// Disposes and clears all registered services from locator.
Future<void> resetLocator() async {
  if (getIt.isRegistered<AppDatabase>()) {
    final db = getIt<AppDatabase>();
    await db.close();
  }
  await getIt.reset();
}
