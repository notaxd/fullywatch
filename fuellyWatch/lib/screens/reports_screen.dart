import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  final List<dynamic> stations;
  const ReportsScreen({super.key, required this.stations});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int? _selectedStationId;
  String _period = 'daily';
  Map<String, dynamic>? _summary;
  bool _loading = false;

  static const Map<String, Color> fuelColors = {
    'petrol': Color(0xFFa855f7),
    'diesel': Color(0xFF3b82f6),
    'high-octane': Color(0xFF22c55e),
  };

  @override
  void initState() {
    super.initState();
    if (widget.stations.isNotEmpty) {
      _selectedStationId = widget.stations.first['id'];
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    if (_selectedStationId == null) return;
    setState(() => _loading = true);
    try {
      final data = await ApiService.get(
          '/transactions/summary?period=$_period&station_id=$_selectedStationId');
      setState(() {
        _summary = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _summary = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _summary?['totals'] as Map<String, dynamic>?;
    final byFuel = (_summary?['by_fuel'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Reports')),
      body: widget.stations.isEmpty
          ? const Center(child: Text('No stations available'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Station selector
                _label('Station'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1b1e26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedStationId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1b1e26),
                      style: const TextStyle(color: Colors.white),
                      items: widget.stations.map<DropdownMenuItem<int>>((s) {
                        return DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text(s['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedStationId = value);
                        _loadSummary();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Period toggle
                _label('Period'),
                const SizedBox(height: 8),
                Row(
                  children: ['daily', 'weekly', 'monthly'].map((p) {
                    final selected = _period == p;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _period = p);
                            _loadSummary();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF7c3aed) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected ? const Color(0xFF7c3aed) : Colors.grey.shade700,
                              ),
                            ),
                            child: Text(
                              p[0].toUpperCase() + p.substring(1),
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_summary == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No data for this period',
                        style: TextStyle(color: Colors.grey))),
                  )
                else ...[
                  // Stat cards
                  Row(
                    children: [
                      _statCard('Total Sales',
                          'Rs ${_fmt(totals?['total_sales'])}', const Color(0xFFa855f7)),
                      const SizedBox(width: 12),
                      _statCard('Volume',
                          '${_fmt(totals?['total_volume'])} L', const Color(0xFF3b82f6)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _statCard('Transactions',
                      '${totals?['transaction_count'] ?? 0}', const Color(0xFF22c55e),
                      fullWidth: true),
                  const SizedBox(height: 24),

                  // Chart
                  if (byFuel.isNotEmpty) ...[
                    _label('Sales by Fuel Type'),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 240,
                      child: _buildChart(byFuel),
                    ),
                    const SizedBox(height: 24),
                    // Breakdown
                    _label('Breakdown'),
                    const SizedBox(height: 8),
                    ...byFuel.map((f) => _breakdownRow(f)),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _buildChart(List<dynamic> byFuel) {
    double maxSales = 0;
    for (var f in byFuel) {
      final s = (f['total_sales'] ?? 0).toDouble();
      if (s > maxSales) maxSales = s;
    }
    if (maxSales == 0) maxSales = 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxSales * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF2a2d36),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final fuel = byFuel[group.x.toInt()];
              return BarTooltipItem(
                '${fuel['fuel_type']}\nRs ${_fmt(fuel['total_sales'])}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= byFuel.length) return const SizedBox();
                final name = byFuel[i]['fuel_type'].toString();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    name.length > 6 ? name.substring(0, 6) : name,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(byFuel.length, (i) {
          final fuel = byFuel[i];
          final sales = (fuel['total_sales'] ?? 0).toDouble();
          final color = fuelColors[fuel['fuel_type']] ?? Colors.grey;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: sales,
                color: color,
                width: 36,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _breakdownRow(Map<String, dynamic> f) {
    final color = fuelColors[f['fuel_type']] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1b1e26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            f['fuel_type'],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs ${_fmt(f['total_sales'])}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('${_fmt(f['total_volume'])} L  ·  ${f['transaction_count']} txns',
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, {bool fullWidth = false}) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1b1e26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: card) : Expanded(child: card);
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600));
  }

  String _fmt(dynamic n) {
    if (n == null) return '0';
    final num value = n is num ? n : num.tryParse(n.toString()) ?? 0;
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }
}