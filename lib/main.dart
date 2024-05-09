import 'package:easy_screenutil/easy_screenutil.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:si_bestie/core/app/app.dart';
import 'package:si_bestie/feature/flashcard/model/flashcard.dart';
import 'package:si_bestie/feature/hive/model/chat_bot/chat_bot.dart';
import 'package:si_bestie/feature/quiz/model/option.dart';
import 'package:si_bestie/feature/quiz/model/question.dart';
import 'package:si_bestie/feature/quiz/model/quiz.dart';

Future<void> main() async {
  ScreenUtil.ensureInitialized(designWidth: 390);
  _initGoogleFonts();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive
    ..init(appDocumentDir.path)
    ..registerAdapter(ChatBotAdapter())
    ..registerAdapter(QuizAdapter())
    ..registerAdapter(FlashcardAdapter())
    ..registerAdapter(QuestionAdapter())
    ..registerAdapter(OptionAdapter());
  await Hive.openBox<ChatBot>('chatbots');
  await Hive.openBox<Quiz>('quizzes');
  await Hive.openBox<Flashcard>('flashcards');

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

void _initGoogleFonts() {
  GoogleFonts.config.allowRuntimeFetching = false;

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
}
