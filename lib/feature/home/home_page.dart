import 'dart:math';

import 'package:dot_navigation_bar/dot_navigation_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:si_bestie/core/config/assets_constants.dart';
import 'package:si_bestie/core/config/type_of_bot.dart';
import 'package:si_bestie/core/extension/context.dart';
import 'package:si_bestie/core/navigation/route.dart';
import 'package:si_bestie/core/navigation/router.dart';
import 'package:si_bestie/feature/chat/provider/message_provider.dart';
import 'package:si_bestie/feature/flashcard/model/flashcard.dart';
import 'package:si_bestie/feature/hive/model/chat_bot/chat_bot.dart';
import 'package:si_bestie/feature/home/provider/chat_bot_provider.dart';
import 'package:si_bestie/feature/home/widgets/widgets.dart';
import 'package:si_bestie/feature/quiz/model/quiz.dart';
import 'package:si_bestie/feature/quiz/provider/quiz_provider.dart';
import 'package:uuid/uuid.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final uuid = const Uuid();

  bool _isBuildingChatBot = false;
  String currentState = '';
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  String filePath = '';

  @override
  void initState() {
    super.initState();
    ref.read(chatBotListProvider.notifier).fetchChatBots();
    ref.read(quizProvider.notifier).fetchQuizzes();
    ref.read(quizProvider.notifier).fetchFlashcards();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildLoadingIndicator(String currentState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitDoubleBounce(
            color: context.colorScheme.onSurface,
          ),
          const SizedBox(height: 8),
          Text(currentState, style: context.textTheme.titleMedium),
        ],
      ),
    );
  }

  void _showAllHistory(
    BuildContext context, {
    List<Quiz>? quiz,
    List<Flashcard>? flashcard,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final chatBotsList = ref.watch(chatBotListProvider);
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Column(
                children: [
                  Container(
                    height: 4,
                    width: 50,
                    decoration: BoxDecoration(
                      color: context.colorScheme.onSurface,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ListView.separated(
                        itemCount: quiz != null
                            ? quiz.length
                            : flashcard != null
                                ? flashcard.length
                                : chatBotsList.length,
                        itemBuilder: (context, index) {
                          final chatBot = chatBotsList[index];
                          final imagePath = chatBot.typeOfBot == TypeOfBot.pdf
                              ? AssetConstants.pdfLogo
                              : chatBot.typeOfBot == TypeOfBot.image
                                  ? AssetConstants.imageLogo
                                  : AssetConstants.textLogo;
                          final tileColor = chatBot.typeOfBot == TypeOfBot.pdf
                              ? context.colorScheme.primary
                              : chatBot.typeOfBot == TypeOfBot.text
                                  ? context.colorScheme.secondary
                                  : context.colorScheme.tertiary;
                          return HistoryItem(
                            imagePath: imagePath,
                            label: quiz != null
                                ? quiz[index].title
                                : flashcard != null
                                    ? flashcard[index].title
                                    : chatBot.title,
                            color: tileColor,
                            chatBot: chatBot,
                            flashcard:
                                flashcard != null ? flashcard[index] : null,
                            quiz: quiz != null ? quiz[index] : null,
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatBotsList = ref.watch(chatBotListProvider);
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: _isBuildingChatBot
          ? _buildLoadingIndicator(currentState)
          : PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildHome(context, chatBotsList),
                _buildHistory(context, chatBotsList),
              ],
            ),
      bottomNavigationBar: currentState == 'Building Chat Bot' ||
              currentState == 'Extracting data'
          ? const SizedBox()
          : Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: DotNavigationBar(
                paddingR: const EdgeInsets.only(
                  top: 5,
                  bottom: 5,
                ),
                currentIndex: _currentPage,
                marginR: const EdgeInsets.symmetric(horizontal: 120),
                itemPadding: const EdgeInsets.only(
                  bottom: 5,
                  left: 10,
                  right: 10,
                  top: 5,
                ),
                dotIndicatorColor: Colors.transparent,
                enablePaddingAnimation: false,
                backgroundColor: const Color.fromARGB(255, 36, 36, 36),
                onTap: (index) {
                  setState(() {
                    _currentPage = index;
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  });
                },
                items: [
                  DotNavigationBarItem(
                    icon: const Icon(
                      Icons.home_filled,
                      size: 32,
                    ),
                    selectedColor: Colors.white,
                    unselectedColor: Colors.grey,
                  ),
                  DotNavigationBarItem(
                    icon: const Icon(
                      Icons.folder_rounded,
                      size: 32,
                    ),
                    selectedColor: Colors.white,
                    unselectedColor: Colors.grey,
                  ),
                ],
              ),
            ),
    );
  }

  SafeArea _buildHome(BuildContext context, List<ChatBot> chatBotsList) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: -300,
            top: -00,
            child: Container(
              height: 500,
              width: 600,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    Theme.of(context).colorScheme.background.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          CustomPaint(
            painter: BackgroundCurvesPainter(),
            size: Size.infinite,
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                        width: 60,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.25),
                              offset: const Offset(4, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Si Bestie AI',
                              style: TextStyle(
                                color: context.colorScheme.background,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Image.asset(
                              AssetConstants.aiStarLogo,
                              scale: 23,
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        maxRadius: 16,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                        child: IconButton(
                          icon: const Icon(
                            CupertinoIcons.settings,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'What do you want to do today?',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .copyWith(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 240,
                    child: Row(
                      children: [
                        Expanded(
                          child: CardButton(
                            title: 'Create Your Study Spaces',
                            color: context.colorScheme.primary,
                            imagePath: AssetConstants.pdfLogo,
                            isMainButton: true,
                            onPressed: () async {
                              final TextEditingController titleController =
                                  TextEditingController();

                              await showDialog<void>(
                                context: context,
                                builder: (ctx) {
                                  return AlertDialog(
                                    backgroundColor:
                                        const Color.fromARGB(255, 18, 18, 18),
                                    title: const Text('Create Study Space'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: titleController,
                                          decoration: const InputDecoration(
                                            labelText: 'Title Subject',
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () async {
                                            final result = await FilePicker
                                                .platform
                                                .pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: ['pdf'],
                                            );
                                            if (result != null) {
                                              final filePath =
                                                  result.files.single.path;
                                              setState(() {
                                                this.filePath = filePath!;
                                              });
                                            }
                                          },
                                          child: Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color:
                                                  context.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  CupertinoIcons.paperclip,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Attach PDF',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          if (filePath.isNotEmpty) {
                                            Navigator.pop(ctx);
                                          }

                                          if (filePath.isNotEmpty) {
                                            await Future.delayed(
                                              const Duration(milliseconds: 250),
                                              () {},
                                            );
                                            setState(() {
                                              _isBuildingChatBot = true;
                                              currentState = 'Extracting data';
                                            });

                                            final textChunks = await ref
                                                .read(
                                                  chatBotListProvider.notifier,
                                                )
                                                .getChunksFromPDF(filePath);

                                            setState(() {
                                              currentState =
                                                  'Building Chat Bot';
                                            });

                                            final embeddingsMap = await ref
                                                .read(
                                                  chatBotListProvider.notifier,
                                                )
                                                .batchEmbedChunks(textChunks);

                                            final chatBot = ChatBot(
                                              messagesList: [],
                                              id: uuid.v4(),
                                              title: '',
                                              typeOfBot: TypeOfBot.pdf,
                                              attachmentPath: filePath,
                                              embeddings: embeddingsMap,
                                              subject:
                                                  titleController.text.isEmpty
                                                      ? 'General'
                                                      : titleController.text,
                                            );

                                            await ref
                                                .read(
                                                  chatBotListProvider.notifier,
                                                )
                                                .saveChatBot(chatBot);
                                            await ref
                                                .read(
                                                  messageListProvider.notifier,
                                                )
                                                .updateChatBot(chatBot);
                                            setState(() {
                                              _isBuildingChatBot = false;
                                              currentState = '';
                                              filePath = '';
                                            });
                                            if (!_isBuildingChatBot) {
                                              if (!context.mounted) {
                                                return;
                                              }
                                              AppRoute.chat.push(context);
                                            }
                                          }
                                        },
                                        child: const Text('Create'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: CardButton(
                                  title: 'Chat with AI',
                                  color: context.colorScheme.secondary,
                                  imagePath: AssetConstants.textLogo,
                                  isMainButton: false,
                                  onPressed: () {
                                    final chatBot = ChatBot(
                                      messagesList: [],
                                      id: uuid.v4(),
                                      title: '',
                                      typeOfBot: TypeOfBot.text,
                                    );
                                    ref
                                        .read(chatBotListProvider.notifier)
                                        .saveChatBot(chatBot);
                                    ref
                                        .read(messageListProvider.notifier)
                                        .updateChatBot(chatBot);
                                    AppRoute.chat.push(context);
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: CardButton(
                                  title: 'Ask Image',
                                  color: context.colorScheme.tertiary,
                                  imagePath: AssetConstants.imageLogo,
                                  isMainButton: false,
                                  onPressed: () async {
                                    final pickedFile = await ref
                                        .read(chatBotListProvider.notifier)
                                        .attachImageFilePath();
                                    if (pickedFile != null) {
                                      final chatBot = ChatBot(
                                        messagesList: [],
                                        id: uuid.v4(),
                                        title: '',
                                        typeOfBot: TypeOfBot.image,
                                        attachmentPath: pickedFile,
                                      );
                                      await ref
                                          .read(chatBotListProvider.notifier)
                                          .saveChatBot(chatBot);
                                      await ref
                                          .read(messageListProvider.notifier)
                                          .updateChatBot(chatBot);
                                      if (!context.mounted) {
                                        return;
                                      }

                                      AppRoute.chat.push(context);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'History',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.95),
                                  ),
                            ),
                            TextButton(
                              onPressed: () => _showAllHistory(context),
                              child: Text(
                                'See all',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.8),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (chatBotsList.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(64),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(width: 12),
                                Text(
                                  'No chats yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                            .withOpacity(0.95),
                                      ),
                                ),
                                const Icon(CupertinoIcons.cube_box),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              chatBotsList.length > 3 ? 3 : chatBotsList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final chatBot = chatBotsList[index];
                            final imagePath = chatBot.typeOfBot == TypeOfBot.pdf
                                ? AssetConstants.pdfLogo
                                : chatBot.typeOfBot == TypeOfBot.image
                                    ? AssetConstants.imageLogo
                                    : AssetConstants.textLogo;
                            final tileColor = chatBot.typeOfBot == TypeOfBot.pdf
                                ? context.colorScheme.primary
                                : chatBot.typeOfBot == TypeOfBot.text
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).colorScheme.tertiary;
                            return HistoryItem(
                              label: chatBot.title,
                              imagePath: imagePath,
                              color: tileColor,
                              chatBot: chatBot,
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SafeArea _buildHistory(BuildContext context, List<ChatBot> chatBotsList) {
    final state = ref.watch(quizProvider);
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            left: -300,
            top: -00,
            child: Container(
              height: 500,
              width: 600,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    Theme.of(context).colorScheme.background.withOpacity(0.5),
                  ],
                ),
              ),
            ),
          ),
          CustomPaint(
            painter: BackgroundCurvesPainter(),
            size: Size.infinite,
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(
                        width: 60,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.25),
                              offset: const Offset(4, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Si Bestie AI',
                              style: TextStyle(
                                color: context.colorScheme.background,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Image.asset(
                              AssetConstants.aiStarLogo,
                              scale: 23,
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        maxRadius: 16,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.2),
                        child: IconButton(
                          icon: const Icon(
                            CupertinoIcons.settings,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () async {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your Subjects',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.95),
                                  ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                'See all',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.8),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.subjects == null || state.subjects!.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 64,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(width: 12),
                                Text(
                                  'No subjects yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                            .withOpacity(0.95),
                                      ),
                                ),
                                const Icon(CupertinoIcons.cube_box),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: state.subjects == null
                                ? []
                                : state.subjects!.map((e) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: CardButton.subject(
                                        title: e,
                                        color: [
                                          Theme.of(context)
                                              .colorScheme
                                              .tertiary,
                                          Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          Theme.of(context).colorScheme.primary,
                                        ][Random().nextInt(3)],
                                        imagePath: AssetConstants.aiStarLogo,
                                        onPressed: () {},
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Generated Quiz',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.95),
                                  ),
                            ),
                            TextButton(
                              onPressed: () => _showAllHistory(
                                context,
                                quiz: state.quiz,
                              ),
                              child: Text(
                                'See all',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.8),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.quiz == null || state.quiz!.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(64),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(width: 12),
                                Text(
                                  'No quiz yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                            .withOpacity(0.95),
                                      ),
                                ),
                                const Icon(CupertinoIcons.cube_box),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: state.quiz == null
                                ? []
                                : state.quiz!.map((e) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: CardButton.generated(
                                        subject: e.subject,
                                        title: e.title,
                                        date: e.createdAt,
                                        color: [
                                          Theme.of(context)
                                              .colorScheme
                                              .tertiary,
                                          Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          Theme.of(context).colorScheme.primary,
                                        ][Random().nextInt(3)],
                                        imagePath: AssetConstants.aiStarLogo,
                                        onPressed: () {
                                          router.push(
                                            AppRoute.quiz.path,
                                            extra: Extras(
                                              datas: {
                                                'question': e.questions,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Generated Flashcards',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    fontWeight: FontWeight.w400,
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withOpacity(0.95),
                                  ),
                            ),
                            TextButton(
                              onPressed: () => _showAllHistory(
                                context,
                                flashcard: state.flashcard,
                              ),
                              child: Text(
                                'See all',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.8),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (state.flashcard == null || state.flashcard!.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(64),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(width: 12),
                                Text(
                                  'No flashcards yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .copyWith(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                            .withOpacity(0.95),
                                      ),
                                ),
                                const Icon(CupertinoIcons.cube_box),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: state.flashcard == null
                                ? []
                                : state.flashcard!.map((e) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: CardButton.generated(
                                        subject: e.subject,
                                        title: e.title,
                                        date: e.createdAt,
                                        color: [
                                          Theme.of(context)
                                              .colorScheme
                                              .tertiary,
                                          Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                          Theme.of(context).colorScheme.primary,
                                        ][Random().nextInt(3)],
                                        imagePath: AssetConstants.aiStarLogo,
                                        onPressed: () {
                                          router.push(
                                            AppRoute.flashcard.path,
                                            extra: Extras(
                                              datas: {
                                                'question': e.questions,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
