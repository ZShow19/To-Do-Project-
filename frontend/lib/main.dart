import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _ink = Color(0xFF1A1A1A);
const _accent = Color(0xFF6C63FF);
const _green = Color(0xFF27AE60);
const _orange = Color(0xFFF2994A);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(ApiClient());
  await store.load();
  runApp(TodoApp(store: store));
}

class ApiClient {
  ApiClient({this.baseUrl = 'http://localhost:5107/api'});
  final String baseUrl;

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = {'Content-Type': 'application/json'};
    late http.Response response;
    if (method == 'GET') response = await http.get(uri, headers: headers);
    if (method == 'POST')
      response = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (method == 'PUT')
      response = await http.put(uri, headers: headers, body: jsonEncode(body));
    if (method == 'PATCH')
      response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
    if (method == 'DELETE') response = await http.delete(uri, headers: headers);
    if (response.statusCode >= 400)
      throw Exception('API ${response.statusCode}');
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<List<TaskItem>> tasks() async => (await _send('GET', '/tasks') as List)
      .map((e) => TaskItem.fromJson(e))
      .toList();
  Future<TaskItem> createTask(TaskItem task) async =>
      TaskItem.fromJson(await _send('POST', '/tasks', task.toJson()));
  Future<TaskItem> completeTask(String id, bool value) async =>
      TaskItem.fromJson(
        await _send('PATCH', '/tasks/$id/complete', {'isCompleted': value}),
      );
  Future<void> deleteTask(String id) => _send('DELETE', '/tasks/$id');
  Future<DailyLog> dailyLog(DateTime date) async =>
      DailyLog.fromJson(await _send('GET', '/daily-logs/${dateKey(date)}'));
  Future<DailyLog> saveDailyLog(DailyLog log) async => DailyLog.fromJson(
    await _send('PUT', '/daily-logs/${dateKey(log.date)}', log.toJson()),
  );
  Future<List<FoodProduct>> products([String? search]) async => (await _send(
    'GET',
    '/products${search == null ? '' : '?search=${Uri.encodeQueryComponent(search)}'}',
  ) as List).map((e) => FoodProduct.fromJson(e)).toList();
  Future<FoodProduct> createProduct(FoodProduct p) async =>
      FoodProduct.fromJson(await _send('POST', '/products', p.toJson()));
  Future<List<MealEntry>> meals(DateTime date) async =>
      (await _send('GET', '/meals?date=${dateKey(date)}') as List)
          .map((e) => MealEntry.fromJson(e))
          .toList();
  Future<MealEntry> createMeal(MealEntry meal) async =>
      MealEntry.fromJson(await _send('POST', '/meals', meal.toJson()));
  Future<void> deleteMeal(String id) => _send('DELETE', '/meals/$id');
  Future<UserSettings> settings() async =>
      UserSettings.fromJson(await _send('GET', '/settings'));
  Future<UserSettings> saveSettings(UserSettings settings) async =>
      UserSettings.fromJson(await _send('PUT', '/settings', settings.toJson()));
  Future<StatsData> stats(DateTime from, DateTime to) async =>
      StatsData.fromJson(
        await _send('GET', '/stats?from=${dateKey(from)}&to=${dateKey(to)}'),
      );
  Future<dynamic> exportData() => _send('GET', '/export');
}

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String dateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

class TaskItem {
  TaskItem({
    this.id = '',
    required this.title,
    this.description = '',
    this.category = 'Р вЂєР С‘РЎвЂЎР Р…Р С•Р Вµ',
    this.priority = 'Р РЋРЎР‚Р ВµР Т‘Р Р…Р С‘Р в„–',
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  String id, title, description, category, priority;
  DateTime? dueDate, completedAt;
  bool isCompleted;
  DateTime createdAt;
  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
    id: '${json['id'] ?? ''}',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    category: json['category'] ?? 'Р вЂєР С‘РЎвЂЎР Р…Р С•Р Вµ',
    priority: json['priority'] ?? 'Р РЋРЎР‚Р ВµР Т‘Р Р…Р С‘Р в„–',
    dueDate: json['dueDateUtc'] == null
        ? null
        : DateTime.tryParse(json['dueDateUtc']),
    isCompleted: json['isCompleted'] == true,
    completedAt: json['completedAtUtc'] == null
        ? null
        : DateTime.tryParse(json['completedAtUtc']),
    createdAt: DateTime.tryParse(json['createdAtUtc'] ?? '') ?? DateTime.now(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'dueDateUtc': dueDate?.toUtc().toIso8601String(),
    'isCompleted': isCompleted,
    'completedAtUtc': completedAt?.toUtc().toIso8601String(),
    'createdAtUtc': createdAt.toUtc().toIso8601String(),
  };
}

class DailyLog {
  DailyLog({required this.date, this.score = 5, this.note = ''});
  DateTime date;
  double score;
  String note;
  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    score: (json['productivityScore'] as num?)?.toDouble() ?? 5,
    note: json['note'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'date': dateKey(date),
    'productivityScore': score,
    'note': note,
  };
}

class FoodProduct {
  FoodProduct({
    this.id = '',
    required this.name,
    this.calories = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.isCustom = false,
  });
  String id, name;
  double calories, protein, fat, carbs;
  bool isCustom;
  factory FoodProduct.fromJson(Map<String, dynamic> json) => FoodProduct(
    id: '${json['id'] ?? ''}',
    name: json['name'] ?? '',
    calories: (json['caloriesPer100g'] as num?)?.toDouble() ?? 0,
    protein: (json['proteinPer100g'] as num?)?.toDouble() ?? 0,
    fat: (json['fatPer100g'] as num?)?.toDouble() ?? 0,
    carbs: (json['carbsPer100g'] as num?)?.toDouble() ?? 0,
    isCustom: json['isCustom'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'caloriesPer100g': calories,
    'proteinPer100g': protein,
    'fatPer100g': fat,
    'carbsPer100g': carbs,
    'isCustom': isCustom,
  };
}

class MealEntry {
  MealEntry({
    this.id = '',
    required this.date,
    required this.mealType,
    required this.product,
    required this.weight,
    this.calories = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
  });
  String id, mealType;
  DateTime date;
  FoodProduct product;
  double weight, calories, protein, fat, carbs;
  factory MealEntry.fromJson(Map<String, dynamic> json) {
    final product = FoodProduct.fromJson(
      (json['product'] as Map?)?.cast<String, dynamic>() ??
          {'id': json['productId'], 'name': 'Р СџРЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљ'},
    );
    return MealEntry(
      id: '${json['id'] ?? ''}',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      mealType: json['mealType'] ?? 'Р СџР ВµРЎР‚Р ВµР С”РЎС“РЎРѓ',
      product: product,
      weight: (json['weightGrams'] as num?)?.toDouble() ?? 0,
      calories: (json['calculatedCalories'] as num?)?.toDouble() ?? 0,
      protein: (json['calculatedProtein'] as num?)?.toDouble() ?? 0,
      fat: (json['calculatedFat'] as num?)?.toDouble() ?? 0,
      carbs: (json['calculatedCarbs'] as num?)?.toDouble() ?? 0,
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dateKey(date),
    'mealType': mealType,
    'productId': product.id,
    'weightGrams': weight,
  };
}

class UserSettings {
  UserSettings({
    this.themeMode = 'system',
    this.calories = 2200,
    this.protein = 140,
    this.fat = 70,
    this.carbs = 240,
    this.minimumTasks = 3,
  });
  String themeMode;
  double calories, protein, fat, carbs;
  int minimumTasks;
  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    themeMode: json['themeMode'] ?? 'system',
    calories: (json['targetCalories'] as num?)?.toDouble() ?? 2200,
    protein: (json['targetProtein'] as num?)?.toDouble() ?? 140,
    fat: (json['targetFat'] as num?)?.toDouble() ?? 70,
    carbs: (json['targetCarbs'] as num?)?.toDouble() ?? 240,
    minimumTasks: (json['minimumTasksPerDay'] as num?)?.toInt() ?? 3,
  );
  Map<String, dynamic> toJson() => {
    'id': 1,
    'themeMode': themeMode,
    'targetCalories': calories,
    'targetProtein': protein,
    'targetFat': fat,
    'targetCarbs': carbs,
    'minimumTasksPerDay': minimumTasks,
  };
}

class DayStat {
  DayStat({
    required this.date,
    this.planned = 0,
    this.completed = 0,
    this.status = 'empty',
    this.productivity = 0,
    this.note = '',
    this.calories = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
  });
  DateTime date;
  int planned, completed;
  String status, note;
  double productivity, calories, protein, fat, carbs;
  factory DayStat.fromJson(Map<String, dynamic> json) => DayStat(
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    planned: json['plannedTasks'] ?? 0,
    completed: json['completedTasks'] ?? 0,
    status: json['status'] ?? 'empty',
    productivity: (json['productivityScore'] as num?)?.toDouble() ?? 0,
    note: json['note'] ?? '',
    calories: (json['calories'] as num?)?.toDouble() ?? 0,
    protein: (json['protein'] as num?)?.toDouble() ?? 0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0,
    carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
  );
}

class StatsData {
  StatsData(this.days, this.points);
  List<DayStat> days;
  List<MetricPoint> points;
  factory StatsData.fromJson(Map<String, dynamic> json) => StatsData(
    (json['days'] as List? ?? []).map((e) => DayStat.fromJson(e)).toList(),
    (json['points'] as List? ?? [])
        .map((e) => MetricPoint.fromJson(e))
        .toList(),
  );
}

class MetricPoint {
  MetricPoint(this.date, this.productivity, this.completion, this.completed);
  DateTime date;
  double productivity, completion;
  int completed;
  factory MetricPoint.fromJson(Map<String, dynamic> j) => MetricPoint(
    DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    (j['productivity'] as num?)?.toDouble() ?? 0,
    (j['completionPercent'] as num?)?.toDouble() ?? 0,
    j['completedTasks'] ?? 0,
  );
}

class AppStore extends ChangeNotifier {
  void refresh() => notifyListeners();
  AppStore(this.api);
  final ApiClient api;
  int page = 0;
  bool loading = true;
  String search = '';
  String? error;
  ThemeMode themeMode = ThemeMode.system;
  List<TaskItem> tasks = [];
  List<FoodProduct> products = [];
  List<MealEntry> meals = [];
  List<DayStat> stats = [];
  DailyLog todayLog = DailyLog(date: DateTime.now());
  UserSettings settings = UserSettings();
  int get completedToday => tasks
      .where(
        (t) =>
            t.isCompleted &&
            _sameDay(
              t.dueDate ?? t.completedAt ?? DateTime.now(),
              DateTime.now(),
            ),
      )
      .length;
  List<TaskItem> get todayTasks => tasks
      .where((t) => _sameDay(t.dueDate ?? DateTime.now(), DateTime.now()))
      .toList();
  int get streak {
    var count = 0;
    for (final day in stats.reversed) {
      if (day.completed > 0)
        count++;
      else if (count > 0)
        break;
    }
    return count;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('themeMode') ?? 'system';
    themeMode = mode == 'dark'
        ? ThemeMode.dark
        : mode == 'light'
        ? ThemeMode.light
        : ThemeMode.system;
    try {
      tasks = await api.tasks();
    } catch (_) {
      tasks = _demoTasks();
    }
    try {
      settings = await api.settings();
    } catch (_) {}
    try {
      products = await api.products();
    } catch (_) {
      products = _demoProducts();
    }
    try {
      todayLog = await api.dailyLog(DateTime.now());
    } catch (_) {}
    try {
      meals = await api.meals(DateTime.now());
    } catch (_) {}
    try {
      stats = (await api.stats(
        DateTime.now().subtract(const Duration(days: 30)),
        DateTime.now(),
      )).days;
    } catch (_) {
      stats = _demoStats();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> saveTheme(String value) async {
    themeMode = value == 'dark'
        ? ThemeMode.dark
        : value == 'light'
        ? ThemeMode.light
        : ThemeMode.system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', value);
    settings.themeMode = value;
    try {
      settings = await api.saveSettings(settings);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addTask(String title) async {
    if (title.trim().isEmpty) return;
    final task = TaskItem(title: title.trim(), dueDate: DateTime.now());
    try {
      tasks.insert(0, await api.createTask(task));
    } catch (_) {
      tasks.insert(0, task);
    }
    notifyListeners();
  }

  Future<void> toggleTask(TaskItem task, bool value) async {
    task.isCompleted = value;
    task.completedAt = value ? DateTime.now() : null;
    try {
      final updated = await api.completeTask(task.id, value);
      task.isCompleted = updated.isCompleted;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeTask(TaskItem task) async {
    tasks.remove(task);
    try {
      if (task.id.isNotEmpty) await api.deleteTask(task.id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveLog() async {
    try {
      todayLog = await api.saveDailyLog(todayLog);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> addMeal(MealEntry meal) async {
    try {
      meals.add(await api.createMeal(meal));
    } catch (_) {
      meals.add(meal);
    }
    notifyListeners();
  }

  Future<void> removeMeal(MealEntry meal) async {
    meals.remove(meal);
    try {
      if (meal.id.isNotEmpty) await api.deleteMeal(meal.id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveSettings() async {
    try {
      settings = await api.saveSettings(settings);
    } catch (_) {}
    notifyListeners();
  }

  Future<String> exportJson() async {
    try {
      return const JsonEncoder.withIndent('  ').convert(await api.exportData());
    } catch (_) {
      return jsonEncode({
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      });
    }
  }

  List<TaskItem> filteredTasks(String filter) {
    final list = tasks.where((t) {
      if (search.isNotEmpty &&
          !('${t.title} ${t.description} ${t.category}'.toLowerCase().contains(
            search.toLowerCase(),
          )))
        return false;
      if (filter == 'Р вЂ™РЎвЂ№Р С—Р С•Р В»Р Р…Р ВµР Р…Р С•')
        return t.isCompleted;
      if (filter == 'Р вЂ™ РЎР‚Р В°Р В±Р С•РЎвЂљР Вµ') return !t.isCompleted;
      if (filter == 'Р СџРЎР‚Р С•РЎРѓРЎР‚Р С•РЎвЂЎР ВµР Р…Р С•')
        return !t.isCompleted &&
            t.dueDate != null &&
            t.dueDate!.isBefore(DateTime.now());
      return true;
    }).toList();
    return list;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  List<TaskItem> _demoTasks() => [
    TaskItem(
      title: 'Р РЋР С•РЎРѓРЎвЂљР В°Р Р†Р С‘РЎвЂљРЎРЉ Р С—Р В»Р В°Р Р… Р Т‘Р Р…РЎРЏ',
      category: 'Р вЂєР С‘РЎвЂЎР Р…Р С•Р Вµ',
      priority: 'Р вЂ™РЎвЂ№РЎРѓР С•Р С”Р С‘Р в„–',
      dueDate: DateTime.now(),
      isCompleted: true,
    ),
    TaskItem(
      title:
          'Р СћРЎР‚Р ВµР Р…Р С‘РЎР‚Р С•Р Р†Р С”Р В° 45 Р СР С‘Р Р…РЎС“РЎвЂљ',
      category: 'Р РЋР С—Р С•РЎР‚РЎвЂљ',
      priority: 'Р РЋРЎР‚Р ВµР Т‘Р Р…Р С‘Р в„–',
      dueDate: DateTime.now(),
    ),
    TaskItem(
      title: 'Р СџРЎР‚Р С•РЎвЂЎР С‘РЎвЂљР В°РЎвЂљРЎРЉ Р С–Р В»Р В°Р Р†РЎС“ Р С”Р Р…Р С‘Р С–Р С‘',
      category: 'Р Р€РЎвЂЎРЎвЂР В±Р В°',
      priority: 'Р СњР С‘Р В·Р С”Р С‘Р в„–',
      dueDate: DateTime.now(),
    ),
    TaskItem(
      title: 'Р В Р В°Р В·Р С•Р В±РЎР‚Р В°РЎвЂљРЎРЉ Р С—Р С•РЎвЂЎРЎвЂљРЎС“',
      category: 'Р В Р В°Р В±Р С•РЎвЂљР В°',
      priority: 'Р РЋРЎР‚Р ВµР Т‘Р Р…Р С‘Р в„–',
      dueDate: DateTime.now(),
    ),
  ];
  List<FoodProduct> _demoProducts() => [
    FoodProduct(
      id: 'chicken',
      name: 'Р С™РЎС“РЎР‚Р С‘Р Р…Р В°РЎРЏ Р С–РЎР‚РЎС“Р Т‘Р С”Р В°',
      calories: 165,
      protein: 31,
      fat: 3.6,
    ),
    FoodProduct(
      id: 'rice',
      name: 'Р В Р С‘РЎРѓ',
      calories: 344,
      protein: 6.7,
      fat: .7,
      carbs: 78,
    ),
    FoodProduct(
      id: 'banana',
      name: 'Р вЂР В°Р Р…Р В°Р Р…',
      calories: 89,
      protein: 1.1,
      fat: .3,
      carbs: 23,
    ),
  ];
  List<DayStat> _demoStats() => List.generate(31, (i) {
    final d = DateTime.now().subtract(Duration(days: 30 - i));
    final done = i % 5 == 0 ? 0 : i % 3 + 1;
    return DayStat(
      date: d,
      planned: 4,
      completed: done,
      status: done == 0
          ? 'empty'
          : done == 4
          ? 'complete'
          : 'partial',
      productivity: done == 0 ? 0 : 5 + (i % 5) / 2,
    );
  });
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      title: 'Р РЋР Р†Р С•Р в„– Р Т‘Р ВµР Р…РЎРЉ',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: store.themeMode,
      home: AppShell(store: store),
    ),
  );
  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Arial',
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: brightness,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: dark
          ? const Color(0xFF111214)
          : const Color(0xFFF6F6F7),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1A1C1E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: dark ? const Color(0xFF2C2F33) : const Color(0xFFE3E3E3),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF242629) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final AppStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final searchController = TextEditingController();
  final quickController = TextEditingController();
  final titles = [
    'Р вЂњР В»Р В°Р Р†Р Р…Р В°РЎРЏ',
    'Р вЂ”Р В°Р Т‘Р В°РЎвЂЎР С‘',
    'Р РЋРЎвЂљР В°РЎвЂљР С‘РЎРѓРЎвЂљР С‘Р С”Р В°',
    'Р СџР С‘РЎвЂљР В°Р Р…Р С‘Р Вµ Р С‘ Р вЂР вЂ“Р Р€',
  ];

  @override
  void dispose() {
    searchController.dispose();
    quickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (_) {
              FocusScope.of(context).requestFocus(FocusNode());
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Column(
            children: [
              TopBar(store: widget.store, controller: searchController),
              Expanded(
                child: Row(
                  children: [
                    Sidebar(store: widget.store, wide: wide, titles: titles),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 28 : 16,
                          24,
                          wide ? 36 : 16,
                          28,
                        ),
                        child: _page(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page() {
    switch (widget.store.page) {
      case 1:
        return TasksPage(store: widget.store);
      case 2:
        return StatsPage(store: widget.store);
      case 3:
        return NutritionPage(store: widget.store);
      case 4:
        return SettingsPage(store: widget.store);
      default:
        return DashboardPage(
          store: widget.store,
          quickController: quickController,
        );
    }
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.store, required this.controller});
  final AppStore store;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    color: _ink,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'Р РЋР Р†Р С•Р в„– Р Т‘Р ВµР Р…РЎРЉ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(width: 38),
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: TextField(
              controller: controller,
              onChanged: (v) {
                store.search = v;
                store.refresh();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Р СџР С•Р С‘РЎРѓР С” Р В·Р В°Р Т‘Р В°РЎвЂЎ Р С‘ Р С—РЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљР С•Р Р†',
                hintStyle: TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Ctrl K',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: Color(0xFFFFB86B),
              ),
              const SizedBox(width: 5),
              Text(
                '${store.streak} Р Т‘Р Р…Р ВµР в„–',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFF8A84FF),
          child: Text(
            'Р С’',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.store,
    required this.wide,
    required this.titles,
  });
  final AppStore store;
  final bool wide;
  final List<String> titles;
  final icons = const [
    Icons.home_outlined,
    Icons.checklist_rounded,
    Icons.insights_outlined,
    Icons.restaurant_outlined,
  ];
  @override
  Widget build(BuildContext context) => Container(
    width: wide ? 238 : 78,
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1C1E)
        : const Color(0xFFF1F1F1),
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
    child: Column(
      children: [
        for (var i = 0; i < titles.length; i++)
          _item(context, i, icons[i], titles[i]),
        const Spacer(),
        _item(
          context,
          4,
          Icons.settings_outlined,
          'Р СњР В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–Р С”Р С‘',
        ),
      ],
    ),
  );
  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final selected = store.page == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          store.page = index;
          store.refresh();
        },
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? _accent.withOpacity(.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? _accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 21,
              ),
              if (wide) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? _accent
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 5),
        Text(
          subtitle!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.store,
    required this.quickController,
  });
  final AppStore store;
  final TextEditingController quickController;
  @override
  Widget build(BuildContext context) {
    final today = store.todayTasks;
    return ListView(
      children: [
        const PageTitle(
          title: 'Р”РѕР±СЂС‹Р№ РґРµРЅСЊ, РђРЅРґСЂРµР№',
          subtitle: 'РЎРѕР±РµСЂС‘Рј СЃРїРѕРєРѕР№РЅС‹Р№ Рё РїСЂРѕРґСѓРєС‚РёРІРЅС‹Р№ РґРµРЅСЊ.',
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: quickController,
                onSubmitted: (v) {
                  store.addTask(v);
                  quickController.clear();
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.add_task_rounded),
                  hintText: 'Р‘С‹СЃС‚СЂРѕ РґРѕР±Р°РІРёС‚СЊ Р·Р°РґР°С‡Сѓ Рё РЅР°Р¶Р°С‚СЊ Enter',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () {
                store.addTask(quickController.text);
                quickController.clear();
              },
              icon: const Icon(Icons.add),
              label: const Text('Р”РѕР±Р°РІРёС‚СЊ'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (_, c) {
            final columns = c.maxWidth > 900
                ? 4
                : c.maxWidth > 560
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 2.2,
              children: [
                _KpiCard(
                  title: 'Р—Р°РґР°С‡Рё Р·Р° РґРµРЅСЊ',
                  value: '${store.completedToday} / ${today.length}',
                  icon: Icons.task_alt_rounded,
                  color: _accent,
                  onTap: () {
                    store.page = 1;
                    store.refresh();
                  },
                ),
                _KpiCard(
                  title: 'РџСЂРѕРґСѓРєС‚РёРІРЅРѕСЃС‚СЊ РґРЅСЏ',
                  value: '${store.todayLog.score.toStringAsFixed(1)} / 10',
                  icon: Icons.bolt_rounded,
                  color: _orange,
                ),
                _KpiCard(
                  title: 'РљР°Р»РѕСЂРёРё Рё Р‘Р–РЈ',
                  value:
                      '${store.meals.fold<double>(0, (s, m) => s + m.calories).round()} РєРєР°Р»',
                  icon: Icons.local_fire_department_outlined,
                  color: const Color(0xFFE85D75),
                  onTap: () {
                    store.page = 3;
                    store.refresh();
                  },
                ),
                _KpiCard(
                  title: 'РЎС‚СЂРёРє',
                  value: '${store.streak} РґРЅРµР№',
                  icon: Icons.local_fire_department_rounded,
                  color: _green,
                  onTap: () {
                    store.page = 2;
                    store.refresh();
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (_, c) {
            final wide = c.maxWidth > 900;
            final productivity = SectionCard(
              child: _ProductivityEditor(store: store),
            );
            final tasks = SectionCard(child: _TodayTasks(store: store));
            if (!wide)
              return Column(
                children: [productivity, const SizedBox(height: 18), tasks],
              );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: productivity),
                const SizedBox(width: 18),
                Expanded(flex: 4, child: tasks),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        SectionCard(child: _MiniHeatmap(store: store)),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProductivityEditor extends StatelessWidget {
  const _ProductivityEditor({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Р С›РЎвЂ Р ВµР Р…Р С”Р В° Р С—РЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљР С‘',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 8),
      Text(
        '${store.todayLog.score.toStringAsFixed(1)} / 10',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: _accent,
        ),
      ),
      Slider(
        value: store.todayLog.score.clamp(1, 10),
        min: 1,
        max: 10,
        divisions: 18,
        label: store.todayLog.score.toStringAsFixed(1),
        onChanged: (v) {
          store.todayLog.score = v;
          store.refresh();
        },
        onChangeEnd: (_) => store.saveLog(),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Р СњР С‘Р В·Р С”Р В°РЎРЏ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          Text(
            'Р СљР В°Р С”РЎРѓР С‘Р СРЎС“Р С',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        maxLines: 3,
        controller: TextEditingController(text: store.todayLog.note)
          ..selection = TextSelection.collapsed(
            offset: store.todayLog.note.length,
          ),
        onChanged: (v) => store.todayLog.note = v,
        onEditingComplete: store.saveLog,
        decoration: const InputDecoration(
          labelText:
              'Р С™Р В°Р С” Р С—РЎР‚Р С•РЎв‚¬РЎвЂР В» Р Т‘Р ВµР Р…РЎРЉ?',
          alignLabelWithHint: true,
        ),
      ),
    ],
  );
}

class _TodayTasks extends StatelessWidget {
  const _TodayTasks({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) {
    final list = store.todayTasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Р вЂ”Р В°Р Т‘Р В°РЎвЂЎР С‘ Р Р…Р В° РЎРѓР ВµР С–Р С•Р Т‘Р Р…РЎРЏ',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            TextButton(
              onPressed: () {
                store.page = 1;
                store.refresh();
              },
              child: const Text('Р вЂ™РЎРѓР Вµ Р В·Р В°Р Т‘Р В°РЎвЂЎР С‘'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Р вЂќР С•Р В±Р В°Р Р†РЎРЉРЎвЂљР Вµ Р С—Р ВµРЎР‚Р Р†РЎС“РЎР‹ Р В·Р В°Р Т‘Р В°РЎвЂЎРЎС“',
              ),
            ),
          ),
        for (final task in list.take(5)) _TaskRow(task: task, store: store),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.store});
  final TaskItem task;
  final AppStore store;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Checkbox(
          value: task.isCompleted,
          onChanged: (v) => store.toggleTask(task, v ?? false),
        ),
        Expanded(
          child: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
        _PriorityBadge(value: task.priority),
      ],
    ),
  );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = value == 'Р вЂ™РЎвЂ№РЎРѓР С•Р С”Р С‘Р в„–'
        ? const Color(0xFFD9534F)
        : value == 'Р СњР С‘Р В·Р С”Р С‘Р в„–'
        ? _green
        : _orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniHeatmap extends StatelessWidget {
  const _MiniHeatmap({required this.store});
  final AppStore store;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Р С’Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљРЎРЉ Р В·Р В° Р С—Р С•РЎРѓР В»Р ВµР Т‘Р Р…Р С‘Р Вµ Р Р…Р ВµР Т‘Р ВµР В»Р С‘',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 5,
        runSpacing: 5,
        children: List.generate(84, (i) {
          final value = store.stats.isEmpty
              ? i % 4
              : (store.stats[i % store.stats.length].completed);
          return Tooltip(
            message:
                'Р вЂќР ВµР Р…РЎРЉ Р В°Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљР С‘',
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value == 0
                    ? Theme.of(context).dividerColor.withOpacity(.3)
                    : _accent.withOpacity(value > 2 ? .9 : .42),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    ],
  );
}

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.store});
  final AppStore store;
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String filter = 'Р’СЃРµ';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.store.filteredTasks(filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const PageTitle(
              title: 'Р—Р°РґР°С‡Рё',
              subtitle: 'РџР»Р°РЅРёСЂСѓР№С‚Рµ, РІС‹РїРѕР»РЅСЏР№С‚Рµ Рё РґРµСЂР¶РёС‚Рµ С„РѕРєСѓСЃ.',
            ),
            FilledButton.icon(
              onPressed: () => _addTask(context),
              icon: const Icon(Icons.add),
              label: const Text('Р”РѕР±Р°РІРёС‚СЊ Р·Р°РґР°С‡Сѓ'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: search,
                onChanged: (v) {
                  widget.store.search = v;
                  widget.store.refresh();
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Р¤РёР»СЊС‚СЂ РїРѕ РЅР°Р·РІР°РЅРёСЋ, РѕРїРёСЃР°РЅРёСЋ РёР»Рё РєР°С‚РµРіРѕСЂРёРё',
                ),
              ),
            ),
            const SizedBox(width: 14),
            PopupMenuButton<String>(
              initialValue: filter,
              onSelected: (v) => setState(() => filter = v),
              itemBuilder: (_) => [
                'Р’СЃРµ',
                'Р’ СЂР°Р±РѕС‚Рµ',
                'Р’С‹РїРѕР»РЅРµРЅРѕ',
                'РџСЂРѕСЃСЂРѕС‡РµРЅРѕ',
              ].map((x) => PopupMenuItem(value: x, child: Text(x))).toList(),
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.filter_list),
                label: Text(filter),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'Р—Р°РґР°С‡ РїРѕ РІС‹Р±СЂР°РЅРЅРѕРјСѓ С„РёР»СЊС‚СЂСѓ РЅРµС‚',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _TaskTableRow(task: list[i], store: widget.store),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _addTask(BuildContext context) async {
    final title = TextEditingController();
    final description = TextEditingController();
    String category = 'Р›РёС‡РЅРѕРµ';
    String priority = 'РЎСЂРµРґРЅРёР№';
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('РќРѕРІР°СЏ Р·Р°РґР°С‡Р°'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'РќР°Р·РІР°РЅРёРµ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'РћРїРёСЃР°РЅРёРµ',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'РљР°С‚РµРіРѕСЂРёСЏ',
                        ),
                        items:
                            [
                                  'Р›РёС‡РЅРѕРµ',
                                  'Р Р°Р±РѕС‚Р°',
                                  'РЈС‡С‘Р±Р°',
                                  'РЎРїРѕСЂС‚',
                                ]
                                .map(
                                  (x) => DropdownMenuItem(
                                    value: x,
                                    child: Text(x),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => set(() => category = v ?? category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'РџСЂРёРѕСЂРёС‚РµС‚',
                        ),
                        items:
                            ['Р’С‹СЃРѕРєРёР№', 'РЎСЂРµРґРЅРёР№', 'РќРёР·РєРёР№']
                                .map(
                                  (x) => DropdownMenuItem(
                                    value: x,
                                    child: Text(x),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => set(() => priority = v ?? priority),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('РћС‚РјРµРЅР°'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('РЎРѕР·РґР°С‚СЊ'),
            ),
          ],
        ),
      ),
    );
    if (result == true && title.text.trim().isNotEmpty) {
      final task = TaskItem(
        title: title.text,
        description: description.text,
        category: category,
        priority: priority,
        dueDate: DateTime.now(),
      );
      try {
        widget.store.tasks.insert(0, await widget.store.api.createTask(task));
      } catch (_) {
        widget.store.tasks.insert(0, task);
      }
      widget.store.refresh();
    }
    title.dispose();
    description.dispose();
  }
}

class _TaskTableRow extends StatelessWidget {
  const _TaskTableRow({required this.task, required this.store});
  final TaskItem task;
  final AppStore store;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
    child: Row(
      children: [
        Checkbox(
          value: task.isCompleted,
          onChanged: (v) => store.toggleTask(task, v ?? false),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              if (task.description.isNotEmpty)
                Text(
                  task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            task.category,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(flex: 2, child: _PriorityBadge(value: task.priority)),
        Expanded(
          flex: 2,
          child: Text(
            task.dueDate == null
                ? 'Р вЂР ВµР В· РЎРѓРЎР‚Р С•Р С”Р В°'
                : dateLabel(task.dueDate!),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        IconButton(
          onPressed: () => store.removeTask(task),
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Р Р€Р Т‘Р В°Р В»Р С‘РЎвЂљРЎРЉ',
        ),
      ],
    ),
  );
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.store});
  final AppStore store;
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String period = '30 Р Т‘Р Р…Р ВµР в„–';
  String metric = 'Р СџРЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљРЎРЉ';
  @override
  Widget build(BuildContext context) {
    final days = widget.store.stats;
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const PageTitle(
              title: 'Р РЋРЎвЂљР В°РЎвЂљР С‘РЎРѓРЎвЂљР С‘Р С”Р В°',
              subtitle: 'Р СџР С•Р в„–Р СР С‘РЎвЂљР Вµ РЎР‚Р С‘РЎвЂљР С Р С‘ Р С—Р С•Р Т‘Р Т‘Р ВµРЎР‚Р В¶Р С‘Р Р†Р В°Р в„–РЎвЂљР Вµ РЎРѓР Р†Р С•Р в„– РЎвЂљР ВµР СР С—.',
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: '7 Р Т‘Р Р…Р ВµР в„–',
                  label: Text('7 Р Т‘Р Р…Р ВµР в„–'),
                ),
                ButtonSegment(
                  value: '30 Р Т‘Р Р…Р ВµР в„–',
                  label: Text('30 Р Т‘Р Р…Р ВµР в„–'),
                ),
                ButtonSegment(
                  value: 'Р вЂњР С•Р Т‘',
                  label: Text('Р вЂњР С•Р Т‘'),
                ),
              ],
              selected: {period},
              onSelectionChanged: (v) => setState(() => period = v.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Р С™Р В°Р В»Р ВµР Р…Р Т‘Р В°РЎР‚РЎРЉ Р В°Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљР С‘',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Р СњР В°Р Р†Р ВµР Т‘Р С‘РЎвЂљР Вµ Р С”РЎС“РЎР‚РЎРѓР С•РЎР‚ Р Р…Р В° Р Т‘Р ВµР Р…РЎРЉ, РЎвЂЎРЎвЂљР С•Р В±РЎвЂ№ РЎС“Р Р†Р С‘Р Т‘Р ВµРЎвЂљРЎРЉ Р Т‘Р ВµРЎвЂљР В°Р В»Р С‘.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: List.generate(140, (i) {
                  final day = days.isEmpty ? null : days[i % days.length];
                  final color = day == null || day.status == 'empty'
                      ? Theme.of(context).dividerColor.withOpacity(.28)
                      : day.status == 'complete'
                      ? _green
                      : _green.withOpacity(.45);
                  return Tooltip(
                    message: day == null
                        ? 'Р СњР ВµРЎвЂљ Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦'
                        : '${dateLabel(day.date)} Р’В· ${day.completed}/${day.planned} Р В·Р В°Р Т‘Р В°РЎвЂЎ',
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Р вЂќР С‘Р Р…Р В°Р СР С‘Р С”Р В°',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  DropdownButton<String>(
                    value: metric,
                    items: const [
                      DropdownMenuItem(
                        value: 'Р СџРЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљРЎРЉ',
                        child: Text(
                          'Р вЂєР С‘РЎвЂЎР Р…Р В°РЎРЏ Р С•РЎвЂ Р ВµР Р…Р С”Р В°',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Р вЂ”Р В°Р С”РЎР‚РЎвЂ№РЎвЂљР С‘Р Вµ',
                        child: Text(
                          'Р СџРЎР‚Р С•РЎвЂ Р ВµР Р…РЎвЂљ Р В·Р В°Р С”РЎР‚РЎвЂ№РЎвЂљРЎвЂ№РЎвЂ¦ Р В·Р В°Р Т‘Р В°РЎвЂЎ',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Р С™Р С•Р В»Р С‘РЎвЂЎР ВµРЎРѓРЎвЂљР Р†Р С•',
                        child: Text(
                          'Р вЂ™РЎвЂ№Р С—Р С•Р В»Р Р…Р ВµР Р…Р Р…РЎвЂ№Р Вµ Р В·Р В°Р Т‘Р В°РЎвЂЎР С‘',
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => metric = v ?? metric),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 230,
                child: _LineChart(points: widget.store.stats, metric: metric),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.points, required this.metric});
  final List<DayStat> points;
  final String metric;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ChartPainter(points, metric, Theme.of(context).colorScheme),
    child: const SizedBox.expand(),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.metric, this.colors);
  final List<DayStat> points;
  final String metric;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.outlineVariant.withOpacity(.4)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = i * size.height / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.isEmpty) return;
    final values = points
        .map(
          (p) =>
              metric ==
                  'Р СџРЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљР С‘Р Р†Р Р…Р С•РЎРѓРЎвЂљРЎРЉ'
              ? p.productivity
              : metric == 'Р вЂ”Р В°Р С”РЎР‚РЎвЂ№РЎвЂљР С‘Р Вµ'
              ? (p.planned == 0 ? 0 : p.completed * 100 / p.planned)
              : p.completed.toDouble(),
        )
        .toList();
    final maxValue = math.max(1.0, values.reduce(math.max).toDouble());
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final double x = values.length == 1
          ? 0.0
          : i * size.width / (values.length - 1);
      final double y =
          size.height - (values[i] / maxValue) * (size.height - 12) - 6;
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = _accent.withOpacity(.12));
    canvas.drawPath(
      path,
      Paint()
        ..color = _accent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.metric != metric;
}

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key, required this.store});
  final AppStore store;
  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  String mealType = 'Р вЂ”Р В°Р Р†РЎвЂљРЎР‚Р В°Р С”';
  FoodProduct? selected;
  final grams = TextEditingController(text: '100');
  final search = TextEditingController();
  @override
  void dispose() {
    grams.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calories = widget.store.meals.fold<double>(
          0,
          (s, m) => s + m.calories,
        ),
        protein = widget.store.meals.fold<double>(0, (s, m) => s + m.protein),
        fat = widget.store.meals.fold<double>(0, (s, m) => s + m.fat),
        carbs = widget.store.meals.fold<double>(0, (s, m) => s + m.carbs);
    return ListView(
      children: [
        const PageTitle(
          title: 'Р СџР С‘РЎвЂљР В°Р Р…Р С‘Р Вµ Р С‘ Р вЂР вЂ“Р Р€',
          subtitle: 'Р РЋР В»Р ВµР Т‘Р С‘РЎвЂљР Вµ Р В·Р В° РЎР‚Р В°РЎвЂ Р С‘Р С•Р Р…Р С•Р С Р В±Р ВµР В· Р В»Р С‘РЎв‚¬Р Р…Р ВµР в„– РЎРѓР В»Р С•Р В¶Р Р…Р С•РЎРѓРЎвЂљР С‘.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (_, c) => GridView.count(
            crossAxisCount: c.maxWidth > 850 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.2,
            children: [
              _NutritionCard(
                'Р С™Р В°Р В»Р С•РЎР‚Р С‘Р С‘',
                calories,
                widget.store.settings.calories,
                'Р С”Р С”Р В°Р В»',
                const Color(0xFFE85D75),
              ),
              _NutritionCard(
                'Р вЂР ВµР В»Р С”Р С‘',
                protein,
                widget.store.settings.protein,
                'Р С–',
                _accent,
              ),
              _NutritionCard(
                'Р вЂ“Р С‘РЎР‚РЎвЂ№',
                fat,
                widget.store.settings.fat,
                'Р С–',
                _orange,
              ),
              _NutritionCard(
                'Р Р€Р С–Р В»Р ВµР Р†Р С•Р Т‘РЎвЂ№',
                carbs,
                widget.store.settings.carbs,
                'Р С–',
                _green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Р вЂќР С•Р В±Р В°Р Р†Р С‘РЎвЂљРЎРЉ Р С—РЎР‚Р С‘РЎвЂР С Р С—Р С‘РЎвЂ°Р С‘',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: mealType,
                      decoration: const InputDecoration(
                        labelText: 'Р СџРЎР‚Р С‘РЎвЂР С Р С—Р С‘РЎвЂ°Р С‘',
                      ),
                      items:
                          [
                                'Р вЂ”Р В°Р Р†РЎвЂљРЎР‚Р В°Р С”',
                                'Р С›Р В±Р ВµР Т‘',
                                'Р Р€Р В¶Р С‘Р Р…',
                                'Р СџР ВµРЎР‚Р ВµР С”РЎС“РЎРѓ',
                              ]
                              .map(
                                (x) =>
                                    DropdownMenuItem(value: x, child: Text(x)),
                              )
                              .toList(),
                      onChanged: (v) =>
                          setState(() => mealType = v ?? mealType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Autocomplete<FoodProduct>(
                      displayStringForOption: (x) => x.name,
                      optionsBuilder: (value) {
                        final q = value.text.toLowerCase();
                        return widget.store.products.where(
                          (p) => p.name.toLowerCase().contains(q),
                        );
                      },
                      onSelected: (p) => setState(() => selected = p),
                      fieldViewBuilder: (_, controller, focus, __) => TextField(
                        controller: controller,
                        focusNode: focus,
                        decoration: const InputDecoration(
                          labelText: 'Р СџРЎР‚Р С•Р Т‘РЎС“Р С”РЎвЂљ',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: grams,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Р вЂњРЎР‚Р В°Р СР СРЎвЂ№',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton(
                      onPressed: selected == null ? null : _addMeal,
                      child: const Text('Р вЂќР С•Р В±Р В°Р Р†Р С‘РЎвЂљРЎРЉ'),
                    ),
                  ),
                ],
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${selected!.name}: ${selected!.calories} Р С”Р С”Р В°Р В» Р’В· Р вЂ ${selected!.protein} Р’В· Р вЂ“ ${selected!.fat} Р’В· Р Р€ ${selected!.carbs} Р Р…Р В° 100 Р С–',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Р вЂќР Р…Р ВµР Р†Р Р…Р С‘Р С” Р С—Р С‘РЎвЂљР В°Р Р…Р С‘РЎРЏ',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (widget.store.meals.isEmpty)
                const Text(
                  'Р СџРЎР‚Р С‘РЎвЂР СР С•Р Р† Р С—Р С‘РЎвЂ°Р С‘ Р ВµРЎвЂ°РЎвЂ Р Р…Р ВµРЎвЂљ.',
                ),
              for (final group in [
                'Р вЂ”Р В°Р Р†РЎвЂљРЎР‚Р В°Р С”',
                'Р С›Р В±Р ВµР Т‘',
                'Р Р€Р В¶Р С‘Р Р…',
                'Р СџР ВµРЎР‚Р ВµР С”РЎС“РЎРѓ',
              ]) ...[
                if (widget.store.meals.any((m) => m.mealType == group))
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      group,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                for (final meal in widget.store.meals.where(
                  (m) => m.mealType == group,
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(meal.product.name),
                    subtitle: Text(
                      '${meal.weight.round()} Р С– Р’В· ${meal.calories.round()} Р С”Р С”Р В°Р В»',
                    ),
                    trailing: IconButton(
                      onPressed: () => widget.store.removeMeal(meal),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _addMeal() {
    final weight = double.tryParse(grams.text.replaceAll(',', '.')) ?? 100;
    final p = selected!;
    final factor = weight / 100;
    widget.store.addMeal(
      MealEntry(
        date: DateTime.now(),
        mealType: mealType,
        product: p,
        weight: weight,
        calories: p.calories * factor,
        protein: p.protein * factor,
        fat: p.fat * factor,
        carbs: p.carbs * factor,
      ),
    );
    setState(() {
      selected = null;
      grams.text = '100';
    });
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard(
    this.title,
    this.value,
    this.target,
    this.unit,
    this.color,
  );
  final String title, unit;
  final double value, target;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Icon(Icons.circle, size: 10, color: color),
            ],
          ),
          const Spacer(),
          Text(
            '${value.round()} $unit',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: target == 0 ? 0 : (value / target).clamp(0, 1),
            color: color,
            backgroundColor: color.withOpacity(.13),
            minHeight: 6,
          ),
          const SizedBox(height: 5),
          Text(
            'Р С‘Р В· ${target.round()} $unit',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController calories, protein, fat, carbs, minTasks;
  @override
  void initState() {
    super.initState();
    final s = widget.store.settings;
    calories = TextEditingController(text: s.calories.round().toString());
    protein = TextEditingController(text: s.protein.round().toString());
    fat = TextEditingController(text: s.fat.round().toString());
    carbs = TextEditingController(text: s.carbs.round().toString());
    minTasks = TextEditingController(text: s.minimumTasks.toString());
  }

  @override
  void dispose() {
    calories.dispose();
    protein.dispose();
    fat.dispose();
    carbs.dispose();
    minTasks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const PageTitle(
        title: 'Р СњР В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–Р С”Р С‘',
        subtitle: 'Р СњР В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–РЎвЂљР Вµ Р С—РЎР‚Р С‘Р В»Р С•Р В¶Р ВµР Р…Р С‘Р Вµ Р С—Р С•Р Т‘ РЎРѓР Р†Р С•Р в„– РЎР‚Р С‘РЎвЂљР С.',
      ),
      const SizedBox(height: 20),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Р С›РЎвЂћР С•РЎР‚Р СР В»Р ВµР Р…Р С‘Р Вµ',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: widget.store.settings.themeMode,
              decoration: const InputDecoration(labelText: 'Р СћР ВµР СР В°'),
              items: const [
                DropdownMenuItem(
                  value: 'system',
                  child: Text('Р РЋР С‘РЎРѓРЎвЂљР ВµР СР Р…Р В°РЎРЏ'),
                ),
                DropdownMenuItem(
                  value: 'light',
                  child: Text('Р РЋР Р†Р ВµРЎвЂљР В»Р В°РЎРЏ'),
                ),
                DropdownMenuItem(
                  value: 'dark',
                  child: Text('Р СћРЎвЂР СР Р…Р В°РЎРЏ'),
                ),
              ],
              onChanged: (v) {
                if (v != null) widget.store.saveTheme(v);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Р В¦Р ВµР В»Р ВµР Р†РЎвЂ№Р Вµ Р Р…Р С•РЎР‚Р СРЎвЂ№',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _numberField(
                  'Р С™Р В°Р В»Р С•РЎР‚Р С‘Р С‘, Р С”Р С”Р В°Р В»',
                  calories,
                ),
                _numberField('Р вЂР ВµР В»Р С”Р С‘, Р С–', protein),
                _numberField('Р вЂ“Р С‘РЎР‚РЎвЂ№, Р С–', fat),
                _numberField('Р Р€Р С–Р В»Р ВµР Р†Р С•Р Т‘РЎвЂ№, Р С–', carbs),
                _numberField(
                  'Р СљР С‘Р Р…Р С‘Р СРЎС“Р С Р В·Р В°Р Т‘Р В°РЎвЂЎ',
                  minTasks,
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'Р РЋР С•РЎвЂ¦РЎР‚Р В°Р Р…Р С‘РЎвЂљРЎРЉ Р Р…Р С•РЎР‚Р СРЎвЂ№',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Р В­Р С”РЎРѓР С—Р С•РЎР‚РЎвЂљ Р Т‘Р В°Р Р…Р Р…РЎвЂ№РЎвЂ¦',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Р РЋР С•РЎвЂ¦РЎР‚Р В°Р Р…Р С‘РЎвЂљРЎРЉ Р Р†РЎРѓР Вµ Р В·Р В°Р Т‘Р В°РЎвЂЎР С‘, Р С—Р С‘РЎвЂљР В°Р Р…Р С‘Р Вµ Р С‘ РЎРѓРЎвЂљР В°РЎвЂљР С‘РЎРѓРЎвЂљР С‘Р С”РЎС“ Р Р† JSON.',
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Р В­Р С”РЎРѓР С—Р С•РЎР‚РЎвЂљ JSON'),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _numberField(String label, TextEditingController controller) =>
      SizedBox(
        width: 180,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );
  void _save() {
    widget.store.settings.calories =
        double.tryParse(calories.text) ?? widget.store.settings.calories;
    widget.store.settings.protein =
        double.tryParse(protein.text) ?? widget.store.settings.protein;
    widget.store.settings.fat =
        double.tryParse(fat.text) ?? widget.store.settings.fat;
    widget.store.settings.carbs =
        double.tryParse(carbs.text) ?? widget.store.settings.carbs;
    widget.store.settings.minimumTasks =
        int.tryParse(minTasks.text) ?? widget.store.settings.minimumTasks;
    widget.store.saveSettings();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Р СњР В°РЎРѓРЎвЂљРЎР‚Р С•Р в„–Р С”Р С‘ РЎРѓР С•РЎвЂ¦РЎР‚Р В°Р Р…Р ВµР Р…РЎвЂ№',
        ),
      ),
    );
  }

  Future<void> _export() async {
    final data = await widget.store.exportJson();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Р В­Р С”РЎРѓР С—Р С•РЎР‚РЎвЂљ Р С—Р С•Р Т‘Р С–Р С•РЎвЂљР С•Р Р†Р В»Р ВµР Р… (${data.length} РЎРѓР С‘Р СР Р†Р С•Р В»Р С•Р Р†)',
        ),
      ),
    );
  }
}
