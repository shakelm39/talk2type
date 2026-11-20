import 'package:flutter/foundation.dart';
import '../../core/database/history_database.dart';
import '../../data/models/transcription_item.dart';

class HistoryProvider extends ChangeNotifier {
  List<TranscriptionItem> _items = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<TranscriptionItem> get items => _items;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  HistoryProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_searchQuery.trim().isEmpty) {
        _items = await HistoryDatabase.instance.getAllItems();
      } else {
        _items = await HistoryDatabase.instance.searchItems(_searchQuery.trim());
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItem(TranscriptionItem item) async {
    try {
      final id = await HistoryDatabase.instance.insertItem(item);
      final newItem = item.copyWith(id: id);
      _items.insert(0, newItem);
      notifyListeners();
    } catch (e) {
      debugPrint("Error inserting history item: $e");
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await HistoryDatabase.instance.deleteItem(id);
      _items.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting history item: $e");
    }
  }

  Future<void> clearAll() async {
    try {
      await HistoryDatabase.instance.clearAll();
      _items.clear();
      notifyListeners();
    } catch (e) {
      debugPrint("Error clearing history: $e");
    }
  }

  void search(String query) {
    _searchQuery = query;
    loadHistory();
  }
}
