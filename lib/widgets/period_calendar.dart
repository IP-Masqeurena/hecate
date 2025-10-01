import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/period_entry.dart';
import 'dart:collection';

class PeriodCalendar extends StatefulWidget {
  final List<PeriodEntry> entries;
  const PeriodCalendar({super.key, required this.entries});

  @override
  State<PeriodCalendar> createState() => _PeriodCalendarState();
}

class _PeriodCalendarState extends State<PeriodCalendar> {
  late final PageController _pageController;
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  Map<DateTime, List<String>> events = {};

  @override
  void initState() {
    super.initState();
    _buildEvents();
  }

  @override
  void didUpdateWidget(covariant PeriodCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) {
      _buildEvents();
    }
  }

  void _buildEvents() {
  events = {};
  final entries = widget.entries;

  // 1) Mark recorded days
  for (final e in entries) {
    DateTime d = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
    final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
    for (; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      _addEvent(d, 'recorded');
    }
  }

  if (entries.isEmpty) {
    // nothing to predict
    if (mounted) setState(() {});
    return;
  }

  // Build chronological list of starts (oldest -> newest)
  final starts = entries
      .map((e) => DateTime(e.startDate.year, e.startDate.month, e.startDate.day))
      .toList()
      .reversed
      .toList();

  debugPrint('PeriodCalendar DEBUG: starts (oldest->newest): $starts');

  if (starts.length >= 2) {
    // Use up to the last N starts to compute cycle diffs
    const int N = 6;
    final recent = starts.length > N ? starts.sublist(starts.length - N) : starts;

    final diffs = <int>[];
    for (int i = 1; i < recent.length; i++) {
      diffs.add(recent[i].difference(recent[i - 1]).inDays);
    }

    debugPrint('PeriodCalendar DEBUG: raw diffs (last $N cycles): $diffs');

    // Filter out obvious outliers (cycles outside plausible range)
    final filtered = diffs.where((d) => d >= 21 && d <= 45).toList();
    final useDiffs = filtered.isNotEmpty ? filtered : diffs;

    debugPrint('PeriodCalendar DEBUG: useDiffs after filtering: $useDiffs');

    int median(List<int> arr) {
      final s = List<int>.from(arr)..sort();
      final m = s.length ~/ 2;
      if (s.isEmpty) return 28;
      return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
    }

    final avgCycle = useDiffs.isEmpty ? 28 : median(useDiffs);

    // period length (days) median
    final periodLens = entries.map((e) => e.endDate.difference(e.startDate).inDays + 1).toList();
    final avgPeriod = periodLens.isEmpty ? 5 : median(periodLens);

    debugPrint('PeriodCalendar DEBUG: avgCycle=$avgCycle, avgPeriod=$avgPeriod');

    // Iteratively compute predictions starting from last actual start
    DateTime base = starts.last; // most recent actual start
    final predictedStarts = <DateTime>[];
    for (int i = 1; i <= 3; i++) {
      base = base.add(Duration(days: avgCycle)); // chain from previous predicted (iterative)
      predictedStarts.add(base);
      // mark avgPeriod days from this predicted start
      for (int d = 0; d < avgPeriod; d++) {
        final dt = DateTime(base.year, base.month, base.day).add(Duration(days: d));
        if (!_hasRecorded(dt)) _addEvent(dt, 'predicted');
      }
    }

    debugPrint('PeriodCalendar DEBUG: predictedStarts = $predictedStarts');
  } else {
    // Only one start available — fallback defaults
    final lastStart = starts.last;
    final avgCycle = 28;
    final avgPeriod = 5;
    debugPrint('PeriodCalendar DEBUG: only 1 start -> using defaults cycle=$avgCycle, period=$avgPeriod');
    DateTime base = lastStart;
    for (int i = 1; i <= 3; i++) {
      base = base.add(Duration(days: avgCycle));
      for (int d = 0; d < avgPeriod; d++) {
        final dt = DateTime(base.year, base.month, base.day).add(Duration(days: d));
        if (!_hasRecorded(dt)) _addEvent(dt, 'predicted');
      }
    }
  }

  if (mounted) setState(() {});
}

  bool _hasRecorded(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    final list = events[key];
    if (list == null) return false;
    return list.contains('recorded');
  }

  void _addEvent(DateTime day, String tag) {
    final key = DateTime(day.year, day.month, day.day);
    events.putIfAbsent(key, () => []);
    if (!events[key]!.contains(tag)) events[key]!.add(tag);
  }

  List<String> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar<String>(
          firstDay: DateTime.utc(2000, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focused,
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          calendarFormat: CalendarFormat.month,
          selectedDayPredicate: (d) => isSameDay(_selected, d),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selected = selectedDay;
              _focused = focusedDay;
            });
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final ev = _getEventsForDay(day);
              if (ev.contains('recorded')) {
                return _buildDayContainer(day.day.toString(), true, false);
              } else if (ev.contains('predicted')) {
                return _buildDayContainer(day.day.toString(), true, true);
              } else {
                return Center(child: Text(day.day.toString()));
              }
            },
            todayBuilder: (context, day, focusedDay) {
              final ev = _getEventsForDay(day);
              if (ev.contains('recorded')) {
                return _buildDayContainer(day.day.toString(), true, false, isToday: true);
              } else if (ev.contains('predicted')) {
                return _buildDayContainer(day.day.toString(), true, true, isToday: true);
              } else {
                return Container(
                  margin: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary), borderRadius: BorderRadius.circular(8.0)),
                  alignment: Alignment.center,
                  child: Text(day.day.toString()),
                );
              }
            },
          ),
          onPageChanged: (focusedDay) {
            _focused = focusedDay;
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [
            _legendDot(Colors.red, 'Recorded period'),
            const SizedBox(width: 12),
            _legendDot(Colors.red.withOpacity(0.5), 'Predicted period'),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selected == null
              ? const Center(child: Text('Select a date to see details'))
              : _detailsForDate(_selected!),
        )
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  Widget _detailsForDate(DateTime day) {
    final ev = _getEventsForDay(day);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat.yMMMMd().format(day), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (ev.isEmpty) const Text('No recorded or predicted event on this date.'),
        if (ev.contains('recorded')) const Text('This day is recorded as part of a period (actual).', style: TextStyle(color: Colors.red)),
        if (ev.contains('predicted')) const Text('This day is predicted to be part of your period (prediction).', style: TextStyle(color: Colors.redAccent)),
      ]),
    );
  }

  Widget _buildDayContainer(String label, bool marked, bool predicted, {bool isToday = false}) {
    final color = predicted ? Colors.red.withOpacity(0.5) : Colors.red;
    return Container(
      margin: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.0),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
