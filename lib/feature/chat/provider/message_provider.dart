import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:si_bestie/core/config/type_of_bot.dart';
import 'package:si_bestie/core/config/type_of_message.dart';
import 'package:si_bestie/core/navigation/route.dart';
import 'package:si_bestie/core/navigation/router.dart';
import 'package:si_bestie/feature/flashcard/model/flashcard.dart';
import 'package:si_bestie/feature/gemini/gemini.dart';
import 'package:si_bestie/feature/hive/model/chat_bot/chat_bot.dart';
import 'package:si_bestie/feature/hive/model/chat_message/chat_message.dart';
import 'package:si_bestie/feature/hive/repository/hive_repository.dart';
import 'package:si_bestie/feature/quiz/model/option.dart';
import 'package:si_bestie/feature/quiz/model/question.dart';
import 'package:si_bestie/feature/quiz/model/quiz.dart';
import 'package:uuid/uuid.dart';

final messageListProvider = StateNotifierProvider<MessageListNotifier, ChatBot>(
  (ref) => MessageListNotifier(),
);

class MessageListNotifier extends StateNotifier<ChatBot> {
  MessageListNotifier()
      : super(ChatBot(messagesList: [], id: '', title: '', typeOfBot: ''));

  final uuid = const Uuid();
  final geminiRepository = GeminiRepository();

  Future<void> updateChatBotWithMessage(ChatMessage message) async {
    final newMessageList = [...state.messagesList, message.toJson()];
    await updateChatBot(
      ChatBot(
        messagesList: newMessageList,
        id: state.id,
        title: state.title.isEmpty ? message.text : state.title,
        typeOfBot: state.typeOfBot,
        attachmentPath: state.attachmentPath,
        embeddings: state.embeddings,
        subject: state.subject,
      ),
    );
  }

  Future<void> handleSendPressed({
    required String text,
    String? imageFilePath,
  }) async {
    final messageId = uuid.v4();
    final ChatMessage message = ChatMessage(
      id: messageId,
      text: text,
      createdAt: DateTime.now(),
      typeOfMessage: TypeOfMessage.user,
      chatBotId: state.id,
    );
    await updateChatBotWithMessage(message);
    await getGeminiResponse(prompt: text, imageFilePath: imageFilePath);
  }

  Future<void> quizPressed(ChatBot chatBot) async {
    await getQuizResponse(
      prompt: 'Tolong buatkan quiz dari materi tersebut',
      root: chatBot,
    );
  }

  Future<void> flashcardPressed(ChatBot chatBot) async {
    await getFlashcardResponse(
      prompt: 'Tolong buatkan flashcard dari materi tersebut',
      root: chatBot,
    );
  }

  Future<void> summaryPressed() async {
    await getGeminiResponse(
      prompt: 'Tolong buatkan rangkuman dari materi tersebut',
    );
  }

  Future<void> getGeminiResponse({
    required String prompt,
    String? imageFilePath,
  }) async {
    final List<Parts> chatParts = state.messagesList.map((msg) {
      return Parts(text: msg['text'] as String);
    }).toList();

    if (state.typeOfBot == TypeOfBot.pdf) {
      final embeddingPrompt = await geminiRepository.promptForEmbedding(
        userPrompt: prompt,
        embeddings: state.embeddings,
      );
      chatParts.add(Parts(text: embeddingPrompt));
    } else {
      chatParts.add(Parts(text: prompt));
    }

    final content = Content(parts: chatParts);

    Stream<Candidates> responseStream;
    ChatMessage placeholderMessage;

    if (imageFilePath != null && state.typeOfBot == TypeOfBot.image) {
      final Uint8List imageBytes = File(imageFilePath).readAsBytesSync();
      responseStream =
          geminiRepository.streamContent(content: content, image: imageBytes);
    } else {
      responseStream =
          geminiRepository.streamContent(content: content, isPdf: true);
    }

    final String modelMessageId = uuid.v4();
    placeholderMessage = ChatMessage(
      id: modelMessageId,
      text: 'waiting for response...',
      createdAt: DateTime.now(),
      typeOfMessage: TypeOfMessage.bot,
      chatBotId: state.id,
    );

    await updateChatBotWithMessage(placeholderMessage);

    final StringBuffer fullResponseText = StringBuffer();

    responseStream.listen((response) async {
      if (response.content!.parts!.isNotEmpty) {
        fullResponseText.write(response.content!.parts!.first.text);
        final int messageIndex =
            state.messagesList.indexWhere((msg) => msg['id'] == modelMessageId);
        if (messageIndex != -1) {
          final newMessagesList =
              List<Map<String, dynamic>>.from(state.messagesList);
          newMessagesList[messageIndex]['text'] = fullResponseText.toString();
          final newState = ChatBot(
            id: state.id,
            title: state.title,
            typeOfBot: state.typeOfBot,
            messagesList: newMessagesList,
            attachmentPath: state.attachmentPath,
            embeddings: state.embeddings,
            subject: state.subject,
          );
          await updateChatBot(newState);
        }
      }
    });
  }

  Future<void> getQuizResponse({
    required String prompt,
    required ChatBot root,
  }) async {
    final List<Parts> chatParts = state.messagesList.map((msg) {
      return Parts(text: msg['text'] as String);
    }).toList();

    final embeddingPrompt = await geminiRepository.promptForQuiz(
      userPrompt: prompt,
      embeddings: state.embeddings,
    );
    chatParts.add(Parts(text: embeddingPrompt));

    final content = Content(parts: chatParts);

    Stream<Candidates> responseStream;

    responseStream =
        geminiRepository.streamContent(content: content, isPdf: true);

    final String modelMessageId = uuid.v4();
    ChatMessage placeholderMessage;

    placeholderMessage = ChatMessage(
      id: modelMessageId,
      text: 'Generating Quiz... ',
      createdAt: DateTime.now(),
      typeOfMessage: TypeOfMessage.bot,
      chatBotId: state.id,
    );

    await updateChatBotWithMessage(placeholderMessage);

    final StringBuffer fullResponseText = StringBuffer();

    responseStream.listen((response) async {
      if (response.content!.parts!.isNotEmpty) {
        fullResponseText.write(response.content!.parts!.first.text);
        final int messageIndex =
            state.messagesList.indexWhere((msg) => msg['id'] == modelMessageId);
        if (messageIndex != -1) {
          final newMessagesList =
              List<Map<String, dynamic>>.from(state.messagesList);
          newMessagesList[messageIndex]['text'] = fullResponseText.toString();
        }
      }
    }).onDone(() async {
      try {
        Logger().i('Full Response Quiz: $fullResponseText');
        final jsonResponse = jsonDecode(fullResponseText.toString());
        Logger().f('Success Response Quiz: $jsonResponse');

        final List<Question> questions = [];

        for (final item in jsonResponse['quiz'] as List<dynamic>) {
          final List<Option> options = [];
          for (final option in item['options'] as List<dynamic>) {
            options.add(
              Option(
                text: option['text'] as String,
                isCorrect:
                    option['isCorrect'].toString().toLowerCase() == 'true',
              ),
            );
          }
          questions.add(
            Question(
              text: item['text'] as String,
              options: options,
            ),
          );
        }
        final temp = questions;
        final extras = Extras(datas: {'question': questions});

        temp.map((e) => Logger().f('${e.text} | ${e.options}')).toList();
        final Quiz quiz = Quiz(
          questions: questions,
          title: jsonResponse['title'] != null
              ? jsonResponse['title'] as String
              : 'Quiz',
          createdAt: DateTime.now(),
          subject: root.subject == null || root.subject == ''
              ? 'General'
              : root.subject.toString(),
          id: uuid.v4(),
        );
        await HiveRepository().saveQuiz(quiz: quiz);
        final newMessagesList =
            List<Map<String, dynamic>>.from(state.messagesList)
              ..removeLast()
              ..add({
                'text': 'Quiz has been created successfully!',
                'typeOfMessage': TypeOfMessage.bot,
                'createdAt': DateTime.now().toIso8601String(),
                'id': uuid.v4(),
              });

        final newState = ChatBot(
          id: state.id,
          title: state.title,
          typeOfBot: state.typeOfBot,
          messagesList: newMessagesList,
          attachmentPath: state.attachmentPath,
          embeddings: state.embeddings,
          subject: state.subject,
        );
        await updateChatBot(newState);
        await router.push(AppRoute.quiz.path, extra: extras);
      } catch (e) {
        final newMessagesList =
            List<Map<String, dynamic>>.from(state.messagesList)..removeLast();

        final newState = ChatBot(
          id: state.id,
          title: state.title,
          typeOfBot: state.typeOfBot,
          messagesList: newMessagesList,
          attachmentPath: state.attachmentPath,
          embeddings: state.embeddings,
          subject: state.subject,
        );
        await updateChatBot(newState);
        Logger().e('Error Response Quiz: $e');
        await getQuizResponse(
          prompt: 'Tolong buatkan quiz dari materi tersebut',
          root: root,
        );
      }
    });
  }

  Future<void> getFlashcardResponse({
    required String prompt,
    required ChatBot root,
  }) async {
    final List<Parts> chatParts = state.messagesList.map((msg) {
      return Parts(text: msg['text'] as String);
    }).toList();

    final embeddingPrompt = await geminiRepository.promptForFlashcard(
      userPrompt: prompt,
      embeddings: state.embeddings,
    );
    chatParts.add(Parts(text: embeddingPrompt));

    final content = Content(parts: chatParts);

    Stream<Candidates> responseStream;

    responseStream =
        geminiRepository.streamContent(content: content, isPdf: true);

    final String modelMessageId = uuid.v4();
    ChatMessage placeholderMessage;

    placeholderMessage = ChatMessage(
      id: modelMessageId,
      text: 'Generating Flashcard... ',
      createdAt: DateTime.now(),
      typeOfMessage: TypeOfMessage.bot,
      chatBotId: state.id,
    );

    await updateChatBotWithMessage(placeholderMessage);

    final StringBuffer fullResponseText = StringBuffer();

    responseStream.listen((response) async {
      if (response.content!.parts!.isNotEmpty) {
        fullResponseText.write(response.content!.parts!.first.text);
        final int messageIndex =
            state.messagesList.indexWhere((msg) => msg['id'] == modelMessageId);
        if (messageIndex != -1) {
          final newMessagesList =
              List<Map<String, dynamic>>.from(state.messagesList);
          newMessagesList[messageIndex]['text'] = fullResponseText.toString();
        }
      }
    }).onDone(() async {
      try {
        Logger().i('Full Response Flashcard: $fullResponseText');
        final jsonResponse = jsonDecode(fullResponseText.toString());
        Logger().f('Success Response Flashcard: $jsonResponse');

        final List<Question> questions = [];

        for (final item in jsonResponse['flashcard'] as List<dynamic>) {
          final List<Option> options = [
            Option(
              text: item['answer'] as String,
              isCorrect: true,
            ),
          ];
          questions.add(
            Question(
              text: item['text'] as String,
              options: options,
            ),
          );
        }
        final temp = questions;
        final extras = Extras(datas: {'question': questions});

        temp.map((e) => Logger().f('${e.text} | ${e.options}')).toList();
        final Flashcard flashcard = Flashcard(
          questions: questions,
          title: jsonResponse['title'] != null
              ? jsonResponse['title'] as String
              : 'Flashcard',
          createdAt: DateTime.now(),
          subject: root.subject == null || root.subject == ''
              ? 'General'
              : root.subject.toString(),
          id: uuid.v4(),
        );
        await HiveRepository().saveFlashcard(flashcard: flashcard);
        final newMessagesList =
            List<Map<String, dynamic>>.from(state.messagesList)
              ..removeLast()
              ..add({
                'text': 'Flashcard has been created successfully!',
                'typeOfMessage': TypeOfMessage.bot,
                'createdAt': DateTime.now().toIso8601String(),
                'id': uuid.v4(),
              });

        final newState = ChatBot(
          id: state.id,
          title: state.title,
          typeOfBot: state.typeOfBot,
          messagesList: newMessagesList,
          attachmentPath: state.attachmentPath,
          embeddings: state.embeddings,
          subject: state.subject,
        );
        await updateChatBot(newState);
        await router.push(AppRoute.flashcard.path, extra: extras);
      } catch (e) {
        final newMessagesList =
            List<Map<String, dynamic>>.from(state.messagesList)..removeLast();

        final newState = ChatBot(
          id: state.id,
          title: state.title,
          typeOfBot: state.typeOfBot,
          messagesList: newMessagesList,
          attachmentPath: state.attachmentPath,
          embeddings: state.embeddings,
          subject: state.subject,
        );
        await updateChatBot(newState);
        Logger().e('Error Response Flashcard: $e');
        await getFlashcardResponse(
          prompt: 'Tolong buatkan flashcard dari materi tersebut',
          root: root,
        );
      }
    });
  }

  Future<void> updateChatBot(ChatBot newChatBot) async {
    state = newChatBot;
    await HiveRepository().saveChatBot(chatBot: state);
  }
}
