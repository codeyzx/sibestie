import 'package:easy_screenutil/easy_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:si_bestie/core/app/style.dart';
import 'package:si_bestie/core/navigation/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Si Bestie',
      theme: darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: ScreenUtil.builder,
    );
  }
}
