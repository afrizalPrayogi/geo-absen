import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

void main() {
  runApp(const EmployeeApp());
}

class EmployeeApp extends StatelessWidget {
  const EmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karyawan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.mint,
          surface: AppColors.card,
        ),
        scaffoldBackgroundColor: AppColors.background,
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: AppColors.accent.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.all(captionStyle(weight: FontWeight.w900)),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.mint, linearTrackColor: AppColors.line),
        snackBarTheme: const SnackBarThemeData(backgroundColor: AppColors.primary, contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const EmployeeRoot(),
    );
  }
}

class AppColors {
  static const background = Color(0xFFF5F8FC);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2F39A9);
  static const secondary = Color(0xFF2E6FA0);
  static const accent = Color(0xFF49A4BB);
  static const mint = Color(0xFF15D8B3);
  static const muted = Color(0xFF667085);
  static const line = Color(0xFFD9DEE7);
  static const soft = Color(0xFFEFF6FB);
  static const success = Color(0xFF0E987F);
  static const warning = Color(0xFFB7791F);
  static const error = Color(0xFFB42318);
}

class EmployeeRoot extends StatefulWidget {
  const EmployeeRoot({super.key});

  @override
  State<EmployeeRoot> createState() => _EmployeeRootState();
}

class _EmployeeRootState extends State<EmployeeRoot> {
  final api = ApiClient(apiBaseUrl);
  AppStage stage = AppStage.splash;
  AuthSession? session;

  @override
  void initState() {
    super.initState();
    _showSplash();
  }

  Future<void> _showSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => stage = AppStage.auth);
  }

  void _setSession(AuthSession nextSession) => setState(() {
        session = nextSession;
        stage = AppStage.dashboard;
      });

  void _logout() => setState(() {
        session = null;
        stage = AppStage.auth;
      });

  @override
  Widget build(BuildContext context) {
    if (stage == AppStage.splash) {
      return const SplashScreen();
    }
    if (stage == AppStage.auth || session == null) {
      return AuthScreen(api: api, onAuthenticated: _setSession);
    }
    return EmployeeShell(api: api, session: session!, onLogout: _logout);
  }
}

enum AppStage { splash, auth, dashboard }

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary, AppColors.accent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 14))],
                    ),
                    child: const Center(child: Text('AP', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -1.4))),
                  ),
                  const SizedBox(height: 22),
                  const Text('Absensi Proyek', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8)),
                  const SizedBox(height: 8),
                  Text('Absensi, lembur, dan payslip dalam satu aplikasi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.86), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 30),
                  const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.mint)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AuthMode { login, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onAuthenticated});
  final ApiClient api;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode mode = AuthMode.login;
  bool loading = false;
  String? error;
  final nameController = TextEditingController();
  final usernameController = TextEditingController(text: 'budi');
  final passwordController = TextEditingController(text: 'password');

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    if (username.length < 3 || password.length < 6 || (mode == AuthMode.register && name.length < 3)) {
      setState(() => error = mode == AuthMode.login ? 'Username dan password wajib valid.' : 'Nama, username, dan password wajib valid.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final nextSession = mode == AuthMode.login ? await widget.api.login(username, password) : await widget.api.register(name: name, username: username, password: password);
      widget.onAuthenticated(nextSession);
    } catch (err) {
      setState(() => error = friendlyError(err));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _switchMode(AuthMode nextMode) {
    setState(() {
      mode = nextMode;
      error = null;
      if (mode == AuthMode.login) {
        usernameController.text = 'budi';
        passwordController.text = 'password';
      } else {
        usernameController.clear();
        passwordController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = mode == AuthMode.login;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                    child: const Center(child: Text('AP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary))),
                  ),
                  const SizedBox(height: 26),
                  Text(isLogin ? 'Masuk ke akun karyawan' : 'Daftarkan karyawan baru', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.8)),
                  const SizedBox(height: 8),
                  Text(isLogin ? 'Gunakan akun karyawan untuk membuka dashboard.' : 'Buat akun, lalu langsung masuk ke dashboard.', style: TextStyle(color: Colors.white.withValues(alpha: 0.84), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: AuthToggle(label: 'Login', selected: isLogin, onTap: () => _switchMode(AuthMode.login))),
                      const SizedBox(width: 10),
                      Expanded(child: AuthToggle(label: 'Register', selected: !isLogin, onTap: () => _switchMode(AuthMode.register))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!isLogin) ...[
                    AuthField(label: 'Nama lengkap', controller: nameController, hint: 'Contoh: Andi Pratama'),
                    const SizedBox(height: 14),
                  ],
                  AuthField(label: 'Username', controller: usernameController, hint: 'Minimal 3 karakter'),
                  const SizedBox(height: 14),
                  AuthField(label: 'Password', controller: passwordController, hint: 'Minimal 6 karakter', obscureText: true),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(error!, style: bodyStyle(color: AppColors.error, weight: FontWeight.w800)),
                  ],
                  const SizedBox(height: 20),
                  loading ? const Center(child: CircularProgressIndicator()) : PrimaryButton(label: isLogin ? 'MASUK' : 'REGISTER & MASUK', onPressed: _submit),
                  const SizedBox(height: 12),
                  Text(isLogin ? 'Demo: budi / password' : 'Akun register tersimpan pada backend local-memory selama server hidup.', textAlign: TextAlign.center, style: captionStyle()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthToggle extends StatelessWidget {
  const AuthToggle({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.soft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.line),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.secondary, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.controller, required this.hint, this.obscureText = false});
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SectionLabel(
      title: label,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: inputDecoration(hint),
      ),
    );
  }
}

class EmployeeShell extends StatefulWidget {
  const EmployeeShell({super.key, required this.api, required this.session, required this.onLogout});

  final ApiClient api;
  final AuthSession session;
  final VoidCallback onLogout;

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  EmployeeTab tab = EmployeeTab.home;
  bool menuOpen = false;
  bool loading = true;
  String? error;
  Attendance? todayAttendance;
  List<Attendance> attendanceHistory = [];
  List<ActivityItem> activity = [];
  List<Overtime> overtimeHistory = [];
  List<PayslipItem> payslips = [];
  String currentGeoText = 'Mencari lokasi...';
  Position? currentPosition;
  XFile? checkInPhoto;
  XFile? overtimePhoto;
  final projectController = TextEditingController(text: 'Proyek Apartemen Cempaka');
  final overtimeProjectController = TextEditingController(text: 'Apartemen Cempaka');
  final overtimeNoteController = TextEditingController(text: 'Penyelesaian instalasi');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    projectController.dispose();
    overtimeProjectController.dispose();
    overtimeNoteController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadData(), _loadLocation()]);
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.todayAttendance(widget.session.token),
        widget.api.attendanceHistory(widget.session.token),
        widget.api.activity(widget.session.token),
        widget.api.overtimeHistory(widget.session.token),
        widget.api.payslips(widget.session.token),
      ]);
      setState(() {
        todayAttendance = results[0] as Attendance?;
        attendanceHistory = results[1] as List<Attendance>;
        activity = results[2] as List<ActivityItem>;
        overtimeHistory = results[3] as List<Overtime>;
        payslips = results[4] as List<PayslipItem>;
      });
    } catch (err) {
      setState(() => error = friendlyError(err));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadLocation() async {
    setState(() => currentGeoText = 'Mencari lokasi...');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => currentGeoText = 'Lokasi belum ditemukan');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => currentGeoText = 'Aktifkan izin lokasi untuk melakukan Check-in.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentPosition = position;
        currentGeoText = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      setState(() => currentGeoText = 'Lokasi belum ditemukan');
    }
  }

  Future<void> _pickPhoto({required bool overtime}) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1400,
      );
      if (image == null) return;
      setState(() {
        if (overtime) {
          overtimePhoto = image;
        } else {
          checkInPhoto = image;
        }
      });
      _snack('✓ Foto siap');
    } catch (_) {
      _snack('Foto gagal diupload. Coba upload kembali sebelum Check-in.');
    }
  }

  Future<void> _checkIn() async {
    final project = projectController.text.trim();
    if (project.length < 3) {
      _snack('Proyek / lokasi kerja wajib diisi.');
      return;
    }
    if (currentPosition == null) {
      _snack('Lokasi belum ditemukan. Aktifkan izin lokasi untuk melakukan Check-in.');
      return;
    }
    if (checkInPhoto == null) {
      _snack('Foto belum tersimpan. Coba upload kembali sebelum Check-in.');
      return;
    }
    setState(() => loading = true);
    try {
      await widget.api.checkIn(
        token: widget.session.token,
        projectName: project,
        photo: checkInPhoto!.path,
        latitude: currentPosition!.latitude,
        longitude: currentPosition!.longitude,
      );
      _snack('Check-in terkirim dan diterima server.');
      await _loadData();
    } catch (err) {
      _snack(friendlyError(err));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => loading = true);
    try {
      await widget.api.checkOut(widget.session.token);
      _snack('Check-out terkirim dan diterima server.');
      await _loadData();
    } catch (err) {
      _snack(friendlyError(err));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _startOvertime() async {
    final project = overtimeProjectController.text.trim();
    final note = overtimeNoteController.text.trim();
    if (project.length < 3 || note.length < 3) {
      _snack('Proyek dan keterangan lembur wajib diisi.');
      return;
    }
    if (currentPosition == null) {
      _snack('Lokasi belum ditemukan. Aktifkan izin lokasi untuk mulai lembur.');
      return;
    }
    if (overtimePhoto == null) {
      _snack('Foto lembur belum tersimpan.');
      return;
    }
    setState(() => loading = true);
    try {
      await widget.api.startOvertime(
        token: widget.session.token,
        projectName: project,
        description: note,
        photo: overtimePhoto!.path,
        latitude: currentPosition!.latitude,
        longitude: currentPosition!.longitude,
      );
      _snack('Lembur dimulai dan diterima server.');
      await _loadData();
    } catch (err) {
      _snack(friendlyError(err));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _finishOvertime(String overtimeId) async {
    setState(() => loading = true);
    try {
      await widget.api.finishOvertime(widget.session.token, overtimeId);
      _snack('Lembur selesai dan masuk review admin.');
      await _loadData();
    } catch (err) {
      _snack(friendlyError(err));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (tab) {
      EmployeeTab.home => _HomeScreen(
          attendance: todayAttendance,
          currentGeoText: currentGeoText,
          photo: checkInPhoto,
          projectController: projectController,
          onPickPhoto: () => _pickPhoto(overtime: false),
          onCheckIn: _checkIn,
          onCheckOut: _checkOut,
          onStartOvertimeShortcut: () => setState(() => tab = EmployeeTab.lembur),
        ),
      EmployeeTab.attendance => _AttendanceScreen(items: attendanceHistory),
      EmployeeTab.activity => _ActivityScreen(items: activity),
      EmployeeTab.lembur => _OvertimeScreen(
          attendance: todayAttendance,
          currentGeoText: currentGeoText,
          projectController: overtimeProjectController,
          noteController: overtimeNoteController,
          photo: overtimePhoto,
          overtimeHistory: overtimeHistory,
          onPickPhoto: () => _pickPhoto(overtime: true),
          onStart: _startOvertime,
          onFinish: _finishOvertime,
        ),
      EmployeeTab.profile => _ProfileScreen(user: widget.session.user),
      EmployeeTab.payslip => _PayslipScreen(items: payslips),
      EmployeeTab.help => _HelpScreen(onRetryLocation: _loadLocation),
    };

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopAppBar(
                  user: widget.session.user,
                  tab: tab,
                  onMenu: () => setState(() => menuOpen = !menuOpen),
                ),
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (error != null) ErrorBanner(message: error!, onRetry: _loadData),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _bootstrap,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 96),
                      children: [content],
                    ),
                  ),
                ),
              ],
            ),
            if (menuOpen)
              Positioned(
                top: 72,
                right: 14,
                child: AccountMenu(
                  user: widget.session.user,
                  onSelect: (nextTab) => setState(() {
                    tab = nextTab;
                    menuOpen = false;
                  }),
                  onLogout: () {
                    setState(() => menuOpen = false);
                    widget.onLogout();
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNav(
        tab: tab,
        onChanged: (nextTab) => setState(() => tab = nextTab),
      ),
    );
  }
}

enum EmployeeTab { home, attendance, activity, lembur, profile, payslip, help }

class _TopAppBar extends StatelessWidget {
  const _TopAppBar({required this.user, required this.tab, required this.onMenu});

  final AppUser user;
  final EmployeeTab tab;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final greeting = switch (tab) {
      EmployeeTab.home => 'Selamat pagi, ${firstName(user.name)}',
      EmployeeTab.lembur => 'Lembur',
      EmployeeTab.attendance => 'Attendance',
      EmployeeTab.activity => 'Activity Tim',
      EmployeeTab.profile => 'Profile',
      EmployeeTab.payslip => 'Payslip',
      EmployeeTab.help => 'Help',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_timeLabel(), style: captionStyle()),
                const SizedBox(height: 4),
                Text(greeting, style: titleStyle()),
                const SizedBox(height: 8),
                Text('Rabu, 2 September 2026', style: captionStyle()),
              ],
            ),
          ),
          IconButton(
            onPressed: onMenu,
            icon: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary),
              ),
              child: Text(initials(user.name), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.attendance,
    required this.currentGeoText,
    required this.photo,
    required this.projectController,
    required this.onPickPhoto,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onStartOvertimeShortcut,
  });

  final Attendance? attendance;
  final String currentGeoText;
  final XFile? photo;
  final TextEditingController projectController;
  final VoidCallback onPickPhoto;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onStartOvertimeShortcut;

  @override
  Widget build(BuildContext context) {
    final item = attendance;
    if (item == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StatusCard(
            label: 'STATUS HARI INI',
            title: 'BELUM CHECK-IN',
            subtitle: 'Jam kerja belum dimulai',
          ),
          const SizedBox(height: 24),
          LocationCard(value: currentGeoText),
          const SizedBox(height: 22),
          AppTextField(label: 'PROYEK / LOKASI KERJA', controller: projectController),
          const SizedBox(height: 22),
          PhotoUploadCard(photo: photo, onTap: onPickPhoto, label: 'BUKTI FOTO'),
          const SizedBox(height: 22),
          PrimaryButton(label: 'CHECK-IN', onPressed: onCheckIn),
        ],
      );
    }

    if (item.status == 'running' || item.checkOutTime == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('● SEDANG BEKERJA', style: sectionStyle(color: AppColors.success)),
                const SizedBox(height: 18),
                MetricRow(label: 'Check-in', value: timeOnly(item.checkInTime)),
                const MetricRow(label: 'Durasi', value: '04:16'),
                const SizedBox(height: 10),
                Text(item.projectName, style: sectionStyle()),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionLabel(title: 'Lokasi Check-in', child: Text('📍 ${item.geoText}', style: bodyStyle(weight: FontWeight.w800))),
          const SizedBox(height: 22),
          const SectionLabel(title: 'Bukti', child: PhotoThumb()),
          const SizedBox(height: 22),
          PrimaryButton(label: 'CHECK-OUT', onPressed: onCheckOut),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusCard(
          label: '',
          title: '✓ PEKERJAAN SELESAI',
          subtitle: 'Hari ini\n${timeOnly(item.checkInTime)} — ${timeOnly(item.checkOutTime!)}\n\nTotal kerja\n${durationLabel(item.durationMinutes)}\n\nProyek\n${item.projectName.replaceFirst('Proyek ', '')}',
          success: true,
        ),
        const SizedBox(height: 26),
        Center(child: Text('Ingin melanjutkan lembur?', style: sectionStyle())),
        const SizedBox(height: 16),
        PrimaryButton(label: 'MULAI LEMBUR', onPressed: onStartOvertimeShortcut),
      ],
    );
  }
}

class _AttendanceScreen extends StatelessWidget {
  const _AttendanceScreen({required this.items});
  final List<Attendance> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('September 2026', style: bodyStyle(weight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const EmptyState(message: 'Belum ada riwayat attendance.')
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AttendanceCard(item: item),
              )),
      ],
    );
  }
}

class _ActivityScreen extends StatelessWidget {
  const _ActivityScreen({required this.items});
  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hari ini', style: bodyStyle(weight: FontWeight.w800)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: items.map((item) => ActivityTile(item: item)).toList(),
          ),
        ),
      ],
    );
  }
}

class _OvertimeScreen extends StatelessWidget {
  const _OvertimeScreen({
    required this.attendance,
    required this.currentGeoText,
    required this.projectController,
    required this.noteController,
    required this.photo,
    required this.overtimeHistory,
    required this.onPickPhoto,
    required this.onStart,
    required this.onFinish,
  });

  final Attendance? attendance;
  final String currentGeoText;
  final TextEditingController projectController;
  final TextEditingController noteController;
  final XFile? photo;
  final List<Overtime> overtimeHistory;
  final VoidCallback onPickPhoto;
  final VoidCallback onStart;
  final Future<void> Function(String id) onFinish;

  @override
  Widget build(BuildContext context) {
    final active = overtimeHistory.where((item) => item.status == 'running').firstOrNull;
    if (active != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('● LEMBUR BERJALAN', style: sectionStyle(color: AppColors.success)),
                const SizedBox(height: 18),
                MetricRow(label: 'Mulai', value: timeOnly(active.startTime)),
                const MetricRow(label: 'Durasi', value: '01:23:16'),
                const SizedBox(height: 10),
                Text('Proyek', style: captionStyle()),
                Text(active.projectName, style: sectionStyle()),
                const SizedBox(height: 10),
                Text('Keterangan', style: captionStyle()),
                Text(active.description, style: sectionStyle()),
              ],
            ),
          ),
          const SizedBox(height: 22),
          PrimaryButton(label: 'SELESAI LEMBUR', onPressed: () => onFinish(active.id)),
        ],
      );
    }

    if (attendance?.checkOutTime == null) {
      return const EmptyState(
        title: 'Belum bisa mulai lembur',
        message: 'Selesaikan Check-out kerja normal terlebih dahulu.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Status kerja normal', style: bodyStyle()),
        Text('✓ Check-out ${timeOnly(attendance!.checkOutTime!)}', style: bodyStyle(color: AppColors.success, weight: FontWeight.w900)),
        const SizedBox(height: 22),
        AppTextField(label: 'Proyek', controller: projectController),
        const SizedBox(height: 18),
        AppTextField(label: 'Keterangan', controller: noteController, maxLines: 3),
        const SizedBox(height: 18),
        LocationCard(value: currentGeoText, compact: true),
        const SizedBox(height: 18),
        PhotoUploadCard(photo: photo, onTap: onPickPhoto, label: 'Bukti lembur'),
        const SizedBox(height: 22),
        PrimaryButton(label: 'MULAI LEMBUR', onPressed: onStart),
      ],
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: titleStyle()),
              const SizedBox(height: 4),
              Text('Employee', style: captionStyle()),
              const SizedBox(height: 18),
              const MetricRow(label: 'Status', value: 'Aktif'),
              const MetricRow(label: 'Role', value: 'Employee'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Nominal gaji tidak ditampilkan di profil karyawan.', style: captionStyle()),
      ],
    );
  }
}

class _PayslipScreen extends StatelessWidget {
  const _PayslipScreen({required this.items});
  final List<PayslipItem> items;

  @override
  Widget build(BuildContext context) {
    final item = items.firstOrNull;
    if (item == null) {
      return const EmptyState(title: 'Payslip belum tersedia', message: 'Payslip baru tampil setelah payroll diterbitkan admin.');
    }
    final payroll = item.payroll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${shortDate(payroll.periodStart)} – ${shortDate(payroll.periodEnd)}', style: bodyStyle(weight: FontWeight.w800)),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PAYSLIP', style: sectionStyle()),
              const SizedBox(height: 12),
              MetricRow(label: 'Hari kerja', value: '${payroll.workingDays} hari'),
              MetricRow(label: 'Gaji normal', value: rupiah(payroll.normalSalary)),
              MetricRow(label: 'Lembur', value: rupiah(payroll.overtimeAmount)),
              MetricRow(label: 'Cashbon', value: '-${rupiah(payroll.cashbonDeduction)}'),
              const Divider(height: 26),
              MetricRow(label: 'TOTAL', value: rupiah(payroll.netSalary), large: true),
              const SizedBox(height: 12),
              Text(payroll.status == 'paid' ? '✓ Sudah dibayar' : '✓ Payslip diterbitkan', style: bodyStyle(color: AppColors.success, weight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }
}

class _HelpScreen extends StatelessWidget {
  const _HelpScreen({required this.onRetryLocation});
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lokasi belum ditemukan', style: sectionStyle()),
              const SizedBox(height: 8),
              Text('Aktifkan izin lokasi untuk melakukan Check-in.', style: bodyStyle(color: AppColors.muted)),
              const SizedBox(height: 14),
              SecondaryButton(label: 'Coba Lagi', onPressed: onRetryLocation),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tidak ada koneksi internet', style: sectionStyle()),
              const SizedBox(height: 8),
              Text('Data Check-in belum terkirim. Jangan tampilkan sukses sebelum server menerima transaksi.', style: bodyStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.label, required this.title, required this.subtitle, this.success = false});
  final String label;
  final String title;
  final String subtitle;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label.isNotEmpty) ...[
                Text(label, style: captionStyle(weight: FontWeight.w900)),
                const SizedBox(height: 20),
              ],
              Text(title, textAlign: TextAlign.center, style: sectionStyle(color: success ? AppColors.success : AppColors.primary)),
              const SizedBox(height: 10),
              Text(subtitle, textAlign: TextAlign.center, style: bodyStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationCard extends StatelessWidget {
  const LocationCard({super.key, required this.value, this.compact = false});
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final found = value.contains(',');
    return SectionLabel(
      title: compact ? 'Lokasi' : 'LOKASI SAAT INI',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(found ? '✓ Lokasi ditemukan' : value, style: bodyStyle(color: found ? AppColors.success : AppColors.warning, weight: FontWeight.w900)),
            const SizedBox(height: 12),
            MapPreview(found: found),
            const SizedBox(height: 12),
            Text('Koordinat geolocation', style: captionStyle(weight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(found ? value : 'Koordinat belum tersedia. Coba lagi dari menu Help.', style: bodyStyle(color: found ? AppColors.primary : AppColors.muted, weight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.found});
  final bool found;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 142,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: found ? const [Color(0xFFDDF8F4), Color(0xFFEAF3FF)] : const [Color(0xFFE8EDF4), Color(0xFFF6F8FB)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(left: -20, right: -20, top: 34, child: Transform.rotate(angle: -0.18, child: Container(height: 16, color: Colors.white.withValues(alpha: 0.72)))),
            Positioned(left: 42, top: -20, bottom: -20, child: Transform.rotate(angle: 0.38, child: Container(width: 14, color: Colors.white.withValues(alpha: 0.58)))),
            Positioned(left: -10, right: -10, bottom: 28, child: Transform.rotate(angle: 0.12, child: Container(height: 12, color: AppColors.accent.withValues(alpha: 0.22)))),
            Positioned(right: 18, top: 16, child: _MapPill(label: found ? 'Live GPS' : 'GPS belum siap')),
            Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: found ? AppColors.primary : AppColors.muted, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 10))]),
                child: const Icon(Icons.location_on, color: Colors.white, size: 30),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
                child: Text('Map geolocation', style: captionStyle(weight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  const _MapPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: captionStyle(weight: FontWeight.w900)),
    );
  }
}

class PhotoUploadCard extends StatelessWidget {
  const PhotoUploadCard({super.key, required this.photo, required this.onTap, required this.label});
  final XFile? photo;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SectionLabel(
      title: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 110),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: photo == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📷 Ambil Foto', style: sectionStyle()),
                      const SizedBox(height: 6),
                      Text('Wajib sebelum check-in', style: captionStyle()),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(photo!.path), width: 120, height: 82, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      Text('✓ Foto siap', style: bodyStyle(color: AppColors.success, weight: FontWeight.w900)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.soft,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: Text('thumbnail', style: captionStyle(weight: FontWeight.w900))),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({super.key, required this.label, required this.controller, this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SectionLabel(
      title: label,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines,
        decoration: inputDecoration(null),
      ),
    );
  }
}

InputDecoration inputDecoration(String? hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: captionStyle(),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.primary, width: 1.6)),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: captionStyle(weight: FontWeight.w900)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.4)),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value, this.large = false});
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bodyStyle(color: AppColors.muted))),
          Text(value, style: large ? moneyStyle() : bodyStyle(weight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key, required this.item});
  final Attendance item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(fullDate(item.date), style: sectionStyle())),
              Text(item.status == 'running' ? '● Masuk' : '✓ Hadir', style: bodyStyle(color: AppColors.success, weight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${timeOnly(item.checkInTime)} → ${item.checkOutTime == null ? '-' : timeOnly(item.checkOutTime!)}', style: sectionStyle()),
          Text(durationLabel(item.durationMinutes), style: captionStyle()),
          const SizedBox(height: 12),
          Text(item.projectName, style: bodyStyle()),
        ],
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.status) {
      'masuk' => '●',
      'lembur_berjalan' => '●',
      'pulang' => '✓',
      _ => '○',
    };
    final label = switch (item.status) {
      'masuk' => 'Masuk · ${timeOnly(item.time)}',
      'lembur_berjalan' => 'Lembur · mulai ${timeOnly(item.time)}',
      'pulang' => 'Pulang · ${timeOnly(item.time)}',
      _ => 'Belum masuk',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$icon ${item.employeeName}', style: sectionStyle()),
          const SizedBox(height: 4),
          Text(label, style: bodyStyle()),
          if (item.projectName != null) Text(item.projectName!, style: captionStyle()),
        ],
      ),
    );
  }
}

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key, required this.user, required this.onSelect, required this.onLogout});
  final AppUser user;
  final ValueChanged<EmployeeTab> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: sectionStyle()),
            Text('Employee', style: captionStyle()),
            const SizedBox(height: 8),
            MenuButton(label: 'Profile', onTap: () => onSelect(EmployeeTab.profile)),
            MenuButton(label: 'Payslip', onTap: () => onSelect(EmployeeTab.payslip)),
            MenuButton(label: 'Help', onTap: () => onSelect(EmployeeTab.help)),
            MenuButton(label: 'Logout', onTap: onLogout),
          ],
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(42),
        alignment: Alignment.centerLeft,
        foregroundColor: AppColors.primary,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.tab, required this.onChanged});
  final EmployeeTab tab;
  final ValueChanged<EmployeeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 72,
      selectedIndex: switch (tab) {
        EmployeeTab.home => 0,
        EmployeeTab.attendance => 1,
        EmployeeTab.activity => 2,
        EmployeeTab.lembur => 3,
        _ => 0,
      },
      onDestinationSelected: (index) => onChanged([EmployeeTab.home, EmployeeTab.attendance, EmployeeTab.activity, EmployeeTab.lembur][index]),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.history_outlined), label: 'Attendance'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Activity'),
        NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Lembur'),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.title = 'Data kosong', required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(title, style: sectionStyle()),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: bodyStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message)])));
  }
}

class ErrorScaffold extends StatelessWidget {
  const ErrorScaffold({super.key, required this.title, required this.message, required this.actionLabel, required this.onAction});
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: titleStyle()),
                  const SizedBox(height: 8),
                  Text(message, style: bodyStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  PrimaryButton(label: actionLabel, onPressed: onAction),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4ED), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text(message, style: bodyStyle(color: AppColors.error, weight: FontWeight.w800))),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class ApiClient {
  ApiClient(this.baseUrl);
  final String baseUrl;

  Future<AuthSession> login(String username, String password) async {
    final json = await _request('POST', '/api/auth/login', body: {'username': username, 'password': password});
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> register({required String name, required String username, required String password}) async {
    final json = await _request('POST', '/api/auth/register', body: {'name': name, 'username': username, 'password': password});
    return AuthSession.fromJson(json);
  }

  Future<Attendance?> todayAttendance(String token) async {
    final json = await _request('GET', '/api/attendance/today', token: token);
    final value = json['attendance'];
    return value == null ? null : Attendance.fromJson(value as Map<String, dynamic>);
  }

  Future<List<Attendance>> attendanceHistory(String token) async {
    final json = await _request('GET', '/api/attendance/history', token: token);
    return (json['attendance'] as List<dynamic>).map((item) => Attendance.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ActivityItem>> activity(String token) async {
    final json = await _request('GET', '/api/activity', token: token);
    return (json['activity'] as List<dynamic>).map((item) => ActivityItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Overtime>> overtimeHistory(String token) async {
    final json = await _request('GET', '/api/overtime/history', token: token);
    return (json['overtime'] as List<dynamic>).map((item) => Overtime.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<PayslipItem>> payslips(String token) async {
    final json = await _request('GET', '/api/payslips', token: token);
    return (json['payslips'] as List<dynamic>).map((item) => PayslipItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> checkIn({required String token, required String projectName, required String photo, required double latitude, required double longitude}) async {
    await _request('POST', '/api/attendance/check-in', token: token, body: {'project_name': projectName, 'photo': photo, 'latitude': latitude, 'longitude': longitude});
  }

  Future<void> checkOut(String token) async {
    await _request('POST', '/api/attendance/check-out', token: token);
  }

  Future<void> startOvertime({required String token, required String projectName, required String description, required String photo, required double latitude, required double longitude}) async {
    await _request('POST', '/api/overtime/start', token: token, body: {'project_name': projectName, 'description': description, 'photo': photo, 'latitude': latitude, 'longitude': longitude});
  }

  Future<void> finishOvertime(String token, String id) async {
    await _request('POST', '/api/overtime/$id/finish', token: token);
  }

  Future<Map<String, dynamic>> _request(String method, String path, {String? token, Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers).timeout(const Duration(seconds: 10)),
      'POST' => http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 10)),
      _ => throw ApiException('Method tidak didukung.'),
    };
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(decoded['error']?['message']?.toString() ?? 'Terjadi kesalahan server.');
    }
    return decoded;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthSession {
  AuthSession({required this.token, required this.user});
  final String token;
  final AppUser user;
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(token: json['token'] as String, user: AppUser.fromJson(json['user'] as Map<String, dynamic>));
}

class AppUser {
  AppUser({required this.id, required this.name, required this.role, this.employeeId});
  final String id;
  final String name;
  final String role;
  final String? employeeId;
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(id: json['id'] as String, name: json['name'] as String, role: json['role'] as String, employeeId: json['employee_id'] as String?);
}

class Attendance {
  Attendance({required this.id, required this.date, required this.projectName, required this.checkInTime, required this.checkOutTime, required this.status, required this.durationMinutes, this.latitude, this.longitude});
  final String id;
  final String date;
  final String projectName;
  final String checkInTime;
  final String? checkOutTime;
  final String status;
  final int durationMinutes;
  final num? latitude;
  final num? longitude;
  String get geoText => latitude == null || longitude == null ? '-' : '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
        id: json['id'] as String,
        date: json['date'].toString().substring(0, 10),
        projectName: json['project_name'] as String,
        checkInTime: json['check_in_time'] as String,
        checkOutTime: json['check_out_time'] as String?,
        status: json['status'] as String,
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
        latitude: json['check_in_latitude'] as num?,
        longitude: json['check_in_longitude'] as num?,
      );
}

class ActivityItem {
  ActivityItem({required this.employeeName, required this.status, this.time, this.projectName});
  final String employeeName;
  final String status;
  final String? time;
  final String? projectName;
  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(employeeName: json['employee_name'] as String, status: json['status'] as String, time: json['time'] as String?, projectName: json['project_name'] as String?);
}

class Overtime {
  Overtime({required this.id, required this.projectName, required this.description, required this.startTime, this.endTime, required this.status});
  final String id;
  final String projectName;
  final String description;
  final String startTime;
  final String? endTime;
  final String status;
  factory Overtime.fromJson(Map<String, dynamic> json) => Overtime(id: json['id'] as String, projectName: json['project_name'] as String, description: json['description'] as String, startTime: json['start_time'] as String, endTime: json['end_time'] as String?, status: json['status'] as String);
}

class PayslipItem {
  PayslipItem({required this.id, required this.payroll});
  final String id;
  final Payroll payroll;
  factory PayslipItem.fromJson(Map<String, dynamic> json) => PayslipItem(id: json['id'] as String, payroll: Payroll.fromJson(json['payroll'] as Map<String, dynamic>));
}

class Payroll {
  Payroll({required this.periodStart, required this.periodEnd, required this.workingDays, required this.normalSalary, required this.overtimeAmount, required this.cashbonDeduction, required this.netSalary, required this.status});
  final String periodStart;
  final String periodEnd;
  final int workingDays;
  final int normalSalary;
  final int overtimeAmount;
  final int cashbonDeduction;
  final int netSalary;
  final String status;
  factory Payroll.fromJson(Map<String, dynamic> json) => Payroll(
        periodStart: json['period_start'].toString().substring(0, 10),
        periodEnd: json['period_end'].toString().substring(0, 10),
        workingDays: (json['working_days'] as num).toInt(),
        normalSalary: (json['normal_salary'] as num).toInt(),
        overtimeAmount: (json['overtime_amount'] as num).toInt(),
        cashbonDeduction: (json['cashbon_deduction'] as num).toInt(),
        netSalary: (json['net_salary'] as num).toInt(),
        status: json['status'] as String,
      );
}

TextStyle titleStyle() => const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.7, color: AppColors.primary);
TextStyle sectionStyle({Color color = AppColors.primary}) => TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color);
TextStyle bodyStyle({Color color = AppColors.primary, FontWeight weight = FontWeight.w500}) => TextStyle(fontSize: 15, fontWeight: weight, color: color);
TextStyle captionStyle({FontWeight weight = FontWeight.w600}) => TextStyle(fontSize: 13, fontWeight: weight, color: AppColors.muted);
TextStyle moneyStyle() => const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.1, color: AppColors.primary);

String firstName(String name) => name.split(' ').first;
String initials(String name) => name.split(' ').where((part) => part.isNotEmpty).map((part) => part[0]).take(2).join().toUpperCase();
String _timeLabel() => '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
String timeOnly(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '-';
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String durationLabel(int minutes) {
  if (minutes <= 0) return '-';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hours}j ${mins.toString().padLeft(2, '0')}m';
}

String fullDate(String date) {
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final value = DateTime.tryParse(date);
  if (value == null) return date;
  return '${days[value.weekday - 1]}, ${value.day} ${months[value.month - 1]}';
}

String shortDate(String date) {
  final value = DateTime.tryParse(date);
  if (value == null) return date;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${value.day} ${months[value.month - 1]}';
}

String rupiah(int value) {
  final text = value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  return 'Rp$text';
}

String friendlyError(Object err) {
  if (err is SocketException || err is TimeoutException) {
    return 'Tidak ada koneksi internet. Data belum terkirim.';
  }
  if (err is ApiException) return err.message;
  return 'Terjadi kesalahan. Coba lagi.';
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
