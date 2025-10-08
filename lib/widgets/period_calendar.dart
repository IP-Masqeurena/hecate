import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/period_entry.dart';

class PeriodCalendar extends StatefulWidget {
  final List<PeriodEntry> entries;
  const PeriodCalendar({super.key, required this.entries});

  @override
  State<PeriodCalendar> createState() => _PeriodCalendarState();
}

class _PeriodCalendarState extends State<PeriodCalendar> 
    with TickerProviderStateMixin {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  Map<DateTime, List<String>> events = {};
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Start from a base date (e.g., 2 years ago) to current + 1 year
  final DateTime _minDate = DateTime.now().subtract(const Duration(days: 730));
  final DateTime _maxDate = DateTime.now().add(const Duration(days: 365));
  late int _totalMonths;
  late int _initialPage;
  double _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _buildEvents();
    
    // Calculate total months and initial page
    _totalMonths = ((_maxDate.year - _minDate.year) * 12) + 
                   (_maxDate.month - _minDate.month) + 1;
    _initialPage = ((_focused.year - _minDate.year) * 12) + 
                   (_focused.month - _minDate.month);
    
    _currentPage = _initialPage.toDouble();
    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.85, // Show partial months on sides
    );
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    
    // Listen to page changes for smooth animation
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page ?? _currentPage;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
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

    // Mark recorded days
    for (final e in entries) {
      DateTime d = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
      final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
      for (; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        _addEvent(d, 'recorded');
      }
    }

    if (entries.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    // Build chronological list of starts
    final starts = entries
        .map((e) => DateTime(e.startDate.year, e.startDate.month, e.startDate.day))
        .toList();
    starts.sort((a, b) => a.compareTo(b));

    if (starts.length >= 2) {
      final diffs = <int>[];
      for (int i = 1; i < starts.length; i++) {
        diffs.add(starts[i].difference(starts[i - 1]).inDays);
      }

      final filtered = diffs.where((d) => d >= 21 && d <= 45).toList();
      final useDiffs = filtered.isNotEmpty ? filtered : diffs;

      int median(List<int> arr) {
        if (arr.isEmpty) return 28;
        final s = List<int>.from(arr)..sort();
        final m = s.length ~/ 2;
        return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
      }

      final avgCycle = useDiffs.isEmpty ? 28 : median(useDiffs);
      final periodLens = entries.map((e) => 
        e.endDate.difference(e.startDate).inDays + 1).toList();
      final avgPeriod = periodLens.isEmpty ? 5 : median(periodLens);

      DateTime base = starts.last;
      for (int i = 1; i <= 3; i++) {
        base = base.add(Duration(days: avgCycle));
        for (int d = 0; d < avgPeriod; d++) {
          final dt = DateTime(base.year, base.month, base.day)
              .add(Duration(days: d));
          if (!_hasRecorded(dt)) _addEvent(dt, 'predicted');
        }
      }
    } else {
      final lastStart = starts.last;
      final avgCycle = 28;
      final avgPeriod = 5;
      DateTime base = lastStart;
      for (int i = 1; i <= 3; i++) {
        base = base.add(Duration(days: avgCycle));
        for (int d = 0; d < avgPeriod; d++) {
          final dt = DateTime(base.year, base.month, base.day)
              .add(Duration(days: d));
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

  bool _isToday(DateTime d) {
    final t = DateTime.now();
    return d.year == t.year && d.month == t.month && d.day == t.day;
  }

  DateTime _getMonthFromIndex(int index) {
    return DateTime(_minDate.year, _minDate.month + index);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    // Dynamic sizing based on screen
    final calendarHeight = screenHeight * 0.55; // 55% of screen height
    final detailsHeight = screenHeight * 0.25; // 25% of screen height
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Calendar PageView
            SizedBox(
              height: calendarHeight.clamp(350.0, 600.0), // Min 350, Max 600
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: _totalMonths,
                onPageChanged: (index) {
                  setState(() {
                    _focused = _getMonthFromIndex(index);
                  });
                },
                itemBuilder: (context, index) {
                  final monthDate = _getMonthFromIndex(index);
                  
                  // Calculate scale based on distance from current page
                  double scale = 1.0;
                  double opacity = 1.0;
                  if (_pageController.hasClients) {
                    double difference = (index - _currentPage).abs();
                    scale = (1.0 - (difference * 0.15)).clamp(0.85, 1.0);
                    opacity = (1.0 - (difference * 0.3)).clamp(0.7, 1.0);
                  }
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()..scale(scale, scale),
                    child: Opacity(
                      opacity: opacity,
                      child: _buildMonth(monthDate, constraints),
                    ),
                  );
                },
              ),
            ),
            // Legend
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32.0 : 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(Colors.red, 'Recorded'),
                  SizedBox(width: isTablet ? 24 : 20),
                  _legendDot(Colors.red.withOpacity(0.5), 'Predicted'),
                ],
              ),
            ),
            // Details section
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: detailsHeight.clamp(100.0, 300.0),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selected == null
                      ? const Center(
                          child: Text('Tap a date to see details',
                              style: TextStyle(color: Colors.grey)))
                      : _detailsForDate(_selected!),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonth(DateTime month, BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    // Dynamic padding and margins
    final horizontalMargin = screenWidth * 0.04; // 4% of screen width
    final cardPadding = screenWidth * 0.03; // 3% of screen width
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin.clamp(12.0, 24.0),
        vertical: 8,
      ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(cardPadding.clamp(8.0, 16.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Month header
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat.yMMMM().format(month),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 24 : 20,
                  ),
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),
              // Calendar content
              Flexible(
                child: AspectRatio(
                  aspectRatio: 7/6, // Width to height ratio for calendar grid
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Weekday headers
                      _buildWeekdayHeaders(constraints),
                      SizedBox(height: isTablet ? 8 : 4),
                      // Calendar grid
                      Expanded(
                        child: _buildCalendarGrid(month, constraints),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders(BoxConstraints constraints) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cellSize = (screenWidth - 80) / 7; // Account for padding
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
          .map((day) => Container(
                width: cellSize.clamp(30.0, 50.0),
                alignment: Alignment.center,
                child: Text(
                  day,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(DateTime month, BoxConstraints constraints) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeekday = firstDay.weekday;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cellSize = (screenWidth - 80) / 7; // Dynamic cell size
    
    List<Widget> dayWidgets = [];
    
    // Add empty cells for days before month starts
    for (int i = 1; i < startWeekday; i++) {
      dayWidgets.add(SizedBox(
        width: cellSize.clamp(30.0, 50.0),
        height: cellSize.clamp(30.0, 50.0),
      ));
    }
    
    // Add days of month
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(month.year, month.month, day);
      final events = _getEventsForDay(date);
      final isSelected = _selected != null &&
          _selected!.year == date.year &&
          _selected!.month == date.month &&
          _selected!.day == date.day;
      
      dayWidgets.add(_buildDayCell(
        date, 
        events, 
        isSelected, 
        cellSize.clamp(30.0, 50.0),
        isTablet,
      ));
    }
    
    // Calculate number of rows needed
    final totalCells = dayWidgets.length;
    final numRows = (totalCells / 7).ceil();
    
    // Create grid
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: isTablet ? 4 : 2,
      crossAxisSpacing: 0,
      childAspectRatio: 1.0,
      children: [
        ...dayWidgets,
        // Add empty cells to complete last row
        ...List.generate(
          (numRows * 7) - totalCells,
          (_) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildDayCell(
    DateTime date, 
    List<String> events, 
    bool isSelected,
    double size,
    bool isTablet,
  ) {
    Color? backgroundColor;
    Color textColor = Colors.white70;
    
    if (events.contains('recorded')) {
      backgroundColor = Colors.red;
      textColor = Colors.white;
    } else if (events.contains('predicted')) {
      backgroundColor = Colors.red.withOpacity(0.4);
      textColor = Colors.white;
    }
    
    if (_isToday(date)) {
      backgroundColor = backgroundColor ?? Colors.blue.withOpacity(0.2);
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selected = date;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.all(size * 0.05), // 5% of cell size
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size * 0.2), // 20% of cell size
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : null,
          boxShadow: isSelected
              ? [BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                )]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected || _isToday(date) 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final dotSize = isTablet ? 18.0 : 14.0;
    
    return Row(
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label, 
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _detailsForDate(DateTime day) {
    final ev = _getEventsForDay(day);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMd().format(day),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: isTablet ? 24 : 20,
            ),
          ),
          const SizedBox(height: 8),
          if (ev.isEmpty)
            Text(
              'No recorded or predicted event on this date.',
              style: TextStyle(fontSize: isTablet ? 16 : 14),
            ),
          if (ev.contains('recorded'))
            Row(
              children: [
                Container(
                  width: isTablet ? 14 : 12,
                  height: isTablet ? 14 : 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recorded period day',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ],
            ),
          if (ev.contains('predicted'))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: isTablet ? 14 : 12,
                    height: isTablet ? 14 : 12,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Predicted period day',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}