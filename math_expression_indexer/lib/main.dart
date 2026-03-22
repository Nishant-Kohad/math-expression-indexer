// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import 'services/pdf_api_service.dart';

void main() {
  runApp(const MathExpressionIndexerApp());
}

// ─────────────────────────────────────────────
// App root
// ─────────────────────────────────────────────
class MathExpressionIndexerApp extends StatelessWidget {
  const MathExpressionIndexerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Math Expression Indexer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Home screen — two tabs: Index PDF | History
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Upload / Index state ──────────────────────────────────────────
  String _selectedFileName = 'No PDF selected';
  List<int>? _selectedFileBytes;
  bool _isLoading = false;

  List<Map<String, dynamic>> _expressions = [];
  List<Map<String, dynamic>> _filteredExpressions = [];
  final TextEditingController _searchController = TextEditingController();

  // ── Pagination ───────────────────────────────────────────────────
  int _currentPage = 0;
  static const int _pageSize = 15;

  // ── History tab ──────────────────────────────────────────────────
  List<dynamic> _history = [];
  bool _historyLoading = false;
  bool _historyLoaded = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true, // required on web to get bytes
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes =
            file.bytes != null ? List<int>.from(file.bytes!) : null;
      });
    }
  }

  Future<void> _uploadPdf() async {
    if (_selectedFileBytes == null) {
      _snack('Please choose a PDF first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await PdfApiService.uploadPdf(
        fileName: _selectedFileName,
        bytes: _selectedFileBytes!,
      );
      final results =
          List<Map<String, dynamic>>.from(data['results'] ?? []);
      setState(() {
        _expressions = results;
        _filteredExpressions = List.from(results);
        _currentPage = 0;
        _searchController.clear();
      });
      _snack(
          'Extracted ${results.length} expression${results.length == 1 ? '' : 's'}.');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) {
    setState(() {
      _currentPage = 0;
      if (query.trim().isEmpty) {
        _filteredExpressions = List.from(_expressions);
      } else {
        final q = query.toLowerCase();
        _filteredExpressions = _expressions.where((e) {
          return (e['expression'] ?? '').toString().toLowerCase().contains(q) ||
              (e['context'] ?? '').toString().toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadHistory() async {
    if (_historyLoading) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final history = await PdfApiService.getHistory();
      setState(() {
        _history = history;
        _historyLoaded = true;
      });
    } catch (e) {
      setState(() {
        _historyError = e.toString();
        _historyLoaded = true;
      });
    } finally {
      setState(() => _historyLoading = false);
    }
  }

  void _exportCsv() {
    html.window.open(PdfApiService.exportCsvUrl, '_blank');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Pagination helpers ────────────────────────────────────────────

  int get _totalPages =>
      (_filteredExpressions.length / _pageSize).ceil().clamp(1, 9999);

  List<Map<String, dynamic>> get _pageItems {
    final start = _currentPage * _pageSize;
    final end =
        (start + _pageSize).clamp(0, _filteredExpressions.length);
    if (start >= _filteredExpressions.length) return [];
    return _filteredExpressions.sublist(start, end);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                _buildBanner(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIndexTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Math Expression Indexer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload PDFs and extract mathematical expressions with LaTeX rendering.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_expressions.isNotEmpty)
            TextButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download, color: Colors.white, size: 18),
              label: const Text('Export CSV',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF1D4ED8),
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black54,
        dividerColor: Colors.transparent,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Index PDF'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  // ── Index tab ─────────────────────────────────────────────────────

  Widget _buildIndexTab() {
    final width = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: width > 850
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(children: [
                    const SizedBox(height: 8),
                    _buildUploadCard(),
                    const SizedBox(height: 12),
                    _buildSearchCard(),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(children: [
                    const SizedBox(height: 8),
                    _buildResultsCard(),
                  ]),
                ),
              ],
            )
          : Column(children: [
              const SizedBox(height: 8),
              _buildUploadCard(),
              const SizedBox(height: 12),
              _buildSearchCard(),
              const SizedBox(height: 12),
              _buildResultsCard(),
            ]),
    );
  }

  // ── Upload card ───────────────────────────────────────────────────

  Widget _buildUploadCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload PDF',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Choose a PDF containing mathematical formulas.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
              color: const Color(0xFFF8FBFF),
            ),
            child: Column(children: [
              const Icon(Icons.picture_as_pdf,
                  size: 42, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                _selectedFileName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _selectedFileBytes != null
                      ? const Color(0xFF1D4ED8)
                      : Colors.black45,
                  fontWeight: _selectedFileBytes != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.folder_open, size: 17),
                      label: const Text('Choose PDF'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _uploadPdf,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.cloud_upload, size: 17),
                      label: Text(
                          _isLoading ? 'Analysing…' : 'Upload & Index'),
                    ),
                  ]),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Search card ───────────────────────────────────────────────────

  Widget _buildSearchCard() {
    return _card(
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Search expressions or context…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 14),
        ),
      ),
    );
  }

  // ── Results card ──────────────────────────────────────────────────

  Widget _buildResultsCard() {
    if (_filteredExpressions.isEmpty) {
      return _card(
        child: SizedBox(
          height: 240,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.functions,
                    size: 50, color: Colors.blue.shade200),
                const SizedBox(height: 12),
                const Text(
                  'No expressions yet.\nUpload a PDF to begin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black38),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                'Results (${_filteredExpressions.length})',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              'Page ${_currentPage + 1} / $_totalPages',
              style: const TextStyle(
                  fontSize: 12, color: Colors.black38),
            ),
          ]),
          const SizedBox(height: 12),
          ..._pageItems.map(_buildExpressionTile),
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  // ── Expression tile with LaTeX rendering ─────────────────────────

  Widget _buildExpressionTile(Map<String, dynamic> item) {
    final expression = (item['expression'] ?? '').toString();
    final page = item['pageNumber'] ?? '-';
    final context = (item['context'] ?? '').toString();
    final showContext =
        context.isNotEmpty && context != '(no surrounding context)';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Math rendering box
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF1D4ED8).withOpacity(0.2)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                expression,
                textStyle: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1D4ED8),
                ),
                onErrorFallback: (_) => Text(
                  expression,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.menu_book_outlined,
                size: 13, color: Colors.black38),
            const SizedBox(width: 4),
            Text('Page $page',
                style: const TextStyle(
                    fontSize: 12, color: Colors.black45)),
          ]),
          if (showContext) ...[
            const SizedBox(height: 6),
            Text(
              context,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black54),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ── Pagination bar ────────────────────────────────────────────────

  Widget _buildPagination() {
    const maxButtons = 7;
    final start =
        (_currentPage - maxButtons ~/ 2).clamp(0, (_totalPages - maxButtons).clamp(0, 9999));
    final end = (start + maxButtons).clamp(0, _totalPages);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous
          _pageBtn(
            icon: Icons.chevron_left,
            onTap: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
          ),
          const SizedBox(width: 4),
          // Numbered buttons
          for (int i = start; i < end; i++)
            _pageNumberBtn(i),
          const SizedBox(width: 4),
          // Next
          _pageBtn(
            icon: Icons.chevron_right,
            onTap: _currentPage < _totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _pageNumberBtn(int page) {
    final isActive = _currentPage == page;
    return GestureDetector(
      onTap: () => setState(() => _currentPage = page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1D4ED8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? const Color(0xFF1D4ED8)
                : Colors.black.withOpacity(0.12),
          ),
        ),
        child: Center(
          child: Text(
            '${page + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageBtn(
      {required IconData icon, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: Colors.black.withOpacity(onTap != null ? 0.12 : 0.06)),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? Colors.black54 : Colors.black26),
      ),
    );
  }

  // ── History tab ───────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_historyLoading || !_historyLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(_historyError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 52, color: Colors.blue.shade200),
            const SizedBox(height: 12),
            const Text(
              'No history yet.\nIndex a PDF first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _history.length,
        itemBuilder: (ctx, i) => _buildHistoryEntry(
            _history[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _buildHistoryEntry(Map<String, dynamic> entry) {
    final pdfName = (entry['pdfName'] ?? 'Unknown').toString();
    final count = (entry['count'] ?? 0) as int;
    final expressions =
        List<Map<String, dynamic>>.from(entry['expressions'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(children: [
          const Icon(Icons.picture_as_pdf,
              color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pdfName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        subtitle: Text(
          '$count expression${count == 1 ? '' : 's'} indexed',
          style: const TextStyle(fontSize: 12, color: Colors.black38),
        ),
        children: expressions.take(50).map((e) {
          final expr = (e['expression'] ?? '').toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    'p.${e['pageNumber']}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Math.tex(
                      expr,
                      textStyle: const TextStyle(
                          fontSize: 13, color: Color(0xFF1D4ED8)),
                      onErrorFallback: (_) => Text(
                        expr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Shared card widget ────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}
