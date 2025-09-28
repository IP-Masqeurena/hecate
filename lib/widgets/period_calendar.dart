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
    // Clear
    events = {};
    final entries = widget.entries;
    // Add actual recorded days
    for (final e in entries) {
      DateTime d = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      for (; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        _addEvent(d, 'recorded');
      }
    }

    // Prediction algorithm: compute avg cycle length (days between starts),
    // and avg period length. Use last N entries (6) if available.
    if (entries.length >= 1) {
      final starts = entries.map((e) => e.startDate).toList().reversed.toList(); // chronological oldest->newest
      if (starts.length >= 2) {
        final diffs = <int>[];
        for (int i = 1; i < starts.length; i++) {
          diffs.add(starts[i].difference(starts[i - 1]).inDays);
        }
        final avgCycle = (diffs.reduce((a, b) => a + b) / diffs.length).round();
        final periodLens = entries.map((e) => e.endDate.difference(e.startDate).inDays + 1).toList();
        final avgPeriod = (periodLens.reduce((a, b) => a + b) / periodLens.length).round();

        final lastStart = starts.last;
        // predict next 3 starts
        for (int i = 1; i <= 3; i++) {
          final predictedStart = lastStart.add(Duration(days: avgCycle * i));
          for (int d = 0; d < avgPeriod; d++) {
            final dt = DateTime(predictedStart.year, predictedStart.month, predictedStart.day).add(Duration(days: d));
            // don't override actual recorded days; but keep predicted tag
            if (!_hasRecorded(dt)) _addEvent(dt, 'predicted');
          }
        }
      } else {
        // only 1 start recorded, predict using a conservative default cycle (28) and period length 5
        final lastStart = starts.last;
        final avgCycle = 28;
        final avgPeriod = 5;
        for (int i = 1; i <= 3; i++) {
          final predictedStart = lastStart.add(Duration(days: avgCycle * i));
          for (int d = 0; d < avgPeriod; d++) {
            final dt = DateTime(predictedStart.year, predictedStart.month, predictedStart.day).add(Duration(days: d));
            if (!_hasRecorded(dt)) _addEvent(dt, 'predicted');
          }
        }
      }
    }

    setState(() {});
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
