import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/user_service.dart';
import 'services/branch_cash_service.dart';
import 'services/sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final userService = UserService();
  await userService.init();
  
  final branchCashService = BranchCashService();
  await branchCashService.init();
  
  runApp(POSCalculatorApp(
    userService: userService,
    branchCashService: branchCashService,
  ));
}

class POSCalculatorApp extends StatefulWidget {
  final UserService userService;
  final BranchCashService branchCashService;
  
  const POSCalculatorApp({
    super.key,
    required this.userService,
    required this.branchCashService,
  });

  @override
  State<POSCalculatorApp> createState() => _POSCalculatorAppState();
}

class _POSCalculatorAppState extends State<POSCalculatorApp> {
  late SyncService _syncService;
  
  @override
  void initState() {
    super.initState();
    _syncService = SyncService();
    _initSync();
  }
  
  Future<void> _initSync() async {
    final userName = widget.userService.currentUser?.name ?? 'Unknown';
    await _syncService.init(userName);
    
    // Set up sync callbacks
    _syncService.onDataReceived = (type, data) {
      switch (type) {
        case SyncMessageType.userUpdate:
          widget.userService.importUsers(List<Map<String, dynamic>>.from(data['users'] ?? []));
          break;
        case SyncMessageType.branchUpdate:
          widget.branchCashService.importData(data);
          break;
        default:
          break;
      }
    };
    
    // Start P2P sync
    await _syncService.start();
  }
  
  @override
  void dispose() {
    _syncService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.userService),
        ChangeNotifierProvider.value(value: widget.branchCashService),
        ChangeNotifierProvider.value(value: _syncService),
      ],
      child: MaterialApp(
        title: 'POS Calculator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF1E1E1E),
          cardColor: const Color(0xFF2D2D2D),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF3D3D3D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: Consumer<UserService>(
          builder: (context, userService, _) {
            if (userService.isLoggedIn) {
              return HomeScreen(
                userService: userService,
                branchCashService: widget.branchCashService,
                syncService: _syncService,
              );
            }
            return LoginScreen(
              userService: userService,
              onLoginSuccess: () {
                // Re-initialize sync with user name
                _initSync();
                setState(() {});
              },
            );
          },
        ),
      ),
    );
  }
}
