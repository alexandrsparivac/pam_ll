import 'app/app_dependencies.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/cubit/gem_store_cubit.dart';
import 'presentation/cubit/gem_store_state.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const GemStoreApp());
}

class GemStoreApp extends StatelessWidget {
  const GemStoreApp({super.key});
  static final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GemStoreCubit>(
      create: (context) => createGemStoreCubit()..loadData(),
      child: MaterialApp(
        scaffoldMessengerKey: _messengerKey,
        builder: (context, child) => BlocConsumer<GemStoreCubit, GemStoreState>(
          listenWhen: (previous, current) =>
              current is GemStoreSuccess &&
              current.operationError != null &&
              (previous is! GemStoreSuccess ||
                  previous.operationError != current.operationError),
          listener: (context, state) {
            if (state is GemStoreSuccess && state.operationError != null) {
              _messengerKey.currentState
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.operationError!)));
            }
          },
          builder: (context, state) => Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (state is GemStoreSuccess && state.isUpdating)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(child: LinearProgressIndicator(minHeight: 3)),
                ),
            ],
          ),
        ),
        onGenerateTitle: (context) {
          final state = context.watch<GemStoreCubit>().state;
          return state is GemStoreSuccess ? state.homeData.storeName : '';
        },
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFFFFFFF),
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF101010),
            surface: const Color(0xFFFFFFFF),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
        ),
        home: const GemStoreHomePage(),
      ),
    );
  }
}
