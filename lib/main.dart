import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter/providers/user_provider.dart';
import 'package:instagram_clone_flutter/responsive/mobile_screen_layout.dart';
import 'package:instagram_clone_flutter/responsive/responsive_layout.dart';
import 'package:instagram_clone_flutter/responsive/web_screen_layout.dart';
import 'package:instagram_clone_flutter/screens/login_screen.dart';
import 'package:instagram_clone_flutter/utils/colors.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instagram_clone_flutter/widgets/offline_notice.dart';
import 'package:instagram_clone_flutter/services/connectivity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  final env = dotenv.env['ENV'] ?? 'dev';
  final url = env == 'prod' ? dotenv.env['SUPABASE_URL_PROD'] : dotenv.env['SUPABASE_URL_DEV'];
  final key = env == 'prod' ? dotenv.env['SUPABASE_ANON_KEY_PROD'] : dotenv.env['SUPABASE_ANON_KEY_DEV'];
  if (url == null || key == null) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: Exception('Missing Supabase configuration'),
      stack: StackTrace.current,
      library: 'main',
      context: ErrorDescription('Reading .env for Supabase config'),
    ));
  } else {
    await Supabase.initialize(url: url, anonKey: key);
  }
  ConnectivityService.instance.start();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return p.MultiProvider(
      providers: [
        p.ChangeNotifierProvider(create: (_) => UserProvider(),),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Instagram Clone',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: mobileBackgroundColor,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: primaryColor,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: blueColor,
          ),
        ),
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: ConnectivityService.instance.hasResult,
                  builder: (context, hasResult, _) {
                    if (!hasResult) return const SizedBox.shrink();
                    return ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService.instance.isOnline,
                      builder: (context, online, __) {
                        if (online) return const SizedBox.shrink();
                        return Container(
                          color: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          child: const Text('No internet connection', style: TextStyle(fontSize: 12)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const OfflineNotice();
            }
            if (snapshot.connectionState == ConnectionState.active) {
              final session = snapshot.data?.session;
              if (session != null) {
                return const ResponsiveLayout(
                  mobileScreenLayout: MobileScreenLayout(),
                  webScreenLayout: WebScreenLayout(),
                );
              } else {
                return const LoginScreen();
              }
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
