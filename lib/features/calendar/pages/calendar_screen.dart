import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/calendar_event_provider.dart';
import '../../../widgets/klasivo_card.dart';
import 'calendar_event_form_screen.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final eventsByDay = ref.watch(eventsByDayProvider);
    final theme = Theme.of(context);

    final firstDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = lastDayOfMonth.day;

    final selectedDay = ref.watch(selectedDayProvider);
    final dayEvents = selectedDay != null ? (eventsByDay[selectedDay] ?? []) : <CalendarEventData>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_monthName(selectedMonth.month)} ${selectedMonth.year}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              ref.read(selectedMonthProvider.notifier).state = DateTime.now();
              ref.read(selectedDayProvider.notifier).state = DateTime.now().day;
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CalendarEventFormScreen(isEditing: false)),
          );
        },
        backgroundColor: const Color(0xFF3B5BDB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Month Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final prev = DateTime(selectedMonth.year, selectedMonth.month - 1);
                    ref.read(selectedMonthProvider.notifier).state = prev;
                    ref.read(selectedDayProvider.notifier).state = null;
                  },
                ),
                Text(
                  '${_monthName(selectedMonth.month)} ${selectedMonth.year}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
                    ref.read(selectedMonthProvider.notifier).state = next;
                    ref.read(selectedDayProvider.notifier).state = null;
                  },
                ),
              ],
            ),
          ),

          // Weekday Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d, style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),

          // Calendar Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startWeekday) return const SizedBox();
                final day = index - startWeekday + 1;
                final dayEvents = eventsByDay[day] ?? [];
                final isSelected = selectedDay == day;
                final isToday = DateTime.now().day == day &&
                    DateTime.now().month == selectedMonth.month &&
                    DateTime.now().year == selectedMonth.year;

                return GestureDetector(
                  onTap: () => ref.read(selectedDayProvider.notifier).state = day,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B5BDB)
                          : isToday
                              ? const Color(0xFF3B5BDB).withOpacity(0.1)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? const Color(0xFF3B5BDB)
                                    : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        if (dayEvents.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: dayEvents.take(3).map((e) => Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Color(e.colorValue),
                                shape: BoxShape.circle,
                              ),
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),

          // Selected Day Events
          if (selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '$selectedDay ${_monthName(selectedMonth.month)}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dayEvents.length} event${dayEvents.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),

          Expanded(
            child: selectedDay == null
                ? Center(
                    child: Text('Select a day to view events',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  )
                : dayEvents.isEmpty
                    ? Center(
                        child: Text('No events on this day',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: dayEvents.length,
                        itemBuilder: (context, index) {
                          final event = dayEvents[index];
                          return _EventCard(event: event);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}

// Selected day state
final selectedDayProvider = StateProvider<int?>((ref) => DateTime.now().day);

class _EventCard extends StatelessWidget {
  final CalendarEventData event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Color(event.colorValue),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(event.typeIcon, size: 20, color: Color(event.colorValue)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  if (event.description != null)
                    Text(event.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(event.colorValue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(event.typeLabel,
                  style: TextStyle(fontSize: 11, color: Color(event.colorValue), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
